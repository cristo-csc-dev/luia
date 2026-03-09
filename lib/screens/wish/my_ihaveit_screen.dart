import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:go_router/go_router.dart';

class MyIHaveItScreen extends StatelessWidget {
  const MyIHaveItScreen({super.key});

@override
  Widget build(BuildContext context) {
    final currentUser = UserAuth.instance.getCurrentUser();
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('ihaveit')
        .orderBy('movedAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Los tengo!'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error al cargar'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No tienes artículos marcados como "Los tengo!"'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = (data['name'] ?? 'Sin nombre').toString();
              final comments = (data['iHaveItComments'] ?? '').toString();
              final imageUrl = (data['imageUrl'] ?? '').toString();

              String dateStr = '';
              final dateVal = data['iHaveItDate'];
              if (dateVal is Timestamp) {
                dateStr = DateFormat.yMMMd().format(dateVal.toDate());
              } else if (dateVal != null) {
                dateStr = dateVal.toString();
              }


              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // Navegar vía GoRouter para mostrar claimId en la URL
                    final claimId = doc.id;
                    context.go('/home/ihaveit/$claimId');
                  },

                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                          child: imageUrl.isEmpty ? Text(name.substring(0, name.length >= 2 ? 2 : 1), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              if (dateStr.isNotEmpty) Text(dateStr, style: TextStyle(color: Colors.grey.shade600)),
                              if (comments.isNotEmpty) Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(comments, style: TextStyle(color: Colors.grey.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
