import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:luia/screens/wish/wish_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class IHaveItDetailScreen extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> claimRef;

  const IHaveItDetailScreen({super.key, required this.claimRef});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: claimRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error al cargar'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data();
          if (data == null) return const Center(child: Text('No encontrado'));

          final name = (data['name'] ?? 'Sin nombre').toString();
          final comments = (data['iHaveItComments'] ?? '').toString();
          final imageUrl = (data['imageUrl'] ?? '').toString();
          String movedAt = '';
          if (data['movedAt'] is Timestamp) movedAt = DateFormat.yMMMd().add_jm().format((data['movedAt'] as Timestamp).toDate());
          String iHaveItDate = '';
          if (data['iHaveItDate'] is Timestamp) iHaveItDate = DateFormat.yMMMd().format((data['iHaveItDate'] as Timestamp).toDate());

          final originalOwner = (data['originalOwnerId'] ?? '').toString();
          final originalWishlist = (data['originalWishlistId'] ?? '').toString();
          final originalWish = (data['originalWishId'] ?? '').toString();
          final productUrl = (data['productUrl'] ?? '').toString();

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 48,
                      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: imageUrl.isEmpty ? Text(name.substring(0, name.length >= 2 ? 2 : 1), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 28, fontWeight: FontWeight.bold)) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (iHaveItDate.isNotEmpty) Text('Fecha obtenida: $iHaveItDate', style: TextStyle(color: Colors.grey.shade700)),
                  if (movedAt.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('Movido: $movedAt', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
                  const SizedBox(height: 12),
                  if (comments.isNotEmpty) Text(comments, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  if (productUrl.isNotEmpty) ...[
                    const Text(
                      'Enlace del Producto',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse(productUrl);
                        await launchUrl(uri);
                      },
                      child: Text(
                        productUrl,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue.shade700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Mostrar ID del deseo original con opción de copiar
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  const SizedBox(height: 20),
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        // Optionally: allow deleting the claim from detail screen
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar'),
                            content: const Text('Eliminar este elemento de "Los tengo"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await claimRef.delete();
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ),
                  ])
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
