import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luia/models/wish_list.dart'; 

class Contact {
  final String id;
  final String? name;
  final String? contactName;
  final String email;
  final String? avatarUrl;
  final DateTime? nextEventDate;
  final List<WishList> sharedWishLists;

  Contact({
    required this.id,
    this.name,
    this.contactName,
    required this.email,
    this.avatarUrl,
    this.nextEventDate,
    this.sharedWishLists = const [],
  });

  /// Nombre que se debe mostrar en UI: prioridad contactName -> name -> email
  String get displayName => contactName ?? name ?? email;

  factory Contact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Contact(
      id: doc.id,
      name: data['name'] as String?,
      contactName: data['contactName'] as String?,
      email: data['email'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
    );
  }
}