import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/dao/user_dao.dart';
import 'package:luia/utils/message_utils.dart';
// Importa la nueva pantalla de creación

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _signInWithEmailAndPassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await UserAuth.instance.signIn(
        _emailController.text,
        _passwordController.text,
      );

      if(await UserDao().getUserById(UserAuth.instance.getCurrentUser().uid) == null) {
        await UserDao().createUser(_auth.currentUser!.uid, _emailController.text, _auth.currentUser!.displayName ?? "Sin nombre");
      }

    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Usuario o contraseña incorrectos.';
      } else {
        message = 'Error: ${e.message}';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Envia un email de restablecimiento de contraseña usando Firebase
  Future<void> _sendPasswordResetEmail(String email) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserDao().triggerPasswordReset(email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Se ha enviado un email de restablecimiento a $email. Revise su bandeja de entrada.'),
        ));
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Error al enviar el email: ${e.message}';
      if (e.code == 'user-not-found') {
        message = 'No se encontró una cuenta con ese email.';
      }
      if (mounted) {
        setState(() {
          _errorMessage = message;
        });
        log(message);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al procesar solicitud. Inténtelo más tarde.')));
      }
    } catch (e) {
      if (mounted) {
        final msg = 'Error al enviar el email: $e.message';
        setState(() {
          _errorMessage = msg;
        });
        log(msg);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al procesar solicitud. Inténtelo más tarde.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Muestra un diálogo para introducir el email y enviar el email de restablecimiento
  void _showForgotPasswordDialog() {
    final controller = TextEditingController(text: _emailController.text);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recuperar contraseña'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'usuario@ejemplo.com',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = controller.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Introduce un email válido.')));
                  return;
                }
                Navigator.of(context).pop();
                await _sendPasswordResetEmail(email);
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar sesión'),
        backgroundColor: Colors.indigo.shade500,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Bienvenido. Por favor, inicia sesión para continuar.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _signInWithEmailAndPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Iniciar sesión'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _showCreateUserScreen(context);
              },
              child: const Text('¿No tienes una cuenta? Crea una aquí'),
            ),
            // Enlace para recuperar contraseña
            TextButton(
              onPressed: _showForgotPasswordDialog,
              child: const Text('¿Has olvidado tu contraseña?'),
            ),
            if (MessageUtils.hasMessage()) ...[Text(
              MessageUtils.getMessage(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),]
          ],
        ),
      ),
    );
  }

  void _showCreateUserScreen(BuildContext context) async {
    context.go('/login/signup');
  }
}
