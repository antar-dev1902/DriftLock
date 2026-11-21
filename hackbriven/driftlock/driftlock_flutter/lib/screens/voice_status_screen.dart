import 'package:driftlock_client/driftlock_client.dart';
import 'package:flutter/material.dart';

import '../client.dart';
import '../voice/voice_media.dart';
import 'sign_in_screen.dart';

class VoiceStatusScreen extends StatelessWidget {
  const VoiceStatusScreen({
    super.key,
    required this.snapshot,
    required this.localStatus,
    this.maximumError,
  });

  final VoiceState snapshot;
  final String localStatus;
  final double? maximumError;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Voice Copilot')),
    body: Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          Text(localStatus, style: Theme.of(context).textTheme.headlineSmall),
          Text(
            '${(snapshot.tMs / 1000).toStringAsFixed(1)} s on the recording clock',
          ),
          if (snapshot.radius95M == null && snapshot.outageState != 'locked')
            const Text('Position accuracy is unavailable.'),
          const SizedBox(height: 16),
          _TypedQuestion(snapshot: snapshot, maximumError: maximumError),
          const SizedBox(height: 16),
          if (VoiceMedia().supported)
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Gnani voice')),
                    body: ServerpodAccess(
                      child: _ConnectedVoice(
                        snapshot: snapshot,
                        localStatus: localStatus,
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open Gnani voice'),
            )
          else
            const Text(
              'Microphone access is unavailable here. Typed questions work offline.',
            ),
        ],
      ),
    ),
  );
}

class _ConnectedVoice extends StatefulWidget {
  const _ConnectedVoice({required this.snapshot, required this.localStatus});
  final VoiceState snapshot;
  final String localStatus;

  @override
  State<_ConnectedVoice> createState() => _ConnectedVoiceState();
}

class _ConnectedVoiceState extends State<_ConnectedVoice> {
  final _media = VoiceMedia();
  late final _configured = client.voice.isConfigured().timeout(
    const Duration(seconds: 5),
  );
  VoiceReply? _reply;
  String? _activity;
  String? _error;

  @override
  void dispose() {
    _media.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (_activity != null) return;
    setState(() {
      _activity = 'Recording for 6 seconds…';
      _error = null;
      _reply = null;
    });
    try {
      final clip = await _media.record();
      if (!mounted) return;
      setState(() => _activity = 'Sending the clip to Gnani…');
      final reply = await client.voice
          .askByVoice(widget.snapshot, clip.audio, clip.mediaType)
          .timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _reply = reply);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The microphone or speech service is unavailable. Typed questions are available offline.',
        );
      }
    } finally {
      if (mounted) setState(() => _activity = null);
    }
  }

  Future<void> _play() async {
    final audio = _reply?.audio;
    if (audio == null) return;
    try {
      await _media.play(audio);
    } catch (_) {
      if (mounted) setState(() => _error = 'Audio playback is unavailable.');
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Ask about GPS or position confidence. Recording sends a short clip to Gnani through Serverpod.',
      ),
      const SizedBox(height: 16),
      FutureBuilder<bool>(
        future: _configured,
        builder: (context, snapshot) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (snapshot.hasError)
              const Text('Serverpod could not confirm Gnani access.'),
            if (snapshot.data == false)
              const Text('Gnani is awaiting server configuration.'),
            FilledButton.icon(
              icon: const Icon(Icons.mic),
              onPressed: snapshot.data == true && _activity == null
                  ? () => _ask()
                  : null,
              label: const Text('Record and send to Gnani'),
            ),
          ],
        ),
      ),

      if (_activity case final text?) Text(text),
      if (_reply == null) ...[
        const SizedBox(height: 12),
        Text(
          '${widget.localStatus} at ${(widget.snapshot.tMs / 1000).toStringAsFixed(1)} s.',
        ),
      ],
      if (_reply case final reply?) ...[
        const SizedBox(height: 12),
        Text(reply.answer, style: Theme.of(context).textTheme.titleMedium),
        if (reply.status == 'needs_key')
          const Text('Gnani is awaiting server configuration.'),
        if (reply.status == 'gnani_text')
          const Text(
            'Gnani transcribed the question. Audio synthesis is unavailable.',
          ),
        if (reply.status == 'unavailable')
          const Text('Gnani is unavailable. Text status is shown.'),
        if (reply.audio != null)
          FilledButton.icon(
            onPressed: _play,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play Gnani audio'),
          ),
      ],
      if (_error case final error?) Text(error),
    ],
  );
}

class _TypedQuestion extends StatefulWidget {
  const _TypedQuestion({required this.snapshot, required this.maximumError});

  final VoiceState snapshot;
  final double? maximumError;

  @override
  State<_TypedQuestion> createState() => _TypedQuestionState();
}

class _TypedQuestionState extends State<_TypedQuestion> {
  final _input = TextEditingController();
  String? _answer;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _ask(String question) {
    final text = question.toLowerCase().trim();
    if (text.isEmpty) return;
    setState(
      () => _answer = answerReplayQuestion(
        text,
        widget.snapshot,
        widget.maximumError,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _input,
        textInputAction: TextInputAction.send,
        onSubmitted: _ask,
        decoration: const InputDecoration(
          labelText: 'Ask DriftLock offline',
          hintText: 'Are we in a GPS blackout?',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        children: [
          for (final label in [
            'GPS status',
            'Position reliability',
            'Maximum error',
          ])
            ActionChip(label: Text(label), onPressed: () => _ask(label)),
        ],
      ),
      if (_answer case final answer?)
        Semantics(liveRegion: true, child: Text(answer)),
    ],
  );
}

String answerReplayQuestion(
  String text,
  VoiceState snapshot,
  double? maximumError,
) {
  final query = text.toLowerCase();
  if (RegExp(r'\b(maximum|max|worst)\b').hasMatch(query)) {
    return maximumError == null
        ? 'No completed benchmark is available for this replay window.'
        : 'The maximum DriftLock error in this window was ${maximumError.toStringAsFixed(1)} metres against withheld phone GPS.';
  }
  if (RegExp(
    r'\b(reliab\w*|accurac\w*|uncertain\w*|confiden\w*|trust)\b',
  ).hasMatch(query)) {
    return snapshot.radius95M != null && snapshot.calibrated
        ? 'The calibrated 95% radius is ${snapshot.radius95M!.toStringAsFixed(1)} metres.'
        : 'A calibrated confidence radius is unavailable for this replay.';
  }
  if (RegExp(
    r'\b(gps|gnss|signal|blackout|outage|reacquiring|status)\b',
  ).hasMatch(query)) {
    return switch (snapshot.outageState) {
      'locked' => 'GPS is available in this replay frame.',
      'blackout' => 'This replay is in a GPS blackout. GPS fixes are withheld.',
      'reacquiring' =>
        'The blackout interval ended. The replay is waiting for a fresh GPS fix.',
      _ => 'GPS status is unavailable.',
    };
  }
  return 'Try asking about GPS status, position reliability, or the maximum error.';
}
