import 'dart:async';
import 'dart:math' as math;

import 'package:driftlock_client/driftlock_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nav_frame_preview.dart';
import 'platform_io.dart';
import 'playback.dart';
import 'screens/benchmark_screen.dart';
import 'screens/mission_screen.dart';
import 'screens/voice_status_screen.dart';

const _graphite = Color(0xff0b1118);
const _surface = Color(0xff111b26);
const _cyan = Color(0xff66e6ff);
const _green = Color(0xff80efae);
const _amber = Color(0xffffbc72);
const _muted = Color(0xffaab9cc);
const _border = Color(0xff2a3b4d);
const _parked = Color(0xffc5a6f6);

void main() => runApp(const DriftlockApp());

class DriftlockApp extends StatelessWidget {
  const DriftlockApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DriftLock',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _cyan,
        onPrimary: _graphite,
        secondary: _green,
        surface: _surface,
      ),
      scaffoldBackgroundColor: _graphite,
      useMaterial3: true,
    ),
    home: const ReplayScreen(),
  );
}

class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen>
    with WidgetsBindingObserver {
  final _austin = Playback.load();
  Playback? _capture;
  String? _captureId;
  Timer? _timer;
  var _time = 0.0;
  var _rate = 2.0;
  var _window = 0;
  var _evaluation = false;
  var _missionControl = true;
  var _judge = false;
  var _loadingCapture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _timer != null) setState(_stop);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _start(ReplayWindow window, {double? from}) {
    _stop();
    final start = from ?? (_time >= window.duration ? 0.0 : _time);
    final clock = Stopwatch()..start();
    setState(() {
      _time = start;
      _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        setState(() {
          _time = math.min(
            window.duration,
            start + clock.elapsedMicroseconds * _rate / 1000000,
          );
          if (_time >= window.duration) _stop();
        });
      });
    });
  }

  void _openReplay({bool judge = false}) {
    setState(() {
      _stop();
      _capture = null;
      _captureId = null;
      _missionControl = false;
      _judge = judge;
      _evaluation = false;
      _rate = 2;
      _time = 0;
      _window = 0;
    });
  }

  Future<void> _openCapture([String? capture]) async {
    if (_loadingCapture) return;
    setState(() {
      _stop();
      _loadingCapture = true;
    });
    try {
      final raw = capture == null
          ? await nativeChannel.invokeMapMethod<String, String>('openRecorder')
          : await nativeChannel.invokeMapMethod<String, String>(
              'loadCapture',
              capture,
            );
      if (!mounted || raw == null) return;
      final replay = Playback.parse(raw['playback']!);
      setState(() {
        _capture = replay;
        _captureId = raw['id'];
        _missionControl = false;
        _judge = false;
        _evaluation = false;
        _time = 0;
        _window = 0;
      });
    } on PlatformException catch (error) {
      if (mounted) {
        _notice(error.message ?? 'This iPhone capture could not be opened.');
      }
    } catch (_) {
      if (mounted) _notice('This iPhone capture could not be opened.');
    } finally {
      if (mounted) setState(() => _loadingCapture = false);
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _navigate(Widget target) {
    setState(_stop);
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => target));
  }

  void _missions() async {
    setState(_stop);
    final selection = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const MissionScreen()),
    );
    if (!mounted || selection == null) return;
    if (selection == 'austin') {
      _openReplay();
    } else {
      await _openCapture(selection);
    }
  }

  void _voice(ReplayWindow window) {
    final state = window.stateAt(_time);
    final status = switch (state) {
      'blackout' => 'GPS blackout',
      'reacquiring' => 'Reacquiring GPS',
      _ => 'GPS locked',
    };
    final recovered = window.resumes != null && _time >= window.resumes!;
    _navigate(
      VoiceStatusScreen(
        snapshot: VoiceState(
          schema: 'driftlock.voice_state.v1',
          sessionId: _captureId == null
              ? 'swift-replay-${window.id}'
              : 'local-replay',
          tMs: ((window.recordingStart + _time) * 1000).round(),
          outageState: state,
          calibrated: false,
        ),
        localStatus: status,
        maximumError:
            recovered && window.drift != null && window.errors.isNotEmpty
            ? window.errors.map((row) => row.drift).reduce(math.max)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: _graphite,
      leading: _missionControl
          ? const Icon(Icons.near_me_rounded, color: _cyan)
          : IconButton(
              tooltip: 'Mission Control',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _stop();
                _missionControl = true;
              }),
            ),
      title: const Text(
        'DRIFTLOCK',
        style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: 'Mission Library',
          onPressed: _missions,
          icon: const Icon(Icons.folder_open_outlined),
        ),
        IconButton(
          tooltip: 'Open NavFrame preview',
          onPressed: () => _navigate(const NavFramePreview()),
          icon: const Icon(Icons.data_object),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder(
        future: _austin,
        builder: (context, snapshot) {
          if (snapshot.hasError && _capture == null) {
            return const Center(
              child: Text('The bundled driving session could not be read.'),
            );
          }
          final playback = _capture ?? snapshot.data;
          if (playback == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final window = playback.windows[_window];
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _missionControl
                  ? _home(playback, window)
                  : _replay(playback, window),
            ),
          );
        },
      ),
    ),
  );

  Widget _home(Playback playback, ReplayWindow window) => ListView(
    key: const ValueKey('mission-control'),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    children: [
      const Text('Mission Control', style: _heading),
      const SizedBox(height: 5),
      const Text(
        'Navigation beyond GPS',
        style: TextStyle(color: _muted, fontSize: 17),
      ),
      const SizedBox(height: 16),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _status(window, _time),
            const SizedBox(height: 9),
            _telemetry(window, _time),
          ],
        ),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Open Replay'),
        onPressed: _openReplay,
      ),
      OutlinedButton.icon(
        icon: const Icon(Icons.fiber_manual_record, size: 16),
        label: Text(_loadingCapture ? 'Opening recorder…' : 'Start Recording'),
        onPressed: _loadingCapture
            ? null
            : () => hasIPhoneBridge
                  ? _openCapture()
                  : _notice(
                      'Location and motion capture are available on a physical iPhone.',
                    ),
      ),
      OutlinedButton.icon(
        icon: const Icon(Icons.analytics_outlined),
        label: const Text('Benchmark Arena'),
        onPressed: () => _navigate(const BenchmarkScreen()),
      ),
      TextButton.icon(
        icon: const Icon(Icons.slideshow),
        label: const Text('Start Judge Mode'),
        onPressed: () => _openReplay(judge: true),
      ),
      const SizedBox(height: 15),
      const Text('Recent missions', style: _subheading),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.route, color: _cyan),
        title: Text(playback.title),
        subtitle: const Text('Recorded session · available offline'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _capture == null
            ? _openReplay()
            : setState(() => _missionControl = false),
      ),
      const Divider(),
      const Text(
        'Navigation works offline. Serverpod and sponsor services connect on demand.',
        style: TextStyle(color: _muted),
      ),
    ],
  );

  Widget _replay(Playback playback, ReplayWindow window) {
    final state = window.stateAt(_time);
    final recovered = window.resumes != null && _time >= window.resumes!;
    final visibleErrors = _evaluation
        ? window.errors.where((row) => row.availableAt <= _time).toList()
        : <
            ({double availableAt, double drift, double constant, double parked})
          >[];
    return ListView(
      key: const ValueKey('blackout-replay'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (_judge) ...[
          const Text('Judge Mode', style: _subheading),
          const Text(
            'A tunnel can take away your GPS fix. Replay an imposed blackout, '
            'then compare how far each estimate strayed from the withheld fixes.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 12),
        ],
        Text(playback.title, style: _heading),
        const SizedBox(height: 4),
        Text(
          '${playback.device} · Recorded motion · Imposed GPS outage',
          style: const TextStyle(color: _muted),
        ),
        const SizedBox(height: 12),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _status(window, _time)),
                  DropdownButton<int>(
                    value: _window,
                    underline: const SizedBox.shrink(),
                    onChanged: (next) {
                      if (next == null) return;
                      setState(() {
                        _stop();
                        _window = next;
                        _time = 0;
                      });
                    },
                    items: [
                      for (final (index, trial) in playback.windows.indexed)
                        DropdownMenuItem(
                          value: index,
                          child: Text('Window ${trial.id}'),
                        ),
                    ],
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 256,
                  child: Semantics(
                    label:
                        'Offline route plot. GPS observations in green, prediction in cyan.',
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _RoutePainter(window, _time, _evaluation),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  const _Legend('Measured GPS', _green),
                  const _Legend('Estimate', _cyan),
                  const _Legend('Constant speed', _amber),
                  const _Legend('Last known position', _parked),
                  if (_evaluation) const _Legend('Withheld GPS', _muted),
                ],
              ),
              const SizedBox(height: 10),
              _telemetry(window, _time),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Slider(
                value: _time,
                max: window.duration,
                onChanged: (value) => setState(() {
                  _stop();
                  _time = value;
                }),
                semanticFormatterCallback: (value) =>
                    '${value.round()} seconds into the window',
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_time.toStringAsFixed(1)} / ${window.duration.round()} s',
                    ),
                  ),
                  const Text('Playback  '),
                  DropdownButton<double>(
                    value: _rate,
                    onChanged: (next) {
                      if (next == null) return;
                      final playing = _timer != null;
                      setState(() => _rate = next);
                      if (playing) _start(window);
                    },
                    items: [
                      for (final rate in [0.5, 1.0, 2.0, 4.0])
                        DropdownMenuItem(
                          value: rate,
                          child: Text('${rate == .5 ? '0.5' : rate.round()}×'),
                        ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        _timer == null ? _start(window) : setState(_stop),
                    icon: Icon(_timer == null ? Icons.play_arrow : Icons.pause),
                    label: Text(_timer == null ? 'Play' : 'Pause'),
                  ),
                  OutlinedButton(
                    onPressed: _time < window.cut
                        ? () => _start(window, from: window.cut)
                        : () => setState(() {
                            _stop();
                            _time = 0;
                          }),
                    child: Text(
                      _time < window.cut ? 'Start outage' : 'Restart',
                    ),
                  ),
                  FilterChip(
                    label: const Text('Evaluation mode'),
                    selected: _evaluation,
                    onSelected: (value) => setState(() => _evaluation = value),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Localization uncertainty', style: _subheading),
              const SizedBox(height: 4),
              Text(
                state == 'locked'
                    ? 'Position comes from recorded GPS fixes.'
                    : !window.estimateAvailableAt(_time)
                    ? 'Estimate unavailable. Timing or sensor coverage is insufficient.'
                    : 'Dead reckoning is unverified · ${(_time - window.cut).toStringAsFixed(1)} s since GPS loss.',
                style: TextStyle(color: state == 'locked' ? _muted : _amber),
              ),
              const Text(
                'Calibrated confidence radius unavailable.',
                style: TextStyle(color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_evaluation)
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Position error over time', style: _subheading),
                const Text(
                  'Evaluation against withheld phone GPS (m).',
                  style: TextStyle(color: _muted),
                ),
                if (visibleErrors.isEmpty)
                  const Text('Waiting for evaluation samples.')
                else ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 84,
                    child: CustomPaint(
                      painter: _ErrorPainter(
                        visibleErrors
                            .map(
                              (row) => (
                                row.availableAt - window.cut,
                                row.drift,
                                row.constant,
                                row.parked,
                              ),
                            )
                            .toList(),
                        window.restore - window.cut,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Text(
                    'Latest · estimate ${visibleErrors.last.drift.toStringAsFixed(1)} m · '
                    'constant speed ${visibleErrors.last.constant.toStringAsFixed(1)} m · '
                    'last known ${visibleErrors.last.parked.toStringAsFixed(1)} m',
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.insights),
              label: const Text('View benchmark'),
              onPressed: () => _navigate(BenchmarkScreen(capture: _captureId)),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.record_voice_over_outlined),
              label: const Text('Voice Copilot'),
              onPressed: () => _voice(window),
            ),
          ],
        ),
        if (recovered && window.drift != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Window mean error · DriftLock ${window.drift!.toStringAsFixed(1)} m · '
              'constant speed ${window.constant!.toStringAsFixed(1)} m',
            ),
          ),
      ],
    );
  }
}

const _heading = TextStyle(
  fontSize: 30,
  fontWeight: FontWeight.w800,
  letterSpacing: -.9,
);
const _subheading = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);

Widget _status(ReplayWindow window, double time) {
  final state = window.stateAt(time);
  final status = switch (state) {
    'blackout' => 'GPS blackout',
    'reacquiring' => 'Reacquiring GPS',
    _ when window.resumes != null && time >= window.resumes! => 'GPS restored',
    _ => 'GPS locked',
  };
  final color = state == 'locked' ? _green : _amber;
  return Row(
    children: [
      Icon(
        state == 'locked' ? Icons.gps_fixed : Icons.gps_off,
        size: 17,
        color: color,
      ),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          status,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

Widget _telemetry(ReplayWindow window, double time) {
  final motion = window.motionAt(time);
  return Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: 10,
    runSpacing: 6,
    children: [
      Text(
        motion == null
            ? 'Speed —'
            : '${(motion.$2 * 3.6).toStringAsFixed(0)} km/h',
      ),
      Text(motion == null ? 'Heading —' : '${motion.$3.round() % 360}° true'),
      Text(
        window.stateAt(time) == 'locked'
            ? 'GPS measurement'
            : 'Motion estimate',
        style: const TextStyle(color: _muted),
      ),
    ],
  );
}

Widget _panel(Widget child) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: _surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _border),
  ),
  child: child,
);

class _Legend extends StatelessWidget {
  const _Legend(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '● ',
          style: TextStyle(color: color),
        ),
        TextSpan(text: text),
      ],
    ),
    style: const TextStyle(fontSize: 12, color: _muted),
  );
}

void _line(
  Canvas canvas,
  List<Offset> points,
  Color color, {
  double width = 2,
  bool marker = false,
}) {
  if (points.isEmpty) return;
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke,
  );
  if (marker) {
    canvas.drawCircle(points.last, 6, Paint()..color = _graphite);
    canvas.drawCircle(points.last, 4, Paint()..color = color);
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.window, this.time, this.reference);

  final ReplayWindow window;
  final double time;
  final bool reference;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(_graphite, BlendMode.src);
    final grid = Paint()..color = _border.withValues(alpha: .55);
    for (double x = 0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final all = [...window.observed, ...window.estimate, ...window.baseline];
    final minX = all.map((row) => row.$2.dx).reduce(math.min);
    final maxX = all.map((row) => row.$2.dx).reduce(math.max);
    final minY = all.map((row) => row.$2.dy).reduce(math.min);
    final maxY = all.map((row) => row.$2.dy).reduce(math.max);
    final scale = math.min(
      (size.width - 46) / math.max(maxX - minX, 1),
      (size.height - 48) / math.max(maxY - minY, 1),
    );
    Offset transform(Offset point) => Offset(
      size.width / 2 + (point.dx - (minX + maxX) / 2) * scale,
      size.height / 2 - (point.dy - (minY + maxY) / 2) * scale,
    );
    void trace(
      Iterable<RouteSample> path,
      Color color, {
      bool marker = true,
      double width = 2,
    }) {
      final points = path
          .where((row) => row.$1 <= time)
          .map((row) => transform(row.$2))
          .toList();
      _line(canvas, points, color, width: width, marker: marker);
    }

    final isLocked = window.stateAt(time) == 'locked';
    trace(
      window.observed.where((row) => row.$1 < window.cut),
      _green,
      marker: time < window.cut,
    );
    if (reference) trace(window.withheld, _muted.withValues(alpha: .8));
    trace(window.baseline, _amber, marker: !isLocked);
    if (window.parked case final point? when time >= window.cut) {
      trace([point], _parked);
    }
    trace(
      window.estimate,
      _cyan,
      marker: !isLocked && window.estimateAvailableAt(time),
      width: 3,
    );
    if (window.resumes case final resumed?) {
      trace(window.observed.where((row) => row.$1 >= resumed), _green);
    }
    final font = TextPainter(
      text: const TextSpan(
        text: '↑ N',
        style: TextStyle(color: _muted, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    font.paint(canvas, Offset(size.width - font.width - 11, 10));
    font.dispose();
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.window != window || old.time != time || old.reference != reference;
}

class _ErrorPainter extends CustomPainter {
  _ErrorPainter(this.samples, this.duration);
  final List<(double, double, double, double)> samples;
  final double duration;

  @override
  void paint(Canvas canvas, Size size) {
    final maximum = samples
        .map((row) => math.max(row.$2, math.max(row.$3, row.$4)))
        .reduce(math.max);
    final grid = Paint()..color = _border;
    for (final level in [0.0, .5, 1.0]) {
      canvas.drawLine(
        Offset(0, size.height * level),
        Offset(size.width, size.height * level),
        grid,
      );
    }
    List<Offset> trace(
      double Function((double, double, double, double)) value,
    ) => [
      for (final row in samples)
        Offset(
          (row.$1 / duration).clamp(0, 1) * size.width,
          (1 - value(row) / math.max(1, maximum)) * (size.height - 6) + 3,
        ),
    ];
    _line(canvas, trace((row) => row.$4), _parked);
    _line(canvas, trace((row) => row.$3), _amber);
    _line(canvas, trace((row) => row.$2), _cyan, width: 2.5, marker: true);
  }

  @override
  bool shouldRepaint(covariant _ErrorPainter old) =>
      old.samples.length != samples.length ||
      old.duration != duration ||
      old.samples.last != samples.last;
}
