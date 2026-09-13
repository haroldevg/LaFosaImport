import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';

/// Public URL where customers open the app to answer a price adjustment.
/// Firebase Hosting's default domain for this project — change it here if a
/// custom domain is wired up later.
const appUrl = 'https://tcgimport-pe.web.app';

/// Queues transactional emails by writing them to the `mail` collection,
/// which the Firebase "Trigger Email from Firestore" extension picks up and
/// delivers (see README — the extension has to be installed in the project or
/// these documents just pile up unsent). There is no backend of our own here,
/// so this write *is* the send; the extension stamps its result back onto the
/// same document under `delivery`.
class MailService {
  MailService._();
  static final MailService instance = MailService._();

  static const _collection = 'mail';

  final _db = FirebaseFirestore.instance;

  /// Tells the customer their order was repriced and that it now needs their
  /// approval. Throws if the write fails — callers decide whether that is
  /// fatal (for the reprice flow it is not: the order is already updated and
  /// the app shows the same request in-app).
  /// [items] is the repriced cart, not `order.items` — the caller still holds
  /// the pre-edit order, so the new lines have to come in separately or the
  /// customer gets emailed the prices they were already quoted.
  Future<void> sendPriceAdjustmentNotice({
    required String to,
    required CardOrder order,
    required List<OrderItem> items,
    required OrderTotalsSummary totals,
    String? note,
  }) async {
    final difference = totals.newTotal - totals.previousTotal;
    final wentUp = difference > 0;
    final subject = wentUp
        ? 'Ajuste de precio en tu pedido — necesitamos tu confirmación'
        : 'Buenas noticias: bajó el precio de tu pedido';

    await _db.collection(_collection).add({
      'to': [to],
      'message': {
        'subject': subject,
        'text': _plainBody(
          order: order,
          items: items,
          totals: totals,
          note: note,
        ),
        'html': _htmlBody(
          order: order,
          items: items,
          totals: totals,
          note: note,
        ),
      },
      // Not read by the extension — kept so a failed send can be traced back
      // to the order it belonged to.
      'orderId': order.id,
      'type': 'price_adjustment',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _plainBody({
    required CardOrder order,
    required List<OrderItem> items,
    required OrderTotalsSummary totals,
    String? note,
  }) {
    final lines = <String>[
      'Hola ${order.userDisplayName},',
      '',
      'Los precios en TCGPlayer cambiaron y nuestro staff actualizó tu pedido. '
          'Necesitamos tu confirmación antes de comprarlo.',
      '',
      'Detalle actualizado:',
      for (final item in items)
        '- ${item.cardName} x${item.quantity}: ${_money(item.unitPrice)} c/u'
            '${item.shipping > 0 ? ' + ${_money(item.shipping)} envío' : ''}'
            ' = ${_money(item.lineTotal)}',
      '',
      'Total anterior: ${_money(totals.previousTotal)}',
      'Total nuevo: ${_money(totals.newTotal)}',
      '${totals.newTotal >= totals.previousTotal ? 'Diferencia' : 'Ahorro'}: '
          '${_money((totals.newTotal - totals.previousTotal).abs())}',
      if (note != null && note.trim().isNotEmpty) ...['', 'Nota: $note'],
      '',
      'Ingresa a $appUrl y confirma el nuevo precio desde tu pedido activo. '
          'Si no estás de acuerdo, puedes rechazarlo y el pedido se cancela.',
      '',
      'La Fosa Store',
    ];
    return lines.join('\n');
  }

  String _htmlBody({
    required CardOrder order,
    required List<OrderItem> items,
    required OrderTotalsSummary totals,
    String? note,
  }) {
    final difference = totals.newTotal - totals.previousTotal;
    final wentUp = difference >= 0;
    final rows = items
        .map(
          (item) =>
              '<tr>'
              '<td style="padding:8px 10px;border-bottom:1px solid #2a2536;">'
              '<strong>${_escape(item.cardName)}</strong> ×${item.quantity}'
              '<br><span style="color:#9d95b0;font-size:12px;">'
              '${_escape([if (item.setName.isNotEmpty) item.setName, item.condition, if (item.sellerName != null && item.sellerName!.isNotEmpty) 'Vendedor: ${item.sellerName}'].join(' · '))}'
              '</span></td>'
              '<td style="padding:8px 10px;border-bottom:1px solid #2a2536;text-align:right;white-space:nowrap;">'
              '${_money(item.unitPrice)} c/u'
              '${item.shipping > 0 ? '<br><span style="color:#9d95b0;font-size:12px;">+ ${_money(item.shipping)} envío</span>' : ''}'
              '</td>'
              '<td style="padding:8px 10px;border-bottom:1px solid #2a2536;text-align:right;white-space:nowrap;">'
              '${_money(item.lineTotal)}</td>'
              '</tr>',
        )
        .join();

    return '''
<div style="background:#0a0a0d;padding:24px;font-family:Segoe UI,Helvetica,Arial,sans-serif;color:#e7e1ce;">
  <div style="max-width:600px;margin:0 auto;background:#16141c;border:1px solid rgba(155,77,255,0.3);border-radius:14px;padding:24px;">
    <h1 style="margin:0 0 4px;font-size:20px;color:#ffffff;">La Fosa Store</h1>
    <p style="margin:0 0 20px;color:#9b4dff;font-weight:600;">Ajuste de precio en tu pedido</p>

    <p style="margin:0 0 16px;">Hola ${_escape(order.userDisplayName)},</p>
    <p style="margin:0 0 16px;">
      Los precios en TCGPlayer cambian constantemente y nuestro staff actualizó
      el detalle de tu pedido. <strong>Necesitamos tu confirmación antes de
      comprarlo.</strong>
    </p>

    <table style="width:100%;border-collapse:collapse;font-size:14px;margin-bottom:16px;">
      $rows
    </table>

    <table style="width:100%;border-collapse:collapse;font-size:14px;">
      <tr><td style="padding:4px 10px;">Subtotal</td>
          <td style="padding:4px 10px;text-align:right;">${_money(totals.subtotal)}</td></tr>
      <tr><td style="padding:4px 10px;">Tax estimado</td>
          <td style="padding:4px 10px;text-align:right;">${_money(totals.tax)}</td></tr>
      ${totals.margin > 0 ? '<tr><td style="padding:4px 10px;">Margen de servicio</td><td style="padding:4px 10px;text-align:right;">${_money(totals.margin)}</td></tr>' : ''}
      <tr><td style="padding:4px 10px;">Envío a Perú</td>
          <td style="padding:4px 10px;text-align:right;">${_money(totals.internationalShipping)}</td></tr>
      <tr><td style="padding:8px 10px;color:#9d95b0;">Total anterior</td>
          <td style="padding:8px 10px;text-align:right;color:#9d95b0;text-decoration:line-through;">${_money(totals.previousTotal)}</td></tr>
      <tr><td style="padding:8px 10px;font-size:16px;"><strong>Total nuevo</strong></td>
          <td style="padding:8px 10px;text-align:right;font-size:16px;"><strong>${_money(totals.newTotal)}</strong></td></tr>
      <tr><td style="padding:0 10px;color:${wentUp ? '#ff8a80' : '#7ddf8f'};">
            ${wentUp ? 'Diferencia a pagar' : 'Ahorro'}</td>
          <td style="padding:0 10px;text-align:right;color:${wentUp ? '#ff8a80' : '#7ddf8f'};">
            ${wentUp ? '+' : '−'}${_money(difference.abs())}</td></tr>
    </table>

    ${note != null && note.trim().isNotEmpty ? '<p style="margin:20px 0 0;padding:12px;background:#211d2b;border-radius:10px;font-size:14px;"><strong>Nota del staff:</strong><br>${_escape(note)}</p>' : ''}

    <p style="margin:24px 0 8px;">
      Ingresa a la app y da tu conformidad para que podamos hacer la compra.
      Si no estás de acuerdo, puedes rechazar el ajuste y el pedido se cancela.
    </p>
    <p style="margin:16px 0 0;">
      <a href="$appUrl" style="display:inline-block;background:#9b4dff;color:#ffffff;text-decoration:none;padding:12px 22px;border-radius:10px;font-weight:600;">
        Revisar y confirmar mi pedido
      </a>
    </p>

    <p style="margin:24px 0 0;font-size:12px;color:#9d95b0;">
      Este pedido lo compra el staff manualmente en TCGPlayer; el monto final
      puede variar levemente hasta el momento de la compra.
    </p>
  </div>
</div>
''';
  }

  static String _money(double value) => 'US\$ ${value.toStringAsFixed(2)}';

  /// Card names, seller names and staff notes are free text that ends up
  /// inside the HTML body, so they get escaped before being interpolated.
  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// The before/after figures a price-adjustment email needs. Built by
/// `OrderService.applyPriceAdjustment` from the recalculated [OrderTotals]
/// plus the total the customer had originally been quoted.
class OrderTotalsSummary {
  final double subtotal;
  final double tax;
  final double margin;
  final double internationalShipping;
  final double previousTotal;
  final double newTotal;

  const OrderTotalsSummary({
    required this.subtotal,
    required this.tax,
    required this.margin,
    required this.internationalShipping,
    required this.previousTotal,
    required this.newTotal,
  });
}
