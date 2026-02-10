import 'package:equatable/equatable.dart';
import 'connection_state.dart';

/// Events for ConnectionBloc
abstract class ConnectionEvent extends Equatable {
  const ConnectionEvent();

  @override
  List<Object?> get props => [];
}

/// User wants to host a game
class HostGameEvent extends ConnectionEvent {
  const HostGameEvent(this.mode);

  final SignalingMode mode;

  @override
  List<Object?> get props => [mode];
}

/// User wants to join a game
class JoinGameEvent extends ConnectionEvent {
  const JoinGameEvent({
    required this.mode,
    this.sessionCode,
    this.offerString,
  });

  final SignalingMode mode;
  final String? sessionCode; // For auto mode
  final String? offerString; // For manual mode

  @override
  List<Object?> get props => [mode, sessionCode, offerString];
}

/// Manual mode: Host receives answer from UI
class ManualHostReceiveAnswerEvent extends ConnectionEvent {
  const ManualHostReceiveAnswerEvent(this.answerString);

  final String answerString;

  @override
  List<Object?> get props => [answerString];
}

/// Manual mode: Joiner receives offer from UI (if not in JoinGameEvent)
class ManualJoinerReceiveOfferEvent extends ConnectionEvent {
  const ManualJoinerReceiveOfferEvent(this.offerString);

  final String offerString;

  @override
  List<Object?> get props => [offerString];
}

/// Reset connection to idle
class ResetConnectionEvent extends ConnectionEvent {
  const ResetConnectionEvent();
}

/// Connection has been established successfully
class ConnectionEstablishedEvent extends ConnectionEvent {
  const ConnectionEstablishedEvent();
}

/// Connection failed with error
class ConnectionFailedEvent extends ConnectionEvent {
  const ConnectionFailedEvent(this.error);

  final String error;

  @override
  List<Object?> get props => [error];
}

/// Send a test message (for ping-pong verification)
class SendTestMessageEvent extends ConnectionEvent {
  const SendTestMessageEvent(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Received a message from opponent
class MessageReceivedEvent extends ConnectionEvent {
  const MessageReceivedEvent(this.data);

  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}

/// Disconnect from opponent
class DisconnectEvent extends ConnectionEvent {
  const DisconnectEvent();
}

/// Internal: Manual mode offer generated
class ManualOfferGeneratedEvent extends ConnectionEvent {
  const ManualOfferGeneratedEvent(this.offerString);

  final String offerString;

  @override
  List<Object?> get props => [offerString];
}

/// Internal: Manual mode answer generated
class ManualAnswerGeneratedEvent extends ConnectionEvent {
  const ManualAnswerGeneratedEvent(this.answerString);

  final String answerString;

  @override
  List<Object?> get props => [answerString];
}
