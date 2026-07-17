import 'dart:io';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Mobile/desktop: write to a temp file and open the platform share sheet.
Future<void> saveOrShareFile(Uint8List bytes, String filename, String mimeType) async {
  final file = File('${Directory.systemTemp.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: mimeType)]),
  );
}
