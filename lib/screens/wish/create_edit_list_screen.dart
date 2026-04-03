import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/dao/user_dao.dart';
import 'package:luia/dao/wish_list_dao.dart';
import 'package:luia/models/contact.dart';
import 'package:luia/models/wish_list.dart';
import 'package:uuid/uuid.dart';

class CreateEditListScreen extends StatefulWidget {
  final String? wishListId; // Si es null, es una nueva lista; si no, es para editar

  const CreateEditListScreen({super.key, this.wishListId});

  @override
  State<CreateEditListScreen> createState() => _CreateEditListScreenState();
}

class _CreateEditListScreenState extends State<CreateEditListScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;
  WishList? _wishList;
  ListPrivacy _selectedPrivacy = ListPrivacy.private;
  List<String> _selectedContactIds = [];
  List<Contact> _contacts = [];
  int? _selectedIconCodePoint;
  int? _selectedColorValue;
  String? _selectedAssetPath;
  String? _selectedKey;
  final ScrollController _iconScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadContactsAndList();    
  }

  Future<void> _loadContactsAndList() async {
    setState(() {
      _isLoading = true;
    });
    var contacts = await UserDao().getAcceptedContacts();
    WishList? wishList;
    if(widget.wishListId != null) {
      final doc = await WishlistDao().getWishlistById(widget.wishListId!);
      wishList = WishList.fromFirestore(doc);
      final data = doc.data();
      if (data != null && data.containsKey('icon')) {
        _selectedIconCodePoint = data['icon'];
      }
      if (data != null && data.containsKey('iconColor')) {
        _selectedColorValue = data['iconColor'];
      }
      if (data != null && data.containsKey('iconAsset')) {
        _selectedAssetPath = data['iconAsset'];
      }
    }
    setState(() {
      _contacts = contacts;
      _wishList = wishList;
      _nameController = TextEditingController(text: _wishList?.name ?? '');
      _selectedPrivacy = _wishList?.privacy ?? ListPrivacy.private;
      _selectedContactIds = List.from(_wishList?.sharedWithContactIds ?? []);
      _selectedAssetPath = null;
      _selectedKey = _wishList?.iconKey;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconScrollController.dispose();
    super.dispose();
  }

  Future<void> _saveList() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final String id = widget.wishListId ?? const Uuid().v4();

      try {
        if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
          throw Exception('Usuario no autenticado');
        }

        WishlistDao().createOrUpdateWishlist(id, {
          'name': _nameController.text,
          'privacy': _selectedPrivacy.toString().split('.').last,
          'sharedWithContactIds': _selectedPrivacy == ListPrivacy.shared
              ? _selectedContactIds
              : [],
          'ownerId': UserAuth.instance.getCurrentUser().uid,
          'createdAt': FieldValue.serverTimestamp(),
          'iconKey': _selectedKey?? "",
          'itemCount': _wishList?.itemCount ?? 0,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lista ${_nameController.text} ${_wishList == null ? 'creada' : 'actualizada'}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de autenticación: $e')),
        );
        return;
      }

      Navigator.pop(context, _nameController.text); // Devuelve la nueva/actualizada lista
    }
  }

  void _scrollIcons(double offset) {
    if (_iconScrollController.hasClients) {
      _iconScrollController.animateTo(
        _iconScrollController.offset + offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _selectContacts() async {
    // Esto es una simulación. En una app real, abrirías una pantalla
    // para seleccionar contactos de tu base de datos o agenda.

    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Contactos'),
        content: SingleChildScrollView(
          child: Column(
            children: /*availableContactIds*/_contacts.map((contact) {
              final isSelected = _selectedContactIds.contains(contact.id);
              return CheckboxListTile(
                title: Text(contact.name?? '--'),
                subtitle: Text(contact.email),
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedContactIds.add(contact.id);
                    } else {
                      _selectedContactIds.remove(contact.id);
                    }
                  });
                  // Forzar la reconstrucción del AlertDialog para reflejar el cambio
                  (context as Element).markNeedsBuild();
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selectedContactIds),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _selectedContactIds = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_wishList == null ? 'Nueva Lista' : 'Editar Lista'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveList,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: _selectedAssetPath != null 
                      ? Colors.transparent 
                      : (_selectedColorValue != null ? Color(_selectedColorValue!).withOpacity(0.1) : Theme.of(context).colorScheme.primary.withOpacity(0.1)),
                  backgroundImage: _selectedAssetPath != null ? AssetImage(_selectedAssetPath!) : null,
                  child: _selectedAssetPath != null ?
                    Image(image: AssetImage(_selectedAssetPath!))
                    : Icon(
                      Icons.card_giftcard,
                      size: 40,
                      color: _selectedColorValue != null ? Color(_selectedColorValue!) : Theme.of(context).colorScheme.primary,
                    ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('Elige un icono', style: TextStyle(color: Colors.grey))),
              const SizedBox(height: 12),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Lista',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce un nombre para la lista';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 24),
              Text(
                'Privacidad de la Lista:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              RadioListTile<ListPrivacy>(
                title: const Text('Privada (Solo yo)'),
                value: ListPrivacy.private,
                groupValue: _selectedPrivacy,
                onChanged: (value) {
                  setState(() {
                    _selectedPrivacy = value!;
                  });
                },
              ),
              RadioListTile<ListPrivacy>(
                title: const Text('Compartir con Contactos/Grupos específicos'),
                value: ListPrivacy.shared,
                groupValue: _selectedPrivacy,
                onChanged: (value) {
                  setState(() {
                    _selectedPrivacy = value!;
                  });
                },
              ),
              if (_selectedPrivacy == ListPrivacy.shared) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _selectContacts,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Añadir Contactos/Grupos'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _selectedContactIds.map((id) {
                    return Chip(
                      label: Text(_contacts.firstWhere((c) => c.id == id).name ?? '--'),
                      onDeleted: () {
                        setState(() {
                          _selectedContactIds.remove(id);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}