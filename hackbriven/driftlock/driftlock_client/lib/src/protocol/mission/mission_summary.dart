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

abstract class MissionSummary
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  MissionSummary._({
    required this.schema,
    required this.sessionId,
    required this.source,
    required this.startedAtUtc,
    required this.durationMs,
    required this.engineVersion,
    this.modelVersion,
    this.benchmarkId,
    required this.consentToUpload,
  });

  factory MissionSummary({
    required String schema,
    required String sessionId,
    required String source,
    required DateTime startedAtUtc,
    required int durationMs,
    required String engineVersion,
    String? modelVersion,
    String? benchmarkId,
    required bool consentToUpload,
  }) = _MissionSummaryImpl;

  factory MissionSummary.fromJson(Map<String, dynamic> jsonSerialization) {
    return MissionSummary(
      schema: jsonSerialization['schema'] as String,
      sessionId: jsonSerialization['session_id'] as String,
      source: jsonSerialization['source'] as String,
      startedAtUtc: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['started_at_utc'],
      ),
      durationMs: jsonSerialization['duration_ms'] as int,
      engineVersion: jsonSerialization['engine_version'] as String,
      modelVersion: jsonSerialization['model_version'] as String?,
      benchmarkId: jsonSerialization['benchmark_id'] as String?,
      consentToUpload: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['consent_to_upload'],
      ),
    );
  }

  String schema;

  String sessionId;

  String source;

  DateTime startedAtUtc;

  int durationMs;

  String engineVersion;

  String? modelVersion;

  String? benchmarkId;

  bool consentToUpload;

  /// Returns a shallow copy of this [MissionSummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  MissionSummary copyWith({
    String? schema,
    String? sessionId,
    String? source,
    DateTime? startedAtUtc,
    int? durationMs,
    String? engineVersion,
    String? modelVersion,
    String? benchmarkId,
    bool? consentToUpload,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MissionSummary',
      'schema': schema,
      'session_id': sessionId,
      'source': source,
      'started_at_utc': startedAtUtc.toJson(),
      'duration_ms': durationMs,
      'engine_version': engineVersion,
      if (modelVersion != null) 'model_version': modelVersion,
      if (benchmarkId != null) 'benchmark_id': benchmarkId,
      'consent_to_upload': consentToUpload,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MissionSummary',
      'schema': schema,
      'session_id': sessionId,
      'source': source,
      'started_at_utc': startedAtUtc.toJson(),
      'duration_ms': durationMs,
      'engine_version': engineVersion,
      if (modelVersion != null) 'model_version': modelVersion,
      if (benchmarkId != null) 'benchmark_id': benchmarkId,
      'consent_to_upload': consentToUpload,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MissionSummaryImpl extends MissionSummary {
  _MissionSummaryImpl({
    required String schema,
    required String sessionId,
    required String source,
    required DateTime startedAtUtc,
    required int durationMs,
    required String engineVersion,
    String? modelVersion,
    String? benchmarkId,
    required bool consentToUpload,
  }) : super._(
         schema: schema,
         sessionId: sessionId,
         source: source,
         startedAtUtc: startedAtUtc,
         durationMs: durationMs,
         engineVersion: engineVersion,
         modelVersion: modelVersion,
         benchmarkId: benchmarkId,
         consentToUpload: consentToUpload,
       );

  /// Returns a shallow copy of this [MissionSummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  MissionSummary copyWith({
    String? schema,
    String? sessionId,
    String? source,
    DateTime? startedAtUtc,
    int? durationMs,
    String? engineVersion,
    Object? modelVersion = _Undefined,
    Object? benchmarkId = _Undefined,
    bool? consentToUpload,
  }) {
    return MissionSummary(
      schema: schema ?? this.schema,
      sessionId: sessionId ?? this.sessionId,
      source: source ?? this.source,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      durationMs: durationMs ?? this.durationMs,
      engineVersion: engineVersion ?? this.engineVersion,
      modelVersion: modelVersion is String? ? modelVersion : this.modelVersion,
      benchmarkId: benchmarkId is String? ? benchmarkId : this.benchmarkId,
      consentToUpload: consentToUpload ?? this.consentToUpload,
    );
  }
}
