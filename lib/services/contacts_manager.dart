import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:luia/dao/user_dao.dart';
import 'package:luia/models/contact.dart';

class ContactsManager extends ChangeNotifier {
  static final ContactsManager instance = ContactsManager._internal();
  ContactsManager._internal();

  final Map<String, Contact> _byId = {};
  bool _loading = false;
  String? _loadedForUid;

  StreamSubscription<QuerySnapshot>? _subscription;

  Map<String, Contact> get contactsById => Map.unmodifiable(_byId);
  bool get loading => _loading;
  int get count => _byId.length;

  Contact? getById(String id) => _byId[id];

  /// Carga una vez los contactos aceptados del usuario actual.
  Future<void> loadForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      clear();
      return;
    }

    if (_loadedForUid == user.uid && _byId.isNotEmpty) return;

    _loading = true;
    notifyListeners();

    final contacts = await UserDao().getAcceptedContacts();
    _byId
      ..clear()
      ..addEntries(contacts.map((c) => MapEntry(c.id, c)));
    _loadedForUid = user.uid;

    _loading = false;
    notifyListeners();
  }

  /// Suscribe a los cambios en Firestore para mantener la cache actualizada en tiempo real.
  void startRealtimeUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_subscription != null) return;

    _subscription = UserDao().getAcceptedContactsStream().listen((snapshot) {
      _byId
        ..clear()
        ..addEntries(snapshot.docs.map((d) => MapEntry(d.id, Contact.fromFirestore(d))));
      _loadedForUid = user.uid;
      notifyListeners();
    });
  }

  void stopRealtimeUpdates() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Limpia la cache y detiene la suscripción a cambios en Firestore.
  void clear() {
    stopRealtimeUpdates();
    _byId.clear();
    _loadedForUid = null;
    notifyListeners();
  }
}
