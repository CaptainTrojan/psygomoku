import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../infrastructure/transport/i_game_transport.dart' as transport;
import 'chat_event.dart';
import 'chat_state.dart';

/// Manages chat messages in a P2P game session
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(this._transport) : super(const ChatState()) {
    on<SendChatMessageEvent>(_onSendMessage);
    on<ReceiveChatMessageEvent>(_onReceiveMessage);
    on<ClearChatEvent>(_onClearChat);
  }

  final transport.IGameTransport _transport;

  Future<void> _onSendMessage(
    SendChatMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (event.message.trim().isEmpty) return;

    // Add message to local chat
    final message = ChatMessage(
      text: event.message,
      isFromMe: true,
      timestamp: DateTime.now(),
    );

    emit(state.copyWith(
      messages: [...state.messages, message],
    ));

    // Send to opponent via transport
    await _transport.send({
      'type': 'chat',
      'text': event.message,
      'timestamp': message.timestamp.toIso8601String(),
    });
  }

  void _onReceiveMessage(
    ReceiveChatMessageEvent event,
    Emitter<ChatState> emit,
  ) {
    final message = ChatMessage(
      text: event.message,
      isFromMe: false,
      timestamp: event.timestamp,
    );

    emit(state.copyWith(
      messages: [...state.messages, message],
    ));
  }

  void _onClearChat(
    ClearChatEvent event,
    Emitter<ChatState> emit,
  ) {
    emit(const ChatState(messages: []));
  }
}
