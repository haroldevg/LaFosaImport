import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/order.dart';

/// Builds an .xlsx shopping list (one row per card) for every order still
/// [OrderStatus.pending] — i.e. what the staff still needs to go buy on
/// TCGPlayer — and hands it to the OS share sheet so it can be saved or sent
/// wherever is convenient (Drive, email, etc.).
class OrderExportService {
  OrderExportService._();
  static final OrderExportService instance = OrderExportService._();

  static const _headers = [
    'Fecha pedido',
    'Solicitado por',
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

  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  /// Returns the number of pending orders exported, or 0 if there was
  /// nothing to export (caller should show that as a message, not an error).
  Future<int> exportPendingOrders(List<CardOrder> orders) async {
    final pending = orders
        .where((o) => o.status == OrderStatus.pending)
        .toList();
    if (pending.isEmpty) return 0;

    final excel = Excel.createExcel();
    final sheet = excel['Pendientes'];
    excel.setDefaultSheet('Pendientes');
    for (final name in excel.sheets.keys.toList()) {
      if (name != 'Pendientes') excel.delete(name);
    }

    sheet.appendRow(_headers.map((h) => TextCellValue(h)).toList());

    for (final order in pending) {
      final date = order.createdAt != null
          ? _dateFmt.format(order.createdAt!)
          : '';
      for (final item in order.items) {
        sheet.appendRow([
          TextCellValue(date),
          TextCellValue(order.userDisplayName),
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

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('No se pudo generar el archivo Excel.');
    }

    final dir = await getTemporaryDirectory();
    final fileName =
        'pedidos_pendientes_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Pedidos pendientes por comprar',
        text:
            '${pending.length} pedido(s) pendiente(s) — exportado desde La Fosa Store.',
      ),
    );

    return pending.length;
  }
}
