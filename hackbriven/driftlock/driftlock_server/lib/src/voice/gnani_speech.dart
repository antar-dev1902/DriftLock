import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class GnaniSpeech {
  GnaniSpeech(this._client, this._key);

  final http.Client _client;
  final String _key;
  static const _maxClipBytes = 256 * 1024;
  static const _maxAudioBytes = 1024 * 1024;

  Future<String?> transcribe(ByteData clip, String mediaType) async {
    final bytes = clip.buffer.asUint8List(
      clip.offsetInBytes,
      clip.lengthInBytes,
    );
    final suffix = switch (mediaType) {
      'audio/wav'
          when _matches(bytes, 0, 'RIFF') && _matches(bytes, 8, 'WAVE') =>
        'wav',
      'audio/ogg' when _matches(bytes, 0, 'OggS') => 'ogg',
      'audio/mp4' when _matches(bytes, 4, 'ftyp') => 'm4a',
      _ => null,
    };
    if (suffix == null || bytes.length > _maxClipBytes) return null;
    final request =
        http.MultipartRequest('POST', Uri.https('api.vachana.ai', '/stt/v3'))
          ..fields.addAll({'language_code': 'en-IN', 'model': 'prisma-v3.0'})
          ..files.add(
            http.MultipartFile.fromBytes(
              'audio_file',
              bytes,
              filename: 'question.$suffix',
              contentType: MediaType.parse(mediaType),
            ),
          );
    final response = await _send(request, maxBytes: 64 * 1024);
    if (response == null) return null;
    try {
      final payload = jsonDecode(utf8.decode(response));
      if (payload case {
        'success': true,
        'transcript': final String transcript,
      }) {
        return transcript.trim();
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<ByteData?> speak(String answer) async {
    final request =
        http.Request(
            'POST',
            Uri.https('api.vachana.ai', '/api/v1/tts/inference'),
          )
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({
            'text': answer,
            'model': 'timbre-v2.5',
            'voice': 'Kaveri',
            'language': 'en-IN',
            'audio_config': {
              'sample_rate': 24000,
              'num_channels': 1,
              'sample_width': 2,
              'encoding': 'linear_pcm',
              'container': 'wav',
            },
          });
    final bytes = await _send(request, maxBytes: _maxAudioBytes);
    if (bytes == null ||
        !_matches(bytes, 0, 'RIFF') ||
        !_matches(bytes, 8, 'WAVE')) {
      return null;
    }
    return ByteData.sublistView(bytes);
  }

  Future<Uint8List?> _send(
    http.BaseRequest request, {
    required int maxBytes,
  }) async {
    request.followRedirects = false;
    request.headers['X-API-Key-ID'] = _key;
    try {
      return await (() async {
        final response = await _client.send(request);
        if (response.statusCode != 200 ||
            (response.contentLength ?? 0) > maxBytes) {
          return null;
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > maxBytes) return null;
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      })().timeout(const Duration(seconds: 8));
    } on Exception {
      return null;
    }
  }

  static bool _matches(Uint8List bytes, int offset, String marker) =>
      bytes.length >= offset + marker.length &&
      ascii.decode(
            bytes.sublist(offset, offset + marker.length),
            allowInvalid: true,
          ) ==
          marker;
}
