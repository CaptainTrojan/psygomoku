import 'package:freezed_annotation/freezed_annotation.dart';

part 'signaling_state.freezed.dart';

/// Phases of the signaling process
enum SignalingPhase {
  /// Initial state, not started
  idle,
  
  /// Gathering ICE candidates
  gathering,
  
  /// Exchanging signaling data (offer/answer)
  exchanging,
  
  /// Signaling complete, P2P connection in progress
  complete,
  
  /// Signaling failed
  failed,
}

/// State of the signaling process
@freezed
class SignalingState with _$SignalingState {
  const SignalingState._();
  
  const factory SignalingState({
    required SignalingPhase phase,
    String? offerSdp,
    String? answerSdp,
    String? sessionCode,
    String? errorMessage,
  }) = _SignalingState;

  factory SignalingState.idle() => const SignalingState(phase: SignalingPhase.idle);

  factory SignalingState.gathering() => const SignalingState(phase: SignalingPhase.gathering);

  factory SignalingState.exchanging({
    String? offerSdp,
    String? answerSdp,
    String? sessionCode,
  }) =>
      SignalingState(
        phase: SignalingPhase.exchanging,
        offerSdp: offerSdp,
        answerSdp: answerSdp,
        sessionCode: sessionCode,
      );

  factory SignalingState.complete() => const SignalingState(phase: SignalingPhase.complete);

  factory SignalingState.failed(String errorMessage) => SignalingState(
        phase: SignalingPhase.failed,
        errorMessage: errorMessage,
      );
}
