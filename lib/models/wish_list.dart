import 'package:cloud_firestore/cloud_firestore.dart';

enum ListPrivacy { 
  
  private, public, shared;

  static ListPrivacy fromString(String value) {
    switch (value.toLowerCase()) {
      case 'private':
        return ListPrivacy.private;
      case 'public':
        return ListPrivacy.public;
      case 'shared':
        return ListPrivacy.shared;
      default:
        throw ArgumentError('Valor de privacidad inválido: $value');
    }
  }
 }

enum WishListFields {
  ownerId, name, privacy, sharedWithContactIds, itemCount;
 }

class WishList {

  String? id;
  String name;
  ListPrivacy privacy;
  int itemCount = 0;
  String ownerId;
  List<String> sharedWithContactIds = [];
  String? iconKey;

  WishList({
    required this.name, 
    required this.privacy, 
    required this.ownerId, 
    this.sharedWithContactIds = const [], 
    this.itemCount = 0,
    this.iconKey,
  });

  factory WishList.fromFirestore(DocumentSnapshot doc) {
    var result = WishList(
      name: doc.get('name'),
      privacy: ListPrivacy.fromString(doc.get('privacy')),
      sharedWithContactIds: doc.get('sharedWithContactIds') != null
          ? List<String>.from(doc.get('sharedWithContactIds'))
          : [],
      ownerId: doc.get('ownerId'),
      itemCount: doc.get('itemCount') ?? 0,
      iconKey: (doc.data() as Map<String,dynamic>).containsKey('iconKey')? doc.get('iconKey') : null,
    );
    result.id = doc.id;
    return result;
  }

  Map<String, dynamic> get data {
    return {
      'name': name,
      'privacy': privacy.toString().split('.').last,
      'sharedWithContactIds': sharedWithContactIds,
      'ownerId': ownerId,
      'itemCount': itemCount,
    };
  }
}