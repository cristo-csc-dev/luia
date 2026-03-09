import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:luia/dao/wish_list_dao.dart';
import 'package:luia/models/wish_list.dart';

// Modelo simplificado para los datos iniciales del deseo
class InitialWishData {
  final String name;
  final String url;

  InitialWishData({
    required this.name,
    required this.url,
  });
}

class AddWishToListsScreen extends StatefulWidget {
  final InitialWishData wishData;

  const AddWishToListsScreen({super.key, required this.wishData});

  @override
  State<AddWishToListsScreen> createState() => _AddWishToListsScreenState();
}

class _AddWishToListsScreenState extends State<AddWishToListsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _priceController = TextEditingController();
  final WishlistDao _wishlistDao = WishlistDao();
  
  // Usamos Set para asegurar que las listas seleccionadas sean únicas
  final Set<WishList> _selectedWishlists = {};
  double _price = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _priceController.text = '0.00'; // Valor inicial
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _toggleWishlistSelection(WishList wishlist) {
    setState(() {
      if (_selectedWishlists.contains(wishlist)) {
        _selectedWishlists.remove(wishlist);
      } else {
        _selectedWishlists.add(wishlist);
      }
    });
  }

  Future<void> _saveWish() async {
    if (_selectedWishlists.isEmpty) {
      _showSnackbar('Debes seleccionar al menos una lista.');
      return;
    }
    
    // Validar y parsear el precio
    final priceText = _priceController.text.replaceAll(',', '.');
    final parsedPrice = double.tryParse(priceText);
    
    if (parsedPrice == null) {
      _showSnackbar('Por favor, introduce un precio válido.');
      return;
    }

    setState(() {
      _isLoading = true;
      _price = parsedPrice;
    });

    // TODO: Aquí iría la lógica real para guardar el deseo en cada lista seleccionada
    // (Añadiendo un nuevo documento a la subcolección 'items' de cada Wishlist seleccionada)
    
    try {
      // Simulación de guardado
      await Future.delayed(const Duration(seconds: 2));

      _showSnackbar(
        'Deseo "${widget.wishData.name}" guardado en ${_selectedWishlists.length} listas con precio €${_price.toStringAsFixed(2)}.',
        duration: 3,
      );
      
      // Vuelve a la pantalla principal
      Navigator.of(context).pop();

    } catch (e) {
      _showSnackbar('Error al guardar el deseo: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackbar(String message, {int duration = 2}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: duration),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      return const Center(child: Text('Inicia sesión para ver tus listas.'));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Añadir Deseo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveWish,
          ),
        ],
      ),
      body: Column(
        children: [
          // Sección de Datos Estáticos y Precio Editable
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ficha del Deseo (No editable)
                Card(
                  elevation: 2,
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(
                      widget.wishData.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        // Text('Proveedor: ${widget.wishData.vendor}'),
                        Text('URL: ${widget.wishData.url}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Campo de Precio Editable
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Precio (Opcional)',
                    hintText: 'Ej: 29.99',
                    prefixIcon: Icon(Icons.euro_symbol),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          
          // Separador y Título de Listas
          const Divider(thickness: 1, height: 1),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Selecciona las Listas de Deseos (Min. 1)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
          ),

          // StreamBuilder para la lista scrollable de Wishlists
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _wishlistDao.getWishlistsStreamSnapshot(_auth.currentUser!.uid),
              builder: (context, myWishlistsSnapshot) {
                if (myWishlistsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (myWishlistsSnapshot.hasError) {
                  return Center(
                    child: Text('Error al cargar listas: ${myWishlistsSnapshot.error}'),
                  );
                }

                if (myWishlistsSnapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No has creado ninguna lista de deseos aún.'),
                  );
                }

                return ListView.builder(
                  itemCount: myWishlistsSnapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final wishlist = WishList.fromFirestore(myWishlistsSnapshot.data!.docs[index]);
                    final isSelected = _selectedWishlists.contains(wishlist);

                    return ListTile(
                      title: Text(wishlist.name),
                      subtitle: Text(wishlist.privacy.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? Colors.indigo : Colors.grey,
                      ),
                      onTap: () => _toggleWishlistSelection(wishlist),
                    );
                  },
                );
              },
            ),
          ),
          
          // Botón de Guardar
          Container(
            padding: const EdgeInsets.all(16.0),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveWish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.add_shopping_cart),
              label: Text(_isLoading ? 'Guardando...' : 'Guardar Deseo'),
            ),
          ),
        ],
      ),
    );
  }
}
