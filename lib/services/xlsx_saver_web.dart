import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Web: turns the workbook into a blob and clicks a hidden `<a download>`, so
/// the browser saves it like any other download. [subject] and [text] are
/// ignored here — they only mean something to the native share sheet.
Future<void> saveXlsx(
  List<int> bytes, {
  required String fileName,
  required String subject,
  required String text,
}) async {
  final blob = web.Blob(
    <JSAny?>[Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: _xlsxMimeType),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();

  // Revoking in the same tick can abort the save in some browsers, so give
  // the download a moment to start before the blob URL stops resolving.
  await Future<void>.delayed(const Duration(seconds: 1));
  web.URL.revokeObjectURL(url);
}
