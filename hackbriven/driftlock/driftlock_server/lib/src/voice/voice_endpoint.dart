import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'gnani_speech.dart';

String? replayVoiceAnswer(VoiceState state) {
  final radius = state.radius95M;
  if (state.schema != 'driftlock.voice_state.v1' ||
      state.sessionId.isEmpty ||
      state.sessionId.length > 96 ||
      state.tMs < 0 ||
      state.tMs > 9007199254740991 ||
      (radius != null &&
          (!state.calibrated || !radius.isFinite || radius < 0))) {
    return null;
  }
  final message = switch (state.outageState) {
    'locked' => 'GPS is available in this replay frame.',
    'blackout' => 'GPS is withheld.',
    'reacquiring' =>
      'GPS is reacquiring. Driftlock is waiting for a fresh fix.',
    _ => null,
  };
  if (message == null) return null;
  final time = (state.tMs / 1000).toStringAsFixed(1);
  final uncertainty = radius == null && state.outageState != 'locked'
      ? ' Position accuracy is unavailable.'
      : '';
  return 'At $time seconds. $message$uncertainty';
}

bool isGpsQuestion(String transcript) => RegExp(
  r'\b(gps|gnss|signal|blackout|outage|lock|locked|reacquiring|satellite|status)\b',
  caseSensitive: false,
).hasMatch(transcript);

class VoiceEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<bool> isConfigured(Session session) async => _key(session) != null;

  Future<VoiceReply> speakStatus(Session session, VoiceState state) async {
    final answer = replayVoiceAnswer(state);
    if (answer == null) return _invalidState();
    final key = _key(session);
    if (key == null) return VoiceReply(answer: answer, status: 'needs_key');
    final client = http.Client();
    try {
      return await _speak(GnaniSpeech(client, key), answer);
    } finally {
      client.close();
    }
  }

  Future<VoiceReply> askByVoice(
    Session session,
    VoiceState state,
    ByteData clip,
    String mediaType,
  ) async {
    final answer = replayVoiceAnswer(state);
    if (answer == null) return _invalidState();
    final key = _key(session);
    if (key == null) return VoiceReply(answer: answer, status: 'needs_key');
    final client = http.Client();
    try {
      final gnani = GnaniSpeech(client, key);
      final question = await gnani.transcribe(clip, mediaType);
      if (question == null) {
        return VoiceReply(answer: answer, status: 'unavailable');
      }
      final accuracyQuestion = RegExp(
        r'\b(reliab\w*|accurac\w*|uncertain\w*|confiden\w*|trust)\b',
        caseSensitive: false,
      ).hasMatch(question);
      if (accuracyQuestion) {
        final radius = state.radius95M;
        final reliability = radius == null
            ? 'A calibrated confidence radius is unavailable for this replay.'
            : 'The calibrated 95 percent radius is ${radius.toStringAsFixed(1)} metres.';
        return await _speak(gnani, reliability, transcribed: true);
      }
      if (!isGpsQuestion(question)) {
        return VoiceReply(
          answer:
              'Ask about GPS signal or confidence, or use the offline benchmark commands.',
          status: 'try_status_question',
        );
      }
      return await _speak(gnani, answer, transcribed: true);
    } finally {
      client.close();
    }
  }

  String? _key(Session session) {
    final key =
        (session.serverpod.getPassword('gnaniApiKey') ??
                Platform.environment['GNANI_API_KEY'])
            ?.trim();
    return key == null || key.isEmpty ? null : key;
  }

  Future<VoiceReply> _speak(
    GnaniSpeech gnani,
    String answer, {
    bool transcribed = false,
  }) async {
    final audio = await gnani.speak(answer);
    return VoiceReply(
      answer: answer,
      status: audio == null
          ? (transcribed ? 'gnani_text' : 'unavailable')
          : 'gnani',
      audio: audio,
    );
  }

  VoiceReply _invalidState() => VoiceReply(
    answer: 'Replay GPS status is unavailable.',
    status: 'invalid_state',
  );
}
