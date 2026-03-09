import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType {
  birthday,
  christmas,
  secretSanta,
  wedding,
  babyShower,
  other,
}

class Event {
  final String id;
  String name;
  String description;
  String ownerId;
  DateTime eventDate;
  EventType type;
  List<String> invitedUserIds;
  List<String> participantUserIds;
  Map<String, List<String>> userListsInEvent;
  Map<String, List<String>> userLooseWishesInEvent;

  Event({
    required this.id,
    required this.name,
    this.description = '',
    required this.ownerId,
    required this.eventDate,
    this.type = EventType.other,
    this.invitedUserIds = const [],
    this.participantUserIds = const [],
    this.userListsInEvent = const {},
    this.userLooseWishesInEvent = const {},
  });

  static Event fromMap(String id, Map<String, dynamic> map) {
    return Event(
      id: id,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      ownerId: map['ownerId'] as String,
      eventDate: DateTime.parse(map['eventDate'] as String),
      type: EventType.values.firstWhere(
        (e) => e.toString() == 'EventType.${map['type']}',
        orElse: () => EventType.other,
      ),
      invitedUserIds: List<String>.from(map['invitedUserIds'] as List<dynamic>? ?? []),
      participantUserIds: List<String>.from(map['participantUserIds'] as List<dynamic>? ?? []),
      userListsInEvent: (map['userListsInEvent'] as Map<dynamic, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List<dynamic>)),
          ) ?? {},
      userLooseWishesInEvent: (map['userLooseWishesInEvent'] as Map<dynamic, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List<dynamic>)),
          ) ?? {},
    );
  }

  static Event fromFirestore(String id, DocumentSnapshot event) {
    return Event(
      id: id,
      name: event['name'] as String,
      description: event['description'] as String? ?? '',
      ownerId: event['ownerId'] as String,
      eventDate: DateTime.parse(event['eventDate'] as String),
      type: EventType.values.firstWhere(
        (e) => e.toString() == 'EventType.${event['type']}',
        orElse: () => EventType.other,
      ),
      invitedUserIds: List<String>.from(event['invitedUserIds'] as List<dynamic>? ?? []),
      participantUserIds: List<String>.from(event['participantUserIds'] as List<dynamic>? ?? []),
      userListsInEvent: (event['userListsInEvent'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List<dynamic>)),
          ) ??
          {},
      userLooseWishesInEvent: (event['userLooseWishesInEvent'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List<dynamic>)),
          ) ??
          {},
    );
  }
}