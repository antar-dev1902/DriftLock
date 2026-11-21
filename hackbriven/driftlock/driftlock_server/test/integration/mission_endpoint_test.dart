import 'package:driftlock_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Mission endpoint', (sessionBuilder, endpoints) {
    final alice = sessionBuilder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        'test-alice',
        {},
      ),
    );
    final bob = sessionBuilder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo('test-bob', {}),
    );
    final guest = sessionBuilder.copyWith(
      authentication: AuthenticationOverride.unauthenticated(),
    );
    final mission = MissionSummary(
      schema: 'driftlock.mission.v1',
      sessionId: 'test-replay-01',
      source: 'recorded',
      startedAtUtc: DateTime.utc(2026, 11, 21),
      durationMs: 60000,
      engineVersion: 'physics-test-v1',
      consentToUpload: true,
    );

    test(
      'save, list and get round-trip the same metadata without duplicate rows',
      () async {
        final first = await endpoints.mission.saveMission(alice, mission);
        final retry = await endpoints.mission.saveMission(alice, mission);
        expect(first.toJson(), mission.toJson());
        expect(retry.toJson(), first.toJson());
        expect(
          await endpoints.mission.listMissions(alice, offset: 0),
          hasLength(1),
        );
        expect(await endpoints.mission.listMissions(alice, offset: 1), isEmpty);
        expect(
          (await endpoints.mission.getMission(
            alice,
            mission.sessionId,
          ))?.toJson(),
          mission.toJson(),
        );
      },
    );

    test('missions are scoped to the authenticated caller', () async {
      await endpoints.mission.saveMission(alice, mission);
      expect(await endpoints.mission.listMissions(bob, offset: 0), isEmpty);
      expect(
        await endpoints.mission.getMission(bob, mission.sessionId),
        isNull,
      );
      await endpoints.mission.saveMission(bob, mission.copyWith(durationMs: 2));
      expect(
        (await endpoints.mission.getMission(
          alice,
          mission.sessionId,
        ))?.durationMs,
        60000,
      );
      expect(
        (await endpoints.mission.getMission(
          bob,
          mission.sessionId,
        ))?.durationMs,
        2,
      );
    });

    test(
      'saving without consent and listing without login are rejected',
      () async {
        await expectLater(
          endpoints.mission.saveMission(
            alice,
            mission.copyWith(consentToUpload: false),
          ),
          throwsA(isA<MissionRejected>()),
        );
        expect(await endpoints.mission.listMissions(alice, offset: 0), isEmpty);
        await expectLater(
          endpoints.mission.listMissions(guest, offset: 0),
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
      },
    );
  });
}
