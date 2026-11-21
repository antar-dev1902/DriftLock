import 'package:driftlock_client/driftlock_client.dart';
import 'package:flutter/material.dart';

import '../client.dart';
import 'sign_in_screen.dart';

class BenchmarkDebriefScreen extends StatelessWidget {
  const BenchmarkDebriefScreen({super.key, required this.evidence});

  final String evidence;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Replay debrief')),
    body: ServerpodAccess(child: _DebriefBody(evidence: evidence)),
  );
}

class _DebriefBody extends StatefulWidget {
  const _DebriefBody({required this.evidence});

  final String evidence;

  @override
  State<_DebriefBody> createState() => _DebriefBodyState();
}

class _DebriefBodyState extends State<_DebriefBody> {
  Future<BenchmarkDebrief>? _debrief;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(widget.evidence, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          FutureBuilder<BenchmarkDebrief>(
            future: _debrief,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              final result = snapshot.data;
              if (result != null) {
                final label = switch (result.source) {
                  'adaption' => 'Emphasis selected by Adaption',
                  'unconfigured' => 'Verified summary · Adaption setup pending',
                  _ => 'Verified summary · Adaption unavailable',
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(label), Text(result.takeaway)],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (snapshot.hasError)
                    const Text(
                      'Adaption is unavailable. The measured replay results are shown above.',
                    ),
                  FilledButton(
                    onPressed: () => setState(() {
                      _debrief = client.debrief.replay().timeout(
                        const Duration(seconds: 12),
                      );
                    }),
                    child: Text(
                      snapshot.hasError
                          ? 'Retry Adaption'
                          : 'Ask Adaption to explain',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
