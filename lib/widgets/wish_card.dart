import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/models/wish_item.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cross_file/cross_file.dart';
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
  bool _isDuplicating = false;

  Future<void> _duplicateToAnotherList() async {
    final sourceListId = widget.wishList?.id;
    if (!_isOwner || sourceListId == null || _isDuplicating) return;
    setState(() => _isDuplicating = true);
    try {
      final userId = UserAuth.instance.getCurrentUser().uid;
      final snapshot = await WishlistDao().getWishlistsStream(userId);
      if (!mounted) return;
      final lists = snapshot.docs
          .where((doc) => doc.id != sourceListId && doc.data()['ownerId'] == userId)
          .map(WishList.fromFirestore)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (lists.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Crea otra lista para poder duplicar este deseo.'),
        ));
        return;
      }
      final destination = await showDialog<WishList>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Duplicar en otra lista'),
          children: [
            for (final list in lists)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, list),
                child: Text(list.name),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
      if (destination == null || !mounted) return;
      await WishlistDao().duplicateItem(
        sourceWishlistId: sourceListId,
        itemId: widget.wishItem.id,
        destinationWishlistId: destination.id!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deseo duplicado en "${destination.name}".'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo duplicar el deseo: $e'),
      ));
    } finally {
      if (mounted) setState(() => _isDuplicating = false);
    }
  }

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
                      child: SizedBox(
                        width: 80,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              color: Colors.grey.shade100,
                              child: Image.network(
                                wishItem.imageUrl!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(Icons.image,
                                        size: 40, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: 80,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        ),
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
                        if (value == 'share') {
                          final parts = <String>[];
                          parts.add(wishItem.name);
                          // Deep link to the app: use list path when available
                          final baseLink = (wishList != null && (wishList.id?.isNotEmpty ?? false))
                              ? 'https://www.luia.app/list/${wishList.id}/wish/${wishItem.id}'
                              : 'https://www.luia.app/wish/${wishItem.id}';
                          // Add UTM params including content and term
                          final utmParams = {
                            'utm_source': 'share',
                            'utm_medium': 'app',
                            'utm_campaign': 'share_button',
                            'utm_content': (wishList != null) ? 'list_item' : 'global_item',
                            'utm_term': wishItem.id,
                          };
                          final deepLink = Uri.parse(baseLink).replace(queryParameters: utmParams).toString();
                          parts.add(deepLink);
                          // Include notes as additional context (hide productUrl and imageUrl)
                          if (wishItem.notes != null && wishItem.notes!.isNotEmpty) parts.add(wishItem.notes!);
                          final shareText = parts.join('\n');

                          // If there's a remote image, try to download and share it as EXTRA_STREAM
                          try {
                            // Log share text for debugging
                            debugPrint('WishCard: sharing text:\n$shareText');
                            if (wishItem.imageUrl != null && wishItem.imageUrl!.isNotEmpty && wishItem.imageUrl!.startsWith('http')) {
                              final file = await DefaultCacheManager().getSingleFile(wishItem.imageUrl!);
                              final xfile = XFile(file.path);
                              await Share.shareXFiles([xfile], text: shareText, subject: wishItem.name);
                              return;
                            }
                          } catch (e) {
                            // ignore and fallback to text share
                          }

                          debugPrint('WishCard: sharing text (fallback):\n$shareText');
                          await Share.share(shareText, subject: wishItem.name);
                        }
                        if (value == 'edit') widget.onEdit?.call();
                        if (value == 'duplicate') await _duplicateToAnotherList();
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
                              value: 'share',
                              child: Row(children: [Icon(Icons.share), SizedBox(width:12), Text('Compartir')]),
                            ),
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                            PopupMenuItem<String>(
                              value: 'duplicate',
                              enabled: !_isDuplicating,
                              child: const Row(children: [
                                Icon(Icons.copy),
                                SizedBox(width: 12),
                                Text('Duplicar en otra lista'),
                              ]),
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
