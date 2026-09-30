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
// unitario de la carta (antes de sumarle la comisión). Como la tabla es
// plana en los dos primeros tramos, una carta barata paga centavos y una
// cara paga un porcentaje; igual que el envío a Perú, es un cobro propio del
// negocio y nunca entra en la base del tax estimado de EE. UU.

/// Por debajo de este precio no hay comisión definida: la tabla empieza en
/// US$ 0.10 y suponer un valor más abajo sería inventar un precio.
const double minimumCommissionablePrice = 0.10;

/// Límite superior (inclusive) del tramo de tarifa plana baja.
const double lowCommissionMaxPrice = 2.00;
const double lowCommissionFee = 0.35;

/// Límite superior (inclusive) del tramo de tarifa plana media.
const double midCommissionMaxPrice = 30.00;
const double midCommissionFee = 1.5;

/// Por encima de [midCommissionMaxPrice] la comisión es un porcentaje del
/// precio completo de la carta.
const double highCommissionRate = 0.07;

/// Una fila de la tabla de comisiones, solo para mostrarla al usuario.
class CommissionTier {
  final String rangeLabel;
  final String feeLabel;

  const CommissionTier(this.rangeLabel, this.feeLabel);
}

const List<CommissionTier> commissionTiers = [
  CommissionTier('\$0.10 a \$2.00', '\$0.35 por unidad'),
  CommissionTier('\$2.01 a \$30.00', '\$1.50 por unidad'),
  CommissionTier('Más de \$30.00', '7% del precio, por unidad'),
];

/// La comisión que paga **una unidad** de una carta que cuesta [unitPrice],
/// redondeada a centavos — o null si el precio está por debajo de
/// [minimumCommissionablePrice], donde la tabla no define ninguna.
///
/// El tramo se elige con el precio unitario tal cual, antes de sumarle nada,
/// y se redondea a centavos antes de comparar para que un precio como 2.00
/// caiga en su tramo sin depender de cómo el binario represente el decimal.
double? commissionPerUnit(double unitPrice) {
  final price = double.parse(unitPrice.toStringAsFixed(2));
  if (price < minimumCommissionablePrice) return null;
  if (price <= lowCommissionMaxPrice) return lowCommissionFee;
  if (price <= midCommissionMaxPrice) return midCommissionFee;
  return double.parse((price * highCommissionRate).toStringAsFixed(2));
}

/// La comisión de toda una línea del carrito: la comisión unitaria por la
/// cantidad comprada. Null cuando el precio de esa línea no tiene comisión
/// definida.
double? commissionForItem(OrderItem item) {
  final perUnit = commissionPerUnit(item.unitPrice);
  if (perUnit == null) return null;
  return double.parse((perUnit * item.quantity).toStringAsFixed(2));
}

/// Cuando la compra supera este monto, la tabla por unidad deja de aplicar y
/// el pedido entero paga [bulkCommissionRate] sobre el subtotal de compra.
const double bulkCommissionThreshold = 150.00;
const double bulkCommissionRate = 0.075;

/// Lo que le toca a una línea cuando el carrito paga el porcentaje: su propio
/// subtotal por la tasa. Es un desglose informativo — los redondeos por línea
/// pueden sumar uno o dos centavos distinto del cobro del carrito, que es el
/// que manda.
double bulkCommissionForItem(OrderItem item) =>
    double.parse((item.lineTotal * bulkCommissionRate).toStringAsFixed(2));

/// La comisión de servicio de todo un carrito, junto con el detalle de cómo
/// salió, para que la pantalla pueda explicarla en vez de mostrar un número
/// suelto.
class CartCommission {
  final double amount;

  /// true cuando se aplicó el porcentaje por superar el umbral, en vez de la
  /// tabla por unidad.
  final bool isPercentage;

  /// Subtotal de compra (cartas + envío del vendedor) sobre el que se midió
  /// el umbral y, cuando aplica, se calculó el porcentaje.
  final double base;

  /// Líneas sin comisión definida (precio bajo el mínimo). Siempre 0 cuando
  /// manda el porcentaje: ahí la comisión la paga el carrito completo, así
  /// que el precio de una carta suelta ya no deja nada sin cobrar.
  final int itemsWithoutCommission;

  const CartCommission({
    required this.amount,
    required this.isPercentage,
    required this.base,
    required this.itemsWithoutCommission,
  });
}

/// Comisión de servicio del carrito.
///
/// Hasta [bulkCommissionThreshold] inclusive se cobra la tabla por unidad: una
/// comisión por cada unidad, según el precio de su carta. Pasado ese monto, el
/// pedido entero paga [bulkCommissionRate] del subtotal de compra — un cobro
/// único que **reemplaza** a los de cada línea, no se suma a ellos.
CartCommission commissionForCart(List<OrderItem> items) {
  final base = double.parse(
    items
        .fold<double>(0, (acc, item) => acc + item.lineTotal)
        .toStringAsFixed(2),
  );

  if (base > bulkCommissionThreshold) {
    return CartCommission(
      amount: double.parse((base * bulkCommissionRate).toStringAsFixed(2)),
      isPercentage: true,
      base: base,
      itemsWithoutCommission: 0,
    );
  }

  var amount = 0.0;
  var missing = 0;
  for (final item in items) {
    final lineCommission = commissionForItem(item);
    if (lineCommission == null) {
      missing++;
      continue;
    }
    amount += lineCommission;
  }
  return CartCommission(
    amount: double.parse(amount.toStringAsFixed(2)),
    isPercentage: false,
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

  /// true cuando la comisión salió del porcentaje por compra grande y no de
  /// la tabla por unidad — la pantalla lo dice para que el monto no parezca
  /// salido de la nada.
  final bool commissionIsPercentage;

  /// Subtotal de compra sobre el que se midió el umbral y se calculó el
  /// porcentaje cuando aplica.
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
    this.commissionIsPercentage = false,
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
      commissionIsPercentage: !adminPricing && cartCommission.isPercentage,
      commissionBase: cartCommission.base,
    );
  }
}
