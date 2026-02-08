import 'package:equatable/equatable.dart';

/// Events for ConnectionBloc
abstract class ConnectionEvent extends Equatable {
  const ConnectionEvent();

  @override
  List<Object?> get props => [];
}

/// User wants to host a game
class HostGameEvent extends ConnectionEvent {
  const HostGameEvent();
}

/// User wants to join a game with signaling data
class JoinGameEvent extends ConnectionEvent {
  const JoinGameEvent(this.signalData);

  final String signalData;

  @override
  List<Object?> get props => [signalData];
}

/// Host receives answer from joiner
class HostReceiveAnswerEvent extends ConnectionEvent {
  const HostReceiveAnswerEvent(this.answerData);

  final String answerData;

  @override
  List<Object?> get props => [answerData];
}

/// Host has shared offer and is ready to receive answer
class HostReadyForAnswerEvent extends ConnectionEvent {
  const HostReadyForAnswerEvent(this.signalData);

  final String signalData;

  @override
  List<Object?> get props => [signalData];
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
