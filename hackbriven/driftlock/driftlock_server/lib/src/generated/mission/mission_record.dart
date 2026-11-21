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
import 'dart:async' as _ida;
import 'package:driftlock_server/src/generated/protocol.dart' as _i1x3j0c8;
import 'package:serverpod/serverpod.dart' as _is;
import '../mission/mission_summary.dart' as _i9j4noxb;

abstract class MissionRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  MissionRecord._({
    this.id,
    required this.ownerIdentifier,
    required this.sessionId,
    required this.startedAtUtc,
    required this.summary,
  });

  factory MissionRecord({
    int? id,
    required String ownerIdentifier,
    required String sessionId,
    required DateTime startedAtUtc,
    required _i9j4noxb.MissionSummary summary,
  }) = _MissionRecordImpl;

  factory MissionRecord.fromJson(Map<String, dynamic> jsonSerialization) {
    return MissionRecord(
      id: jsonSerialization['id'] as int?,
      ownerIdentifier: jsonSerialization['ownerIdentifier'] as String,
      sessionId: jsonSerialization['sessionId'] as String,
      startedAtUtc: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['startedAtUtc'],
      ),
      summary: _i1x3j0c8.Protocol().deserialize<_i9j4noxb.MissionSummary>(
        jsonSerialization['summary'],
      ),
    );
  }

  static final t = MissionRecordTable();

  static const db = MissionRecordRepository._();

  @override
  int? id;

  String ownerIdentifier;

  String sessionId;

  DateTime startedAtUtc;

  _i9j4noxb.MissionSummary summary;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [MissionRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  MissionRecord copyWith({
    int? id,
    String? ownerIdentifier,
    String? sessionId,
    DateTime? startedAtUtc,
    _i9j4noxb.MissionSummary? summary,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MissionRecord',
      if (id != null) 'id': id,
      'ownerIdentifier': ownerIdentifier,
      'sessionId': sessionId,
      'startedAtUtc': startedAtUtc.toJson(),
      'summary': summary.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static MissionRecordInclude include() {
    return MissionRecordInclude._();
  }

  static MissionRecordIncludeList includeList({
    _is.WhereExpressionBuilder<MissionRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MissionRecordTable>? orderBy,
    _is.OrderByListBuilder<MissionRecordTable>? orderByList,
    MissionRecordInclude? include,
  }) {
    return MissionRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MissionRecord.t),
      orderByList: orderByList?.call(MissionRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MissionRecordImpl extends MissionRecord {
  _MissionRecordImpl({
    int? id,
    required String ownerIdentifier,
    required String sessionId,
    required DateTime startedAtUtc,
    required _i9j4noxb.MissionSummary summary,
  }) : super._(
         id: id,
         ownerIdentifier: ownerIdentifier,
         sessionId: sessionId,
         startedAtUtc: startedAtUtc,
         summary: summary,
       );

  /// Returns a shallow copy of this [MissionRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  MissionRecord copyWith({
    Object? id = _Undefined,
    String? ownerIdentifier,
    String? sessionId,
    DateTime? startedAtUtc,
    _i9j4noxb.MissionSummary? summary,
  }) {
    return MissionRecord(
      id: id is int? ? id : this.id,
      ownerIdentifier: ownerIdentifier ?? this.ownerIdentifier,
      sessionId: sessionId ?? this.sessionId,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      summary: summary ?? this.summary.copyWith(),
    );
  }
}

class MissionRecordUpdateTable extends _is.UpdateTable<MissionRecordTable> {
  MissionRecordUpdateTable(super.table);

  _is.ColumnValue<String, String> ownerIdentifier(String value) =>
      _is.ColumnValue(
        table.ownerIdentifier,
        value,
      );

  _is.ColumnValue<String, String> sessionId(String value) => _is.ColumnValue(
    table.sessionId,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> startedAtUtc(DateTime value) =>
      _is.ColumnValue(
        table.startedAtUtc,
        value,
      );

  _is.ColumnValue<_i9j4noxb.MissionSummary, _i9j4noxb.MissionSummary> summary(
    _i9j4noxb.MissionSummary value,
  ) => _is.ColumnValue(
    table.summary,
    value,
  );
}

class MissionRecordTable extends _is.Table<int?> {
  MissionRecordTable({super.tableRelation})
    : super(tableName: 'driftlock_mission') {
    updateTable = MissionRecordUpdateTable(this);
    ownerIdentifier = _is.ColumnString(
      'ownerIdentifier',
      this,
    );
    sessionId = _is.ColumnString(
      'sessionId',
      this,
    );
    startedAtUtc = _is.ColumnDateTime(
      'startedAtUtc',
      this,
    );
    summary = _is.ColumnSerializable<_i9j4noxb.MissionSummary>(
      'summary',
      this,
    );
  }

  late final MissionRecordUpdateTable updateTable;

  late final _is.ColumnString ownerIdentifier;

  late final _is.ColumnString sessionId;

  late final _is.ColumnDateTime startedAtUtc;

  late final _is.ColumnSerializable<_i9j4noxb.MissionSummary> summary;

  @override
  List<_is.Column> get columns => [
    id,
    ownerIdentifier,
    sessionId,
    startedAtUtc,
    summary,
  ];
}

class MissionRecordInclude extends _is.IncludeObject {
  MissionRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => MissionRecord.t;
}

class MissionRecordIncludeList extends _is.IncludeList {
  MissionRecordIncludeList._({
    _is.WhereExpressionBuilder<MissionRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(MissionRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => MissionRecord.t;
}

class MissionRecordRepository {
  const MissionRecordRepository._();

  /// Returns a list of [MissionRecord]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<MissionRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MissionRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MissionRecordTable>? orderBy,
    _is.OrderByListBuilder<MissionRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<MissionRecord>(
      where: where?.call(MissionRecord.t),
      orderBy: orderBy?.call(MissionRecord.t),
      orderByList: orderByList?.call(MissionRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [MissionRecord]s matching the given query parameters every time the
  /// source tables are modified.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// Use [throttle] to specify the minimum interval between queries. It can
  /// also be set to `null`, in which case the stream will only be throttled
  /// when its subscription is paused.
  ///
  /// Source tables are collected from the queried table, [where], [orderBy],
  /// [orderByList], and the [include] graph. [alsoTriggerOnTables] is added
  /// to that set. Pass [Table] instances such as `MissionRecord.t`.
  ///
  /// Raw [Expression] SQL is not inspected. Tables referenced only in raw
  /// SQL must be passed via [alsoTriggerOnTables].
  ///
  /// The stream always reads committed state and never joins an ambient
  /// [Transaction]. Emissions for a write fire after that write commits.
  ///
  /// Currently only supported on SQLite. Calling this method on PostgreSQL
  /// throws an [UnsupportedError].
  ///
  /// ```dart
  /// var subscription = Persons.db.watch(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// ).listen((persons) {
  ///   // Handle the latest matching rows.
  /// });
  /// ```
  _ida.Stream<List<MissionRecord>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MissionRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MissionRecordTable>? orderBy,
    _is.OrderByListBuilder<MissionRecordTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<MissionRecord>(
      where: where?.call(MissionRecord.t),
      orderBy: orderBy?.call(MissionRecord.t),
      orderByList: orderByList?.call(MissionRecord.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [MissionRecord] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<MissionRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MissionRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<MissionRecordTable>? orderBy,
    _is.OrderByListBuilder<MissionRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<MissionRecord>(
      where: where?.call(MissionRecord.t),
      orderBy: orderBy?.call(MissionRecord.t),
      orderByList: orderByList?.call(MissionRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [MissionRecord] by its [id] or null if no such row exists.
  Future<MissionRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<MissionRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [MissionRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [MissionRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MissionRecord>> insert(
    _is.DatabaseSession session,
    List<MissionRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<MissionRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [MissionRecord] and returns the inserted row.
  ///
  /// The returned [MissionRecord] will have its `id` field set.
  Future<MissionRecord> insertRow(
    _is.DatabaseSession session,
    MissionRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<MissionRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [MissionRecord]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [MissionRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MissionRecord>> upsert(
    _is.DatabaseSession session,
    List<MissionRecord> rows, {
    required _is.ColumnSelections<MissionRecordTable> conflictColumns,
    _is.ColumnSelections<MissionRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<MissionRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<MissionRecord>(
      rows,
      conflictColumns: conflictColumns(MissionRecord.t),
      updateColumns: updateColumns?.call(MissionRecord.t),
      updateWhere: updateWhere?.call(MissionRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [MissionRecord] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [MissionRecord] will have its `id` field set.
  Future<MissionRecord?> upsertRow(
    _is.DatabaseSession session,
    MissionRecord row, {
    required _is.ColumnSelections<MissionRecordTable> conflictColumns,
    _is.ColumnSelections<MissionRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<MissionRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<MissionRecord>(
      row,
      conflictColumns: conflictColumns(MissionRecord.t),
      updateColumns: updateColumns?.call(MissionRecord.t),
      updateWhere: updateWhere?.call(MissionRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [MissionRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MissionRecord>> update(
    _is.DatabaseSession session,
    List<MissionRecord> rows, {
    _is.ColumnSelections<MissionRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<MissionRecord>(
      rows,
      columns: columns?.call(MissionRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [MissionRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<MissionRecord> updateRow(
    _is.DatabaseSession session,
    MissionRecord row, {
    _is.ColumnSelections<MissionRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<MissionRecord>(
      row,
      columns: columns?.call(MissionRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [MissionRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<MissionRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<MissionRecordUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<MissionRecord>(
      id,
      columnValues: columnValues(MissionRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [MissionRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MissionRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<MissionRecordUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<MissionRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MissionRecordTable>? orderBy,
    _is.OrderByListBuilder<MissionRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<MissionRecord>(
      columnValues: columnValues(MissionRecord.t.updateTable),
      where: where(MissionRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MissionRecord.t),
      orderByList: orderByList?.call(MissionRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [MissionRecord]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MissionRecord>> delete(
    _is.DatabaseSession session,
    List<MissionRecord> rows, {
    _is.OrderByBuilder<MissionRecordTable>? orderBy,
    _is.OrderByListBuilder<MissionRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<MissionRecord>(
      rows,
      orderBy: orderBy?.call(MissionRecord.t),
      orderByList: orderByList?.call(MissionRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [MissionRecord].
  Future<MissionRecord> deleteRow(
    _is.DatabaseSession session,
    MissionRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<MissionRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MissionRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<MissionRecordTable> where,
    _is.OrderByBuilder<MissionRecordTable>? orderBy,
    _is.OrderByListBuilder<MissionRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<MissionRecord>(
      where: where(MissionRecord.t),
      orderBy: orderBy?.call(MissionRecord.t),
      orderByList: orderByList?.call(MissionRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MissionRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<MissionRecord>(
      where: where?.call(MissionRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [MissionRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<MissionRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<MissionRecord>(
      where: where(MissionRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
