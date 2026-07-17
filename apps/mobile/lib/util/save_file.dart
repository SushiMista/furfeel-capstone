/// Platform-appropriate "get this file to the user": share sheet on mobile,
/// browser download on web (QA item 13).
library;

export 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart';
