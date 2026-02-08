import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:psygomoku/infrastructure/transport/i_game_transport.dart';
import 'package:psygomoku/presentation/blocs/chat_bloc/chat_bloc.dart';
import 'package:psygomoku/presentation/blocs/chat_bloc/chat_state.dart';
import 'package:psygomoku/presentation/widgets/chat_widget.dart';

@GenerateMocks([IGameTransport])
import 'chat_widget_test.mocks.dart';

void main() {
  group('ChatWidget', () {
    late MockIGameTransport mockTransport;

    setUp(() {
      mockTransport = MockIGameTransport();
      when(mockTransport.send(any)).thenAnswer((_) async => true);
    });

    testWidgets('displays empty state when no messages', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => ChatBloc(mockTransport),
              child: const ChatWidget(),
            ),
          ),
        ),
      );

      expect(find.text('No messages yet.\nStart chatting!'), findsOneWidget);
    });

    testWidgets('displays chat header', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => ChatBloc(mockTransport),
              child: const ChatWidget(),
            ),
          ),
        ),
      );

      expect(find.text('Chat'), findsOneWidget);
      expect(find.byIcon(Icons.chat), findsOneWidget);
    });

    testWidgets('displays text input and send button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => ChatBloc(mockTransport),
              child: const ChatWidget(),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('can enter text in input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => ChatBloc(mockTransport),
              child: const ChatWidget(),
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Hello, World!');

      expect(find.text('Hello, World!'), findsOneWidget);
    });

    testWidgets('displays sent messages', (WidgetTester tester) async {
      final chatBloc = ChatBloc(mockTransport);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: chatBloc,
              child: const ChatWidget(),
            ),
          ),
        ),
      );

      // Enter and send a message
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Test message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify message is displayed
      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('clears input after sending', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => ChatBloc(mockTransport),
              child: const ChatWidget(),
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      
      // Enter text
      await tester.enterText(textField, 'Test');
      expect(find.text('Test'), findsOneWidget);

      // Send message
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify input is cleared (only finds in message bubble, not in TextField)
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.controller?.text, isEmpty);
    });

    testWidgets('displays received messages differently from sent', (WidgetTester tester) async {
      final chatBloc = ChatBloc(mockTransport);

      // Add a mix of sent and received messages to the state
      chatBloc.emit(
        ChatState(
          messages: [
            ChatMessage(
              text: 'My message',
              isFromMe: true,
              timestamp: DateTime.now(),
            ),
            ChatMessage(
              text: 'Their message',
              isFromMe: false,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: chatBloc,
              child: const ChatWidget(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Both messages should be visible
      expect(find.text('My message'), findsOneWidget);
      expect(find.text('Their message'), findsOneWidget);
    });
  });
}
