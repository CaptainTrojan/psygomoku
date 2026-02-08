import 'package:equatable/equatable.dart';

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
  const HostingState(this.signalData);

  final String signalData; // SDP offer for QR code / link

  @override
  List<Object?> get props => [signalData];
}

/// Host waiting to receive answer from joiner
class HostingWaitingForAnswerState extends ConnectionState {
  const HostingWaitingForAnswerState(this.signalData);

  final String signalData; // Original SDP offer

  @override
  List<Object?> get props => [signalData];
}

/// Joining a game, establishing connection
class JoiningState extends ConnectionState {
  const JoiningState();
}

/// Joiner has created answer, waiting for connection
class JoiningWaitingForHostState extends ConnectionState {
  const JoiningWaitingForHostState(this.answerData);

  final String answerData; // SDP answer to send back to host

  @override
  List<Object?> get props => [answerData];
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
