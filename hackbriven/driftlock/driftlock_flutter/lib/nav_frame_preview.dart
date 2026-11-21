import 'dart:convert';

import 'package:driftlock_client/driftlock_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nav_frame.dart';
import 'screens/voice_status_screen.dart';

enum _PreviewSource {
  recorded('Austin recording · Imposed GPS outage'),
  simulated('Simulated outage · Sample values'),
  canonical('Canonical example · Sample values');

  const _PreviewSource(this.label);
  final String label;
}

class NavFramePreview extends StatefulWidget {
  const NavFramePreview({super.key});

  @override
  State<NavFramePreview> createState() => _NavFramePreviewState();
}

class _NavFramePreviewState extends State<NavFramePreview> {
  final _sample = _loadFrames();
  var _index = 0;
  var _source = _PreviewSource.recorded;

  static Future<Map<_PreviewSource, List<NavFrame>>> _loadFrames() async {
    final sources = await Future.wait([
      rootBundle.loadString('assets/nav_frame.json'),
      rootBundle.loadString('assets/nav_frame_demo.jsonl'),
      rootBundle.loadString('assets/nav_frame_austin_swift.jsonl'),
    ]);
    return {
      _PreviewSource.canonical: [NavFrame.fromJson(jsonDecode(sources[0]))],
      _PreviewSource.simulated: NavFrame.readSession(sources[1]),
      _PreviewSource.recorded: NavFrame.readSession(sources[2]),
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('NavFrame preview')),
    body: FutureBuilder(
      future: _sample,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('The bundled NavFrame could not be read.'),
          );
        }
        final sample = snapshot.data;
        if (sample == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final frames = sample[_source]!;
        final frame = frames[_index];
        final status = switch (frame.outageState) {
          NavOutageState.locked => 'GPS locked',
          NavOutageState.blackout => 'GPS blackout',
          NavOutageState.reacquiring => 'Reacquiring GPS',
        };

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DropdownButton<_PreviewSource>(
                  value: _source,
                  isExpanded: true,
                  onChanged: (source) {
                    if (source == null) return;
                    setState(() {
                      _source = source;
                      _index = 0;
                    });
                  },
                  items: [
                    for (final source in _PreviewSource.values)
                      DropdownMenuItem(
                        value: source,
                        child: Text(source.label),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(status, style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  '${(frame.timeMs / 1000).toStringAsFixed(1)} s · ${frame.sessionId}',
                ),
                if (frames.length > 1) ...[
                  Slider(
                    value: _index.toDouble(),
                    max: (frames.length - 1).toDouble(),
                    divisions: frames.length - 1,
                    onChanged: (index) =>
                        setState(() => _index = index.round()),
                    semanticFormatterCallback: (index) =>
                        '${frames[index.round()].timeMs / 1000} seconds',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _index > 0
                            ? () => setState(() => _index--)
                            : null,
                        child: const Text('Previous frame'),
                      ),
                      FilledButton(
                        onPressed: _index < frames.length - 1
                            ? () => setState(() => _index++)
                            : null,
                        child: const Text('Next frame'),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 32),
                Text('Position · ${_position(frame.predicted)}'),
                Text('Speed · ${_value(frame.speedMps, 'm/s')}'),
                Text('Heading · ${_value(frame.headingDeg, '°')}'),
                Text('95% radius · ${_value(frame.radius95M, 'm')}'),
                Text('Road match · ${frame.roadStatus.name}'),
                Text('Engine · ${frame.engineVersion}'),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.graphic_eq),
                  label: const Text('Voice status'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VoiceStatusScreen(
                        localStatus: status,
                        snapshot: VoiceState(
                          schema: 'driftlock.voice_state.v1',
                          sessionId: frame.sessionId,
                          tMs: frame.timeMs,
                          outageState: frame.outageState.name,
                          radius95M: frame.radius95M,
                          calibrated: frame.uncertaintyCalibrated,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  static String _position(NavPosition position) {
    final (latitude: latitude, longitude: longitude) = position;
    if (latitude == null || longitude == null) return 'Unavailable';
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  static String _value(double? value, String unit) =>
      value == null ? 'Unavailable' : '${value.toStringAsFixed(1)} $unit';
}
