import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'dart:js_interop';

/// Web: trigger a plain browser download (QA item 13 — no share sheet needed).
Future<void> saveOrShareFile(Uint8List bytes, String filename, String mimeType) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
