import 'package:flutter/material.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/models/wish_list.dart';

class ListCard extends StatelessWidget {
  final WishList wishList;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onAdd; // Nueva opción para añadir un deseo directamente desde la tarjeta

  const ListCard({
    super.key,
    required this.wishList,
    required this.onTap,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
    this.onAdd,
  });

  String _getPrivacyStatus() {
    switch (wishList.privacy) {
      case ListPrivacy.private:
        return 'Privada';
      case ListPrivacy.public:
        return 'Pública (Enlace)';
      case ListPrivacy.shared:
        return 'Compartida con ${wishList.sharedWithContactIds.length} pers.';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool showOptions = wishList.ownerId == UserAuth.instance.getCurrentUser().uid;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  backgroundImage: null,
                  child: (wishList.name.isNotEmpty
                          ? Text((wishList.name.length > 1 ? wishList.name.substring(0, 2) : wishList.name).toUpperCase(),
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold))
                          : const Icon(Icons.card_giftcard, color: Colors.indigo)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.card_giftcard, color: Colors.blueGrey.shade700), // Usar un icono de la lista
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          wishList.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showOptions)...[
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') onEdit();
                            if (value == 'share') onShare();
                            if (value == 'add') onAdd?.call();
                            if (value == 'delete') onDelete();
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'add',
                              child: Text('Añadir deseo'),
                            ),
                            // const PopupMenuItem<String>(
                            //   value: 'share',
                            //   child: Text('Compartir'),
                            // ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      ]
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${wishList.itemCount} deseos',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estado: ${_getPrivacyStatus()}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  // if (wishList.items.isNotEmpty) ...[
                  //   const SizedBox(height: 12),
                  //   Row(
                  //     children: wishList.items
                  //         .take(3)
                  //         .map((item) => Padding(
                  //               padding: const EdgeInsets.only(right: 8.0),
                  //               child: CircleAvatar(
                  //                 radius: 20,
                  //                 backgroundImage: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  //                     ? NetworkImage(item.imageUrl!)
                  //                     : null,
                  //                 child: item.imageUrl == null || item.imageUrl!.isEmpty
                  //                     ? const Icon(Icons.shopping_bag_outlined, size: 20)
                  //                     : null,
                  //               ),
                  //             ))
                  //         .toList(),
                  //   ),
                  // ],
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}