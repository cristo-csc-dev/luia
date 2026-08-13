import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/dao/notification_dao.dart';
import 'package:luia/intent/android_intent.dart';
import 'package:luia/models/wish_item.dart';
import 'package:luia/screens/notification/notification_list_screen.dart';
import 'package:luia/screens/wish/add_wish_screen.dart';
import 'package:luia/screens/wish/tag_wishes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _sharedLink = "{}";
  static const platform = MethodChannel('com.luia/channel');
  StreamSubscription? _notificationCountSubscription;
  StreamSubscription<User?>? _userChangesSubscription;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _pendingRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotificationsCount();
    platform.setMethodCallHandler(_handleMethodCalls);
    _userChangesSubscription = _auth.userChanges().listen((user) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luia'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: _getDrawerHeader(
              UserAuth().isUserAuthenticated()
                  ? UserAuth().getCurrentUser()
                  : null,
            ).currentAccountPicture!,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationListScreen(),
                    ),
                  );
                },
              ),
              if (_pendingRequestsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$_pendingRequestsCount',
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: _buildAppDrawer(),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('all_wishes_global')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final wishesByTag = <String, _TagGroup>{};
          for (final wish in snapshot.data?.docs ?? []) {
            final tags = (wish.data()['tags'] as List?)?.whereType<String>();
            for (final rawTag in tags ?? const <String>[]) {
              final tagName = rawTag.trim();
              if (tagName.isEmpty) continue;
              wishesByTag
                  .putIfAbsent(
                    tagName.toLowerCase(),
                    () => _TagGroup(name: tagName),
                  )
                  .wishes
                  .add(wish);
            }
          }
          final groups = wishesByTag.values.toList()
            ..sort(
              (first, second) =>
                  first.name.toLowerCase().compareTo(second.name.toLowerCase()),
            );
          for (final group in groups) {
            group.wishes.sort((first, second) {
              final firstHasImage = _hasUsableWishImage(first);
              final secondHasImage = _hasUsableWishImage(second);
              if (firstHasImage == secondHasImage) return 0;
              return firstHasImage ? -1 : 1;
            });
          }
          if (groups.isEmpty) {
            return const Center(child: Text('No hay etiquetas disponibles.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final group = groups[index];
              return _TagPanel(tagName: group.name, wishes: group.wishes);
            },
          );
        },
      ),
    );
  }

  void _fetchNotificationsCount() {
    if (UserAuth.instance.isUserAuthenticatedAndVerified()) {
      _notificationCountSubscription = NotificationDao()
          .getNotificationsCount()
          .listen(
            (QuerySnapshot snapshot) {
              if (mounted) {
                // 3. Opcional, pero buena práctica: comprobar 'mounted' antes de setState
                setState(() {
                  _pendingRequestsCount = snapshot.docs.length;
                });
              }
            },
            onError: (error) {
              if (mounted) {
                setState(() {
                  _pendingRequestsCount = 0;
                });
              }
            },
          );
    }
  }

  void _signOut() async {
    UserAuth.instance.signOut();
  }

  Future<void> _handleMethodCalls(MethodCall call) async {
    if (call.method == 'onSharedText') {
      _sharedLink = call.arguments;
      final Map<String, dynamic> jsonData = jsonDecode(_sharedLink);
      dev.log("Received shared text: $jsonData");
      WishItem wishDataItem = getWishItemFromMap(jsonData)!;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddWishScreen(wishItem: wishDataItem),
        ),
      );
    }
  }

  Widget _buildAppDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _getDrawerHeader(
            UserAuth().isUserAuthenticated()
                ? UserAuth().getCurrentUser()
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.indigo),
            title: const Text('Perfil'),
            onTap: () {
              Navigator.pop(context);
              context.go('/home/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.list, color: Colors.indigo),
            title: const Text('Mis listas'),
            onTap: () {
              Navigator.pop(context);
              context.go('/home/wishlists/mine');
            },
          ),
          ListTile(
            leading: const Icon(Icons.card_giftcard, color: Colors.indigo),
            title: const Text('Los tengo!'),
            onTap: () {
              Navigator.pop(context);
              context.go('/home/ihaveit');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.people, color: Colors.indigo),
            title: const Text('Contactos'),
            onTap: () {
              Navigator.pop(context);
              context.go('/home/contacts');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Salir'),
            onTap: () {
              Navigator.pop(context);
              _signOut();
            },
          ),
        ],
      ),
    );
  }

  UserAccountsDrawerHeader _getDrawerHeader(User? user) {
    return UserAccountsDrawerHeader(
      accountName: Text(user?.displayName ?? "Nombre de Usuario"),
      accountEmail: Text(user?.email ?? ""),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white,
        backgroundImage: user?.photoURL != null
            ? NetworkImage(user!.photoURL!)
            : null,
        child: user?.photoURL == null
            ? const Icon(Icons.person_outline, size: 40, color: Colors.blueGrey)
            : null,
      ),
      decoration: const BoxDecoration(color: Colors.blueGrey),
    );
  }

  @override
  void dispose() {
    _notificationCountSubscription?.cancel();
    _userChangesSubscription?.cancel();
    super.dispose();
  }
}

class _TagGroup {
  final String name;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> wishes = [];

  _TagGroup({required this.name});
}

bool _hasUsableWishImage(QueryDocumentSnapshot<Map<String, dynamic>> wish) {
  final imageUrl = wish.data()['imageUrl'] as String?;
  final uri = imageUrl == null ? null : Uri.tryParse(imageUrl.trim());
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

class _TagPanel extends StatelessWidget {
  final String tagName;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> wishes;

  const _TagPanel({required this.tagName, required this.wishes});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TagWishesScreen(tagName: tagName)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#$tagName',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: wishes.length > 10 ? 10 : wishes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      _TagWishThumbnail(globalWish: wishes[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagWishThumbnail extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> globalWish;

  const _TagWishThumbnail({required this.globalWish});

  @override
  Widget build(BuildContext context) {
    final data = globalWish.data();
    final globalWishId = globalWish.id;
    final imageUrl = data['imageUrl'] as String?;
    return _buildThumbnail(
      context,
      globalWishId,
      imageUrl,
      (data['name'] as String?) ?? 'Deseo',
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    String globalWishId,
    String? imageUrl,
    String name,
  ) {
    final uri = imageUrl == null ? null : Uri.tryParse(imageUrl.trim());
    final hasImage =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    return SizedBox(
      width: 108,
      child: InkWell(
        onTap: () => context.go('/home/global/$globalWishId/detail'),
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                        ),
                      )
                    : const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.grey,
                      ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
