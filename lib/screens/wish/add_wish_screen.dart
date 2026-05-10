import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:luia/dao/wish_list_dao.dart';
import 'package:luia/models/wish_item.dart';
import 'package:uuid/uuid.dart';
import 'package:luia/models/wish_list.dart';

class AddWishScreen extends StatefulWidget {
  final String? wishItemId;
  final String? wishListId;
  final WishItem? wishItem;

  const AddWishScreen({
    super.key,
    this.wishItemId,
    this.wishListId,
    this.wishItem,
  });

  @override
  State<AddWishScreen> createState() => _AddWishScreenState();
}

class _AddWishScreenState extends State<AddWishScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _priceController;
  late TextEditingController _storeController;
  late TextEditingController _notesController;
  late TextEditingController _newListController;
  late TextEditingController _newStoreNameController;
  late TextEditingController _newStoreUrlController;
  late TextEditingController _newStorePriceController;
  List<StoreOption> _storeOptions = [];
  int _selectedPriority = 3; // Default medium priority
  final Set<String> _selectedWishlistIds = {};

  bool _isLoading = false;
  WishItem? _wishItem;
  WishList? _wishList;
  bool _listSelectionError = false;

  @override
  void initState() {
    super.initState();
    _loadListAndWish();
  }

  void _loadListAndWish() async {
    WishList? wishList;
    WishItem? wishItem;

    setState(() {
      _isLoading = true;
    });
    if (widget.wishListId != null) {
      var wishListSnapshot = await WishlistDao().getWishlistById(
        widget.wishListId!,
      );
      wishList = WishList.fromFirestore(wishListSnapshot);
      if (widget.wishItemId != null) {
        var wishItemSnapshot = await wishListSnapshot.reference
            .collection("items")
            .doc(widget.wishItemId)
            .get();
        wishItem = WishItem.fromFirestore(wishItemSnapshot);
      }
    }
    if (widget.wishItem != null) {
      wishItem = widget.wishItem;
    }
    setState(() {
      _wishList = wishList;
      _wishItem = wishItem;
      fillForm();
      _isLoading = false;
    });
  }

  void fillForm() {
    _nameController = TextEditingController(text: _wishItem?.name ?? '');
    _urlController = TextEditingController(text: _wishItem?.productUrl ?? '');
    _priceController = TextEditingController(
      text: _wishItem?.estimatedPrice?.toString() ?? '',
    );
    _storeController = TextEditingController(
      text: _wishItem?.suggestedStore ?? '',
    );
    _notesController = TextEditingController(text: _wishItem?.notes ?? '');
    _newListController = TextEditingController();
    _newListController.addListener(_onNewListNameChanged);
    _selectedPriority = _wishItem?.priority ?? 3;
    _storeOptions = List.from(_wishItem?.storeOptions ?? []);
    _newStoreNameController = TextEditingController();
    _newStoreUrlController = TextEditingController();
    _newStorePriceController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _priceController.dispose();
    _storeController.dispose();
    _notesController.dispose();
    _newListController.removeListener(_onNewListNameChanged);
    _newListController.dispose();
    _newStoreNameController.dispose();
    _newStoreUrlController.dispose();
    _newStorePriceController.dispose();
    super.dispose();
  }

  void _toggleWishlistSelection(String wishlistId) {
    setState(() {
      if (_selectedWishlistIds.contains(wishlistId)) {
        _selectedWishlistIds.remove(wishlistId);
      } else {
        _selectedWishlistIds.add(wishlistId);
      }
      if (_selectedWishlistIds.isNotEmpty && _listSelectionError) {
        _listSelectionError = false;
      }
    });
  }

  void _addStoreOption() {
    final name = _newStoreNameController.text.trim();
    final url = _newStoreUrlController.text.trim();
    final price = double.tryParse(_newStorePriceController.text.trim()) ?? 0.0;

    if (name.isNotEmpty) {
      setState(() {
        _storeOptions.add(StoreOption(name: name, productUrl: url, price: price));
        _newStoreNameController.clear();
        _newStoreUrlController.clear();
        _newStorePriceController.clear();
      });
    }
  }

  void _removeStoreOption(int index) {
    setState(() {
      _storeOptions.removeAt(index);
    });
  }

  void _onNewListNameChanged() {
    if (_newListController.text.trim().isNotEmpty && _listSelectionError) {
      setState(() {
        _listSelectionError = false;
      });
    }
  }

  Future<void> _saveWish() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newListName = _newListController.text.trim();
    // Si no se informó `wishListId` en el widget, es obligatorio seleccionar al menos una lista o crear una nueva.
    if (widget.wishListId == null &&
        _selectedWishlistIds.isEmpty &&
        newListName.isEmpty) {
      setState(() {
        _listSelectionError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Por favor, selecciona al menos una lista o crea una nueva.',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) return;

    final wishItem = WishItem(
      id: _wishItem?.id ?? const Uuid().v4(),
      name: _nameController.text,
      productUrl: _urlController.text,
      estimatedPrice: double.tryParse(_priceController.text),
      suggestedStore: _storeController.text,
      notes: _notesController.text,
      priority: _selectedPriority,
      imageUrl: _wishItem?.imageUrl,
      storeOptions: _storeOptions,
    );

    try {
      final wishlistDao = WishlistDao();
      String? newWishlistId;

      // Create a new list if a name was provided
      if (newListName.isNotEmpty) {
        final newList = WishList(
          name: newListName,
          privacy: ListPrivacy.private,
          ownerId: user.uid,
          itemCount: 0,
        );
        newList.id = await wishlistDao.createWishlist(newList.data);
        newWishlistId = newList.id;
      }

      // If we are editing an existing wish
      if (_wishItem != null && _wishList != null && _wishList!.id != null) {
        await wishlistDao.updateItem(
          _wishList!.id!,
          wishItem.id,
          wishItem.toMap(),
        );
      } else {
        // Adding a new wish to one or more lists
        final allFutures = <Future>[];
        final allListIds = {..._selectedWishlistIds};
        if (newWishlistId != null) {
          allListIds.add(newWishlistId);
        }
        if (_wishList != null && _wishList!.id != null) {
          allListIds.add(_wishList!.id!);
        }
        for (final listId in allListIds) {
          allFutures.add(wishlistDao.addItem(listId, wishItem.toMap()));
        }
        await Future.wait(allFutures);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _wishItem == null
                ? 'Deseo añadido con éxito'
                : 'Deseo actualizado con éxito',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar el deseo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    final wishlistsStreamSnapshot = WishlistDao().getWishlistsStreamSnapshot(
      auth.currentUser!.uid,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_wishItem == null ? 'Añadir Deseo' : 'Editar Deseo'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveWish),
        ],
      ),
      body: _isLoading
          ? Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del Deseo',
                            hintText: 'Ej: Auriculares Bluetooth',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El nombre del deseo es obligatorio';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'URL del Producto (Opcional)',
                            hintText: 'Ej: https://amazon.es/producto',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Precio Estimado (€) (Opcional)',
                            hintText: 'Ej: 79.99',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _storeController,
                          decoration: const InputDecoration(
                            labelText: 'Tienda Sugerida (Opcional)',
                            hintText: 'Ej: Amazon, El Corte Inglés',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notas / Detalles (Opcional)',
                            hintText: 'Ej: Me gustaría en color negro',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'Alternativas',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ..._storeOptions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(option.name),
                              subtitle: Text(
                                '${option.price.toStringAsFixed(2)}€\n${option.productUrl}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeStoreOption(index),
                              ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                        Text(
                          'Añadir alternativa:',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _newStoreNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre de la alternativa',
                                      isDense: true,
                                    ),
                                  ),
                                  TextField(
                                    controller: _newStoreUrlController,
                                    decoration: const InputDecoration(
                                      labelText: 'URL del producto',
                                      isDense: true,
                                    ),
                                  ),
                                  TextField(
                                    controller: _newStorePriceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Precio',
                                      isDense: true,
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _addStoreOption,
                              icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 32),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Prioridad:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return IconButton(
                              iconSize: 36,
                              onPressed: () {
                                setState(() {
                                  _selectedPriority = index + 1;
                                });
                              },
                              icon: Icon(
                                index < _selectedPriority
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                              ),
                            );
                          }),
                        ),
                        Center(
                          child: Text(
                            _getPriorityLabel(_selectedPriority),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        if (_wishList == null) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            'Añadir a Listas de Deseos',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ]),
                    ),
                  ),
                  if (_wishList == null)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: wishlistsStreamSnapshot,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SliverToBoxAdapter(
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError) {
                            return SliverToBoxAdapter(
                              child: Center(
                                child: Text(
                                  'Error al cargar listas: ${snapshot.error}',
                                ),
                              ),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];

                          return SliverList(
                            delegate: SliverChildListDelegate([
                              if (docs.isNotEmpty) ...[
                                const Text(
                                  'Selecciona una o más listas:',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                ...docs.map((doc) {
                                  final wishlist = WishList.fromFirestore(doc);
                                  final isSelected = _selectedWishlistIds
                                      .contains(wishlist.id);
                                  return CheckboxListTile(
                                    title: Text(wishlist.name),
                                    subtitle: Text(wishlist.privacy.name),
                                    value: isSelected,
                                    onChanged: (_) =>
                                        _toggleWishlistSelection(wishlist.id!),
                                    activeColor: Colors.indigo,
                                  );
                                }),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 16),
                              ],
                              Text(
                                docs.isEmpty
                                    ? 'Crea tu primera lista:'
                                    : 'O crea una nueva:',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _newListController,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre de la nueva lista',
                                  hintText: 'Ej: Regalos de cumpleaños',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) {
                                  final offsetAnimation = Tween<Offset>(
                                    begin: const Offset(0, -0.12),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: offsetAnimation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _listSelectionError
                                    ? Container(
                                        key: const ValueKey('list_error'),
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8.0,
                                          horizontal: 12.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(
                                                context,
                                              ).appBarTheme.backgroundColor ??
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                          borderRadius:
                                              BorderRadius.circular(6.0),
                                        ),
                                        child: Text(
                                          'Selecciona o crea una lista para guardar el deseo',
                                          style: TextStyle(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).appBarTheme.foregroundColor ??
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                          ),
                                        ),
                                      )
                                    : const SizedBox(
                                        key: ValueKey('list_empty'),
                                        height: 0,
                                      ),
                              ),
                              const SizedBox(height: 24), // Espacio al final
                            ]),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'Baja';
      case 2:
        return 'Normal';
      case 3:
        return 'Media';
      case 4:
        return 'Alta';
      case 5:
        return 'Imprescindible';
      default:
        return 'Media';
    }
  }
}
