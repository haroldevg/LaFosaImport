import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Android/iOS/desktop: writes the workbook to the temp directory and hands
/// it to the OS share sheet, so it can be saved or sent wherever is
/// convenient (Drive, email, WhatsApp, etc.).
Future<void> saveXlsx(
  List<int> bytes, {
  required String fileName,
  required String subject,
  required String text,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);

  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: subject, text: text),
  );
}
