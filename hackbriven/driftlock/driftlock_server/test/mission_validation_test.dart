import 'dart:convert';
import 'dart:io';

import 'package:driftlock_server/src/generated/protocol.dart';
import 'package:driftlock_server/src/mission/mission_endpoint.dart';
import 'package:test/test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              '../../../contracts/fixtures/mission_summary.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final summary = MissionSummary.fromJson(fixture);

  test(
    'the canonical mission round-trips with nullable fields and UTC start',
    () {
      final encoded = summary.toJson()..remove('__className__');
      encoded.putIfAbsent('model_version', () => null);
      encoded.putIfAbsent('benchmark_id', () => null);
      encoded['started_at_utc'] = DateTime.parse(
        encoded['started_at_utc'] as String,
      );
      expect(encoded, {
        ...fixture,
        'started_at_utc': DateTime.parse(fixture['started_at_utc'] as String),
      });
    },
  );

  test('explicit consent is required', () {
    expect(
      () => validateMissionForUpload(summary),
      throwsA(isA<MissionRejected>()),
    );
    expect(
      () => validateMissionForUpload(summary.copyWith(consentToUpload: true)),
      returnsNormally,
    );
  });

  test('invalid schema, source, duration and session IDs are rejected', () {
    final consented = summary.copyWith(consentToUpload: true);
    for (final invalid in [
      consented.copyWith(schema: 'driftlock.mission.v2'),
      consented.copyWith(source: 'unclassified'),
      consented.copyWith(durationMs: -1),
      consented.copyWith(sessionId: 'x' * 97),
      consented.copyWith(sessionId: 'demo-001\n'),
    ]) {
      expect(
        () => validateMissionForUpload(invalid),
        throwsA(isA<MissionRejected>()),
      );
    }
  });
}
