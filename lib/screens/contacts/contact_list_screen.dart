import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/dao/user_dao.dart';
import 'package:luia/models/contact.dart';
import 'package:luia/widgets/contact_avatar.dart';

class ContactsListScreen extends StatelessWidget {
  const ContactsListScreen({super.key});

  Stream<List<Contact>> _getContactsStream() {
    return UserDao().getAcceptedContactsStream().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Contact.fromFirestore(doc);
      }).toList();
    });
  }

  Widget _buildContent(AsyncSnapshot<List<Contact>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No tienes contactos aún.'),
          );
        }

        var contactsWithSharedLists = snapshot.data!;

        if (contactsWithSharedLists.isEmpty) {
          return const Center(
            child: Text('Nadie ha compartido una lista contigo aún.'),
          );
        }

        return ListView.builder(
          itemCount: contactsWithSharedLists.length,
          itemBuilder: (context, index) {
            final contact = contactsWithSharedLists[index];
            final displayName = (contact.contactName?? contact.name ?? contact.email);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () {
                  context.go('/home/contacts/${contact.id}');
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ContactAvatar(contactId: contact.id, displayName: displayName),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              context.go('/home/contacts/${contact.id}/editFromList');
                            }, 
                            icon: const Icon(Icons.edit)
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          });
  }

  @override
  Widget build(BuildContext context) {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mis Contactos'),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Inicia sesión para ver tus contactos.',
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Contactos'),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Contact>>(
        stream: _getContactsStream(),
        builder: (context, snapshot) {
          return _buildContent(snapshot);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Si estamos en la pestaña de eventos, el FAB crea un evento
          context.go('/home/contacts/add');
        },
        child: Icon(Icons.add), // Icono dinámico
      )
    );
  }
}

