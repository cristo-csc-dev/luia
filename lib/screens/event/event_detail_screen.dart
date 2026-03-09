// lib/screens/event_detail_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/dao/wish_list_dao.dart';
import 'package:luia/models/contact.dart';
import 'package:luia/models/event.dart';
import 'package:luia/models/wish_list.dart'; // Para seleccionar listas existentes
import 'package:luia/models/wish_item.dart'; // Para añadir deseos sueltos
import 'package:luia/screens/wish/add_wish_screen.dart';
import 'package:luia/screens/wish/list_detail_screen.dart'; // Para ver el detalle de una lista
import 'package:luia/screens/event/create_edit_event_screen.dart';

// Simulación de usuario actual y sus listas/deseos
const String currentUserId = 'current_user_id';
// Las listas y deseos globales ya definidas en home_screen.dart
// (userWishLists, contactsWithSharedLists, etc.) se usarían aquí.

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Event _currentEvent;
  List<WishList> userWishLists = []; // Simulación de listas del usuario actual
  List availableContactsForEvents = [];
  List userAssociatedLists = [];

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    // Asegurarse de que el usuario actual es un participante si es el organizador o invitado.
    // Lógica real: si el usuario no es participante, mostrar botón "Unirse al Evento".
    if (!_currentEvent.participantUserIds.contains(currentUserId) && _currentEvent.invitedUserIds.contains(currentUserId)) {
      _currentEvent.participantUserIds.add(currentUserId);
      // Aquí se enviaría la actualización al backend
    }
  }

  void _addContentToEvent() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.playlist_add_check),
                title: const Text('Añadir una Lista Existente'),
                onTap: () {
                  Navigator.pop(context); // Cierra el bottom sheet
                  _selectExistingList();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_shopping_cart),
                title: const Text('Añadir un Deseo Suelto'),
                onTap: () {
                  Navigator.pop(context); // Cierra el bottom sheet
                  _addLooseWish();
                },
              ),
              // Aquí podrías añadir un filtro sobre una lista (ej. solo deseos de X€)
              // ListTile(
              //   leading: const Icon(Icons.filter_list),
              //   title: const Text('Aplicar Filtro a Lista'),
              //   onTap: () {
              //     Navigator.pop(context);
              //     // Lógica para aplicar filtro
              //   },
              // ),
            ],
          ),
        );
      },
    );
  }

  void _selectExistingList() async {
    // Filtrar listas que no estén ya en este evento por el usuario actual
    QuerySnapshot<Map<String, dynamic>> currentUserLists = await WishlistDao().getWishlistsStream(currentUserId);
    List<WishList> availableLists = currentUserLists.docs.map(WishList.fromFirestore).toList();

    final WishList? selectedList = await showDialog<WishList>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar Lista'),
          content: availableLists.isEmpty
              ? const Text('No tienes listas disponibles para añadir.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableLists.length,
                    itemBuilder: (context, index) {
                      final list = availableLists[index];
                      return ListTile(
                        title: Text(list.name),
                        onTap: () => Navigator.pop(context, list),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (selectedList != null) {
      setState(() {
        _currentEvent.userListsInEvent.update(
          currentUserId,
          (existingLists) => existingLists..add(selectedList.id!),
          ifAbsent: () => [selectedList.id!],
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lista "${selectedList.name}" añadida al evento.')));
    }
  }

  void _addLooseWish() async {
    final newWish = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddWishScreen()),
    );
    if (newWish != null && newWish is WishItem) {
      // Necesitamos una forma de almacenar el deseo suelto en una base de datos global
      // o asociarlo al evento directamente si WishItem tiene un eventId.
      // Por simplicidad, aquí lo agregamos a una lista "ficticia" global de deseos sueltos del usuario.
      // En una app real, este deseo suelto se guardaría en tu backend y se asociaría al evento.
      print("Deseo suelto creado: ${newWish.name}");

      setState(() {
        _currentEvent.userLooseWishesInEvent.update(
          currentUserId,
          (existingWishes) => existingWishes..add(newWish.id),
          ifAbsent: () => [newWish.id],
        );
        // También simular que el deseo suelto existe en algún lugar para poder mostrarlo
        // Esto es una simplificación: en una app real, WishItem tendría un ID global
        // y se recuperaría desde el backend.
        if (!userWishLists.any((list) => list.name == 'Deseos Sueltos del Evento')) {
          userWishLists.add(WishList(
            name: 'Deseos Sueltos del Evento',
            privacy: ListPrivacy.private, 
            ownerId: currentUserId,
          ));
        }
        // userWishLists.firstWhere((list) => list.get(WishListFields.name) == 'Deseos Sueltos del Evento').items.add(newWish);
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deseo "${newWish.name}" añadido al evento.')));
    }
  }


  @override
  Widget build(BuildContext context) {
    // En una app real, harías llamadas a tu backend para obtener las listas/deseos reales
    // de cada participante asociados a este evento.
    // Aquí, usamos los datos simulados.

    // Obtener todas las listas y deseos sueltos asociados a este evento por todos los participantes
    final Map<String, List<WishList>> participantLists = {};
    final Map<String, List<WishItem>> participantLooseWishes = {};

    _currentEvent.userListsInEvent.forEach((userId, listIds) {
      final userAssociatedLists = userWishLists.where((list) => listIds.contains(list.id)).toList();
      participantLists[userId] = userAssociatedLists;
    });

    // _currentEvent.userLooseWishesInEvent.forEach((userId, itemIds) {
    //     // Para simplificar, asumimos que los deseos sueltos están "disponibles" globalmente
    //     // En una app real, tendrías una colección de "LooseEventWishes" por ejemplo.
    //     final userAssociatedLooseWishes = userWishLists
    //         .expand((list) => list.items) // Expande todos los ítems de todas las listas
    //         .where((item) => itemIds.contains(item.id))
    //         .toList();
    //     participantLooseWishes[userId] = userAssociatedLooseWishes;
    // });

    // Para esta demo, el "current_user_id" está en la simulación.
    // Esto es solo para la UI, la lógica de backend sería más compleja.
    final bool isOrganizer = _currentEvent.ownerId == currentUserId;
    final bool isParticipant = _currentEvent.participantUserIds.contains(currentUserId);


    return Scaffold(
      appBar: AppBar(
        title: Text(_currentEvent.name),
        actions: [
          if (isOrganizer) // Solo el organizador puede editar el evento
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updatedEvent = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateEditEventScreen(event: _currentEvent),
                  ),
                );
                if (updatedEvent != null && updatedEvent is Event) {
                  setState(() {
                    _currentEvent = updatedEvent;
                  });
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Compartir evento "${_currentEvent.name}"')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fecha: ${_currentEvent.eventDate.toIso8601String().split('T')[0]}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Tipo: ${_currentEvent.type.toString().split('.').last}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _currentEvent.description.isNotEmpty
                  ? _currentEvent.description
                  : 'Sin descripción.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            Text(
              'Participantes (${_currentEvent.participantUserIds.length}):',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            // Mostrar avatares de participantes
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _currentEvent.participantUserIds.map((userId) {
                // Simulación para obtener nombre del contacto
                final contact = Contact(id: userId, name: 'Tú' /* o "Usuario Desconocido" */, email: '');
                return Chip( // Usamos CachedNetworkImage para una carga y caché eficientes de avatares.
                  avatar: CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    child: (contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty)
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: contact.avatarUrl!,
                              placeholder: (context, url) => const SizedBox.shrink(), // Muestra el backgroundColor del avatar mientras carga
                              errorWidget: (context, url, error) => const Icon(Icons.person_outline), // Icono en caso de error
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.person_outline),
                  ),
                  label: Text(contact.name ?? '--'),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Deseos y Listas del Evento:',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (isParticipant) // Solo los participantes pueden añadir contenido
                  ElevatedButton.icon(
                    onPressed: _addContentToEvent,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir Contenido'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Mostrar las listas y deseos de CADA participante
            if (participantLists.isEmpty && participantLooseWishes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Aún no hay deseos o listas añadidas a este evento.'),
                ),
              ),
            ..._currentEvent.participantUserIds.expand((userId) {
              final userName = (userId == currentUserId) ? 'Tú' : availableContactsForEvents.firstWhere((c) => c.id == userId, orElse: () => Contact(id: userId, name: 'Usuario Desconocido', email: '')).name;
              final userEventLists = participantLists[userId] ?? [];
              final userEventLooseWishes = participantLooseWishes[userId] ?? [];

              if (userEventLists.isEmpty && userEventLooseWishes.isEmpty) {
                return <Widget>[]; // No mostrar sección si no tiene contenido
              }

              return <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'Deseos de $userName:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...userEventLists.map((list) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ListTile(
                    leading: const Icon(Icons.list_alt),
                    title: Text(list.name),
                    subtitle: Text('${list.itemCount} deseos'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => ListDetailScreen(userId: UserAuth.instance.getCurrentUser().uid, wishListId: list.id!,), // Se puede ver la lista del evento para regalar
                      ));
                    },
                  ),
                )),
                ...userEventLooseWishes.map((item) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ListTile(
                    leading: const Icon(Icons.shopping_bag_outlined),
                    title: Text(item.name),
                    subtitle: Text(item.estimatedPrice != null ? '${item.estimatedPrice}€' : 'Sin precio'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Puedes navegar a un detalle de deseo suelto si lo necesitas,
                      // o solo mostrarlo aquí. Por ahora, solo es una lista.
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Detalle de deseo suelto: ${item.name}')));
                    },
                  ),
                )),
              ];
            }),
          ],
        ),
      ),
    );
  }
}