import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/models/wish_item.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:luia/models/wish_list.dart';
import 'package:luia/dao/wish_list_dao.dart';
import 'package:luia/screens/wish/i_have_it_screen.dart';

class WishCard extends StatefulWidget {
  final WishItem wishItem;
  final WishList? wishList;
  final bool isForGifting; // Si esta tarjeta es para el regalador
  final VoidCallback? onMarkAsBought; // Solo si isForGifting es true
  final VoidCallback? onEdit; // Solo si no es forGifting
  final VoidCallback? onDelete; // Solo si no es forGifting

  const WishCard({
    super.key,
    required this.wishItem,
    this.wishList,
    this.isForGifting = false,
    this.onMarkAsBought,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<WishCard> createState() => _WishCardState();
}

class _WishCardState extends State<WishCard> {
  late int _currentPriority;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentPriority = widget.wishItem.priority;
  }

  bool get _isOwner => widget.wishList != null &&
      widget.wishList!.ownerId == UserAuth.instance.getCurrentUser().uid;

  Future<void> _setPriority(int newPriority) async {
    if (!_isOwner) return;
    final oldPriority = _currentPriority;
    setState(() {
      _currentPriority = newPriority;
      _isUpdating = true;
    });

    final wishlistId = widget.wishList?.id ?? '';
    if (wishlistId.isEmpty) {
      setState(() {
        _currentPriority = oldPriority;
        _isUpdating = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lista inválida')));
      return;
    }

    try {
      await WishlistDao().updateItem(wishlistId, widget.wishItem.id, {
        'priority': newPriority,
      });
    } catch (e) {
      setState(() {
        _currentPriority = oldPriority;
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar prioridad: $e')),
        );
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Widget _buildPriorityStars() {
    // Mostrar fila de 5 estrellas; si no es owner, deshabilitadas
    final Color starColor =
        Theme.of(context).appBarTheme.backgroundColor ??
        Theme.of(context).colorScheme.primary;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: List.generate(5, (index) {
          final starIndex = index + 1;
          final filled = starIndex <= _currentPriority;
          return IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: null,
            icon: Icon(
              filled ? Icons.star : Icons.star_border,
              color: starColor,
              size: 18,
            ),
            tooltip: 'Prioridad $starIndex',
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wishItem = widget.wishItem;
    final wishList = widget.wishList;
    bool showOptions = 
        ((wishList?.ownerId?? '') == UserAuth.instance.getCurrentUser().uid);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () async {
          if(wishList == null) {
            context.go(
              '/home/global/${wishItem.id}/detail',
            );
          } else {
            // Si la lista pertenece al usuario actual, usar la ruta de "mis listas"; si no, la de contactos
            if (wishList.ownerId == UserAuth.instance.getCurrentUser().uid) {
              context.go(
                '/home/wishlists/mine/${wishList.id}/wish/${wishItem.id}/detail',
              );
            } else {
              context.go(
                '/home/contacts/${wishList.ownerId}/lists/${wishList.id}/wishes/${wishItem.id}/detail',
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wishItem.imageUrl != null &&
                      wishItem.imageUrl!.isNotEmpty &&
                      wishItem.imageUrl!.startsWith('http'))
                    Hero(
                      tag: 'wish_image_${wishItem.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            Image.network(
                              wishItem.imageUrl!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.image,
                                      size: 40, color: Colors.grey),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Material(
                                color: Colors.white.withOpacity(0.95),
                                shape: const CircleBorder(),
                                elevation: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          const Center(
                            child: Icon(
                              Icons.image,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                wishItem.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (wishItem.isTaken)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Chip(
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  label: const Text('Obtenido'),
                                  avatar: const Icon(Icons.check, size: 16),
                                ),
                              ),
                          ],
                        ),
                        // Prioridad (estrellas) antes del precio
                        _buildPriorityStars(),
                        const SizedBox(height: 4),
                        if (wishItem.estimatedPrice != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              '${wishItem.estimatedPrice!.toStringAsFixed(2)}€',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        if (wishItem.suggestedStore != null &&
                            wishItem.suggestedStore!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              'Tienda: ${wishItem.suggestedStore}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        if (wishItem.notes != null &&
                            wishItem.notes!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Notas: ${wishItem.notes}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if(showOptions)...[
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') widget.onEdit?.call();
                        if (value == 'delete') widget.onDelete?.call();
                        if (value == 'ihaveit') {
                          // Abrir formulario para marcar como 'Lo tengo!'
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => IHaveItScreen(
                                sourceUserId: UserAuth().getCurrentUser().uid,
                                wishListId: wishList?.id ?? '',
                                wishItemId: wishItem.id,
                                wishItemName: wishItem.name,
                              ),
                            ),
                          );
                          if (result != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Deseo marcado como "Lo tengo!"'),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                            if (wishList != null && wishList.ownerId == UserAuth.instance.getCurrentUser().uid)
                              const PopupMenuItem<String>(
                                value: 'ihaveit',
                                child: Text('Lo tengo!'),
                              ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (wishItem.productUrl != null &&
                      wishItem.productUrl!.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (!await launchUrl(Uri.parse(wishItem.productUrl!))) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo abrir el enlace.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Ver en web'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.blueGrey,
                        backgroundColor: Colors.blueGrey.shade50,
                        elevation: 0,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
