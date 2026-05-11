import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:luia/models/wish_item.dart';
import 'package:luia/widgets/comments_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class CompactWishCard extends StatelessWidget {
  final WishItem wishItem;

  const CompactWishCard({
    super.key,
    required this.wishItem,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              // Navegar al detalle del deseo
              context.go('/home/global/${wishItem.id}/detail');
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Imagen del deseo
                  if (wishItem.imageUrl != null && wishItem.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        wishItem.imageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 24,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.photo_library,
                        color: Colors.grey,
                        size: 24,
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Nombre y botón
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wishItem.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (wishItem.productUrl != null && wishItem.productUrl!.isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(wishItem.productUrl!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Ver en web'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                textStyle: const TextStyle(fontSize: 12),
                                minimumSize: const Size(0, 32), // Permite ancho mínimo
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.comment, size: 18, color: Colors.blue.shade600),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CommentsDialog(wishItem: wishItem),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                Text('${wishItem.commentCount}', style: TextStyle(fontSize: 14, color: Colors.blue.shade600, fontWeight: FontWeight.w500)),
                const SizedBox(width: 16),
                Icon(Icons.list, size: 18, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text('${wishItem.sharedCount}', style: TextStyle(fontSize: 14, color: Colors.green.shade600, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}