import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luia/auth/user_auth.dart';

class ContactRequestDao {
  final _db = FirebaseFirestore.instance;

  Future<void> sendContactRequest({
    required String recipientUserId,
    required String recipientUserName,
  }) async {
    final senderUser = UserAuth.instance.getCurrentUser();
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('User not authenticated');
    }

    final senderUserId = senderUser.uid;
    final senderUserName = senderUser.email ?? 'Usuario Desconocido'; 
    final collectionPath = 'users/$recipientUserId/contactRequests';
    final docRef = _db.collection(collectionPath).doc(senderUserId);

    await docRef.set({
      'senderId': senderUserId,
      'senderName': senderUserName,
      'recipientId': recipientUserId,
      'recipientName': recipientUserName,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}