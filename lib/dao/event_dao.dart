import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:luia/auth/user_auth.dart';

class EventDao {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton
  static final EventDao _instance = EventDao._internal();
  factory EventDao() => _instance;
  EventDao._internal();

  // Obtiene el stream de datos del usuario actual
  Stream<DocumentSnapshot> getCurrentUserStream() {
    if (UserAuth.instance.isUserAuthenticatedAndVerified()) {
      return _db.collection('users').doc(UserAuth.instance.getCurrentUser().uid).snapshots();
    } else {
      throw Exception('No user is currently signed in.');
    }
  }

  void createOrUpdateEvent(String id, Map<String, Object> map) {
    _db.collection('events').doc(id).set(map, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> getEventsSharedWithMe() {
    final user = _auth.currentUser;
    if (user != null && user.emailVerified) {
      return _db.collection('events').where(
        Filter.or(Filter('invitedUserIds', arrayContains: user.uid), Filter('ownerId', isEqualTo: user.uid))
      ).snapshots();
    } else {
      throw Exception('No user is currently signed in.');
    }
  }
}