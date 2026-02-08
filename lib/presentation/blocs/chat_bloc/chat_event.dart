import 'package:equatable/equatable.dart';

/// Events for ChatBloc
abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// User sends a chat message
class SendChatMessageEvent extends ChatEvent {
  const SendChatMessageEvent(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Chat message received from opponent
class ReceiveChatMessageEvent extends ChatEvent {
  const ReceiveChatMessageEvent(this.message, this.timestamp);

  final String message;
  final DateTime timestamp;

  @override
  List<Object?> get props => [message, timestamp];
}

/// Clear chat history
class ClearChatEvent extends ChatEvent {
  const ClearChatEvent();
}
