import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luia/models/wish_item.dart';
import 'package:luia/widgets/catalog_wish_card.dart';

class TagWishesScreen extends StatelessWidget {
  final String tagName;

  const TagWishesScreen({super.key, required this.tagName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('#$tagName')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('all_wishes_global')
            .where('tags', arrayContains: tagName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'No se pudieron cargar los deseos: ${snapshot.error}',
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final wishes = snapshot.data?.docs ?? [];
          if (wishes.isEmpty) {
            return Center(
              child: Text('No hay artículos con la etiqueta "#$tagName".'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 278,
            ),
            itemCount: wishes.length,
            itemBuilder: (context, index) {
              final wishItem = WishItem.fromFirestore(wishes[index]);
              return CatalogWishCard(
                key: ValueKey(wishItem.id),
                wishItem: wishItem,
              );
            },
          );
        },
      ),
    );
  }
}
