import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:luia/models/wish_item.dart';
import 'package:luia/widgets/comments_dialog.dart';
import 'package:luia/widgets/compact_wish_card.dart';

class CatalogWishCard extends StatelessWidget {
  final WishItem wishItem;

  const CatalogWishCard({super.key, required this.wishItem});

  @override
  Widget build(BuildContext context) {
    final uri = wishItem.imageUrl == null
        ? null
        : Uri.tryParse(wishItem.imageUrl!.trim());
    final hasImage = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.go('/home/global/${wishItem.id}/detail'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: hasImage
                          ? Image.network(
                              wishItem.imageUrl!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey,
                                size: 42,
                              ),
                            )
                          : const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.grey,
                              size: 42,
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    child: Text(
                      wishItem.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Row(
              children: [
                _Action(
                  icon: Icons.comment_outlined,
                  count: wishItem.commentCount,
                  color: Colors.blue.shade600,
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => CommentsDialog(wishItem: wishItem),
                  ),
                ),
                const Spacer(),
                _Action(
                  icon: Icons.playlist_add,
                  count: wishItem.sharedCount,
                  color: Colors.green.shade600,
                  onPressed: () => CompactWishCard.addToUserList(
                    context,
                    wishItem,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback onPressed;

  const _Action({
    required this.icon,
    required this.count,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
