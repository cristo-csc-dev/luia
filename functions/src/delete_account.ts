import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {
  CollectionReference, DocumentData, DocumentReference,
  FieldValue, QueryDocumentSnapshot,
} from "firebase-admin/firestore";

/** Walk a collection in bounded pages, including its nested collections.
 * @param {CollectionReference} collection Collection to visit.
 * @param {Function} visit Callback for each document.
 */
async function walk(
  collection: CollectionReference,
  visit: (doc: QueryDocumentSnapshot) => Promise<void>
): Promise<void> {
  let cursor: QueryDocumentSnapshot | undefined;
  for (;;) {
    let query = collection.orderBy("__name__").limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) return;
    for (const doc of page.docs) {
      for (const child of await doc.ref.listCollections()) {
        await walk(child, visit);
      }
      await visit(doc);
    }
    cursor = page.docs[page.docs.length - 1];
  }
}

/** Extract stored image URLs, including nested store data.
 * @param {DocumentData} data Document contents.
 * @param {Set<string>} urls Output URLs.
 */
function imageUrls(data: DocumentData, urls: Set<string>): void {
  for (const [key, value] of Object.entries(data)) {
    if (typeof value === "string" && /image|photo|avatar/i.test(key)) {
      urls.add(value);
    } else if (value && typeof value === "object" &&
        !(value instanceof admin.firestore.DocumentReference)) {
      imageUrls(value, urls);
    }
  }
}

/** Identify a global catalog entry corresponding to a private item.
 * @param {QueryDocumentSnapshot} doc Private item.
 * @return {string} Catalog ID.
 */
function catalogId(doc: QueryDocumentSnapshot): string {
  const data = doc.data();
  return data.linkToGlobalWishId ?? data.globalWishId ?? doc.id;
}

export const deleteMyAccount = functions
  .runWith({timeoutSeconds: 540, memory: "512MB", maxInstances: 10})
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated", "Debes iniciar sesión."
      );
    }
    if (data?.confirm !== true) {
      throw new functions.https.HttpsError(
        "failed-precondition", "Debes confirmar la eliminación."
      );
    }
    const authTime = Number(context.auth.token.auth_time);
    if (!Number.isFinite(authTime) ||
        Math.abs(Date.now() / 1000 - authTime) > 300) {
      throw new functions.https.HttpsError(
        "unauthenticated", "Vuelve a verificar tu identidad."
      );
    }
    // The target is always derived from the verified token, never client input.
    const uid = context.auth.uid;
    const account = await admin.auth().getUser(uid);
    if (account.disabled) {
      throw new functions.https.HttpsError(
        "unauthenticated", "La cuenta está deshabilitada."
      );
    }
    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    // Keep the profile/tree until cleanup finishes, allowing safe retries.
    await userRef.set({accountDeletionPending: true}, {merge: true});
    const candidates = new Set<string>();
    const retainedImages = new Set<string>();
    const ownedCatalog = new Set<string>();
    const remainingCounts = new Map<string, number>();
    imageUrls((await userRef.get()).data() ?? {}, candidates);
    for (const collection of await userRef.listCollections()) {
      await walk(collection, async (doc) => {
        imageUrls(doc.data(), candidates);
        if (doc.ref.parent.id === "items") ownedCatalog.add(catalogId(doc));
      });
    }

    // Remove personal information copied into other people's records.
    await walk(db.collection("users"), async (doc) => {
      if (doc.ref.path === userRef.path ||
          doc.ref.path.startsWith(`${userRef.path}/`)) return;
      const value = doc.data();
      const collection = doc.ref.parent.id;
      if ((collection === "contacts" && doc.id === uid) ||
          (["contactRequests", "notifications"].includes(collection) &&
          (value.senderUserId === uid || value.recipientUserId === uid ||
           value.senderId === uid || doc.id === uid))) {
        await db.recursiveDelete(doc.ref);
        return;
      }
      const patch: DocumentData = {};
      if (value.originalOwnerId === uid) {
        for (const field of ["originalOwnerId", "originalWishlistId",
          "originalWishId", "originalWishRef"]) {
          patch[field] = FieldValue.delete();
        }
      }
      if (value.claimedBy === uid) {
        patch.claimedBy = FieldValue.delete();
        patch.claimedAt = FieldValue.delete();
        patch.isTaken = false;
      }
      if (value.boughtById === uid) {
        patch.boughtById = FieldValue.delete();
        patch.isBought = false;
      }
      if (Array.isArray(value.sharedWithContactIds) &&
          value.sharedWithContactIds.includes(uid)) {
        patch.sharedWithContactIds = FieldValue.arrayRemove(uid);
      }
      if (Object.keys(patch).length) await doc.ref.update(patch);
      imageUrls(value, retainedImages);
      if (collection === "items") {
        const id = catalogId(doc);
        remainingCounts.set(id, (remainingCounts.get(id) ?? 0) + 1);
      }
    });

    await walk(db.collection("events"), async (doc) => {
      const value = doc.data();
      if (value.ownerId === uid) {
        imageUrls(value, candidates);
        await db.recursiveDelete(doc.ref);
      } else if (doc.ref.parent.id === "events") {
        await doc.ref.update({
          invitedUserIds: FieldValue.arrayRemove(uid),
          participantUserIds: FieldValue.arrayRemove(uid),
          userListsInEvent: Object.fromEntries(Object.entries(
            value.userListsInEvent ?? {}).filter(([key]) => key !== uid)),
          userLooseWishesInEvent: Object.fromEntries(Object.entries(
            value.userLooseWishesInEvent ?? {}).filter(([key]) => key !== uid)),
        });
      }
    });

    const removedGlobals: DocumentReference[] = [];
    await walk(db.collection("all_wishes_global"), async (doc) => {
      const value = doc.data();
      if (doc.ref.parent.id === "comments" && value.userId === uid) {
        await doc.ref.delete();
      } else if (doc.ref.parent.id === "all_wishes_global") {
        if (ownedCatalog.has(doc.id) && !remainingCounts.has(doc.id)) {
          imageUrls(value, candidates);
          removedGlobals.push(doc.ref);
          await db.recursiveDelete(doc.ref);
        } else {
          imageUrls(value, retainedImages);
          const comments = await doc.ref.collection("comments").count().get();
          const patch: DocumentData = {commentCount: comments.data().count};
          if (ownedCatalog.has(doc.id)) {
            patch.sharedCount = remainingCounts.get(doc.id) ?? 0;
          }
          if (value.ownerId === uid) patch.ownerId = FieldValue.delete();
          await doc.ref.update(patch);
        }
      }
    });
    await walk(db.collection("tags"), async (doc) => {
      if (doc.ref.parent.id === "wishes" &&
          removedGlobals.some((ref) => ref.id === doc.id)) {
        await doc.ref.delete();
      } else if (doc.ref.parent.id === "tags") {
        const remaining = await doc.ref.collection("wishes").limit(1).get();
        if (remaining.empty) await doc.ref.delete();
      }
    });

    const bucket = admin.storage().bucket();
    for (const url of candidates) {
      if (retainedImages.has(url)) continue;
      // Never fetch arbitrary URLs or delete files in another bucket.
      let parsed: URL;
      try {
        parsed = new URL(url);
      } catch {
        continue;
      }
      const prefix = `/v0/b/${bucket.name}/o/`;
      if (parsed.hostname !== "firebasestorage.googleapis.com" ||
          !parsed.pathname.startsWith(prefix)) continue;
      const name = decodeURIComponent(parsed.pathname.slice(prefix.length));
      if (!/^(wish_images|contact_images)\//.test(name)) continue;
      await bucket.file(name).delete({ignoreNotFound: true});
    }
    await bucket.deleteFiles({prefix: `user_profiles/${uid}/`});
    if (account.email) {
      await db.collection("reset_password").doc(account.email).delete();
    }
    await db.recursiveDelete(userRef);
    // Authentication is removed last: a failed cleanup can be retried.
    await admin.auth().deleteUser(uid);
    return {deleted: true};
  });
