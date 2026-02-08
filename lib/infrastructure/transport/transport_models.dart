import 'package:freezed_annotation/freezed_annotation.dart';

part 'transport_models.freezed.dart';
part 'transport_models.g.dart';

/// Signaling data for establishing P2P connection.
/// 
/// Contains SDP offer/answer and ICE candidates for WebRTC,
/// or device identifiers for Nearby Connections.
@freezed
class SignalData with _$SignalData {
  const factory SignalData({
    required String type, // 'offer', 'answer', 'ice-candidate'
    required String data, // JSON-encoded SDP or ICE candidate
    @Default(null) String? candidate,
    @Default(null) String? sdpMid,
    @Default(null) int? sdpMLineIndex,
  }) = _SignalData;

  factory SignalData.fromJson(Map<String, dynamic> json) =>
      _$SignalDataFromJson(json);
}

/// Transport-level message wrapper.
/// 
/// Wraps all messages sent over the transport layer with metadata.
@freezed
class TransportMessage with _$TransportMessage {
  const factory TransportMessage({
    required String type, // Message type identifier
    required Map<String, dynamic> payload, // Actual message data
    required DateTime timestamp, // When message was created
    @Default(null) String? messageId, // Optional unique ID for tracking
  }) = _TransportMessage;

  factory TransportMessage.fromJson(Map<String, dynamic> json) =>
      _$TransportMessageFromJson(json);
}

/// Result of attempting to send a message.
@freezed
class SendResult with _$SendResult {
  const factory SendResult.success() = _Success;
  const factory SendResult.failure(String reason) = _Failure;
}
