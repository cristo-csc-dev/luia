import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:luia/utils/message_utils.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_busy || !_confirmed) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/login?from=%2Fhome%2Fprofile%2Fdelete-account');
      return;
    }
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: _password.text,
        ),
      );
      await user.getIdToken(true);
      await FirebaseFunctions.instance
          .httpsCallable(
            'deleteMyAccount',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
          )
          .call<void>({'confirm': true});
      _password.clear();
      MessageUtils.setMessage(
        'Se han eliminado tus datos y se ha cerrado tu cuenta de Luia.',
      );
      await FirebaseAuth.instance.signOut();
      router.go('/login');
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = switch (e.code) {
            'wrong-password' ||
            'invalid-credential' => 'La contraseña no es correcta.',
            'too-many-requests' =>
              'Demasiados intentos. Espera unos minutos y vuelve a intentarlo.',
            'network-request-failed' =>
              'Comprueba tu conexión y vuelve a intentarlo.',
            _ =>
              'No se ha podido verificar tu identidad. Vuelve a iniciar sesión.',
          };
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.code == 'unauthenticated'
              ? 'Vuelve a iniciar sesión para confirmar tu identidad.'
              : 'No se ha completado la eliminación. Puedes volver a intentarlo. '
                    'Es posible que parte de los datos ya se haya eliminado.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo confirmar el resultado. '
              'Comprueba tu conexión y vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final errorColor = Theme.of(context).colorScheme.error;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Eliminar cuenta'),
          automaticallyImplyLeading: !_busy,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  Icons.delete_forever_outlined,
                  size: 56,
                  color: errorColor,
                ),
                const SizedBox(height: 24),
                Text(
                  'Eliminar mis datos de la aplicación y cerrar cuenta',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (user == null) ...[
                  const Text('Debes iniciar sesión para eliminar tu cuenta.'),
                  TextButton(
                    onPressed: () => context.go(
                      '/login?from=%2Fhome%2Fprofile%2Fdelete-account',
                    ),
                    child: const Text('Iniciar sesión'),
                  ),
                ] else ...[
                  Text('Cuenta: ${user.email ?? ""}'),
                  const SizedBox(height: 16),
                  const Text(
                    'Esta acción es permanente. Se eliminarán tu perfil, listas, '
                    'contactos, comentarios, eventos propios y los datos asociados a tu cuenta. '
                    'Los productos del catálogo que utilicen otras personas podrán mantenerse sin vinculación contigo.',
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Confirma tu contraseña',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _confirmed,
                    onChanged: _busy
                        ? null
                        : (value) =>
                              setState(() => _confirmed = value ?? false),
                    title: const Text(
                      'Entiendo que perderé mis datos y que esta acción no se puede deshacer.',
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(color: errorColor),
                        semanticsLabel: _error,
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _confirmed && !_busy ? _deleteAccount : null,
                    style: FilledButton.styleFrom(backgroundColor: errorColor),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_forever),
                    label: Text(
                      _busy
                          ? 'Eliminando datos…'
                          : 'Eliminar definitivamente mi cuenta',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/home/profile'),
                    child: const Text('Cancelar y conservar mi cuenta'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
