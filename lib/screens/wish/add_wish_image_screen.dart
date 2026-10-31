import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:luia/utils/simple_image_cropper.dart';
import 'package:luia/utils/webview_capture.dart';
import 'package:uuid/uuid.dart';

class AddWishImageScreen extends StatefulWidget {
  final String? productUrl;

  const AddWishImageScreen({super.key, this.productUrl});

  @override
  State<AddWishImageScreen> createState() => _AddWishImageScreenState();
}

class _AddWishImageScreenState extends State<AddWishImageScreen> {
  bool _isLoading = false;

  Future<void> _selectImage({ImageSource? source}) async {
    setState(() => _isLoading = true);
    try {
      String? imageUrl;
      if (source == null) {
        imageUrl = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) =>
                WebViewCapture(initialUrl: widget.productUrl!.trim()),
          ),
        );
      } else {
        final image = await ImagePicker().pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1024,
        );
        if (image == null) return;
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        final croppedBytes = await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(
            builder: (_) => SimpleImageCropper(imageBytes: bytes),
          ),
        );
        if (croppedBytes == null) return;
        final ref = FirebaseStorage.instance.ref().child(
          'wish_images/${const Uuid().v4()}.png',
        );
        await ref.putData(
          croppedBytes,
          SettableMetadata(contentType: 'image/png'),
        );
        imageUrl = await ref.getDownloadURL();
      }
      if (mounted && imageUrl != null && imageUrl.isNotEmpty) {
        Navigator.of(context).pop(imageUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo añadir la imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProductUrl = widget.productUrl?.trim().isNotEmpty ?? false;
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Añadir imagen al deseo')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '¿Quieres añadir una imagen a tu deseo?',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Puedes subir una foto o capturar una imagen desde la web del producto.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _selectImage(source: ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Subir una foto'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _selectImage(source: ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Hacer una foto'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading || !hasProductUrl
                        ? null
                        : () => _selectImage(),
                    icon: const Icon(Icons.language),
                    label: const Text('Capturar desde la web del producto'),
                  ),
                  if (!hasProductUrl)
                    const Text(
                      'Añade la URL del producto en el formulario para capturar desde su web.',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Continuar sin imagen'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
