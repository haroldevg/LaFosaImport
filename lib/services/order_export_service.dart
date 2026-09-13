import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/order.dart';

/// The two .xlsx reports the staff works off, each handed to the OS share
/// sheet so it can be saved or sent wherever is convenient (Drive, email,
/// etc.): the shopping list of what still has to be bought on TCGPlayer, and
/// the delivery list of what was already bought and now has to reach each
/// customer.
class OrderExportService {
  OrderExportService._();
  static final OrderExportService instance = OrderExportService._();

  static const _pendingHeaders = [
    'Fecha pedido',
    'Solicitado por',
    'Estado',
    'Carta',
    'Set',
    'Condición',
    'Cantidad',
    'Vendedor',
    'Link',
    'Precio unitario',
    'Envío',
    'Total línea',
    'Precio referencial',
  ];

  static const _deliverySummaryHeaders = [
    'Cliente',
    'Correo',
    'Fecha pedido',
    'Comprado el',
    'Unidades',
    'Líneas',
    'Total a cobrar',
    'ID pedido',
  ];

  static const _deliveryDetailHeaders = [
    'Cliente',
    'Carta',
    'Set',
    'Condición',
    'Cantidad',
    'Vendedor',
    'Precio unitario',
    'Envío',
    'Total línea',
  ];

  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  /// Shopping list (one row per card) for every order the staff still has to
  /// go buy on TCGPlayer (see [OrderStatusX.isReadyToBuy]). Orders still
  /// waiting on a customer's answer to a price adjustment are deliberately
  /// left out; the status column says which of the rest are already paid for.
  ///
  /// Returns the number of orders exported, or 0 if there was nothing to
  /// export (caller should show that as a message, not an error).
  Future<int> exportPendingOrders(List<CardOrder> orders) async {
    final pending = orders.where((o) => o.status.isReadyToBuy).toList();
    if (pending.isEmpty) return 0;

    final excel = _newWorkbook(['Pendientes']);
    final sheet = excel['Pendientes'];
    sheet.appendRow(_pendingHeaders.map(TextCellValue.new).toList());

    for (final order in pending) {
      final date = order.createdAt != null
          ? _dateFmt.format(order.createdAt!)
          : '';
      for (final item in order.items) {
        sheet.appendRow([
          TextCellValue(date),
          TextCellValue(order.userDisplayName),
          TextCellValue(order.status.label),
          TextCellValue(item.cardName),
          TextCellValue(item.setName),
          TextCellValue(item.condition),
          IntCellValue(item.quantity),
          TextCellValue(item.sellerName ?? ''),
          TextCellValue(item.listingUrl ?? ''),
          DoubleCellValue(item.unitPrice),
          DoubleCellValue(item.shipping),
          DoubleCellValue(item.lineTotal),
          TextCellValue(item.isReferencePrice ? 'Sí' : 'No'),
        ]);
      }
    }

    await _shareWorkbook(
      excel,
      fileNamePrefix: 'pedidos_pendientes',
      subject: 'Pedidos pendientes por comprar',
      text:
          '${pending.length} pedido(s) pendiente(s) — exportado desde La Fosa Store.',
    );
    return pending.length;
  }

  /// Delivery list for every order already bought ([OrderStatus.ordered]):
  /// who it belongs to and which cards have to reach them. Two sheets, because
  /// the staff uses them for different things — "Por entregar" is one row per
  /// order (who to contact and how much to collect), "Detalle" is one row per
  /// card, grouped by order and closed with that order's total, to check the
  /// cards off one by one as they're packed.
  ///
  /// Returns the number of orders exported, or 0 if there was nothing to
  /// export.
  Future<int> exportPurchasedOrders(List<CardOrder> orders) async {
    final purchased = orders
        .where((o) => o.status == OrderStatus.ordered)
        .toList();
    if (purchased.isEmpty) return 0;

    final excel = _newWorkbook(['Por entregar', 'Detalle']);
    final summary = excel['Por entregar'];
    final detail = excel['Detalle'];

    summary.appendRow(_deliverySummaryHeaders.map(TextCellValue.new).toList());
    detail.appendRow(_deliveryDetailHeaders.map(TextCellValue.new).toList());

    for (final order in purchased) {
      final units = order.items.fold<int>(0, (acc, i) => acc + i.quantity);
      summary.appendRow([
        TextCellValue(order.userDisplayName),
        TextCellValue(order.userEmail),
        TextCellValue(
          order.createdAt != null ? _dateFmt.format(order.createdAt!) : '',
        ),
        // The last status change on a bought order is the purchase itself.
        TextCellValue(
          order.updatedAt != null ? _dateFmt.format(order.updatedAt!) : '',
        ),
        IntCellValue(units),
        IntCellValue(order.items.length),
        DoubleCellValue(order.estimatedTotal),
        TextCellValue(order.id),
      ]);

      for (final item in order.items) {
        detail.appendRow([
          TextCellValue(order.userDisplayName),
          TextCellValue(item.cardName),
          TextCellValue(item.setName),
          TextCellValue(item.condition),
          IntCellValue(item.quantity),
          TextCellValue(item.sellerName ?? ''),
          DoubleCellValue(item.unitPrice),
          DoubleCellValue(item.shipping),
          DoubleCellValue(item.lineTotal),
        ]);
      }
      detail.appendRow([
        TextCellValue(order.userDisplayName),
        TextCellValue('TOTAL A COBRAR ($units unidad(es))'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(order.estimatedTotal),
      ]);
      // Blank line between orders so each block reads as its own packing list.
      detail.appendRow([TextCellValue('')]);
    }

    await _shareWorkbook(
      excel,
      fileNamePrefix: 'pedidos_por_entregar',
      subject: 'Pedidos comprados por entregar',
      text:
          '${purchased.length} pedido(s) comprado(s) por entregar — exportado desde La Fosa Store.',
    );
    return purchased.length;
  }

  /// A workbook holding exactly [sheetNames], in that order — Excel.createExcel
  /// always seeds a default sheet of its own, which has to be dropped or the
  /// file opens on an empty tab.
  Excel _newWorkbook(List<String> sheetNames) {
    final excel = Excel.createExcel();
    for (final name in sheetNames) {
      excel[name];
    }
    excel.setDefaultSheet(sheetNames.first);
    for (final name in excel.sheets.keys.toList()) {
      if (!sheetNames.contains(name)) excel.delete(name);
    }
    return excel;
  }

  Future<void> _shareWorkbook(
    Excel excel, {
    required String fileNamePrefix,
    required String subject,
    required String text,
  }) async {
    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('No se pudo generar el archivo Excel.');
    }

    final dir = await getTemporaryDirectory();
    final fileName =
        '${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject, text: text),
    );
  }
}
