import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class VoiceMedia {
  static const maxClipBytes = 256 * 1024;
  web.MediaStream? _stream;
  web.HTMLAudioElement? _player;
  bool _disposed = false;

  bool get supported => true;

  Future<({ByteData audio, String mediaType})> record() async {
    _player?.pause();
    final mediaType = const [
      'audio/mp4',
      'audio/ogg',
    ].where((type) => web.MediaRecorder.isTypeSupported(type)).firstOrNull;
    if (mediaType == null) {
      throw UnsupportedError(
        'This browser cannot record a format accepted by Gnani.',
      );
    }
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart;
    _stream = stream;
    Timer? timer;
    try {
      if (_disposed) throw StateError('Voice screen closed');
      final recorder = web.MediaRecorder(
        stream,
        web.MediaRecorderOptions(
          mimeType: mediaType,
          audioBitsPerSecond: 64000,
        ),
      );
      final stopped = Completer<web.Blob>();
      web.Blob? clip;
      recorder.ondataavailable = ((web.BlobEvent event) {
        clip = event.data;
      }).toJS;
      recorder.onstop = ((web.Event event) {
        if (stopped.isCompleted) return;
        final audio = clip;
        if (audio == null || audio.size == 0 || audio.size > maxClipBytes) {
          stopped.completeError(
            StateError('The recording is empty or too large.'),
          );
        } else {
          stopped.complete(audio);
        }
      }).toJS;
      recorder.onerror = ((web.Event event) {
        if (!stopped.isCompleted) {
          stopped.completeError(StateError('Recording failed.'));
        }
      }).toJS;
      recorder.start();
      timer = Timer(const Duration(seconds: 6), () {
        if (recorder.state == 'recording') recorder.stop();
      });
      final blob = await stopped.future.timeout(const Duration(seconds: 9));
      final buffer = (await blob.arrayBuffer().toDart).toDart;
      return (audio: buffer.asByteData(), mediaType: mediaType);
    } finally {
      timer?.cancel();
      _stopRecording();
    }
  }

  Future<void> play(ByteData audio) async {
    _player?.pause();
    final bytes = audio.buffer.asUint8List(
      audio.offsetInBytes,
      audio.lengthInBytes,
    );
    final player = _player = web.HTMLAudioElement()
      ..src = 'data:audio/wav;base64,${base64Encode(bytes)}';
    await player.play().toDart;
  }

  void _stopRecording() {
    final stream = _stream;
    _stream = null;
    if (stream == null) return;
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }

  void dispose() {
    _disposed = true;
    _stopRecording();
    _player?.pause();
    _player = null;
  }
}
