import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:luia/auth/user_auth.dart';
import 'firebase_options.dart';
import 'package:luia/routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:luia/services/contacts_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Esta es la línea mágica para Flutter
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    // Para ver logs detallados de la red y permisos:
    FirebaseFirestore.setLoggingEnabled(true);
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {

  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    // Escuchar cambios de estado de autenticación para cargar/limpiar contactos
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        ContactsManager.instance.loadForCurrentUser();
        ContactsManager.instance.startRealtimeUpdates();
      } else {
        ContactsManager.instance.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp.router(
      title: 'Luma',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blueGrey,
        ),
      ),
      routerConfig: getRouter(UserAuth.instance),
    );
  }
}