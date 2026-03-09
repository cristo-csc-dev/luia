import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/models/contact.dart';
import 'package:luia/models/contact_request.dart';
import 'package:luia/models/notification.dart';

class UserDao {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _appId = 'luia'; // Reemplaza con tu ID de app si es diferente

  // Singleton
  static final UserDao _instance = UserDao._internal();
  factory UserDao() => _instance;
  UserDao._internal();

  Future<void> createUser(String userId, String email, String name) async {
    print(FirebaseAuth.instance.currentUser?.uid);
    await _db.collection('users').doc(userId).set({
      'email': email,
      'name': name,
      'email_lowercase': email.toLowerCase(),
      'createdAt': Timestamp.now(),
      'appId': _appId,
    });
  }

  Future<void> updateCurrentUserName(String name) async {
    try {
      await _db
        .collection('users')
        .doc(UserAuth.instance.getCurrentUser().uid)
        .set({"name": name}, SetOptions(merge: true));
    } catch (e) {
      // Devolvemos el error para que el UI pueda manejarlo
      throw Exception('Error al actualizar el usuario: $e');
    }
  }

  Future<DocumentSnapshot?> getUserById(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.exists ? doc : null;
  }

  // Función para enviar una solicitud de contacto
  Future<void> sendContactRequest({
    required String email,
    required String? message,
  }) async {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }

    final recipientsSnapshot = await _db
      .collection('users')
      .where('email_lowercase', isEqualTo: email.toLowerCase())
      .limit(1)
      .get();
    final senderSnapshot = await _db
      .collection('users')
      .doc(UserAuth.instance.getCurrentUser().uid)
      .get();

    if (recipientsSnapshot.docs.isEmpty) {
      throw Exception('No se encontró un usuario con ese email.');
    }

    final recipientDoc = recipientsSnapshot.docs.first;
    final recipientUid = recipientDoc.id;

    if (recipientUid == UserAuth.instance.getCurrentUser().uid) {
      throw Exception('No puedes agregarte a ti mismo como contacto.');
    }

    DocumentReference contactRequestRef = _db
        .collection('users')
        .doc(UserAuth.instance.getCurrentUser().uid)
        .collection('contactRequests')
        .doc(recipientUid);
    DocumentSnapshot doc = await contactRequestRef.get();
    Map<String, dynamic>? data = {};
    if (doc.exists) {
      data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'pending') {
        throw Exception('Ya has enviado una solicitud de contacto a este usuario.');
      } else if (data['status'] == 'accepted') {
        throw Exception('Este usuario ya es tu contacto.');
      } else if (data['status'] == 'blocked') {
        throw Exception('No ha sido posible añadir este contacto.');
      }
    } else {
      data = {
        'senderUserId': UserAuth.instance.getCurrentUser().uid,
        'senderName': senderSnapshot['name'],
        'senderEmail': senderSnapshot['email'],
        'recipientUserId': recipientUid,
        'recipientName': recipientDoc['name'],
        'recipientEmail': recipientDoc['email'],
        'message': message,
        'status': 'pending',
        'requestDate': Timestamp.now(),
        'requestBy': UserAuth.instance.getCurrentUser().uid,
      };
    }
    // Crea un documento con los datos de la solicitud en la subcolección del destinatario
    await contactRequestRef
        .set(data, SetOptions(merge: true));
  }

  // Función para aceptar una solicitud de contacto
  Future<void> _responseContactRequest({
      required String response,
      required AppNotification notification,
    }) async {
    
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }

    return _db.runTransaction((transaction) async {

      var data = {
          'userId': UserAuth.instance.getCurrentUser().uid,
          'name': notification.senderName,
          'email': notification.senderEmail,
          'status': response,
          'requestDate': notification.timestamp,
          'acceptanceDate': Timestamp.now(),
          'requestBy': notification.senderUserId,
          'acceptedBy': UserAuth.instance.getCurrentUser().uid,
        };
      _db
        .collection('users')
        .doc(UserAuth.instance.getCurrentUser().uid)
        .collection('contacts')
        .doc(notification.senderUserId)
        .set(data, SetOptions(merge: true));
       
      data['name'] = notification.recipientName;
      data['email'] = notification.recipientEmail;
      _db
        .collection('users')
        .doc(notification.senderUserId)
        .collection('contacts')
        .doc(UserAuth.instance.getCurrentUser().uid)
        .set(data, SetOptions(merge: true));
      notification.docRef!.reference.delete();
    });
  }

  Future<void> acceptContact({required AppNotification notification}) async {
    return _responseContactRequest(response: "accepted", notification: notification);
  }

  Future<void> declineContact({required AppNotification notification}) async {
    return _responseContactRequest(response: "declined", notification: notification);
  }

  Future<void> blockContact({required AppNotification notification}) async {
    return _responseContactRequest(response: "blocked", notification: notification);
  }

  Future<List<Contact>> getAcceptedContacts() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || !UserAuth.instance.isUserAuthenticatedAndVerified()) {
      return [];
    }

    final contactsSnapshot = await _db
        .collection('users')
        .doc(currentUser.uid)
        .collection('contacts')
        .where('status', isEqualTo: 'accepted')
        .orderBy('name')
        .orderBy('email')
        .get();

    return contactsSnapshot.docs.map((doc) => Contact.fromFirestore(doc)).toList();
  }

  Stream<QuerySnapshot> getAcceptedContactsStream() {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      // Retorna un stream vacío si no hay usuario
      return Stream.empty();
    }

    return _db
        .collection('users')
        .doc(UserAuth.instance.getCurrentUser().uid)
        .collection('contacts')
        .where('status', isEqualTo: 'accepted')
        .orderBy('name')
        .orderBy('email')
        .snapshots();
  }

  // Función para recuperar las solicitudes de contacto pendientes para el usuario actual
  Stream<QuerySnapshot> getPendingRequests() {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      // Retorna un stream vacío si no hay usuario
      return Stream.empty();
    }

    return _db
        .collection('users')
        .doc(UserAuth.instance.getCurrentUser().uid)
        .collection('contacts')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> updateContact(User currentUser, ContactRequest request) async {
    final userContactRef = _db
        .collection('users')
        .doc(currentUser.uid)
        .collection('contacts')
        .doc(request.id);
    
    await userContactRef.update({
      'acceptanceDate': FieldValue.serverTimestamp(),
      'status': 'accepted',
    });
  }

  Future<void> updateContactUserName(Contact contact, String name) async {
    final userContactRef = _db
        .collection('users')
        .doc(UserAuth.instance.getCurrentUser().uid)
        .collection('contacts')
        .doc(contact.id);

    final resolvedName = name.trim().isNotEmpty ? name.trim() : (contact.name ?? '');

    await userContactRef.update({
      'contactName': resolvedName,
    });
  }

  Future<void> updateContactAvatar(Contact contact, String avatarUrl) async {
    final userContactRef = _db
        .collection('users')
        .doc(UserAuth.instance.getCurrentUser().uid)
        .collection('contacts')
        .doc(contact.id);
    
    await userContactRef.update({
      'avatarUrl': avatarUrl,
    });
  }

  void deleteNotification({required AppNotification notification}) {
    notification.docRef!.reference.delete();
  }

  Future<Contact> getContactById(String contactId) async {
    final doc = await _db
      .collection('users')
      .doc(UserAuth.instance.getCurrentUser().uid)
      .collection('contacts')
      .doc(contactId)
      .get();
    return Contact.fromFirestore(doc);
  }
}
