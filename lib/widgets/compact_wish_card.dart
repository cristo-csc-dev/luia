import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:luia/dao/user_dao.dart';
import 'package:luia/dao/wish_list_dao.dart';
import 'package:luia/models/contact.dart';
import 'package:luia/models/wish_item.dart';
import 'package:luia/models/wish_list.dart';
import 'package:luia/widgets/comments_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class CompactWishCard extends StatelessWidget {
  final WishItem wishItem;

  const CompactWishCard({
    super.key,
    required this.wishItem,
  });

  Future<void> _addToUserList(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para guardar el artículo en tus listas.')),
      );
      return;
    }

    final wishlistsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('wishlists')
        .get();

    if (!context.mounted) return;

    final selectedList = await showDialog<WishList?>(
      context: context,
      builder: (dialogContext) {
        return _AddToListDialog(
          wishItem: wishItem,
          existingLists: wishlistsSnapshot.docs
              .map((doc) => WishList.fromFirestore(doc))
              .toList(),
        );
      },
    );

    if (selectedList == null || selectedList.id == null) return;

    try {
      await WishlistDao().addItem(selectedList.id!, {
        'name': wishItem.name,
        'productUrl': wishItem.productUrl,
        'estimatedPrice': wishItem.estimatedPrice,
        'suggestedStore': wishItem.suggestedStore,
        'notes': wishItem.notes,
        'imageUrl': wishItem.imageUrl,
        'priority': wishItem.priority,
        'isBought': false,
        'isTaken': false,
        'storeOptions': wishItem.storeOptions?.map((option) => option.toMap()).toList(),
        'sourceGlobalWishId': wishItem.id,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Añadido a ${selectedList.name}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    }
  }

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
                IconButton(
                  icon: Icon(Icons.list, size: 18, color: Colors.green.shade600),
                  onPressed: () => _addToUserList(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
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

class _AddToListDialog extends StatefulWidget {
  final WishItem wishItem;
  final List<WishList> existingLists;

  const _AddToListDialog({required this.wishItem, required this.existingLists});

  @override
  State<_AddToListDialog> createState() => _AddToListDialogState();
}

class _AddToListDialogState extends State<_AddToListDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<Contact> _contacts = [];
  ListPrivacy _selectedPrivacy = ListPrivacy.private;
  List<String> _selectedContactIds = [];
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await UserDao().getAcceptedContacts();
    if (!mounted) return;
    setState(() {
      _contacts.addAll(contacts);
    });
  }

  Future<void> _createAndSelectList() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isCreating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final listId = const Uuid().v4();
      await WishlistDao().createOrUpdateWishlist(listId, {
        'name': _nameController.text.trim(),
        'privacy': _selectedPrivacy.toString().split('.').last,
        'sharedWithContactIds': _selectedPrivacy == ListPrivacy.shared ? _selectedContactIds : [],
        'ownerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'itemCount': 0,
      });

      final createdList = WishList(
        id: listId,
        ownerId: user.uid,
        name: _nameController.text.trim(),
        privacy: _selectedPrivacy,
        itemCount: 0,
        sharedWithContactIds: _selectedPrivacy == ListPrivacy.shared ? _selectedContactIds : [],
      );

      if (!mounted) return;
      Navigator.pop(context, createdList);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la lista: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir a una lista'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.existingLists.isNotEmpty) ...[
                const Text('Listas existentes', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...widget.existingLists.map((wishlist) {
                  return ListTile(
                    dense: true,
                    title: Text(wishlist.name),
                    onTap: () => Navigator.pop(context, wishlist),
                  );
                }),
                const Divider(height: 24),
              ],
              const Text('Crear una nueva lista', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la lista',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Introduce un nombre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<ListPrivacy>(
                      title: const Text('Privada'),
                      value: ListPrivacy.private,
                      groupValue: _selectedPrivacy,
                      onChanged: (value) {
                        setState(() => _selectedPrivacy = value!);
                      },
                    ),
                    RadioListTile<ListPrivacy>(
                      title: const Text('Compartida con contactos'),
                      value: ListPrivacy.shared,
                      groupValue: _selectedPrivacy,
                      onChanged: (value) {
                        setState(() => _selectedPrivacy = value!);
                      },
                    ),
                    if (_selectedPrivacy == ListPrivacy.shared) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await showDialog<List<String>>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Seleccionar contactos'),
                              content: SingleChildScrollView(
                                child: Column(
                                  children: _contacts.map((contact) {
                                    final selected = _selectedContactIds.contains(contact.id);
                                    return CheckboxListTile(
                                      value: selected,
                                      title: Text(contact.name ?? '--'),
                                      subtitle: Text(contact.email),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedContactIds.add(contact.id);
                                          } else {
                                            _selectedContactIds.remove(contact.id);
                                          }
                                        });
                                        (dialogContext as Element).markNeedsBuild();
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, _selectedContactIds),
                                  child: const Text('Confirmar'),
                                ),
                              ],
                            ),
                          );
                          if (result != null) {
                            setState(() => _selectedContactIds = result);
                          }
                        },
                        icon: const Icon(Icons.group_add),
                        label: const Text('Añadir contactos'),
                      ),
                      if (_selectedContactIds.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          children: _selectedContactIds.map((id) {
                            final contact = _contacts.firstWhere((c) => c.id == id, orElse: () => Contact(id: id, name: 'Contacto', email: ''));
                            return Chip(label: Text(contact.name ?? '--'));
                          }).toList(),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createAndSelectList,
          child: _isCreating
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Crear y usar'),
        ),
      ],
    );
  }
}