import 'dart:typed_data';

import '../platform_io.dart';

class VoiceMedia {
  bool get supported => hasIPhoneBridge;

  Future<({ByteData audio, String mediaType})> record() async {
    final bytes = await nativeChannel.invokeMethod<Uint8List>('recordVoice');
    if (bytes == null) throw StateError('No microphone data');
    return (audio: ByteData.sublistView(bytes), mediaType: 'audio/wav');
  }

  Future<void> play(ByteData audio) => nativeChannel.invokeMethod<void>(
    'playVoice',
    audio.buffer.asUint8List(audio.offsetInBytes, audio.lengthInBytes),
  );

  void dispose() {}
}
