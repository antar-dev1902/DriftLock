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
import 'package:driftlock_server/src/generated/mission/mission_summary.dart'
    as _igi43o7x;
import 'package:serverpod/protocol.dart' as _isp;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _iais;
import 'debrief/benchmark_debrief.dart' as _iheohywj;
import 'greetings/greeting.dart' as _izw8z7ou;
import 'mission/mission_record.dart' as _ixzmkss7;
import 'mission/mission_rejected.dart' as _iaytks8j;
import 'mission/mission_summary.dart' as _ixddbk87;
import 'voice/voice_reply.dart' as _i9vw6so8;
import 'voice/voice_state.dart' as _ij17m3mv;
export 'debrief/benchmark_debrief.dart';
export 'greetings/greeting.dart';
export 'mission/mission_record.dart';
export 'mission/mission_rejected.dart';
export 'mission/mission_summary.dart';
export 'voice/voice_reply.dart';
export 'voice/voice_state.dart';

class Protocol extends _is.DatabaseSerializationManager
    implements _is.DatabaseProtocolDeserializationProvider {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  @override
  _is.ProtocolDeserialization get deserializationMetadata =>
      _is.ProtocolDeserialization.cached(
        this,
        types: const [
          _is.getType<_iheohywj.BenchmarkDebrief>,
          _is.getType<_izw8z7ou.Greeting>,
          _is.getType<_ixzmkss7.MissionRecord>,
          _is.getType<_iaytks8j.MissionRejected>,
          _is.getType<_ixddbk87.MissionSummary>,
          _is.getType<_i9vw6so8.VoiceReply>,
          _is.getType<_ij17m3mv.VoiceState>,
          _is.getType<_iheohywj.BenchmarkDebrief?>,
          _is.getType<_izw8z7ou.Greeting?>,
          _is.getType<_ixzmkss7.MissionRecord?>,
          _is.getType<_iaytks8j.MissionRejected?>,
          _is.getType<_ixddbk87.MissionSummary?>,
          _is.getType<_i9vw6so8.VoiceReply?>,
          _is.getType<_ij17m3mv.VoiceState?>,
          _is.getType<List<_igi43o7x.MissionSummary>>,
        ],
        modules: const [
          _iais.Protocol.new,
          _iacs.Protocol.new,
          _isp.Protocol.new,
        ],
        classNames: const [
          'BenchmarkDebrief',
          'Greeting',
          'MissionRecord',
          'MissionRejected',
          'MissionSummary',
          'VoiceReply',
          'VoiceState',
        ],
      );

  static List<_isp.TableDefinition> get targetTableDefinitions => [
    ..._ownTableDefinitions,
    ..._iais.Protocol().getOwnTableDefinitions(),
    ..._iacs.Protocol().getOwnTableDefinitions(),
    ..._isp.Protocol.targetTableDefinitions,
  ];

  static List<_isp.TableDefinition> get _ownTableDefinitions => [
    _isp.TableDefinition(
      name: 'driftlock_mission',
      dartName: 'MissionRecord',
      schema: 'public',
      module: 'driftlock',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'ownerIdentifier',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'sessionId',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'startedAtUtc',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'summary',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'protocol:MissionSummary',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'driftlock_mission_owner_session',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'ownerIdentifier',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sessionId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
  ];

  static String? getClassNameFromObjectJson(dynamic data) =>
      _is.ProtocolDeserialization.readClassName(data);

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;
    final rawDataClassName = _is.ProtocolDeserialization.readClassName(data);
    final dataClassName = rawDataClassName;
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _is.DeserializationClassNameNotFoundException catch (_) {
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
    if (t == _ixzmkss7.MissionRecord) {
      return _ixzmkss7.MissionRecord.fromJson(data) as T;
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
    if (t == _is.getType<_iheohywj.BenchmarkDebrief?>()) {
      return (data != null ? _iheohywj.BenchmarkDebrief.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_izw8z7ou.Greeting?>()) {
      return (data != null ? _izw8z7ou.Greeting.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ixzmkss7.MissionRecord?>()) {
      return (data != null ? _ixzmkss7.MissionRecord.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iaytks8j.MissionRejected?>()) {
      return (data != null ? _iaytks8j.MissionRejected.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ixddbk87.MissionSummary?>()) {
      return (data != null ? _ixddbk87.MissionSummary.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i9vw6so8.VoiceReply?>()) {
      return (data != null ? _i9vw6so8.VoiceReply.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ij17m3mv.VoiceState?>()) {
      return (data != null ? _ij17m3mv.VoiceState.fromJson(data) : null) as T;
    }
    if (t == List<_igi43o7x.MissionSummary>) {
      return (data as List)
              .map((e) => deserialize<_igi43o7x.MissionSummary>(e))
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
      } on _is.DeserializationTypeNotFoundException catch (_) {}
    }

    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _iheohywj.BenchmarkDebrief => 'BenchmarkDebrief',
      _izw8z7ou.Greeting => 'Greeting',
      _ixzmkss7.MissionRecord => 'MissionRecord',
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
      case _ixzmkss7.MissionRecord():
        return 'MissionRecord';
      case _iaytks8j.MissionRejected():
        return 'MissionRejected';
      case _ixddbk87.MissionSummary():
        return 'MissionSummary';
      case _i9vw6so8.VoiceReply():
        return 'VoiceReply';
      case _ij17m3mv.VoiceState():
        return 'VoiceState';
    }
    className = _iais.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_idp.$className';
    }
    className = _iacs.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    className = _isp.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.') ? className : 'serverpod.$className';
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
    if (dataClassName == 'MissionRecord') {
      return deserialize<_ixzmkss7.MissionRecord>(data['data']);
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
      return _iais.Protocol().deserializeByClassName({
        ...data,
        'className': dataClassName.substring(19),
      });
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      return _iacs.Protocol().deserializeByClassName({
        ...data,
        'className': dataClassName.substring(20),
      });
    }
    if (dataClassName.startsWith('serverpod.')) {
      return _isp.Protocol().deserializeByClassName({
        ...data,
        'className': dataClassName.substring(10),
      });
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iais.Protocol().registerHostProtocol('driftlock', this);
    _iacs.Protocol().registerHostProtocol('driftlock', this);
  }

  @override
  _is.Table? getTableForType(Type t) {
    {
      var table = _iais.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _iacs.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _isp.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _ixzmkss7.MissionRecord:
        return _ixzmkss7.MissionRecord.t;
    }
    return null;
  }

  @override
  List<_isp.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  List<_isp.TableDefinition> getOwnTableDefinitions() => _ownTableDefinitions;

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
      return _iais.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _iacs.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
