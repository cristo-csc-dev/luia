/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import * as logger from "firebase-functions/logger";
import {getFirestore, DocumentSnapshot} from "firebase-admin/firestore";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {QueryDocumentSnapshot} from "firebase-functions/v1/firestore";
import * as nodemailer from "nodemailer";
import * as fs from "fs";
import * as path from "path";

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = getFirestore();

// Interfaces for type safety
interface ItemData {
  [key: string]: unknown;
}

interface ContactRequestData {
  senderUserId: string;
  senderName?: string;
  senderEmail: string;
  recipientUserId: string;
  recipientName?: string;
  recipientEmail: string;
  message?: string;
}

interface NotificationData {
  type: string;
  title: string;
  message?: string;
  senderUserId?: string;
  senderId?: string; // From original JS, for contactAccepted notifications
  senderName?: string;
  senderEmail?: string;
  recipientUserId?: string;
  recipientName?: string;
  recipientEmail?: string;
  status: "pending" | "accepted" | "rejected";
  timestamp: admin.firestore.FieldValue;
  isRead: boolean;
}

interface ContactData {
  name?: string;
  email: string;
  createdAt: admin.firestore.FieldValue;
}

// Escuchamos los cambios en el nivel más profundo: los ítems
export const syncItemsToGlobalList = functions
  .runWith({maxInstances: 10})
  .firestore
  .document("users/{userId}/wishlists/{wishlistId}/items/{itemId}")
  .onWrite(
    async (
      change: functions.Change<DocumentSnapshot>,
      context: functions.EventContext
    ) => {
      const {userId, wishlistId, itemId} = context.params;
      const globalRef = db.collection("all_wishes_global").doc(itemId);

      // 1. Manejo de ELIMINACIÓN
      if (!change.after.exists) {
        await globalRef.delete();
        logger.info(`Ítem ${itemId} eliminado de la lista global.`);
        return;
      }

      // 2. Manejo de CREACIÓN o ACTUALIZACIÓN
      const itemData = change.after.data() as ItemData;
      await globalRef.set(
        {
          ...itemData,
          itemId: itemId,
          originalWishlistId: wishlistId,
          ownerId: userId,
          flattenedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );

      logger.info(
        `Ítem ${itemId} de la lista ${wishlistId} sincronizado globalmente`
      );
    }
  );

export const onNewContactRequest = functions
  .runWith({maxInstances: 10})
  .firestore
  .document("users/{senderUserId}/contactRequests/{recipientUserId}")
  .onCreate(
    async (snap: QueryDocumentSnapshot) => {
      const requestData = snap.data() as ContactRequestData;
      const {
        senderUserId,
        senderName,
        senderEmail,
        recipientUserId,
        recipientName,
        recipientEmail,
        message,
      } = requestData;

      // Use explicit type or simplified object to avoid long line length errors
      const newNotification: NotificationData = {
        type: "contactRequest",
        title: `Nueva solicitud de contacto de ${senderName || ""} (${
          senderEmail || ""
        })`,
        message: message,
        senderUserId: senderUserId,
        senderName: senderName,
        senderEmail: senderEmail,
        recipientUserId: recipientUserId,
        recipientName: recipientName,
        recipientEmail: recipientEmail,
        // status defined in interface allows "pending"
        status: "pending",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      };

      const notificationRef = admin
        .firestore()
        .collection(`users/${recipientUserId}/notifications`);

      await notificationRef.add(newNotification);

      logger.info(
        `Notificación creada para ${recipientUserId} por ${senderUserId}`
      );
    }
  );

export const onContactRequestStatusUpdate = functions
  .runWith({maxInstances: 10})
  .firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onUpdate(
    async (
      change: functions.Change<QueryDocumentSnapshot>,
      context: functions.EventContext
    ) => {
      const before = change.before.data() as NotificationData;
      const after = change.after.data() as NotificationData;

      if (after.type !== "contactRequest" || before.status === after.status) {
        return null;
      }

      const recipientId = context.params.userId;
      const senderId = after.senderUserId;
      const newStatus = after.status;

      if (!senderId) {
        logger.error(
          `ERROR: Notificación ${context.params.notificationId} ` +
          "no tiene senderUserId."
        );
        return null;
      }

      const addedAt = admin.firestore.FieldValue.serverTimestamp();
      const recipientContactData: ContactData = {
        name: after.senderName,
        email: after.senderEmail || "",
        createdAt: addedAt,
      };
      const senderContactData: ContactData = {
        name: after.recipientName,
        email: after.recipientEmail || "",
        createdAt: addedAt,
      };

      if (newStatus === "accepted") {
        await Promise.all([
          admin
            .firestore()
            .doc(`users/${recipientId}/contacts/${senderId}`)
            .set(recipientContactData, {merge: true}),
          admin
            .firestore()
            .doc(`users/${senderId}/contacts/${recipientId}`)
            .set(senderContactData, {merge: true}),
        ]);

        logger.info(
          `Contactos creados (bidireccional) entre ${recipientId} y ${senderId}`
        );

        const recipientContactName =
          after.recipientName || after.recipientEmail;
        const newNotification: Partial<NotificationData> = {
          type: "contactAccepted",
          title: "Solicitud de contacto aceptada",
          message: `${recipientContactName} ha aceptado tu solicitud.`,
          senderId: recipientId,
          status: "pending",
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
        };

        await admin
          .firestore()
          .collection(`users/${senderId}/notifications`)
          .add(newNotification);
      }

      // Eliminar la solicitud de contacto original del remitente
      await admin
        .firestore()
        .doc(`users/${senderId}/contactRequests/${recipientId}`)
        .delete()
        .catch(() => null);

      // Eliminar la notificación procesada del receptor
      await change.after.ref.delete().catch(() => null);

      logger.info(
        `Procesada la actualización de estado a "${newStatus}" ` +
        `para la solicitud de contacto entre ${senderId} y ${recipientId}.`
      );

      return null;
    }
  );

// Configuración de Hostinger
const transporter = nodemailer.createTransport({
  host: "smtp.hostinger.com",
  port: 465,
  secure: true,
  auth: {
    user: "noresponder@luia.app", // Tu email de Hostinger
    pass: "nrspndr@L4pp", // Tu contraseña
  },
});

export const sendWelcomeEmail = functions.auth.user().onCreate(async (user) => {
  const email = user.email;
  if (!email) return null;

  try {
    // Generamos el link oficial de verificación
    const link = await admin.auth().generateEmailVerificationLink(email, {
      url: "https://luia-48689.firebaseapp.com",
      handleCodeInApp: false,
    });

    // ... dentro de tu función onCreate:
    const pathToHtml = path.join(__dirname, "../templates/welcome.html");
    const htmlTemplate = fs.readFileSync(pathToHtml, "utf8");

    // Reemplazas variables (como el link) usando una expresión
    // regular global para todas las ocurrencias
    const finalHtml = htmlTemplate.replace(/{{link}}/g, link);

    // Diseño del correo (Aquí puedes meter TODO el HTML/CSS que quieras)
    const mailOptions = {
      from: "noresponder@luia.app",
      to: email,
      subject: "¡Bienvenido! Activa tu cuenta",
      html: finalHtml,
    };

    await transporter.sendMail(mailOptions);
    console.log("Email enviado con éxito a:", email);
  } catch (error) {
    console.error("Error enviando email:", error);
  }
  return null;
});
