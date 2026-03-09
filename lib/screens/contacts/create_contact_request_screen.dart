
import 'package:flutter/material.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/dao/user_dao.dart';

class CreateContactRequestScreen extends StatefulWidget {
  const CreateContactRequestScreen({super.key});

  @override
  State<CreateContactRequestScreen> createState() => _CreateContactRequestScreenState();
}

class _CreateContactRequestScreenState extends State<CreateContactRequestScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentUser = UserAuth.instance.getCurrentUser();
    // Asigna el nombre de usuario actual o un alias por defecto
    _nameController.text = currentUser.displayName ?? currentUser.email?? '';

    // Prepara el mensaje por defecto
    final defaultName = currentUser.displayName ?? 'un amigo';
    _messageController.text =
        'Hola, soy $defaultName. ¿Me agregas como wishy-contacto?';
  }

  void _addContact() async {
    // Aquí es donde se conectará con la base de datos o el servicio
    // para añadir el contacto. Por ahora, solo imprimimos los datos.
    final name = _nameController.text;
    final email = _emailController.text;
    final message = _messageController.text;
    
    //try {
      if (name.isNotEmpty && email.isNotEmpty) {
        await UserDao().sendContactRequest(email: email, message: message);
        print('Añadir contacto: $name, $email');
        Navigator.of(context).pop();
      } else {
        // Mostrar un mensaje de error si los campos están vacíos
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, rellena todos los campos.')),
        );
      }
    /*} catch (e, stacktrace) {
      // Manejar errores al enviar la solicitud de contacto
      dev.log('Error al enviar la solicitud de contacto: $e\n$stacktrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((e as Exception).toString())),
      );
    }*/ 
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Contacto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tu nombre o alias',
                  hintText: 'Cómo te verá tu contacto',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce tu nombre o alias.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email del contacto',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce el email del contacto.';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Introduce un email válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Mensaje personalizado (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3, // Define el área de texto de 3 líneas
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _addContact,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Enviar Solicitud'),
              ),
          ],
        ),
      ),
    );
  }
}
