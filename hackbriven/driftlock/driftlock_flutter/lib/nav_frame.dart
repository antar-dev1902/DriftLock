import 'dart:convert';

enum NavSource { recorded, simulated, live }

enum NavOutageState { locked, blackout, reacquiring }

enum NavRoadStatus { unavailable, ambiguous, matched }

typedef NavPosition = ({double? latitude, double? longitude});

final class NavFrame {
  NavFrame.fromJson(Object? input) {
    final row = _fields(input, 'NavFrame', const {
      'schema',
      'session_id',
      't_ms',
      'source',
      'outage_state',
      'predicted',
      'motion',
      'uncertainty',
      'road_match',
      'versions',
    });
    if (row['schema'] != 'driftlock.nav.v1') {
      throw const FormatException('Expected driftlock.nav.v1');
    }
    final time = row['t_ms'];
    if (time is! int || time < 0) {
      throw const FormatException('t_ms must be a nonnegative integer');
    }
    sessionId = _requiredString(row['session_id'], 'session_id');
    timeMs = time;
    source = _choice(NavSource.values, row['source'], 'source');
    outageState = _choice(
      NavOutageState.values,
      row['outage_state'],
      'outage_state',
    );
    predicted = _position(
      _fields(row['predicted'], 'predicted', const {
        'lat_deg',
        'lon_deg',
      }),
      'predicted',
    );

    final motion = _fields(row['motion'], 'motion', const {
      'speed_mps',
      'heading_deg',
    });
    speedMps = _number(motion['speed_mps'], 'motion.speed_mps');
    headingDeg = _number(motion['heading_deg'], 'motion.heading_deg');
    if (headingDeg case final heading? when heading < 0 || heading >= 360) {
      throw const FormatException('Heading must be in [0, 360)');
    }

    final uncertainty = _fields(row['uncertainty'], 'uncertainty', const {
      'radius_95_m',
      'calibrated',
    });
    final calibrated = uncertainty['calibrated'];
    if (calibrated is! bool) {
      throw const FormatException('uncertainty.calibrated must be a boolean');
    }
    uncertaintyCalibrated = calibrated;
    radius95M = _number(uncertainty['radius_95_m'], 'uncertainty.radius_95_m');
    if (radius95M case final radius? when !calibrated || radius < 0) {
      throw const FormatException(
        'An uncertainty radius must be calibrated and nonnegative',
      );
    }

    final road = _fields(row['road_match'], 'road_match', const {
      'status',
      'lat_deg',
      'lon_deg',
    });
    roadStatus = _choice(
      NavRoadStatus.values,
      road['status'],
      'road_match.status',
    );
    roadPosition = _position(road, 'road_match');
    final versions = _fields(row['versions'], 'versions', const {
      'engine',
      'ml_model',
    });
    engineVersion = _requiredString(versions['engine'], 'versions.engine');
    final model = versions['ml_model'];
    modelVersion = model == null
        ? null
        : _requiredString(model, 'versions.ml_model');
  }

  late final String sessionId;
  late final int timeMs;
  late final NavSource source;
  late final NavOutageState outageState;
  late final NavPosition predicted;
  late final double? speedMps, headingDeg, radius95M;
  late final bool uncertaintyCalibrated;
  late final NavRoadStatus roadStatus;
  late final NavPosition roadPosition;
  late final String engineVersion;
  late final String? modelVersion;

  static List<NavFrame> readSession(String jsonLines) {
    final frames = <NavFrame>[];
    for (final line in const LineSplitter().convert(jsonLines)) {
      if (line.trim().isEmpty) continue;
      final frame = NavFrame.fromJson(jsonDecode(line));
      if (frames.isNotEmpty) {
        final previous = frames.last;
        if (frame.sessionId != previous.sessionId ||
            frame.source != previous.source) {
          throw const FormatException('Replay requires one session and source');
        }
        if (frame.timeMs <= previous.timeMs) {
          throw const FormatException('Replay timestamps must increase');
        }
      }
      frames.add(frame);
    }
    if (frames.isEmpty) throw const FormatException('Replay has no frames');
    return List.unmodifiable(frames);
  }
}

Map<String, dynamic> _fields(Object? value, String label, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !keys.every(value.containsKey)) {
    throw FormatException('Unexpected fields in $label');
  }
  return value;
}

T _choice<T extends Enum>(List<T> choices, Object? value, String label) {
  for (final choice in choices) {
    if (choice.name == value) return choice;
  }
  throw FormatException('Invalid $label');
}

String _requiredString(Object? value, String label) {
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing $label');
  }
  return value;
}

double? _number(Object? value, String label) {
  if (value == null) return null;
  if (value is! num || !value.isFinite) throw FormatException('Invalid $label');
  return value.toDouble();
}

NavPosition _position(Map<String, dynamic> row, String label) {
  final latitude = _number(row['lat_deg'], '$label.lat_deg');
  final longitude = _number(row['lon_deg'], '$label.lon_deg');
  if ((latitude != null && latitude.abs() > 90) ||
      (longitude != null && longitude.abs() > 180)) {
    throw FormatException('Coordinates outside WGS84 range in $label');
  }
  return (latitude: latitude, longitude: longitude);
}
