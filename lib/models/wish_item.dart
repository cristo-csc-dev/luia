import 'package:cloud_firestore/cloud_firestore.dart';

class StoreOption {
  final String name;
  final String productUrl;
  final double price;

  StoreOption({
    required this.name,
    required this.productUrl,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'productUrl': productUrl,
      'price': price,
    };
  }

  factory StoreOption.fromMap(Map<String, dynamic> map) {
    return StoreOption(
      name: map['name'] ?? '',
      productUrl: map['productUrl'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WishItem {
  final String id;
  String name;
  String? productUrl;
  double? estimatedPrice;
  String? suggestedStore;
  String? notes;
  String? imageUrl;
  int priority;
  bool isBought;
  String? boughtById;

  // Nuevo: campos para marcación 'Lo tengo'
  bool isTaken;
  String? claimedBy;
  DateTime? claimedAt;

  List<StoreOption>? storeOptions;

  WishItem({
    required this.id,
    required this.name,
    this.productUrl,
    this.estimatedPrice,
    this.suggestedStore,
    this.notes,
    this.imageUrl,
    this.priority = 3,
    this.isBought = false,
    this.boughtById,
    this.isTaken = false,
    this.claimedBy,
    this.claimedAt,
    this.storeOptions,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'productUrl': productUrl,
      'estimatedPrice': estimatedPrice,
      'suggestedStore': suggestedStore,
      'notes': notes,
      'imageUrl': imageUrl,
      'priority': priority,
      'isBought': isBought,
      'boughtById': boughtById,
      'storeOptions': storeOptions?.map((o) => o.toMap()).toList(),
    };
  }

  static WishItem fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WishItem(
      id: doc.id,
      name: data['name'] ?? '',
      productUrl: data['productUrl'],
      estimatedPrice: (data['estimatedPrice'] != null)
          ? (data['estimatedPrice'] as num).toDouble()
          : null,
      suggestedStore: data['suggestedStore'],
      notes: data['notes'],
      imageUrl: data['imageUrl'],
      priority: data['priority'] ?? 3,
      isBought: data['isBought'] ?? false,
      boughtById: data['boughtById'],
      storeOptions: (data['storeOptions'] as List?)
          ?.map((o) => StoreOption.fromMap(o as Map<String, dynamic>))
          .toList(),
    );
  }
}