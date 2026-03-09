import 'package:go_router/go_router.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/screens/contacts/contact_list_screen.dart';
import 'package:luia/screens/contacts/create_contact_request_screen.dart';
import 'package:luia/screens/contacts/edit_contact_screen.dart';
import 'package:luia/screens/contacts/friend_list_overview_screen.dart';
import 'package:luia/screens/home_screen.dart';
import 'package:luia/screens/login/create_user_screen.dart';
import 'package:luia/screens/login/login_screen.dart';
import 'package:luia/screens/user/user_profile_screen.dart';
import 'package:luia/screens/wish/my_ihaveit_screen.dart';
import 'package:luia/screens/wish/add_wish_screen.dart';
import 'package:luia/screens/wish/create_edit_list_screen.dart';
import 'package:luia/screens/wish/my_lists_overview_screen.dart';
import 'package:luia/screens/wish/list_detail_screen.dart';
import 'package:luia/screens/wish/wish_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luia/screens/wish/ihaveit_detail_screen.dart';

GoRouter getRouter(UserAuth userAuth) => GoRouter(

  initialLocation: '/home',
  refreshListenable: userAuth, // URL por defecto al abrir la app
  redirect: (context, state) {
    final isLoggedIn = userAuth.isAuthenticated;
    final isGoingToLogin = state.uri.toString() == '/login';
    final isGoingToSignup = state.uri.toString() == '/login/signup';

    // CASO 1: No está logueado y no está en login ni signup -> Mandar a Login
    if (!isLoggedIn && !isGoingToLogin && !isGoingToSignup) {
      return '/login';
    }

    // CASO 2: Ya está logueado e intenta ir al login -> Mandar a Home
    if (isLoggedIn && isGoingToLogin) {
      return '/home';
    }

    if(state.uri.toString() == '/') {
      return '/home';
    }

    // CASO 3: No hace falta redirección
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
      routes: [
        GoRoute(
          path: '/signup',
          builder: (context, state) => const CreateUserScreen(),
        ),
      ],
    ),
    // Home
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: '/signup',
          builder: (context, state) => const CreateUserScreen(),
        ),
        // Perfil de usuario
        GoRoute(
          path: '/profile',
          builder: (context, state) => const UserProfileScreen(),
        ),
        GoRoute(
          path: '/global/:wishItemId/detail',
          builder: (context, state) {
            final wishItemId = state.pathParameters['wishItemId'] ?? '';
            return WishDetailScreen(wishItemId: wishItemId);
          },
        ),
        // Mis items "Los tengo"
        GoRoute(
          path: '/ihaveit',
          builder: (context, state) => const MyIHaveItScreen(),
          routes: [
            GoRoute(
              path: '/:claimId',
              builder: (context, state) {
                final claimId = state.pathParameters['claimId'] ?? '';
                final currentUserId = UserAuth.instance.getCurrentUser().uid;
                final claimRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .collection('ihaveit')
                  .doc(claimId);
                return IHaveItDetailScreen(claimRef: claimRef);
              },
              routes: [
                GoRoute(
                  path: '/detail/:wishListId/:wishItemId',
                  builder: (context, state) {
                    final wishListId = state.pathParameters['wishListId'] ?? '';
                    final wishItemId = state.pathParameters['wishId'] ?? '';
                    return WishDetailScreen(wishListId: wishListId, wishItemId: wishItemId);
                  },
                ),
              ],
            ),
          ],
        ),
        // Contactos
        GoRoute(
          path: '/contacts',
          builder: (context, state) => const ContactsListScreen(),
          routes: [
            GoRoute(
              path: '/add',
              builder: (context, state) => const CreateContactRequestScreen(),
            ),
            GoRoute(
              path: '/:contactId/editFromList',
              builder: (context, state) {
                final contactId = state.pathParameters['contactId'] ?? '';
                return EditContactScreen(contactId: contactId);
              },
            ),
            GoRoute(
              path: '/:contactId',
              builder: (context, state) {
                final contactId = state.pathParameters['contactId'] ?? '';
                return FriendListsOverviewScreen(contactId: contactId);
              },
              routes: [
                GoRoute(
                  path: '/edit',
                  builder: (context, state) {
                    final contactId = state.pathParameters['contactId'] ?? '';
                    return EditContactScreen(contactId: contactId);
                  },
                ),
                GoRoute(
                  path: '/lists/:wishlistId',
                  builder: (context, state) {
                    final contactId = state.pathParameters['contactId'] ?? '';
                    final wishlistId = state.pathParameters['wishlistId'] ?? '';
                    return ListDetailScreen(userId: contactId, wishListId: wishlistId);
                  },
                  routes: [
                    GoRoute(
                      path: '/wishes/:wishId/detail',
                      builder: (context, state) {
                        final contactId = state.pathParameters['contactId'] ?? '';
                        final wishlistId = state.pathParameters['wishlistId'] ?? '';
                        final wishItem = state.pathParameters['wishId'] ?? '';
                        return WishDetailScreen(userId: contactId, wishListId: wishlistId, wishItemId: wishItem);
                      },
                    ),
                  ]
                ),
              ],
            ),
          ],
        ),
        // Listas de deseos (propias)
        GoRoute(
          path: '/wishlists/mine',
          builder: (context, state) => const MyListsOverviewScreen(),
          routes: [
            GoRoute(path: "/add", builder: (context, state) => const CreateEditListScreen()),
            GoRoute(
              path: '/:wishlistId',
              builder: (context, state) {
                final wishListId = state.pathParameters['wishlistId'] ?? '';
                return ListDetailScreen(
                  wishListId: wishListId,
                  userId: UserAuth.instance.getCurrentUser().uid,
                );
              },
              routes: [
                GoRoute(
                  path: '/edit',
                  builder: (context, state) {
                    final wishListId = state.pathParameters['wishlistId'] ?? '';
                    return CreateEditListScreen(wishListId: wishListId);
                  },
                ),

                GoRoute(
                  path: '/wish/add',
                  builder: (context, state) {
                    final wishListId = state.pathParameters['wishlistId'] ?? '';
                    return AddWishScreen(wishListId: wishListId);
                  },
                ),
                GoRoute(
                  path: '/wish/:wishId/detail',
                  builder: (context, state) {
                    final wishListId = state.pathParameters['wishlistId'] ?? '';
                    final wishId = state.pathParameters['wishId'] ?? '';
                    return WishDetailScreen(
                      userId: UserAuth.instance.getCurrentUser().uid,
                      wishListId: wishListId,
                      wishItemId: wishId,
                    );
                  },
                  routes: [
                    GoRoute(path: '/edit', builder: (context, state) {
                      final wishListId = state.pathParameters['wishlistId'] ?? '';
                      final wishId = state.pathParameters['wishId'] ?? '';
                      return AddWishScreen(
                        wishListId: wishListId,
                        wishItemId: wishId,
                      );
                    }),
                  ]
                ),
                GoRoute(
                  path: '/wish/:wishId/editFromList',
                  builder: (context, state) {
                    final wishListId = state.pathParameters['wishlistId'] ?? '';
                    final wishId = state.pathParameters['wishId'] ?? '';
                    return AddWishScreen(
                      wishItemId: wishId,
                      wishListId: wishListId,
                    );
                  },
                ),
              ]
            ),
            GoRoute(
              path: '/:wishlistId/editFromList',
              builder: (context, state) {
                final wishListId = state.pathParameters['wishlistId'] ?? '';
                return CreateEditListScreen(wishListId: wishListId);
              },
            ),
          ],
        ),
      ],
    ),
  ],
);