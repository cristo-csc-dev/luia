import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/dao/wish_list_dao.dart';
import 'package:luia/models/contact.dart';
import 'package:luia/models/wish_list.dart';
import 'package:luia/models/wish_item.dart';
import 'package:luia/screens/wish/add_wish_screen.dart';
import 'package:luia/services/contacts_manager.dart';
import 'package:luia/widgets/wish_card.dart';

class ListDetailScreen extends StatefulWidget {
  final String userId;
  final String wishListId;

  const ListDetailScreen({
    super.key,
    required this.userId,
    required this.wishListId,
  });

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {

  WishList? _currentWishList;
  bool _isLoading = false;
  String? _errorMessage;

  // Ordenación
  String? _orderByField = 'priority'; // default: ordenar por prioridad descendente (opciones: 'priority', 'name')
  bool _descending = true; // por defecto descendente (ej: prioridad: mayor primero)

  @override
  void initState() {
    super.initState();
    _getWishList(widget.wishListId);
  }

  void _getWishList(String wishListId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final doc = await WishlistDao().getContactWishlistById(widget.wishListId, widget.userId);
      if (!doc.exists) {
        setState(() {
          _currentWishList = null;
          _isLoading = false;
          _errorMessage = 'Lista no encontrada o no compartida.';
        });
        return;
      }
      WishList wishList = WishList.fromFirestore(doc);
      setState(() {
        _currentWishList = wishList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _currentWishList = null;
        _isLoading = false;
        _errorMessage = 'Error al cargar la lista: $e';
      });
    }
  }

  /// Construye el botón de ordenación con indicador de dirección
  Widget _buildSortButton({required IconData icon, required String label, required String field}) {
    final isActive = _orderByField == field;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (_orderByField == field) {
                // Toggle order
                _descending = !_descending;
              } else {
                _orderByField = field;
                _descending = true; // default: descending
              }
            });
          },
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: isActive ? null : Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: isActive ? Colors.white : null),
                if (isActive)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Icon(
                      _descending ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 12,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  void _addWishItem() async {
    final newWish = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddWishScreen(wishListId: _currentWishList!.id),
      ),
    );
    if (newWish != null && newWish is WishItem) {
      setState(() {
        WishlistDao().addItem(_currentWishList!.id!, newWish.toMap());
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deseo "${newWish.name}" añadido.')));
    }
  }

  void _editWishItem(QueryDocumentSnapshot wishItem) async {
    final updatedWish = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddWishScreen(
          wishItemId: wishItem.id,
          wishListId: _currentWishList!.id,
        ),
      ),
    );
    if (updatedWish != null && updatedWish is WishItem) {
      setState(() {
        wishItem.reference.update(updatedWish.toMap());
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deseo "${updatedWish.name}" actualizado.')));
    }
  }

  void _deleteWishItem(QuerySnapshot<Object?> wishItemList, int index) {
    final wishItem = wishItemList.docs[index];
    final WishItem wishItemObj = WishItem.fromFirestore(wishItem);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Deseo'),
          content: Text('¿Estás seguro de que quieres eliminar "${wishItemObj.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  WishlistDao().removeItem(_currentWishList!.id!, wishItem.id);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deseo "${wishItemObj.name}" eliminado.')));
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Contact? contact = ContactsManager.instance.getById(widget.userId);
    return Scaffold(
      appBar: AppBar(
        title: Text('"${_currentWishList?.name ?? ""}" ${contact != null? "creada por ${contact.displayName}" : ""}'),
      ),
      floatingActionButton: (_currentWishList != null && _currentWishList!.ownerId == UserAuth.instance.getCurrentUser().uid)
        ? FloatingActionButton(
            onPressed: _addWishItem,
            child: const Icon(Icons.add),
          )
        : null,
      body: _isLoading
          ? Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : (_currentWishList == null)
            ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage ?? 'Lista no encontrada.')))
            : Column(
              children: [
                // Botones de ordenación centrados
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSortButton(
                        icon: Icons.flag,
                        label: 'Prioridad',
                        field: 'priority',
                      ),
                      const SizedBox(width: 24),
                      _buildSortButton(
                        icon: Icons.sort_by_alpha,
                        label: 'Nombre',
                        field: 'name',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: WishlistDao().getListItems(
                      widget.userId,
                      _currentWishList!,
                      orderByField: _orderByField,
                      descending: _descending,
                      includeTaken: widget.userId == UserAuth.instance.getCurrentUser().uid,
                    ),
                    builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Esta lista no tiene deseos aún.'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final itemDoc = snapshot.data!.docs[index];
                    WishItem item = WishItem.fromFirestore(itemDoc);
                    return WishCard(
                      wishItem: item,
                      wishList: _currentWishList!,
                      // isForGifting: widget.isForGifting,
                      onEdit: () => _currentWishList?.ownerId == UserAuth.instance.getCurrentUser().uid? _editWishItem(itemDoc): null,
                      onDelete: () => _currentWishList?.ownerId == UserAuth.instance.getCurrentUser().uid? _deleteWishItem(snapshot.data!, index): null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}