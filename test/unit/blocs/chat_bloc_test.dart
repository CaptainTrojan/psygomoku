import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:psygomoku/infrastructure/transport/i_game_transport.dart';
import 'package:psygomoku/presentation/blocs/chat_bloc/chat_bloc.dart';
import 'package:psygomoku/presentation/blocs/chat_bloc/chat_event.dart';
import 'package:psygomoku/presentation/blocs/chat_bloc/chat_state.dart';

@GenerateMocks([IGameTransport])
import 'chat_bloc_test.mocks.dart';

void main() {
  group('ChatBloc', () {
    late MockIGameTransport mockTransport;
    late ChatBloc chatBloc;

    setUp(() {
      mockTransport = MockIGameTransport();
      chatBloc = ChatBloc(mockTransport);
    });

    tearDown(() {
      chatBloc.close();
    });

    test('initial state is empty chat', () {
      expect(chatBloc.state, const ChatState(messages: []));
    });

    blocTest<ChatBloc, ChatState>(
      'emits message when SendChatMessageEvent is added',
      build: () {
        when(mockTransport.send(any)).thenAnswer((_) async => true);
        return chatBloc;
      },
      act: (bloc) => bloc.add(const SendChatMessageEvent('Hello!')),
      wait: const Duration(milliseconds: 100),
      verify: (_) {
        verify(mockTransport.send(any)).called(1);
      },
      expect: () => [
        predicate<ChatState>((state) {
          return state.messages.length == 1 &&
              state.messages.first.text == 'Hello!' &&
              state.messages.first.isFromMe == true;
        }),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'does not emit when message is empty',
      build: () => chatBloc,
      act: (bloc) => bloc.add(const SendChatMessageEvent('   ')),
      expect: () => [],
    );

    blocTest<ChatBloc, ChatState>(
      'emits received message when ReceiveChatMessageEvent is added',
      build: () => chatBloc,
      act: (bloc) => bloc.add(
        ReceiveChatMessageEvent('Hi there!', DateTime.now()),
      ),
      expect: () => [
        predicate<ChatState>((state) {
          return state.messages.length == 1 &&
              state.messages.first.text == 'Hi there!' &&
              state.messages.first.isFromMe == false;
        }),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'maintains message order',
      build: () {
        when(mockTransport.send(any)).thenAnswer((_) async => true);
        return chatBloc;
      },
      act: (bloc) {
        bloc.add(const SendChatMessageEvent('First'));
        bloc.add(ReceiveChatMessageEvent('Second', DateTime.now()));
        bloc.add(const SendChatMessageEvent('Third'));
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        predicate<ChatState>((state) => state.messages.length == 1),
        predicate<ChatState>((state) => state.messages.length == 2),
        predicate<ChatState>((state) {
          return state.messages.length == 3 &&
              state.messages[0].text == 'First' &&
              state.messages[0].isFromMe == true &&
              state.messages[1].text == 'Second' &&
              state.messages[1].isFromMe == false &&
              state.messages[2].text == 'Third' &&
              state.messages[2].isFromMe == true;
        }),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'clears messages when ClearChatEvent is added',
      build: () {
        when(mockTransport.send(any)).thenAnswer((_) async => true);
        return chatBloc;
      },
      seed: () => ChatState(
        messages: [
          ChatMessage(
            text: 'test',
            isFromMe: true,
            timestamp: DateTime.now(),
          ),
        ],
      ),
      act: (bloc) => bloc.add(const ClearChatEvent()),
      expect: () => [const ChatState(messages: [])],
    );
  });
}
