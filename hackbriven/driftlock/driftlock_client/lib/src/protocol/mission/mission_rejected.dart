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

abstract class MissionRejected
    implements
        _isc.SerializableException,
        _isc.SerializableModel,
        _isc.ProtocolSerialization {
  MissionRejected._({required this.message});

  factory MissionRejected({required String message}) = _MissionRejectedImpl;

  factory MissionRejected.fromJson(Map<String, dynamic> jsonSerialization) {
    return MissionRejected(message: jsonSerialization['message'] as String);
  }

  String message;

  /// Returns a shallow copy of this [MissionRejected]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  MissionRejected copyWith({String? message});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MissionRejected',
      'message': message,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MissionRejected',
      'message': message,
    };
  }

  @override
  String toString() {
    return 'MissionRejected(message: $message)';
  }
}

class _MissionRejectedImpl extends MissionRejected {
  _MissionRejectedImpl({required String message}) : super._(message: message);

  /// Returns a shallow copy of this [MissionRejected]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  MissionRejected copyWith({String? message}) {
    return MissionRejected(message: message ?? this.message);
  }
}
