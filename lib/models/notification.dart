import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luia/screens/notification/types/notification_type.dart';

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  String senderName;
  String senderEmail;
  String senderUserId;
  String recipientUserId;
  String recipientName;
  String recipientEmail;
  final DateTime timestamp;
  final bool isRead;
  final DocumentReference? contactRef;
  DocumentSnapshot? docRef;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.senderUserId,
    this.senderName = '',
    this.senderEmail = '',
    required this.recipientUserId,
    this.recipientName = '',
    required this.recipientEmail,
    required this.timestamp,
    this.isRead = false,
    this.contactRef,
    this.docRef,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    var type = NotificationType.fromFirestore(data['type']);
    return AppNotification(
      id: doc.id,
      type: type,
      title: type.title,
      message: data['message'] as String,
      recipientUserId: data['recipientUserId'],
      recipientName: data['recipientName'] ?? '',
      recipientEmail: data['recipientEmail'] ?? '',
      senderName: data['senderName'],
      senderEmail: data['senderEmail'],
      senderUserId: data['senderUserId'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] as bool? ?? false,
      docRef: doc,
    );
  }
}

class Sender {
  final String id;
  final String name;
  final String email;

  Sender({
    required this.id,
    required this.name,
    required this.email,
  });

  factory Sender.fromMap(Map<String, dynamic> data) {
    return Sender(
      id: data['uid'] as String,
      name: data['name']?? "Anónimo",
      email: data['email'] as String,
    );
  }
}
