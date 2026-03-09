import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:luia/dao/user_dao.dart';
import 'package:luia/dao/wish_list_dao.dart';
import 'package:luia/models/contact.dart';
import 'package:luia/models/wish_list.dart';
import 'package:luia/widgets/contact_avatar.dart';
import 'package:luia/widgets/list_card.dart';

class FriendListsOverviewScreen extends StatefulWidget {
  final String contactId;

  const FriendListsOverviewScreen({super.key, required this.contactId});
  
  @override
  State<StatefulWidget> createState() {
    return FriendListOverviewState();
  }
}

class FriendListOverviewState extends State<FriendListsOverviewScreen> {

  Contact? _contact;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getContact();
  }

  void _getContact() async {
    Contact contact = await UserDao().getContactById(widget.contactId);
    if (mounted) {
      setState(() {
        _contact = contact;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _contact?.displayName ?? 'Contacto';
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Listas de $displayName'),
        actions: [
          IconButton(
            onPressed: () {
              if (_contact != null) {
                context.go('/home/contacts/${_contact!.id}/edit');
              }
            },
            icon: const Icon(Icons.edit),
            tooltip: 'Editar contacto',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                ContactAvatar(contactId: widget.contactId, displayName: displayName, radius: ContactAvatar.high),
                // CircleAvatar(
                //   backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                //   radius: 40,
                //   backgroundImage: _contact?.avatarUrl != null && _contact!.avatarUrl!.isNotEmpty
                //       ? NetworkImage(_contact!.avatarUrl!)
                //       : null,
                //   child: _contact?.avatarUrl == null || _contact!.avatarUrl!.isEmpty
                //       ? Text(
                //           displayName.isNotEmpty ? displayName[0].toUpperCase() : '',
                //           style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 30),
                //         )
                //       : null,
                // ),
              ],
            ),
          ),

          _isLoading?
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ):
            _contact != null ? Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: WishlistDao().getSharedWishlistsStreamSnapshot(_contact!.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('¡$displayName no ha compartido ninguna lista contigo aún!'),
                      ),
                    );
                  }

                  final contactSharedLists = docs.map((doc) => WishList.fromFirestore(doc)).toList();

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: contactSharedLists.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (contextItem, index) {
                      final list = contactSharedLists[index];
                      return ListCard(
                        wishList: list,
                        onTap: () {
                          context.go('/home/contacts/${_contact!.id}/lists/${list.id}');
                        },
                        onEdit: () {},
                        onShare: () {},
                        onDelete: () {},
                      );
                    },
                  );
                },
              ),
            ) : const Expanded(child: Center(child: Text('Error al cargar contacto'))),
        ],
      ),
    );
  }
}