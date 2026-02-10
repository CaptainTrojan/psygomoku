import 'package:equatable/equatable.dart';

/// Signaling mode selection
enum SignalingMode {
  /// Manual copy/paste (offline, no server)
  manual,
  
  /// Auto server-based (4-digit code)
  auto,
}

/// States for ConnectionBloc
abstract class ConnectionState extends Equatable {
  const ConnectionState();

  @override
  List<Object?> get props => [];
}

/// Initial idle state
class ConnectionIdleState extends ConnectionState {
  const ConnectionIdleState();
}

/// Hosting a game, waiting for opponent
class HostingState extends ConnectionState {
  const HostingState({
    required this.mode,
    this.sessionCode,
    this.offerString,
  });

  final SignalingMode mode;
  final String? sessionCode; // For auto mode (4-digit code)
  final String? offerString; // For manual mode (compressed SDP offer)

  @override
  List<Object?> get props => [mode, sessionCode, offerString];
}

/// Manual mode: Host waiting to receive answer from UI
class ManualWaitingForAnswerState extends ConnectionState {
  const ManualWaitingForAnswerState(this.offerString);

  final String offerString;

  @override
  List<Object?> get props => [offerString];
}

/// Joining a game, establishing connection
class JoiningState extends ConnectionState {
  const JoiningState();
}

/// Manual mode: Joiner has answer ready to copy
class ManualAnswerReadyState extends ConnectionState {
  const ManualAnswerReadyState(this.answerString);

  final String answerString;

  @override
  List<Object?> get props => [answerString];
}

/// Successfully connected to opponent
class ConnectedState extends ConnectionState {
  const ConnectedState({this.receivedMessages = const []});

  final List<Map<String, dynamic>> receivedMessages;

  @override
  List<Object?> get props => [receivedMessages];

  ConnectedState copyWithMessage(Map<String, dynamic> message) {
    return ConnectedState(
      receivedMessages: [...receivedMessages, message],
    );
  }
}

/// Connection failed
class ConnectionErrorState extends ConnectionState {
  const ConnectionErrorState(this.error);

  final String error;

  @override
  List<Object?> get props => [error];
}

/// Disconnected from opponent
class DisconnectedState extends ConnectionState {
  const DisconnectedState();
}
