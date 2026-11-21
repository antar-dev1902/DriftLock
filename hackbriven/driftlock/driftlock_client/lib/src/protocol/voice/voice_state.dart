/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

abstract class VoiceState
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  VoiceState._({
    required this.schema,
    required this.sessionId,
    required this.tMs,
    required this.outageState,
    this.radius95M,
    required this.calibrated,
  });

  factory VoiceState({
    required String schema,
    required String sessionId,
    required int tMs,
    required String outageState,
    double? radius95M,
    required bool calibrated,
  }) = _VoiceStateImpl;

  factory VoiceState.fromJson(Map<String, dynamic> jsonSerialization) {
    return VoiceState(
      schema: jsonSerialization['schema'] as String,
      sessionId: jsonSerialization['session_id'] as String,
      tMs: jsonSerialization['t_ms'] as int,
      outageState: jsonSerialization['outage_state'] as String,
      radius95M: (jsonSerialization['radius_95_m'] as num?)?.toDouble(),
      calibrated: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['calibrated'],
      ),
    );
  }

  String schema;

  String sessionId;

  int tMs;

  String outageState;

  double? radius95M;

  bool calibrated;

  /// Returns a shallow copy of this [VoiceState]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  VoiceState copyWith({
    String? schema,
    String? sessionId,
    int? tMs,
    String? outageState,
    double? radius95M,
    bool? calibrated,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VoiceState',
      'schema': schema,
      'session_id': sessionId,
      't_ms': tMs,
      'outage_state': outageState,
      if (radius95M != null) 'radius_95_m': radius95M,
      'calibrated': calibrated,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VoiceState',
      'schema': schema,
      'session_id': sessionId,
      't_ms': tMs,
      'outage_state': outageState,
      if (radius95M != null) 'radius_95_m': radius95M,
      'calibrated': calibrated,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VoiceStateImpl extends VoiceState {
  _VoiceStateImpl({
    required String schema,
    required String sessionId,
    required int tMs,
    required String outageState,
    double? radius95M,
    required bool calibrated,
  }) : super._(
         schema: schema,
         sessionId: sessionId,
         tMs: tMs,
         outageState: outageState,
         radius95M: radius95M,
         calibrated: calibrated,
       );

  /// Returns a shallow copy of this [VoiceState]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  VoiceState copyWith({
    String? schema,
    String? sessionId,
    int? tMs,
    String? outageState,
    Object? radius95M = _Undefined,
    bool? calibrated,
  }) {
    return VoiceState(
      schema: schema ?? this.schema,
      sessionId: sessionId ?? this.sessionId,
      tMs: tMs ?? this.tMs,
      outageState: outageState ?? this.outageState,
      radius95M: radius95M is double? ? radius95M : this.radius95M,
      calibrated: calibrated ?? this.calibrated,
    );
  }
}
