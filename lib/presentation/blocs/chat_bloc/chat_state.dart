import 'package:equatable/equatable.dart';

/// Represents a single chat message
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.text,
    required this.isFromMe,
    required this.timestamp,
  });

  final String text;
  final bool isFromMe;
  final DateTime timestamp;

  @override
  List<Object?> get props => [text, isFromMe, timestamp];
}

/// State for ChatBloc
class ChatState extends Equatable {
  const ChatState({
    this.messages = const [],
  });

  final List<ChatMessage> messages;

  ChatState copyWith({
    List<ChatMessage>? messages,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
    );
  }

  @override
  List<Object?> get props => [messages];
}
