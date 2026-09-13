import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle of a pedido. [OrderStatus.priceReview] and
/// [OrderStatus.priceConfirmed] are the two steps of the reprice loop:
/// TCGPlayer prices move constantly, so the staff can rewrite the prices of
/// an already-placed order, which parks it in `priceReview` until the
/// customer approves the new total — only then (`priceConfirmed`) is the
/// staff cleared to actually buy it.
enum OrderStatus {
  pending,
  priceReview,
  priceConfirmed,
  awaitingPayment,
  ordered,
  shipped,
  inTransit,
  delivered,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Pendiente',
    OrderStatus.priceReview => 'Ajuste de precio — por confirmar',
    OrderStatus.priceConfirmed => 'Precio confirmado',
    OrderStatus.awaitingPayment => 'Pedido confirmado (Pendiente de pago)',
    OrderStatus.ordered => 'Comprado',
    OrderStatus.shipped => 'Enviado',
    OrderStatus.inTransit => 'En tránsito',
    OrderStatus.delivered => 'Entregado',
    OrderStatus.cancelled => 'Cancelado',
  };

  bool get isActive =>
      this != OrderStatus.delivered && this != OrderStatus.cancelled;

  /// Orders the staff still has to go buy on TCGPlayer: freshly placed ones,
  /// the ones whose reprice the customer already approved, and the ones only
  /// waiting on the customer's payment — all of them still belong on the
  /// shopping list (the export carries a status column to tell them apart).
  bool get isReadyToBuy =>
      this == OrderStatus.pending ||
      this == OrderStatus.priceConfirmed ||
      this == OrderStatus.awaitingPayment;

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

/// Trace of the last staff reprice on an order: what the customer had been
/// quoted, what they are being asked to approve now, and how they answered.
class PriceAdjustment {
  final double previousTotal;
  final double newTotal;
  final String? note;
  final String? adjustedByName;
  final DateTime? adjustedAt;
  final DateTime? respondedAt;

  /// null while the customer has not answered yet.
  final bool? accepted;

  const PriceAdjustment({
    required this.previousTotal,
    required this.newTotal,
    this.note,
    this.adjustedByName,
    this.adjustedAt,
    this.respondedAt,
    this.accepted,
  });

  /// Positive when the order got more expensive, negative when it got cheaper.
  double get difference =>
      double.parse((newTotal - previousTotal).toStringAsFixed(2));

  static PriceAdjustment? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return PriceAdjustment(
      previousTotal: (map['previousTotal'] as num?)?.toDouble() ?? 0,
      newTotal: (map['newTotal'] as num?)?.toDouble() ?? 0,
      note: map['note'] as String?,
      adjustedByName: map['adjustedByName'] as String?,
      adjustedAt: (map['adjustedAt'] as Timestamp?)?.toDate(),
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
      accepted: map['accepted'] as bool?,
    );
  }
}

class CardOrder {
  final String id;
  final String userId;
  final String userDisplayName;
  final String userEmail;
  final List<OrderItem> items;
  final double estimatedTaxRate;
  final double estimatedSubtotal;
  final double estimatedTax;
  final double estimatedMargin;
  final double estimatedInternationalShipping;
  final double estimatedTotal;
  final OrderStatus status;

  /// Whether the order was originally quoted on the admin schedule (no
  /// service margin, reduced Peru shipping fee). Absent on orders created
  /// before this field existed — use [usesAdminPricing], not this, to decide
  /// how to reprice.
  final bool? ownerIsAdmin;
  final PriceAdjustment? priceAdjustment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CardOrder({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    this.userEmail = '',
    required this.items,
    required this.estimatedTaxRate,
    required this.estimatedSubtotal,
    required this.estimatedTax,
    this.estimatedMargin = 0,
    this.estimatedInternationalShipping = 0,
    required this.estimatedTotal,
    required this.status,
    this.ownerIsAdmin,
    this.priceAdjustment,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasReferencePriceItem => items.any((i) => i.isReferencePrice);

  /// Which fee schedule a reprice has to keep using. Orders placed before
  /// [ownerIsAdmin] was recorded fall back to reading it off the quote
  /// itself: a zero margin on a non-empty cart only ever happens on the admin
  /// schedule, since every priced card charges some margin otherwise.
  bool get usesAdminPricing => ownerIsAdmin ?? (estimatedMargin == 0);

  /// The last reprice is still waiting on this customer's yes/no.
  bool get awaitsPriceConfirmation => status == OrderStatus.priceReview;

  factory CardOrder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    final rawAdjustment = data['priceAdjustment'];
    return CardOrder(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userDisplayName: data['userDisplayName'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
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
      ownerIsAdmin: data['ownerIsAdmin'] as bool?,
      priceAdjustment: PriceAdjustment.fromMap(
        rawAdjustment == null
            ? null
            : Map<String, dynamic>.from(rawAdjustment as Map),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
