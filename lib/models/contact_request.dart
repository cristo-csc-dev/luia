import 'package:cloud_firestore/cloud_firestore.dart';

class ContactRequest {
    final String id;
    final String senderId;
    final String senderEmail;
    final String senderName;
    final String status;
    final bool read;

    ContactRequest({
      required this.id,
      required this.senderId,
      required this.senderEmail,
      required this.senderName,
      this.read = false,
      this.status = "pending",
    });

    factory ContactRequest.fromFirestore(DocumentSnapshot doc) {
      Map data = doc.data() as Map<String, dynamic>;
      return ContactRequest(
        id: doc.id,
        senderId: data['userId'] ?? '',
        senderEmail: data['email'] ?? 'Usuario desconocido',
        senderName: data['name'] ?? 'Anónimo',
        read: data['read'] ?? false,
        status: data['status'] ?? 'pending',
      );
    }
  }