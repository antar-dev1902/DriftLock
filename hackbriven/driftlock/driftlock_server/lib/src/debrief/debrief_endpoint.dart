import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'adaption_debrief.dart';

class DebriefEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  // Every caller sees the same bundled evidence. Share a request rather than
  // spending credits for each viewer of the same benchmark.
  static Future<BenchmarkDebrief>? _cached;
  static DateTime? _expiresAt;

  Future<BenchmarkDebrief> replay(Session session) async {
    final key =
        (session.serverpod.getPassword('adaptionApiKey') ??
                Platform.environment['ADAPTION_API_KEY'])
            ?.trim();
    final model =
        (session.serverpod.getPassword('adaptionModel') ??
                Platform.environment['ADAPTION_MODEL'])
            ?.trim();
    if (key == null || key.isEmpty || model == null || model.isEmpty) {
      return benchmarkDebrief(null, source: 'unconfigured');
    }
    final now = DateTime.now();
    final cached = _cached;
    if (cached != null && _expiresAt!.isAfter(now)) return cached;
    _expiresAt = now.add(const Duration(minutes: 2));
    return _cached = _create(key, model);
  }

  Future<BenchmarkDebrief> _create(String key, String model) async {
    final client = http.Client();
    try {
      final focus = await AdaptionDebrief(
        client,
        apiKey: key,
        model: model,
      ).chooseFocus();
      return benchmarkDebrief(
        focus,
        source: focus == null ? 'unavailable' : 'adaption',
      );
    } finally {
      client.close();
    }
  }
}
