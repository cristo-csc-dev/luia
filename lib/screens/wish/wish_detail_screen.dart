import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/dao/wish_list_dao.dart';
import 'package:luia/models/wish_item.dart';
import 'package:luia/models/wish_list.dart'; // Asegúrate de que este import sea correcto
import 'package:uuid/uuid.dart';
import 'package:luia/utils/simple_image_cropper.dart';

import 'package:luia/utils/webview_capture.dart';
import 'package:intl/intl.dart';

class WishDetailScreen extends StatefulWidget {
  final String wishItemId;
  final String? wishListId;
  final String? userId;

  const WishDetailScreen({
    super.key,
    this.userId,
    this.wishListId,
    required this.wishItemId,
  });

  @override
  State<WishDetailScreen> createState() => _WishDetailScreenState();
}

class _WishDetailScreenState extends State<WishDetailScreen> {
  bool _isLoading = false;
  WishItem? _wishItem;
  WishList? _wishList;

  @override
  void initState() {
    super.initState();
    _loadListAndWish();
  }

  void _loadListAndWish() async {
    setState(() {
      _isLoading = true;
    });
    if (widget.wishListId != null) {
      var wishListSnapshot = await WishlistDao().getContactWishlistById(
        widget.wishListId!,
        widget.userId,
      );
      var wishItem = await wishListSnapshot.reference
          .collection("items")
          .doc(widget.wishItemId)
          .get();
      setState(() {
        _wishList = WishList.fromFirestore(wishListSnapshot);
        _wishItem = WishItem.fromFirestore(wishItem);
        _isLoading = false;
      });
    } else {
      var wishItem = await WishlistDao().getGlobalWish(wishItemId: widget.wishItemId);
      setState(() {
        _wishItem = wishItem;
        _isLoading = false;
      });
    }
  }

  // Helper para mostrar un ítem de detalle
  Widget _buildDetailItem(String title, String? value, {bool isUrl = false}) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink(); // No muestra nada si el valor es nulo o vacío
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              if (!isUrl) return;
              final uri = Uri.parse(value);
              await launchUrl(uri);
            },
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: isUrl ? Colors.blue.shade700 : Colors.black87,
                decoration: isUrl
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  // Helper para formatear el precio
  String _formatPrice(double? price) {
    if (price == null) return 'N/A';
    // Se asume la configuración regional española para el símbolo del Euro
    final formatter = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    return formatter.format(price);
  }

  // Helper para generar el widget de prioridad
  Widget _buildPriorityTag(int priority) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < priority ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 32,
        );
      }),
    );
  }

  Future<void> _updateWishImage(String imageUrl) async {
    if (_wishList == null || _wishItem == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Intentar borrar la imagen anterior si existe y es de Firebase Storage
      if (_wishItem!.imageUrl != null && _wishItem!.imageUrl!.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(_wishItem!.imageUrl!);
          await ref.delete();
        } catch (e) {
          // Ignoramos errores si la imagen no es de Firebase o ya no existe
          debugPrint('No se pudo borrar la imagen anterior: $e');
        }
      }

      await WishlistDao().updateItem(
        _wishList!.id!,
        _wishItem!.id,
        {'imageUrl': imageUrl},
      );
      _loadListAndWish(); // Recargar para mostrar la nueva imagen
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar imagen: $e')),
      );
    }
  }

  Future<void> _pickImageAndUpload(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1024);

    if (image == null) return;

    final imageBytes = await image.readAsBytes();

    if (!mounted) return;

    // Navegar a la pantalla de recorte personalizada
    final Uint8List? croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => SimpleImageCropper(imageBytes: imageBytes),
      ),
    );

    if (croppedBytes == null) return; // El usuario canceló el recorte

    setState(() {
      _isLoading = true;
    });

    String? downloadUrl;
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final String fileName = '${const Uuid().v4()}.jpg';
      final imageRef = storageRef.child('wish_images/$fileName');

      // Subir los bytes de la imagen recortada (que están en formato PNG desde el cropper)
      await imageRef.putData(
        croppedBytes,
        SettableMetadata(contentType: 'image/png'),
      );

      downloadUrl = await imageRef.getDownloadURL();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir la imagen: $e')),
        );
      }
    }

    if (downloadUrl != null) {
      await _updateWishImage(downloadUrl);
    } else {
      // If upload failed, hide loader
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Deseo'),
        actions: [
          if (_wishList?.ownerId == UserAuth.instance.getCurrentUser().uid)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // Usamos la ruta de edición dentro de "mis listas"
                context.go(
                  '/home/wishlists/mine/${widget.wishListId}/wish/${widget.wishItemId}/detail/edit',
                );
              },
            ),
        ],
      ),
      body: _isLoading || _wishItem == null
          ? Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen principal del deseo con botones de acción
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        // Contenedor de la imagen
                        if (_wishItem!.imageUrl != null &&
                            _wishItem!.imageUrl!.isNotEmpty &&
                            _wishItem!.imageUrl!.startsWith('http'))
                          Hero(
                            tag: 'wish_image_${_wishItem!.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _wishItem!.imageUrl!,
                                width: double.infinity,
                                height: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: double.infinity,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.image,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
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
                            child: const Icon(
                              Icons.image,
                              size: 80,
                              color: Colors.grey,
                            ),
                          ),

                        // Botones sobre la imagen
                        if (_wishList?.ownerId == UserAuth.instance.getCurrentUser().uid)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                  // Menú para cambiar imagen
                                  Material(
                                    color: Colors.white.withOpacity(0.85),
                                    shape: const CircleBorder(),
                                    elevation: 2,
                                    child: PopupMenuButton<String>(
                                      icon: Icon(Icons.edit,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                      tooltip: 'Cambiar imagen',
                                      onSelected: (value) async {
                                        if (value == 'webview') {
                                          if (_wishItem?.productUrl != null &&
                                              _wishItem!
                                                  .productUrl!.isNotEmpty) {
                                            final result = await Navigator.of(
                                                    context)
                                                .push(
                                              MaterialPageRoute(
                                                builder: (_) => WebViewCapture(
                                                    initialUrl: _wishItem!
                                                        .productUrl!),
                                              ),
                                            );
                                            if (result != null &&
                                                result is String) {
                                              _updateWishImage(result);
                                            }
                                          }
                                        } else if (value == 'capture') {
                                          _showImageSourceOptions();
                                        }
                                      },
                                      itemBuilder: (BuildContext context) =>
                                          <PopupMenuEntry<String>>[
                                        PopupMenuItem<String>(
                                          value: 'webview',
                                          enabled: _wishItem?.productUrl != null && _wishItem!.productUrl!.isNotEmpty,
                                          child: const Row(
                                            children: [
                                              Icon(Icons.link),
                                              SizedBox(width: 12),
                                              Text('Desde enlace'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem<String>(
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
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Título Principal
                    Text(
                      _wishItem!.name,
                      style: Theme.of(context).textTheme.headlineMedium!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // Etiqueta de Prioridad
                    _buildPriorityTag(_wishItem!.priority),
                    const SizedBox(height: 20),

                    // Información del Precio
                    _buildDetailItem(
                      'Precio Estimado',
                      _formatPrice(_wishItem!.estimatedPrice),
                    ),

                    // Información de la Tienda
                    _buildDetailItem(
                      'Tienda Sugerida',
                      _wishItem!.suggestedStore,
                    ),

                    // URL del Producto
                    _buildDetailItem(
                      'Enlace del Producto',
                      _wishItem!.productUrl,
                      isUrl: true,
                    ),

                    // Notas / Detalles
                    if (_wishItem!.notes != null &&
                        _wishItem!.notes!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        "Notas / Detalles",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          _wishItem!.notes!,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ],

                    if (_wishItem!.storeOptions != null &&
                        _wishItem!.storeOptions!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Alternativas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 180,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _wishItem!.storeOptions!.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final option = _wishItem!.storeOptions![index];
                            return SizedBox(
                              width: 200,
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        option.price > 0
                                            ? '${option.price.toStringAsFixed(2)} €'
                                            : 'Precio no especificado',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (option.productUrl.isNotEmpty)
                                        Text(
                                          option.productUrl,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      if (option.productUrl.isNotEmpty)
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              final uri =
                                                  Uri.parse(option.productUrl);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri);
                                              }
                                            },
                                            icon: const Icon(Icons.open_in_new),
                                            label: const Text('Abrir'),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // // Lista a la que pertenece
                    // _buildDetailItem(
                    //   'Perteneciente a la Lista',
                    //   _wishList!.name,
                    // ),
                    const SizedBox(height: 20),

                    // Aquí podrías añadir un botón para volver a editar si lo deseas
                  ],
                ),
              ),
            ),
    );
  }
}
