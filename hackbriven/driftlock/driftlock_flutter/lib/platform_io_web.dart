import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> exportText(String filename, String contents) async {
  final url = web.URL.createObjectURL(web.Blob([contents.toJS].toJS));
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();
  await Future<void>.delayed(const Duration(seconds: 1));
  web.URL.revokeObjectURL(url);
}
