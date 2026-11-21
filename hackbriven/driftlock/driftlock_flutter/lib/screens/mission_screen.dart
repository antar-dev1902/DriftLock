import 'dart:convert';

import 'package:driftlock_client/driftlock_client.dart';
import 'package:flutter/material.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../client.dart';
import '../platform_io.dart';
import 'sign_in_screen.dart';

class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  late final _local = hasIPhoneBridge
      ? nativeChannel.invokeListMethod<Map>('listCaptures')
      : Future<List<Map>?>.value([]);

  static final _austin = MissionSummary(
    schema: 'driftlock.mission.v1',
    sessionId: 'cloudpose-austin-dataset1',
    source: 'recorded',
    startedAtUtc: DateTime.fromMillisecondsSinceEpoch(
      1523201497097,
      isUtc: true,
    ),
    durationMs: 341814,
    engineVersion: 'driftlock-ios-planar-v1',
    benchmarkId: 'cloudpose-austin-dataset1',
    consentToUpload: false,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Missions')),
    body: _MissionColumn(
      children: [
        Text(
          'Available offline',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.route),
          title: const Text('Austin recording'),
          subtitle: Text(
            '${_describe(_austin)}\n'
            'Engine ${_austin.engineVersion} · Physics only\n'
            'GPS outages imposed in replay · Austin benchmark · Offline',
          ),
          trailing: const Icon(Icons.play_arrow),
          onTap: () => Navigator.pop(context, 'austin'),
        ),
        if (hasIPhoneBridge)
          FutureBuilder(
            future: _local,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Local recordings could not be listed.');
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              final recordings = snapshot.data ?? [];
              if (recordings.isEmpty) {
                return const Text('No iPhone recordings yet.');
              }
              return Column(
                children: [
                  for (final file in recordings)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        (file['id'] as String).replaceFirst('.csv', ''),
                      ),
                      subtitle: Text(
                        'iPhone capture · ${file['date']} · Local only',
                      ),
                      onTap: () => Navigator.pop(context, file['id']),
                      trailing: IconButton(
                        tooltip: 'Share recorded CSV',
                        icon: const Icon(Icons.ios_share),
                        onPressed: () async {
                          try {
                            await nativeChannel.invokeMethod<void>(
                              'shareCapture',
                              file['id'],
                            );
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Recording export unavailable.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Export Austin mission summary'),
          onPressed: () async {
            try {
              await exportText(
                'driftlock-austin-mission.json',
                _missionJson(_austin),
              );
              if (context.mounted && !hasIPhoneBridge) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mission JSON export ready')),
                );
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mission export unavailable.')),
                );
              }
            }
          },
        ),
        const SizedBox(height: 18),
        const Text(
          'Serverpod connects when you open sync. Saving the Austin summary requires consent.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.cloud_outlined),
          label: const Text('Open Serverpod sync'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _MissionConnection(summary: _austin),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MissionConnection extends StatelessWidget {
  const _MissionConnection({required this.summary});
  final MissionSummary summary;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Serverpod sync')),
    body: ServerpodAccess(child: _SyncedMissions(summary: summary)),
  );
}

class _SyncedMissions extends StatefulWidget {
  const _SyncedMissions({required this.summary});
  final MissionSummary summary;

  @override
  State<_SyncedMissions> createState() => _SyncedMissionsState();
}

class _SyncedMissionsState extends State<_SyncedMissions> {
  late Future<List<MissionSummary>> _missions = _loadMissions();
  bool _consent = false;
  bool _saving = false;
  bool _opening = false;

  Future<List<MissionSummary>> _loadMissions() => client.mission
      .listMissions(offset: 0)
      .timeout(const Duration(seconds: 8));

  Future<void> _save() async {
    if (!_consent || _saving) return;
    setState(() => _saving = true);
    try {
      await client.mission
          .saveMission(widget.summary.copyWith(consentToUpload: true))
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _consent = false;
        _missions = _loadMissions();
      });
      _notice('Austin mission summary saved.');
    } on MissionRejected catch (error) {
      if (mounted) _notice(error.message);
    } catch (_) {
      if (mounted) {
        _notice('Save could not be confirmed. You can retry this mission.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open(String sessionId) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final summary = await client.mission
          .getMission(sessionId)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (summary == null) {
        _notice('This saved mission is unavailable.');
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(summary.sessionId),
          content: Text(
            '${_describe(summary)}\n\nEngine ${summary.engineVersion}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) _notice('Could not load the mission from Serverpod.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await client.auth.signOutDevice();
    } catch (_) {
      if (mounted) _notice('Could not sign out. Try again when connected.');
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => _MissionColumn(
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _consent,
        onChanged: _saving
            ? null
            : (value) => setState(() => _consent = value ?? false),
        title: const Text('Allow saving the Austin mission summary'),
        subtitle: const Text(
          'Shares session ID, recording time, duration, source, and engine version.',
        ),
      ),
      FilledButton(
        onPressed: _consent && !_saving ? _save : null,
        child: Text(_saving ? 'Saving…' : 'Save mission summary'),
      ),
      const Divider(height: 32),
      Row(
        children: [
          Expanded(
            child: Text(
              'Saved missions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Refresh missions',
            onPressed: () => setState(() => _missions = _loadMissions()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      FutureBuilder<List<MissionSummary>>(
        future: _missions,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) return const Text('Serverpod is unavailable.');
          final missions = snapshot.data ?? [];
          if (missions.isEmpty) return const Text('No saved missions yet.');
          return Column(
            children: [
              for (final mission in missions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(mission.sessionId),
                  subtitle: Text(_describe(mission)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _opening ? null : () => _open(mission.sessionId),
                ),
            ],
          );
        },
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _saving || _opening ? null : _signOut,
          child: const Text('Sign out'),
        ),
      ),
    ],
  );
}

class _MissionColumn extends StatelessWidget {
  const _MissionColumn({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(padding: const EdgeInsets.all(20), children: children),
    ),
  );
}

String _describe(MissionSummary mission) =>
    '${mission.source} · ${mission.durationMs / 1000} s · ${mission.startedAtUtc.toUtc().toIso8601String()}';

String _missionJson(MissionSummary mission) =>
    const JsonEncoder.withIndent('  ').convert({
      'schema': mission.schema,
      'session_id': mission.sessionId,
      'source': mission.source,
      'started_at_utc': mission.startedAtUtc.toUtc().toIso8601String(),
      'duration_ms': mission.durationMs,
      'engine_version': mission.engineVersion,
      'model_version': mission.modelVersion,
      'benchmark_id': mission.benchmarkId,
      'consent_to_upload': mission.consentToUpload,
    });
