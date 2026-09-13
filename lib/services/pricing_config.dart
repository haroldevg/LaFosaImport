import '../models/order.dart';

/// Flat estimated US sales tax rate applied to the cards + seller shipping
/// subtotal. Kept as a single fixed rate rather than a per-state lookup.
const double fixedTaxRate = 0.10;

/// Flat fee charged per card unit (every unit counts, regardless of whether
/// it's the same card repeated or different cards) to cover consolidating
/// and forwarding the cards from the US forwarder address to Peru. This is
/// the business's own handling fee, not part of the TCGPlayer purchase, so
/// it is never subject to the US sales tax estimate. Admins pay a reduced fee.
const double internationalShippingFeePerCard = 0.75;
const double adminInternationalShippingFeePerCard = 0.5;

double internationalShippingFeeFor(bool isAdmin) => isAdmin
    ? adminInternationalShippingFeePerCard
    : internationalShippingFeePerCard;

/// One row of the tiered service-margin table: a card whose unit price falls
/// at or above [from] (and below the next tier's [from], or unbounded for
/// the last tier) is charged [rate] as the business's margin.
class MarginTier {
  final double from;
  final String rangeLabel;
  final double rate;

  const MarginTier({
    required this.from,
    required this.rangeLabel,
    required this.rate,
  });
}

/// Tiered margin schedule — cheaper cards carry a higher margin since fixed
/// per-order costs matter more relative to their price; higher-value cards
/// get a lower percentage. Like the Peru shipping fee, this is the
/// business's own service margin, not part of the TCGPlayer purchase, so
/// it's never subject to the US sales tax estimate. Applies to non-admin
/// users only — admins pay no margin (see [marginAmountForItem] callers).
const List<MarginTier> marginTiers = [
  MarginTier(from: 0, rangeLabel: 'Hasta \$30', rate: 0.20),
  MarginTier(from: 30, rangeLabel: '\$31 a \$99', rate: 0.12),
  MarginTier(from: 99, rangeLabel: '\$100 a \$299', rate: 0.075),
  MarginTier(from: 299, rangeLabel: '\$300+', rate: 0.035),
];

double marginRateFor(double unitPrice) {
  var rate = marginTiers.first.rate;
  for (final tier in marginTiers) {
    if (unitPrice >= tier.from) rate = tier.rate;
  }
  return rate;
}

/// The business's margin for one cart line: its per-unit rate (picked by the
/// card's own unit price, not the line's total) applied across all units
/// bought on that line.
double marginAmountForItem(OrderItem item) {
  return item.unitPrice * item.quantity * marginRateFor(item.unitPrice);
}

/// The aggregate money figures for a cart, computed in one place so that a
/// staff reprice (see `OrderService.applyPriceAdjustment`) lands on exactly
/// the same arithmetic — same rounding, same order of operations — that the
/// original quote was built with.
///
/// [adminPricing] mirrors how the order was first priced: orders placed by an
/// admin carry no service margin and a reduced per-card Peru shipping fee, so
/// a later reprice has to keep applying that same schedule.
class OrderTotals {
  final double subtotal;
  final double taxRate;
  final double tax;
  final double margin;
  final double internationalShipping;
  final double total;
  final int totalQuantity;

  const OrderTotals({
    required this.subtotal,
    required this.taxRate,
    required this.tax,
    required this.margin,
    required this.internationalShipping,
    required this.total,
    required this.totalQuantity,
  });

  factory OrderTotals.forItems(
    List<OrderItem> items, {
    required bool adminPricing,
  }) {
    final rawSubtotal = items.fold<double>(
      0,
      (acc, item) => acc + item.lineTotal,
    );
    final subtotal = double.parse(rawSubtotal.toStringAsFixed(2));
    final tax = double.parse((subtotal * fixedTaxRate).toStringAsFixed(2));
    final margin = adminPricing
        ? 0.0
        : double.parse(
            items
                .fold<double>(0, (acc, item) => acc + marginAmountForItem(item))
                .toStringAsFixed(2),
          );
    final totalQuantity = items.fold<int>(
      0,
      (acc, item) => acc + item.quantity,
    );
    final internationalShipping = double.parse(
      (totalQuantity * internationalShippingFeeFor(adminPricing))
          .toStringAsFixed(2),
    );
    return OrderTotals(
      subtotal: subtotal,
      taxRate: fixedTaxRate,
      tax: tax,
      margin: margin,
      internationalShipping: internationalShipping,
      total: double.parse(
        (subtotal + tax + margin + internationalShipping).toStringAsFixed(2),
      ),
      totalQuantity: totalQuantity,
    );
  }
}
