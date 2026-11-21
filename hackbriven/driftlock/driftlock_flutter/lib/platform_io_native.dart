import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<void> exportText(String filename, String contents) async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await const MethodChannel('driftlock/ios').invokeMethod<void>(
      'shareText',
      {'filename': filename, 'text': contents},
    );
  } else {
    await Clipboard.setData(ClipboardData(text: contents));
  }
}
