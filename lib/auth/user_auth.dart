import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:luia/services/contacts_manager.dart';

class UserAuth extends ChangeNotifier {

  // 1. Creamos una instancia estática privada (la única que existirá)
  static final UserAuth _instance = UserAuth._internal();

  // 2. Constructor privado para evitar que se creen más instancias por error
  // Inicializa el estado a partir de FirebaseAuth y mantiene sincronizado
  UserAuth._internal() {
    // Estado inicial basado en si ya hay usuario persistido
    _isAuthenticated = FirebaseAuth.instance.currentUser != null;

    // Mantener el estado sincronizado y notificar a los listeners (ej. GoRouter)
    FirebaseAuth.instance.authStateChanges().listen((user) {
      final newVal = user != null;
      if (_isAuthenticated != newVal) {
        _isAuthenticated = newVal;
        notifyListeners();
      }
    });
  }

  // 3. Factory para que al llamar AuthService() siempre devuelva la misma instancia
  factory UserAuth() {
    return _instance;
  }
  
  // 4. Getter estático para acceso rápido (Opcional pero recomendado)
  static UserAuth get instance => _instance;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  void logout() {
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<UserCredential> signIn(String user, String password) async {
    UserCredential userCredential = await _getInstance().signInWithEmailAndPassword(
      email: user,
      password: password,
    );
    _isAuthenticated = true;
    notifyListeners();
    return userCredential;
  }

  bool isUserAuthenticated() {
    return _getInstance().currentUser != null;
  }

  bool isUserAuthenticatedAndVerified() {
    if(_getInstance().currentUser != null) {
      return _getInstance().currentUser!.emailVerified;
      // return true;
    }
    return false;
  }

  User getCurrentUser() {
    if (_getInstance().currentUser == null) {
      throw Exception('Usuario no autenticado.');
    }
    return FirebaseAuth.instance.currentUser!;
  }

  FirebaseAuth _getInstance() {
    return FirebaseAuth.instance;
  }

  Future<void> sendEmailVerification(UserCredential userCredential) async  {
    await userCredential.user!.sendEmailVerification();
  }

  void signOut() async {
    await FirebaseAuth.instance.signOut();
    _isAuthenticated = false;
    // Limpiar cache de contactos al cerrar sesión
    ContactsManager.instance.clear();
    notifyListeners();
  }
}