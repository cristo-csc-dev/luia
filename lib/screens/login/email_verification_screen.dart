import 'package:flutter/material.dart';
import 'login_screen.dart'; // Importamos la pantalla de Login

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmación de Cuenta'),
        backgroundColor: Colors.indigo.shade500,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Oculta el botón de retroceso
      ),
      body: Padding( // <-- APLICAMOS EL PADDING AQUÍ
        padding: const EdgeInsets.all(24.0),
        child: Center( // <-- EL CENTER SOLO SE ENCARGA DE CENTRAR
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icono grande de correo
              Icon(
                Icons.mail_lock,
                color: Colors.indigo.shade400,
                size: 100,
              ),
              const SizedBox(height: 30),
              
              // Título
              const Text(
                '¡Registro Exitoso!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),

              // Mensaje de confirmación
              const Text(
                'Hemos enviado un enlace de confirmación a tu correo electrónico. Por favor, revisa tu bandeja de entrada (y la carpeta de spam) para verificar tu cuenta antes de iniciar sesión.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 50),

              // Botón para ir al Login
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navega a la pantalla de Login y elimina todas las rutas anteriores
                    // (incluyendo la de crear usuario)
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: const Text(
                    'Ir a la Pantalla de Inicio de Sesión',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}