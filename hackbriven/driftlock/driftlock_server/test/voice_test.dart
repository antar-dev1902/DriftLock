import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:driftlock_server/src/generated/protocol.dart';
import 'package:driftlock_server/src/voice/gnani_speech.dart';
import 'package:driftlock_server/src/voice/voice_endpoint.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              '../../../contracts/fixtures/voice_state.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final blackout = VoiceState.fromJson(fixture);

  test('status is bounded to the replay state and its timestamp', () {
    expect(
      replayVoiceAnswer(blackout),
      contains('At 30.0 seconds. GPS is withheld.'),
    );
    expect(
      replayVoiceAnswer(blackout),
      contains('Position accuracy is unavailable.'),
    );
    expect(
      replayVoiceAnswer(blackout.copyWith(outageState: 'reacquiring')),
      contains('waiting for a fresh fix'),
    );
    expect(
      replayVoiceAnswer(blackout.copyWith(outageState: 'locked')),
      contains('GPS is available'),
    );
    expect(replayVoiceAnswer(blackout.copyWith(radius95M: 2)), isNull);
    expect(
      replayVoiceAnswer(blackout.copyWith(outageState: 'driving')),
      isNull,
    );
    expect(isGpsQuestion('Do I have GPS signal?'), isTrue);
    expect(isGpsQuestion('Drive me to my office'), isFalse);
  });

  test(
    'Prisma receives the audio clip and language without the replay state',
    () async {
      http.Request? sent;
      final transport = MockClient((request) async {
        sent = request;
        return http.Response('{"success":true,"transcript":"GPS status"}', 200);
      });
      addTearDown(transport.close);
      final clip = ByteData.sublistView(
        Uint8List.fromList(ascii.encode('OggStest')),
      );
      expect(
        await GnaniSpeech(transport, 'test-key').transcribe(clip, 'audio/ogg'),
        'GPS status',
      );
      final request = sent!;
      expect(request.url, Uri.parse('https://api.vachana.ai/stt/v3'));
      expect(request.headers['x-api-key-id'], 'test-key');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(
        request.body,
        contains('name="audio_file"; filename="question.ogg"'),
      );
      expect(request.body.toLowerCase(), contains('content-type: audio/ogg'));
      expect(request.body, contains('prisma-v3.0'));
      expect(request.body, isNot(contains(blackout.sessionId)));
    },
  );

  test('native WAV is recognized and passed to Prisma', () async {
    final transport = MockClient((request) async {
      expect(request.body, contains('filename="question.wav"'));
      return http.Response('{"success":true,"transcript":"GPS status"}', 200);
    });
    addTearDown(transport.close);
    final bytes = ByteData.sublistView(
      Uint8List.fromList(ascii.encode('RIFF0000WAVE')),
    );
    expect(
      await GnaniSpeech(transport, 'test-key').transcribe(bytes, 'audio/wav'),
      'GPS status',
    );
  });

  test('Timbre receives the status answer and returns WAV audio', () async {
    final answer = replayVoiceAnswer(blackout)!;
    final transport = MockClient((request) async {
      expect(
        request.url,
        Uri.parse('https://api.vachana.ai/api/v1/tts/inference'),
      );
      expect(request.headers['x-api-key-id'], 'test-key');
      final json = jsonDecode(request.body) as Map<String, dynamic>;
      expect(json['text'], answer);
      expect(json['voice'], 'Kaveri');
      expect(json['audio_config'], containsPair('container', 'wav'));
      expect(request.body, isNot(contains(blackout.sessionId)));
      return http.Response.bytes(ascii.encode('RIFF0000WAVE'), 200);
    });
    addTearDown(transport.close);
    expect(
      (await GnaniSpeech(transport, 'test-key').speak(answer))?.lengthInBytes,
      12,
    );
  });

  test(
    'bad clips never leave the app server and provider failure has no audio',
    () async {
      var requests = 0;
      final transport = MockClient((_) async {
        requests++;
        return http.Response('invalid key', 401);
      });
      addTearDown(transport.close);
      final gnani = GnaniSpeech(transport, 'test-key');
      expect(await gnani.transcribe(ByteData(4), 'audio/ogg'), isNull);
      expect(requests, 0);
      expect(await gnani.speak('GPS status'), isNull);
      expect(requests, 1);
    },
  );
}
