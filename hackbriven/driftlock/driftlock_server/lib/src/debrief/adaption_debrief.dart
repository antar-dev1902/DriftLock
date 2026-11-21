import 'dart:convert';

import 'package:http/http.dart' as http;

import '../generated/protocol.dart';

// The audited Austin replay results, also bundled in Flutter's playback asset.
const austinEvidence =
    'In 5 thirty-second outages on one recorded drive, Driftlock averaged '
    '57.9 metres against withheld phone GPS, compared with 76.9 metres for '
    'the last-speed-and-heading baseline. Driftlock had lower mean error in '
    '2 of 5 windows.';

enum DebriefFocus { evidence, tradeoff }

BenchmarkDebrief benchmarkDebrief(
  DebriefFocus? focus, {
  required String source,
}) {
  final takeaway = switch (focus) {
    DebriefFocus.evidence =>
      'Both estimators started from the same pre-outage fix. The errors are '
          'measured against withheld phone GPS on this recorded drive.',
    DebriefFocus.tradeoff =>
      'The average error was lower across the five windows, and Driftlock '
          'improved on the baseline in two. Performance varied across outages.',
    null =>
      'All five windows came from one drive. These measurements describe the '
          'replay under its imposed outages.',
  };
  return BenchmarkDebrief(
    source: source,
    focus: focus?.name ?? 'scope',
    takeaway: takeaway,
  );
}

class AdaptionDebrief {
  AdaptionDebrief(this._client, {required this.apiKey, required this.model});

  final http.Client _client;
  final String apiKey;
  final String model;

  Future<DebriefFocus?> chooseFocus() async {
    final request =
        http.Request(
            'POST',
            Uri.https('api.prod.adaptionlabs.ai', '/api/v1/chat/completions'),
          )
          ..followRedirects = false
          ..headers['Authorization'] = 'Bearer $apiKey'
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({
            'model': model,
            'stream': false,
            'store': false,
            'max_completion_tokens': 512,
            'messages': [
              {
                'role': 'system',
                'content':
                    'Choose the clearest emphasis for this GPS blackout replay benchmark. Return exactly one word: evidence or tradeoff. Choose tradeoff when the average improves but fewer than half of the tested windows improve. Otherwise choose evidence.',
              },
              {'role': 'user', 'content': austinEvidence},
            ],
          });

    try {
      return await (() async {
        final response = await _client.send(request);
        if (response.statusCode != 200) return null;
        const limit = 64 * 1024;
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > limit) return null;
          bytes.addAll(chunk);
        }
        final body = jsonDecode(utf8.decode(bytes));
        if (body case {
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {'content': final String answer},
            },
          ],
        }) {
          return switch (answer.trim().toLowerCase()) {
            'evidence' => DebriefFocus.evidence,
            'tradeoff' => DebriefFocus.tradeoff,
            _ => null,
          };
        }
        return null;
      })().timeout(const Duration(seconds: 10));
    } on Exception {
      return null;
    }
  }
}
