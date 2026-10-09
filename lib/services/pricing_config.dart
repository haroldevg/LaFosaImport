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

// ── Comisión de servicio, por unidad ──────────────────────────────────────
//
// Cada unidad comprada paga una sola comisión, elegida por el precio
// unitario de la carta (antes de sumarle la comisión): una tarifa fija mínima
// para las cartas baratas y un porcentaje del precio desde ahí. Igual que el
// envío a Perú, es un cobro propio del negocio y nunca entra en la base del
// tax estimado de EE. UU.

/// Por debajo de este precio no hay comisión definida: la tabla empieza en
/// US$ 0.10 y suponer un valor más abajo sería inventar un precio.
const double minimumCommissionablePrice = 0.10;

/// Comisión mínima por unidad. Rige mientras el [commissionRate] del precio
/// no la supere (hasta ~US$ 3.33): el trabajo de comprar y entregar una carta
/// es el mismo valga centavos o dólares.
const double flatCommissionFee = 0.40;

/// Porcentaje del precio unitario que se cobra una vez superado el mínimo.
const double commissionRate = 0.12;

/// Hasta este precio (inclusive) rige [commissionRate] sobre todo el precio.
const double commissionRateMaxPrice = 30.00;

/// Porcentaje sobre la parte del precio que pase de [commissionRateMaxPrice].
/// Es marginal —lo anterior sigue pagando [commissionRate]— para que la
/// comisión nunca baje al subir el precio.
const double highCommissionRate = 0.075;

/// Una fila de la tabla de comisiones, solo para mostrarla al usuario.
class CommissionTier {
  final String rangeLabel;
  final String feeLabel;

  const CommissionTier(this.rangeLabel, this.feeLabel);
}

const List<CommissionTier> commissionTiers = [
  CommissionTier('\$0.10 a \$3.33', '\$0.40 por unidad'),
  CommissionTier('\$3.34 a \$30.00', '12% del precio, por unidad'),
  CommissionTier(
    'Más de \$30.00',
    '\$3.60 + 7.5% de lo que pase de \$30.00, por unidad',
  ),
];

/// La comisión que paga **una unidad** de una carta que cuesta [unitPrice],
/// redondeada a centavos — o null si el precio está por debajo de
/// [minimumCommissionablePrice], donde la tabla no define ninguna.
///
/// El tramo se elige con el precio unitario tal cual, antes de sumarle nada,
/// y se redondea a centavos antes de comparar para que un precio como 30.00
/// caiga en su tramo sin depender de cómo el binario represente el decimal.
double? commissionPerUnit(double unitPrice) {
  final price = double.parse(unitPrice.toStringAsFixed(2));
  if (price < minimumCommissionablePrice) return null;
  if (price <= commissionRateMaxPrice) {
    final byRate = double.parse((price * commissionRate).toStringAsFixed(2));
    return byRate < flatCommissionFee ? flatCommissionFee : byRate;
  }
  final atMax = commissionRateMaxPrice * commissionRate;
  final above = (price - commissionRateMaxPrice) * highCommissionRate;
  return double.parse((atMax + above).toStringAsFixed(2));
}

/// La comisión de toda una línea del carrito: la comisión unitaria por la
/// cantidad comprada. Null cuando el precio de esa línea no tiene comisión
/// definida.
double? commissionForItem(OrderItem item) {
  final perUnit = commissionPerUnit(item.unitPrice);
  if (perUnit == null) return null;
  return double.parse((perUnit * item.quantity).toStringAsFixed(2));
}

/// Descuento por compra grande: la parte del subtotal que pasa de este monto
/// ya no paga la tabla por unidad sino [bulkCommissionRate].
const double bulkCommissionThreshold = 150.00;
const double bulkCommissionRate = 0.075;

/// Lo que le toca a una línea cuando el carrito supera el umbral: su parte de
/// la tabla por unidad (prorrateada a la porción del pedido que no pasa del
/// umbral) más su parte de lo que sí pasa. Es un desglose informativo — los
/// redondeos por línea pueden sumar uno o dos centavos distinto del cobro del
/// carrito, que es el que manda.
double commissionShareWithVolume(OrderItem item, double cartBase) {
  final table = commissionForItem(item) ?? 0;
  final tableShare = table * bulkCommissionThreshold / cartBase;
  final overShare =
      bulkCommissionRate *
      item.lineTotal *
      (cartBase - bulkCommissionThreshold) /
      cartBase;
  return double.parse((tableShare + overShare).toStringAsFixed(2));
}

/// La comisión de servicio de todo un carrito, junto con el detalle de cómo
/// salió, para que la pantalla pueda explicarla en vez de mostrar un número
/// suelto.
class CartCommission {
  final double amount;

  /// true cuando el subtotal superó [bulkCommissionThreshold] y la parte que
  /// pasa del umbral se cobró a [bulkCommissionRate].
  final bool hasVolumeRate;

  /// Subtotal de compra (cartas + envío del vendedor) sobre el que se midió
  /// el umbral.
  final double base;

  /// Líneas sin comisión definida (precio bajo el mínimo).
  final int itemsWithoutCommission;

  const CartCommission({
    required this.amount,
    required this.hasVolumeRate,
    required this.base,
    required this.itemsWithoutCommission,
  });
}

/// Comisión de servicio del carrito.
///
/// Hasta [bulkCommissionThreshold] inclusive se cobra la tabla por unidad: una
/// comisión por cada unidad, según el precio de su carta. Pasado ese monto, la
/// tabla se aplica a la porción del pedido que llega al umbral (prorrateada) y
/// lo que lo excede paga [bulkCommissionRate]. Es continuo en el umbral: sumar
/// una carta nunca baja la comisión total.
CartCommission commissionForCart(List<OrderItem> items) {
  final base = double.parse(
    items
        .fold<double>(0, (acc, item) => acc + item.lineTotal)
        .toStringAsFixed(2),
  );

  var table = 0.0;
  var missing = 0;
  for (final item in items) {
    final lineCommission = commissionForItem(item);
    if (lineCommission == null) {
      missing++;
      continue;
    }
    table += lineCommission;
  }

  if (base > bulkCommissionThreshold) {
    final amount =
        table * bulkCommissionThreshold / base +
        bulkCommissionRate * (base - bulkCommissionThreshold);
    return CartCommission(
      amount: double.parse(amount.toStringAsFixed(2)),
      hasVolumeRate: true,
      base: base,
      itemsWithoutCommission: missing,
    );
  }
  return CartCommission(
    amount: double.parse(table.toStringAsFixed(2)),
    hasVolumeRate: false,
    base: base,
    itemsWithoutCommission: missing,
  );
}

/// The aggregate money figures for a cart, computed in one place so that a
/// staff reprice (see `OrderService.applyPriceAdjustment`) lands on exactly
/// the same arithmetic — same rounding, same order of operations — that the
/// original quote was built with.
///
/// [adminPricing] mirrors how the order was first priced: orders placed by an
/// admin carry no commission and a reduced per-card Peru shipping fee, so a
/// later reprice has to keep applying that same schedule.
class OrderTotals {
  final double subtotal;
  final double taxRate;
  final double tax;

  /// Suma de las comisiones de todas las líneas. Se guarda en Firestore bajo
  /// `estimatedMargin`, que es como se llamaba cuando era un margen
  /// escalonado; el nombre del campo se mantuvo para no migrar los pedidos
  /// que ya existían.
  final double commission;
  final double internationalShipping;
  final double total;
  final int totalQuantity;

  /// Cuántas líneas quedaron sin comisión por estar debajo de
  /// [minimumCommissionablePrice]. La pantalla del carrito no deja llegar
  /// ninguna hasta acá, pero si una llegara, el total no puede fingir que
  /// costó cero: quien muestre estos totales tiene que advertirlo.
  final int itemsWithoutCommission;

  /// true cuando el subtotal superó el umbral de compra grande y la parte que
  /// lo excede pagó el porcentaje en vez de la tabla por unidad — la pantalla
  /// lo dice para que el monto no parezca salido de la nada.
  final bool commissionHasVolumeRate;

  /// Subtotal de compra sobre el que se midió el umbral.
  final double commissionBase;

  const OrderTotals({
    required this.subtotal,
    required this.taxRate,
    required this.tax,
    required this.commission,
    required this.internationalShipping,
    required this.total,
    required this.totalQuantity,
    this.itemsWithoutCommission = 0,
    this.commissionHasVolumeRate = false,
    this.commissionBase = 0,
  });

  bool get hasItemsWithoutCommission => itemsWithoutCommission > 0;

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
    final cartCommission = commissionForCart(items);
    final commission = adminPricing ? 0.0 : cartCommission.amount;
    final itemsWithoutCommission = adminPricing
        ? 0
        : cartCommission.itemsWithoutCommission;
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
      commission: commission,
      internationalShipping: internationalShipping,
      total: double.parse(
        (subtotal + tax + commission + internationalShipping).toStringAsFixed(
          2,
        ),
      ),
      totalQuantity: totalQuantity,
      itemsWithoutCommission: itemsWithoutCommission,
      commissionHasVolumeRate: !adminPricing && cartCommission.hasVolumeRate,
      commissionBase: cartCommission.base,
    );
  }
}
