import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/dao/wish_list_dao.dart';
import 'package:luia/models/comment.dart';
import 'package:luia/models/wish_item.dart';

class CommentsDialog extends StatefulWidget {
  final WishItem wishItem;

  const CommentsDialog({super.key, required this.wishItem});

  @override
  State<CommentsDialog> createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<CommentsDialog> {
  final TextEditingController _commentController = TextEditingController();
  final int _maxLength = 200;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = UserAuth.instance.getCurrentUser();
    if (user == null) return;

    // Obtener nombre del usuario (asumiendo que está en displayName o algo)
    final userName = user.displayName ?? user.email ?? 'Usuario';

    await WishlistDao().addComment(
      wishId: widget.wishItem.id,
      userId: user.uid,
      userName: userName,
      text: text,
    );

    _commentController.clear();
    // El stream se actualizará automáticamente
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Espacio para el botón de cerrar
                const SizedBox(height: 24),
                // Título
                Text(
                  'Comentarios de ${widget.wishItem.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Campo de texto
                TextField(
                  controller: _commentController,
                  maxLength: _maxLength,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Escribe tu comentario...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                // Botón Comentar
                ElevatedButton(
                  onPressed: _addComment,
                  child: const Text('Comentar'),
                ),
                const SizedBox(height: 16),
                // Lista de comentarios
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: WishlistDao().getCommentsStream(widget.wishItem.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text('Error al cargar comentarios'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(child: Text('No hay comentarios aún.'));
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final comment = Comment.fromFirestore(docs[index]);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.userName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatDate(comment.createdAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comment.text,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Botón de cerrar
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min';
    } else {
      return 'Ahora';
    }
  }
}