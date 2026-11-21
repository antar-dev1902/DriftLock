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
import 'dart:typed_data' as _idt;
import 'package:serverpod_client/serverpod_client.dart' as _isc;

abstract class VoiceReply
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  VoiceReply._({
    required this.answer,
    required this.status,
    this.audio,
  });

  factory VoiceReply({
    required String answer,
    required String status,
    _idt.ByteData? audio,
  }) = _VoiceReplyImpl;

  factory VoiceReply.fromJson(Map<String, dynamic> jsonSerialization) {
    return VoiceReply(
      answer: jsonSerialization['answer'] as String,
      status: jsonSerialization['status'] as String,
      audio: jsonSerialization['audio'] == null
          ? null
          : _isc.ByteDataJsonExtension.fromJson(jsonSerialization['audio']),
    );
  }

  String answer;

  String status;

  _idt.ByteData? audio;

  /// Returns a shallow copy of this [VoiceReply]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  VoiceReply copyWith({
    String? answer,
    String? status,
    _idt.ByteData? audio,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VoiceReply',
      'answer': answer,
      'status': status,
      if (audio != null) 'audio': audio?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VoiceReply',
      'answer': answer,
      'status': status,
      if (audio != null) 'audio': audio?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VoiceReplyImpl extends VoiceReply {
  _VoiceReplyImpl({
    required String answer,
    required String status,
    _idt.ByteData? audio,
  }) : super._(
         answer: answer,
         status: status,
         audio: audio,
       );

  /// Returns a shallow copy of this [VoiceReply]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  VoiceReply copyWith({
    String? answer,
    String? status,
    Object? audio = _Undefined,
  }) {
    return VoiceReply(
      answer: answer ?? this.answer,
      status: status ?? this.status,
      audio: audio is _idt.ByteData? ? audio : this.audio?.clone(),
    );
  }
}
