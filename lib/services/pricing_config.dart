import '../models/order.dart';

/// Flat fee charged per card unit (every unit counts, regardless of whether
/// it's the same card repeated or different cards) to cover consolidating
/// and forwarding the cards from the US forwarder address to Peru. This is
/// the business's own handling fee, not part of the TCGPlayer purchase, so
/// it is never subject to the US sales tax estimate.
const double internationalShippingFeePerCard = 0.5;

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
/// it's never subject to the US sales tax estimate.
const List<MarginTier> marginTiers = [
  MarginTier(from: 0, rangeLabel: 'Hasta \$30', rate: 0.20),
  MarginTier(from: 30, rangeLabel: '\$31 a \$99', rate: 0.13),
  MarginTier(from: 99, rangeLabel: '\$100 a \$299', rate: 0.08),
  MarginTier(from: 299, rangeLabel: '\$300+', rate: 0.04),
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
