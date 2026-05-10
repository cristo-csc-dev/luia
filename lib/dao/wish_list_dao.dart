import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luia/auth/user_auth.dart';
import 'package:luia/models/wish_item.dart';
import 'package:luia/models/wish_list.dart';

class WishlistDao {
  // Patrón Singleton
  static final WishlistDao _instance = WishlistDao._internal();

  factory WishlistDao() {
    return _instance;
  }

  WishlistDao._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getWishlistsStreamSnapshot(String userId) {
    return _db
      .collection('users')
      .doc(userId)
      .collection('wishlists')
      .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getSharedWishlistsStreamSnapshot(String userId) {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }
    return _db
      .collection('users')
      .doc(userId)
      .collection('wishlists')
      .where(
        Filter.and(
          Filter.or(
            Filter('sharedWithContactIds', arrayContains: UserAuth.instance.getCurrentUser().uid),
            Filter('privacy', isEqualTo: 'public')
          ), 
          Filter('ownerId', isEqualTo: userId)
        )
      ).snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getWishlistsStream(String userId) {
    return _db
      .collection('users')
      .doc(userId)
      .collection('wishlists').get();
  }

  Future<String> createWishlist(Map<String, dynamic> wishlistData) async {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }
    try {
      DocumentReference newWishList = await _db
        .collection('users')
        .doc(UserAuth.instance.getCurrentUser().uid)
        .collection('wishlists')
        .add(wishlistData);
      return newWishList.id;
    } catch (e) {
      // Devolvemos el error para que el UI pueda manejarlo
      throw Exception('Error al crear la lista de deseos: $e');
    }
  }

  Future<void> addItem(String wishlistId, Map<String, dynamic> itemData) async {
    try {
      if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
        throw Exception('Usuario no autenticado.');
      }
      await _db.runTransaction((transaction) async {
        final wishlistRef = _db
          .collection('users')
          .doc(UserAuth.instance.getCurrentUser().uid)
          .collection('wishlists').doc(wishlistId);
        CollectionReference itemsRef = wishlistRef.collection('items');

        // Añadimos timestamp para poder ordenar por fecha añadida
        final dataWithTimestamp = Map<String, dynamic>.from(itemData);
        // Asegurarnos de que los campos de 'taken' existen por defecto
        dataWithTimestamp['isTaken'] = dataWithTimestamp['isTaken'] ?? false;
        dataWithTimestamp['createdAt'] = FieldValue.serverTimestamp();

        await itemsRef.add(dataWithTimestamp);
        int itemCount = (await itemsRef.count().get()).count ?? 0;

        transaction.update(wishlistRef, {'itemCount': itemCount});
      });
    } catch (e) {
      // Devolvemos el error para que el UI pueda manejarlo
      throw Exception('Error al agregar el deseo: $e');
    }
  }

  Future<void> updateItem(String wishlistId, String itemId,  Map<String, dynamic> itemData) async {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }
    try {
      await _db
        .collection('users')
        .doc(UserAuth.instance.getCurrentUser().uid)
        .collection('wishlists')
        .doc(wishlistId)
        .collection('items')
        .doc(itemId)
        .set(itemData, SetOptions(merge: true));
    } catch (e) {
      // Devolvemos el error para que el UI pueda manejarlo
      throw Exception('Error al actualizar el deseo: $e');
    }
  }

  Future<void> removeItem(String wishlistId, String itemId) async {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }
    try {
      await _db.runTransaction((transaction) async {
        final wishlistRef = _db
          .collection('users')
          .doc(UserAuth.instance.getCurrentUser().uid)
          .collection('wishlists')
          .doc(wishlistId);
        CollectionReference itemsRef = wishlistRef.collection('items');
        await itemsRef.doc(itemId).delete();

        int itemCount = (await itemsRef.count().get()).count ?? 0;
        transaction.update(wishlistRef, {'itemCount': itemCount});
      });
    } catch (e) {
      // Devolvemos el error para que el UI pueda manejarlo
      throw Exception('Error al eliminar el deseo: $e');
    }
  }

  /// Marca un item como 'taken' y crea un documento de 'claim' en `users/{currentUser}/ihaveit`.
  /// El 'claim' contiene una referencia al wish original y campos `iHaveItDate` y `iHaveItComments`.
  Future<void> moveItemToIHaveIt({
    required String sourceUserId,
    required String wishlistId,
    required String itemId,
    required DateTime iHaveItDate,
    String? iHaveItComments,
  }) async {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }

    try {
      await _db.runTransaction((transaction) async {
        final sourceItemRef = _db
          .collection('users')
          .doc(sourceUserId)
          .collection('wishlists')
          .doc(wishlistId)
          .collection('items')
          .doc(itemId);

        final sourceSnapshot = await transaction.get(sourceItemRef);
        if (!sourceSnapshot.exists) {
          throw Exception('Deseo no encontrado.');
        }

        final sourceData = Map<String, dynamic>.from(sourceSnapshot.data() as Map<String, dynamic>);

        final currentUserId = UserAuth.instance.getCurrentUser().uid;
        final destCollection = _db.collection('users').doc(currentUserId).collection('ihaveit');
        final newDocRef = destCollection.doc();

        // Preparar datos del claim
        final claimData = <String, dynamic>{};
        claimData['iHaveItDate'] = Timestamp.fromDate(iHaveItDate);
        claimData['iHaveItComments'] = iHaveItComments ?? '';
        claimData['originalOwnerId'] = sourceUserId;
        claimData['originalWishlistId'] = wishlistId;
        claimData['originalWishId'] = itemId;
        claimData['originalWishRef'] = sourceItemRef;
        // Incluir algunos campos del deseo original para mostrar en la lista rápidamente
        claimData['name'] = sourceData['name'];
        claimData['imageUrl'] = sourceData['imageUrl'] ?? '';
        claimData['estimatedPrice'] = sourceData['estimatedPrice'];
        claimData['productUrl'] = sourceData['productUrl'] ?? '';
        claimData['suggestedStore'] = sourceData['suggestedStore'] ?? '';
        claimData['priority'] = sourceData['priority'];
        claimData['productUrl'] = sourceData['productUrl'] ?? '';
        claimData['storeOptions'] = sourceData['storeOptions'];
        claimData['movedAt'] = FieldValue.serverTimestamp();

        // Escribir claim
        transaction.set(newDocRef, claimData);

        // Eliminar item original de la wishlist y decrementar el contador en la wishlist
        final wishlistRef = _db
          .collection('users')
          .doc(sourceUserId)
          .collection('wishlists')
          .doc(wishlistId);

        final alreadyTaken = sourceData['isTaken'] == true;
        if (alreadyTaken) {
          throw Exception('El deseo ya fue marcado como obtenido por otra persona.');
        }

        transaction.delete(sourceItemRef);
        transaction.update(wishlistRef, {'itemCount': FieldValue.increment(-1)});
      });
    } catch (e) {
      throw Exception('Error al mover el deseo: $e');
    }
  }

  void createOrUpdateWishlist(String id, Map<String, Object> map) async {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }
    await _db
     .collection('users')
      .doc(UserAuth.instance.getCurrentUser().uid)
      .collection('wishlists')
      .doc(id)
      .set(map, SetOptions(merge: true));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getContactWishlistById(String wishListId, String? userId) async {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }
    String userIdToUse = userId ?? UserAuth.instance.getCurrentUser().uid;
    return await _db
      .collection('users')
      .doc(userIdToUse)
      .collection('wishlists')
      .doc(wishListId)
      .get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getWishlistById(String wishListId) async {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }
    String userIdToUse = UserAuth.instance.getCurrentUser().uid;
    return await _db
      .collection('users')
      .doc(userIdToUse)
      .collection('wishlists')
      .doc(wishListId)
      .get();
  }

  void deleteWishlist(String id) {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }
    _db
      .collection('users')
      .doc(UserAuth.instance.getCurrentUser().uid)
      .collection('wishlists')
      .doc(id)
      .delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getListItems(String userId, WishList currentWishList, {String? orderByField, bool descending = true, bool includeTaken = false}) {
    if (!UserAuth.instance.isUserAuthenticatedAndVerified()) {
      throw Exception('Usuario no autenticado.');
    }

    Query<Map<String, dynamic>> collectionRef = _db
      .collection('users')
      .doc(userId)
      .collection('wishlists')
      .doc(currentWishList.id)
      .collection('items');

    // if (!includeTaken) {
    //   collectionRef = collectionRef.where('isTaken', isEqualTo: false);
    // }

    if (orderByField != null && orderByField.isNotEmpty) {
      return collectionRef.orderBy(orderByField, descending: descending).snapshots();
    }

    return collectionRef.snapshots();
  }

  Future<WishItem> getGlobalWish({required String wishItemId}) async {
    DocumentSnapshot<Map<String, dynamic>> wishMap = await _db.collection('all_wishes_global')
      .doc(wishItemId)
      .get();
    return WishItem.fromFirestore(wishMap);
  }

}