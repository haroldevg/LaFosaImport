import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { pending, ordered, shipped, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Pendiente',
    OrderStatus.ordered => 'Comprado',
    OrderStatus.shipped => 'Enviado',
    OrderStatus.delivered => 'Entregado',
    OrderStatus.cancelled => 'Cancelado',
  };

  bool get isActive =>
      this != OrderStatus.delivered && this != OrderStatus.cancelled;

  static OrderStatus fromName(String name) {
    return OrderStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => OrderStatus.pending,
    );
  }
}

/// One card within a [CardOrder]'s cart. Either tied to a specific seller
/// listing (from the scraper or typed in manually), or just a rough
/// [isReferencePrice] estimate when the user doesn't have a specific listing.
class OrderItem {
  final String cardName;
  final String setName;
  final String condition;
  final String? sellerName;
  final String? listingUrl;
  final double unitPrice;
  final double shipping;
  final int quantity;
  final bool isReferencePrice;

  const OrderItem({
    required this.cardName,
    required this.setName,
    required this.condition,
    required this.unitPrice,
    this.shipping = 0,
    this.quantity = 1,
    this.sellerName,
    this.listingUrl,
    this.isReferencePrice = false,
  });

  /// Unit price × quantity, plus the listing's flat shipping fee (charged
  /// once per line, not per unit).
  double get lineTotal => unitPrice * quantity + shipping;

  Map<String, dynamic> toMap() => {
    'cardName': cardName,
    'setName': setName,
    'condition': condition,
    'sellerName': sellerName,
    'listingUrl': listingUrl,
    'unitPrice': unitPrice,
    'shipping': shipping,
    'quantity': quantity,
    'isReferencePrice': isReferencePrice,
  };

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      cardName: map['cardName'] as String? ?? '',
      setName: map['setName'] as String? ?? '',
      condition: map['condition'] as String? ?? '',
      sellerName: map['sellerName'] as String?,
      listingUrl: map['listingUrl'] as String?,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      shipping: (map['shipping'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      isReferencePrice: map['isReferencePrice'] as bool? ?? false,
    );
  }
}

class CardOrder {
  final String id;
  final String userId;
  final String userDisplayName;
  final List<OrderItem> items;
  final double estimatedTaxRate;
  final double estimatedSubtotal;
  final double estimatedTax;
  final double estimatedMargin;
  final double estimatedInternationalShipping;
  final double estimatedTotal;
  final OrderStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CardOrder({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.items,
    required this.estimatedTaxRate,
    required this.estimatedSubtotal,
    required this.estimatedTax,
    this.estimatedMargin = 0,
    this.estimatedInternationalShipping = 0,
    required this.estimatedTotal,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasReferencePriceItem => items.any((i) => i.isReferencePrice);

  factory CardOrder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    return CardOrder(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userDisplayName: data['userDisplayName'] as String? ?? '',
      items: rawItems
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      estimatedTaxRate: (data['estimatedTaxRate'] as num?)?.toDouble() ?? 0,
      estimatedSubtotal: (data['estimatedSubtotal'] as num?)?.toDouble() ?? 0,
      estimatedTax: (data['estimatedTax'] as num?)?.toDouble() ?? 0,
      estimatedMargin: (data['estimatedMargin'] as num?)?.toDouble() ?? 0,
      estimatedInternationalShipping:
          (data['estimatedInternationalShipping'] as num?)?.toDouble() ?? 0,
      estimatedTotal: (data['estimatedTotal'] as num?)?.toDouble() ?? 0,
      status: OrderStatusX.fromName(data['status'] as String? ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
