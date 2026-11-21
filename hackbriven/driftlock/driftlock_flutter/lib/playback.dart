import 'dart:convert';

import 'package:flutter/services.dart';

class Playback {
  Playback._(this.title, this.device, this.windows);

  final String title;
  final String device;
  final List<ReplayWindow> windows;

  static Future<Playback> load() async => Playback.parse(
    await rootBundle.loadString('assets/austin_replay_v2.json'),
  );

  factory Playback.parse(String contents) {
    final json = jsonDecode(contents) as Map<String, dynamic>;
    if (json['schema'] != 'driftlock-flutter-playback-v2') {
      throw const FormatException('Unknown playback schema');
    }
    final windows = (json['windows'] as List)
        .map((row) => ReplayWindow(row))
        .toList();
    if (windows.isEmpty) throw const FormatException('No playback windows');
    return Playback._(
      json['title'] as String,
      json['device'] as String,
      windows,
    );
  }
}

typedef RouteSample = (double, Offset);
typedef MotionSample = (double, double, double);

class ReplayWindow {
  ReplayWindow(Map json)
    : id = json['id'] as String,
      recordingStart = _number(json['recordingStart']),
      cut = _number(json['cut']),
      restore = _number(json['restore']),
      resumes = (json['resumes'] as num?)?.toDouble(),
      duration = _number(json['duration']),
      drift = (json['metrics']['meanDriftlockErrorMeters'] as num?)?.toDouble(),
      constant = (json['metrics']['meanBaselineErrorMeters'] as num?)
          ?.toDouble(),
      observed = _samples(json['observed'] as List),
      withheld = _samples(json['withheld'] as List),
      estimate = _samples(json['estimate'] as List),
      baseline = _samples(json['baseline'] as List),
      parked = json['lastPosition'] == null
          ? null
          : _sample(json['lastPosition']),
      motion = [
        for (final List row in json['motion'] as List)
          (_number(row[0]), _number(row[1]), _number(row[2])),
      ],
      errors = [
        for (final Map row in json['errors'] as List)
          (
            availableAt: _number(row['availableAt']),
            drift: _number(row['driftlock']),
            constant: _number(row['constant']),
            parked: _number(row['lastPosition']),
          ),
      ] {
    if (!(0 <= cut && cut < restore && restore <= duration) ||
        (resumes != null && !(restore <= resumes! && resumes! <= duration)) ||
        observed.isEmpty ||
        observed.any(
          (row) => row.$1 >= cut && row.$1 < (resumes ?? double.infinity),
        )) {
      throw const FormatException('Invalid GNSS replay timeline');
    }
  }

  final String id;
  final double recordingStart, cut, restore, duration;
  final double? resumes, drift, constant;
  final List<RouteSample> observed, withheld, estimate, baseline;
  final RouteSample? parked;
  final List<MotionSample> motion;
  final List<
    ({double availableAt, double drift, double constant, double parked})
  >
  errors;

  String stateAt(double time) {
    if (time < cut || (resumes != null && time >= resumes!)) return 'locked';
    return time < restore ? 'blackout' : 'reacquiring';
  }

  bool estimateAvailableAt(double time) =>
      estimate.isNotEmpty &&
      time >= estimate.first.$1 &&
      time - estimate.last.$1 <= .21;

  MotionSample? motionAt(double time) {
    final state = stateAt(time);
    if (state != 'locked' && !estimateAvailableAt(time)) return null;
    for (final sample in motion.reversed) {
      if (sample.$1 <= time) return sample;
    }
    return null;
  }

  static double _number(Object? value) {
    if (value is! num || !value.isFinite) {
      throw const FormatException('Non-finite replay value');
    }
    return value.toDouble();
  }

  static RouteSample _sample(List row) => (
    _number(row[0]),
    Offset(_number(row[1]), _number(row[2])),
  );

  static List<RouteSample> _samples(List input) {
    final samples = input.map((row) => _sample(row as List)).toList();
    for (var i = 1; i < samples.length; i++) {
      if (samples[i - 1].$1 >= samples[i].$1) {
        throw const FormatException('Replay timestamps must increase');
      }
    }
    return samples;
  }
}
