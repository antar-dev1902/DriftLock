import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_io_native.dart'
    if (dart.library.js_interop) 'platform_io_web.dart'
    as platform;

const nativeChannel = MethodChannel('driftlock/ios');
bool get hasIPhoneBridge =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

Future<void> exportText(String filename, String contents) =>
    platform.exportText(filename, contents);
