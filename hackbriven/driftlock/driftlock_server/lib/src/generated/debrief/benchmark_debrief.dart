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
import 'package:serverpod/serverpod.dart' as _is;

abstract class BenchmarkDebrief
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BenchmarkDebrief._({
    required this.source,
    required this.focus,
    required this.takeaway,
  });

  factory BenchmarkDebrief({
    required String source,
    required String focus,
    required String takeaway,
  }) = _BenchmarkDebriefImpl;

  factory BenchmarkDebrief.fromJson(Map<String, dynamic> jsonSerialization) {
    return BenchmarkDebrief(
      source: jsonSerialization['source'] as String,
      focus: jsonSerialization['focus'] as String,
      takeaway: jsonSerialization['takeaway'] as String,
    );
  }

  String source;

  String focus;

  String takeaway;

  /// Returns a shallow copy of this [BenchmarkDebrief]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BenchmarkDebrief copyWith({
    String? source,
    String? focus,
    String? takeaway,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BenchmarkDebrief',
      'source': source,
      'focus': focus,
      'takeaway': takeaway,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BenchmarkDebrief',
      'source': source,
      'focus': focus,
      'takeaway': takeaway,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _BenchmarkDebriefImpl extends BenchmarkDebrief {
  _BenchmarkDebriefImpl({
    required String source,
    required String focus,
    required String takeaway,
  }) : super._(
         source: source,
         focus: focus,
         takeaway: takeaway,
       );

  /// Returns a shallow copy of this [BenchmarkDebrief]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BenchmarkDebrief copyWith({
    String? source,
    String? focus,
    String? takeaway,
  }) {
    return BenchmarkDebrief(
      source: source ?? this.source,
      focus: focus ?? this.focus,
      takeaway: takeaway ?? this.takeaway,
    );
  }
}
