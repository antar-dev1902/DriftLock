import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

final _identifier = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$');

void validateMissionForUpload(MissionSummary summary) {
  if (!summary.consentToUpload) {
    throw MissionRejected(message: 'Mission upload requires explicit consent.');
  }
  if (summary.schema != 'driftlock.mission.v1') {
    throw MissionRejected(message: 'Unsupported mission schema.');
  }
  if (!const {'recorded', 'simulated', 'live'}.contains(summary.source) ||
      !summary.startedAtUtc.isUtc ||
      summary.durationMs < 0 ||
      summary.durationMs > 9007199254740991) {
    throw MissionRejected(
      message: 'Invalid mission source, start or duration.',
    );
  }
  _validateIdentifier(summary.sessionId, 'session ID');
  _validateIdentifier(summary.engineVersion, 'engine version');
  if (summary.modelVersion case final version?) {
    _validateIdentifier(version, 'model version');
  }
  if (summary.benchmarkId case final id?) {
    _validateIdentifier(id, 'benchmark ID');
  }
}

void _validateIdentifier(String value, String label) {
  final match = _identifier.firstMatch(value);
  if (match == null || match.end != value.length) {
    throw MissionRejected(message: 'Invalid $label.');
  }
}

class MissionEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<MissionSummary> saveMission(
    Session session,
    MissionSummary summary,
  ) async {
    final owner = session.authenticated!.userIdentifier;
    validateMissionForUpload(summary);
    final saved = await MissionRecord.db.upsertRow(
      session,
      MissionRecord(
        ownerIdentifier: owner,
        sessionId: summary.sessionId,
        startedAtUtc: summary.startedAtUtc,
        summary: summary,
      ),
      conflictColumns: (row) => [row.ownerIdentifier, row.sessionId],
    );
    if (saved == null) {
      throw MissionRejected(message: 'The mission could not be saved.');
    }
    return saved.summary;
  }

  Future<List<MissionSummary>> listMissions(
    Session session, {
    int offset = 0,
  }) async {
    final owner = session.authenticated!.userIdentifier;
    if (offset < 0) {
      throw MissionRejected(message: 'Invalid mission list offset.');
    }
    final rows = await MissionRecord.db.find(
      session,
      where: (row) => row.ownerIdentifier.equals(owner),
      orderByList: (row) => [
        row.startedAtUtc.desc(),
        row.sessionId.asc(),
      ],
      offset: offset,
      limit: 50,
    );
    return rows.map((row) => row.summary).toList();
  }

  Future<MissionSummary?> getMission(Session session, String sessionId) async {
    final owner = session.authenticated!.userIdentifier;
    _validateIdentifier(sessionId, 'session ID');
    final row = await MissionRecord.db.findFirstRow(
      session,
      where: (row) =>
          row.ownerIdentifier.equals(owner) & row.sessionId.equals(sessionId),
    );
    return row?.summary;
  }
}
