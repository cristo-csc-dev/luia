import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:luia/dao/user_dao.dart';
import 'package:luia/models/contact.dart';
import 'package:luia/utils/simple_image_cropper.dart';
import 'package:luia/widgets/contact_avatar.dart';

class EditContactScreen extends StatefulWidget {

  final String contactId;

  const EditContactScreen({super.key, required this.contactId});

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _displayEmailController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  Contact? _contact;

  @override
  void initState() {
    super.initState();
    _getContact();
  }

  void _getContact() async {
    setState(() {
      _isLoading = true;
    });
    try {
      Contact contact = await UserDao().getContactById(widget.contactId);
      setState(() {
        _contact = contact;
        _displayNameController.text = contact.name ?? '';
        _displayEmailController.text = contact.email;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar el contacto.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _displayEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickImageAndUpload(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
    );

    if (image == null) return;
    final imageBytes = await image.readAsBytes();
    if (!mounted) return;

    final Uint8List? croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => SimpleImageCropper(imageBytes: imageBytes),
      ),
    );

    if (croppedBytes == null) return;

    setState(() => _isLoading = true);
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final String fileName = '${const Uuid().v4()}.jpg';
      final imageRef = storageRef.child('contact_images/$fileName');

      await imageRef.putData(
        croppedBytes,
        SettableMetadata(contentType: 'image/png'),
      );

      final downloadUrl = await imageRef.getDownloadURL();
      if (_contact != null) {
        await UserDao().updateContactAvatar(_contact!, downloadUrl);
        _getContact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir la imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageAndUpload(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Cámara'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageAndUpload(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      if (_contact != null) {
        try {
          await UserDao().updateContactUserName(_contact!, _displayNameController.text.trim());
         
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contacto actualizado con éxito')),
            );
            Navigator.of(context).pop();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al actualizar el contacto: $e')),
            );
          }
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
      ),
      body: _isLoading || _contact == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Avatar del usuario
              Center(
                child: Stack(
                  children: [
                    ContactAvatar(contactId: _contact!.id, displayName: _contact?.name ?? '', radius: ContactAvatar.high),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Campo para el nombre de visualización
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: 'Nombre de usuario',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa tu nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Campo para el email (solo lectura)
              TextFormField(
                controller: _displayEmailController,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa un email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Botón de guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text('Guardar Cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
