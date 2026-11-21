/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:driftlock_client/src/protocol/mission/mission_summary.dart'
    as _iz932zoq;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'debrief/benchmark_debrief.dart' as _iheohywj;
import 'greetings/greeting.dart' as _izw8z7ou;
import 'mission/mission_rejected.dart' as _iaytks8j;
import 'mission/mission_summary.dart' as _ixddbk87;
import 'voice/voice_reply.dart' as _i9vw6so8;
import 'voice/voice_state.dart' as _ij17m3mv;
export 'debrief/benchmark_debrief.dart';
export 'greetings/greeting.dart';
export 'mission/mission_rejected.dart';
export 'mission/mission_summary.dart';
export 'voice/voice_reply.dart';
export 'voice/voice_state.dart';
export 'client.dart';

class Protocol extends _isc.SerializationManager
    implements _isc.ProtocolDeserializationProvider {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  @override
  _isc.ProtocolDeserialization get deserializationMetadata =>
      _isc.ProtocolDeserialization.cached(
        this,
        types: const [
          _isc.getType<_iheohywj.BenchmarkDebrief>,
          _isc.getType<_izw8z7ou.Greeting>,
          _isc.getType<_iaytks8j.MissionRejected>,
          _isc.getType<_ixddbk87.MissionSummary>,
          _isc.getType<_i9vw6so8.VoiceReply>,
          _isc.getType<_ij17m3mv.VoiceState>,
          _isc.getType<_iheohywj.BenchmarkDebrief?>,
          _isc.getType<_izw8z7ou.Greeting?>,
          _isc.getType<_iaytks8j.MissionRejected?>,
          _isc.getType<_ixddbk87.MissionSummary?>,
          _isc.getType<_i9vw6so8.VoiceReply?>,
          _isc.getType<_ij17m3mv.VoiceState?>,
          _isc.getType<List<_iz932zoq.MissionSummary>>,
        ],
        modules: const [
          _iaic.Protocol.new,
          _iacc.Protocol.new,
        ],
        classNames: const [
          'BenchmarkDebrief',
          'Greeting',
          'MissionRejected',
          'MissionSummary',
          'VoiceReply',
          'VoiceState',
        ],
      );

  static String? getClassNameFromObjectJson(dynamic data) =>
      _isc.ProtocolDeserialization.readClassName(data);

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;
    final rawDataClassName = _isc.ProtocolDeserialization.readClassName(data);
    final dataClassName = rawDataClassName;
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _isc.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _iheohywj.BenchmarkDebrief) {
      return _iheohywj.BenchmarkDebrief.fromJson(data) as T;
    }
    if (t == _izw8z7ou.Greeting) {
      return _izw8z7ou.Greeting.fromJson(data) as T;
    }
    if (t == _iaytks8j.MissionRejected) {
      return _iaytks8j.MissionRejected.fromJson(data) as T;
    }
    if (t == _ixddbk87.MissionSummary) {
      return _ixddbk87.MissionSummary.fromJson(data) as T;
    }
    if (t == _i9vw6so8.VoiceReply) {
      return _i9vw6so8.VoiceReply.fromJson(data) as T;
    }
    if (t == _ij17m3mv.VoiceState) {
      return _ij17m3mv.VoiceState.fromJson(data) as T;
    }
    if (t == _isc.getType<_iheohywj.BenchmarkDebrief?>()) {
      return (data != null ? _iheohywj.BenchmarkDebrief.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_izw8z7ou.Greeting?>()) {
      return (data != null ? _izw8z7ou.Greeting.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iaytks8j.MissionRejected?>()) {
      return (data != null ? _iaytks8j.MissionRejected.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ixddbk87.MissionSummary?>()) {
      return (data != null ? _ixddbk87.MissionSummary.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i9vw6so8.VoiceReply?>()) {
      return (data != null ? _i9vw6so8.VoiceReply.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ij17m3mv.VoiceState?>()) {
      return (data != null ? _ij17m3mv.VoiceState.fromJson(data) : null) as T;
    }
    if (t == List<_iz932zoq.MissionSummary>) {
      return (data as List)
              .map((e) => deserialize<_iz932zoq.MissionSummary>(e))
              .toList()
          as T;
    }
    final modules = deserializationMetadata.modulesForDeserialization(
      t,
      className: rawDataClassName,
    );
    for (final module in modules) {
      try {
        return module.deserialize<T>(data, t);
      } on _isc.DeserializationTypeNotFoundException catch (_) {}
    }

    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _iheohywj.BenchmarkDebrief => 'BenchmarkDebrief',
      _izw8z7ou.Greeting => 'Greeting',
      _iaytks8j.MissionRejected => 'MissionRejected',
      _ixddbk87.MissionSummary => 'MissionSummary',
      _i9vw6so8.VoiceReply => 'VoiceReply',
      _ij17m3mv.VoiceState => 'VoiceState',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('driftlock.', '');
    }

    switch (data) {
      case _iheohywj.BenchmarkDebrief():
        return 'BenchmarkDebrief';
      case _izw8z7ou.Greeting():
        return 'Greeting';
      case _iaytks8j.MissionRejected():
        return 'MissionRejected';
      case _ixddbk87.MissionSummary():
        return 'MissionSummary';
      case _i9vw6so8.VoiceReply():
        return 'VoiceReply';
      case _ij17m3mv.VoiceState():
        return 'VoiceState';
    }
    className = _iaic.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_idp.$className';
    }
    className = _iacc.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'BenchmarkDebrief') {
      return deserialize<_iheohywj.BenchmarkDebrief>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_izw8z7ou.Greeting>(data['data']);
    }
    if (dataClassName == 'MissionRejected') {
      return deserialize<_iaytks8j.MissionRejected>(data['data']);
    }
    if (dataClassName == 'MissionSummary') {
      return deserialize<_ixddbk87.MissionSummary>(data['data']);
    }
    if (dataClassName == 'VoiceReply') {
      return deserialize<_i9vw6so8.VoiceReply>(data['data']);
    }
    if (dataClassName == 'VoiceState') {
      return deserialize<_ij17m3mv.VoiceState>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      return _iaic.Protocol().deserializeByClassName({
        ...data,
        'className': dataClassName.substring(19),
      });
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      return _iacc.Protocol().deserializeByClassName({
        ...data,
        'className': dataClassName.substring(20),
      });
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iaic.Protocol().registerHostProtocol('driftlock', this);
    _iacc.Protocol().registerHostProtocol('driftlock', this);
  }

  @override
  String getModuleName() => 'driftlock';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _iaic.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _iacc.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
