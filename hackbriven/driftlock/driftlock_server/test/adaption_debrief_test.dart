import 'dart:convert';
import 'dart:io';

import 'package:driftlock_server/src/debrief/adaption_debrief.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

http.Response completion(String answer) => http.Response(
  jsonEncode({
    'choices': [
      {
        'finish_reason': 'stop',
        'message': {'content': answer},
      },
    ],
  }),
  200,
);

void main() {
  test(
    'Adaption receives the audited summary and selects a supported label',
    () async {
      http.Request? sent;
      final transport = MockClient((request) async {
        sent = request;
        return completion(' tradeoff\n');
      });
      addTearDown(transport.close);
      final debrief = AdaptionDebrief(
        transport,
        apiKey: 'test-key',
        model: 'test-model',
      );
      expect(await debrief.chooseFocus(), DebriefFocus.tradeoff);
      final request = sent!;
      expect(request.url.host, 'api.prod.adaptionlabs.ai');
      expect(request.headers['authorization'], 'Bearer test-key');
      expect(request.followRedirects, false);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'test-model');
      expect(body['store'], false);
      expect(body['messages'][1]['content'], austinEvidence);
      expect(
        benchmarkDebrief(DebriefFocus.tradeoff, source: 'adaption').takeaway,
        contains('in two'),
      );
    },
  );

  test(
    'unexpected text and provider error fall back without displaying model output',
    () async {
      final transport = MockClient(
        (_) async =>
            completion('tradeoff: guaranteed accurate under five metres'),
      );
      addTearDown(transport.close);
      final debrief = AdaptionDebrief(
        transport,
        apiKey: 'test-key',
        model: 'test-model',
      );
      final focus = await debrief.chooseFocus();
      expect(focus, isNull);
      final result = benchmarkDebrief(focus, source: 'unavailable');
      expect(result.takeaway, contains('one drive'));
      final failing = MockClient(
        (_) async => http.Response('provider failure', 401),
      );
      addTearDown(failing.close);
      expect(
        await AdaptionDebrief(
          failing,
          apiKey: 'bad',
          model: 'test-model',
        ).chooseFocus(),
        isNull,
      );
    },
  );

  test('the prompt matches the measured benchmark bundled with Flutter', () {
    final pack =
        jsonDecode(
              File(
                '../driftlock_flutter/assets/austin_playback.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final trials = (pack['windows'] as List<dynamic>)
        .map((window) => window['metrics'])
        .toList();
    final drift = trials
        .map((trial) => trial['meanDriftlockErrorMeters'] as num)
        .toList();
    final baseline = trials
        .map((trial) => trial['meanBaselineErrorMeters'] as num)
        .toList();
    String mean(List<num> values) =>
        (values.reduce((a, b) => a + b) / values.length).toStringAsFixed(1);
    final wins = [
      for (var i = 0; i < drift.length; i++)
        if (drift[i] < baseline[i]) i,
    ].length;
    expect(austinEvidence, contains('averaged ${mean(drift)} metres'));
    expect(austinEvidence, contains('compared with ${mean(baseline)} metres'));
    expect(austinEvidence, contains('$wins of ${trials.length} windows'));
  });
}
