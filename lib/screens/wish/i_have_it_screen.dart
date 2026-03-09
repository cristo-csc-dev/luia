import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:luia/dao/wish_list_dao.dart';
import 'package:luia/utils/simple_image_cropper.dart';
import 'package:luia/utils/webview_capture.dart';
import 'package:uuid/uuid.dart';

class IHaveItScreen extends StatefulWidget {
  final String? wishListId;
  final String? wishItemId;
  final String? sourceUserId; // owner of the original wishlist
  final String? wishItemName;

  const IHaveItScreen({super.key, this.wishListId, this.wishItemId, this.sourceUserId, this.wishItemName});

  @override
  State<IHaveItScreen> createState() => _IHaveItScreenState();
}

class _IHaveItScreenState extends State<IHaveItScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  bool _isLoading = false;
  String? _imageUrl;
  String? _productUrl;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWishItem();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadWishItem() async {
    if (widget.wishListId == null || widget.wishItemId == null) return;
    setState(() => _isLoading = true);
    try {
      final snapshot = await WishlistDao().getWishlistById(widget.wishListId!);
      final itemDoc = await snapshot.reference
          .collection('items')
          .doc(widget.wishItemId)
          .get();
      if (itemDoc.exists) {
        final data = itemDoc.data();
        if (data != null) {
          setState(() {
            _imageUrl = data['imageUrl'];
            _productUrl = data['productUrl'];
            // Si ya hay notas, las ponemos en la descripción si está vacía
            if (_descriptionController.text.isEmpty && data['notes'] != null) {
              _descriptionController.text = data['notes'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading wish item: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateImage(String imageUrl) async {
    setState(() {
      _imageUrl = imageUrl;
    });
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
      final imageRef = storageRef.child('wish_images/$fileName');

      await imageRef.putData(
        croppedBytes,
        SettableMetadata(contentType: 'image/png'),
      );

      final downloadUrl = await imageRef.getDownloadURL();
      _updateImage(downloadUrl);
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¿Cuándo fue?')));
      return;
    }

    // Llamar a DAO para mover el documento
    try {
      if (widget.wishItemId == null || widget.sourceUserId == null || widget.wishListId == null) {
        throw Exception('Faltan identificadores del deseo o lista.');
      }

      final scaffold = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      // Primero actualizamos la imagen si ha cambiado
      if (_imageUrl != null && widget.wishListId != null && widget.wishItemId != null) {
         await WishlistDao().updateItem(widget.wishListId!, widget.wishItemId!, {
           'imageUrl': _imageUrl,
         });
      }

      await WishlistDao().moveItemToIHaveIt(
        sourceUserId: widget.sourceUserId!,
        wishlistId: widget.wishListId!,
        itemId: widget.wishItemId!,
        iHaveItDate: _selectedDate!,
        iHaveItComments: _descriptionController.text.trim(),
      );

      if (!mounted) return;
      scaffold.showSnackBar(const SnackBar(content: Text('Deseo movido a "Lo tengo!"')));
      navigator.pop(true);
    } catch (e) {
      final scaffold = ScaffoldMessenger.of(context);
      scaffold.showSnackBar(SnackBar(content: Text('Error guardando: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lo tengo!'),
        actions: [
          IconButton(
            onPressed: _save,
            tooltip: 'Guardar',
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estructura de imagen idéntica a WishDetailScreen
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  if (_imageUrl != null && _imageUrl!.isNotEmpty)
                    Hero(
                      tag: 'wish_image_${widget.wishItemId}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _imageUrl!,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: double.infinity,
                            height: 220,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, size: 80, color: Colors.grey),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.image, size: 80, color: Colors.grey),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Material(
                      color: Colors.white.withOpacity(0.85),
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                        tooltip: 'Cambiar imagen',
                        onSelected: (value) async {
                          if (value == 'webview') {
                            if (_productUrl != null && _productUrl!.isNotEmpty) {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WebViewCapture(initialUrl: _productUrl!),
                                ),
                              );
                              if (result != null && result is String) {
                                _updateImage(result);
                              }
                            }
                          } else if (value == 'capture') {
                            _showImageSourceOptions();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'webview',
                            enabled: _productUrl != null && _productUrl!.isNotEmpty,
                            child: const Row(
                              children: [
                                Icon(Icons.link),
                                SizedBox(width: 12),
                                Text('Desde enlace'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'capture',
                            child: Row(
                              children: [
                                Icon(Icons.add_a_photo),
                                SizedBox(width: 12),
                                Text('Capturar imagen'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (widget.wishItemName != null) ...[
                Text(
                  widget.wishItemName!,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
              ],
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_selectedDate == null ? '¿Cuándo fue?' : _selectedDate!.toLocal().toString().split(' ')[0]),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Cuéntenos un poco sobre cómo fue :)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Introduce una descripción.';
                  }
                  return null;
                },
                keyboardType: TextInputType.multiline,
                minLines: 4,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
