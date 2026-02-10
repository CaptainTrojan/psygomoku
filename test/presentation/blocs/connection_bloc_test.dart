import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psygomoku/presentation/blocs/connection_bloc/connection_bloc.dart';
import 'package:psygomoku/presentation/blocs/connection_bloc/connection_event.dart';
import 'package:psygomoku/presentation/blocs/connection_bloc/connection_state.dart';

void main() {
  group('ConnectionBloc', () {
    late ConnectionBloc bloc;

    setUp(() {
      bloc = ConnectionBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state is ConnectionIdleState', () {
      expect(bloc.state, isA<ConnectionIdleState>());
    });

    blocTest<ConnectionBloc, ConnectionState>(
      'emits [ConnectionIdleState] when DisconnectEvent is added',
      build: () => ConnectionBloc(),
      act: (bloc) => bloc.add(const DisconnectEvent()),
      expect: () => [isA<ConnectionIdleState>()],
    );

    blocTest<ConnectionBloc, ConnectionState>(
      'emits [ConnectionErrorState] when connection fails',
      build: () => ConnectionBloc(),
      act: (bloc) => bloc.add(const ConnectionFailedEvent('Test error')),
      expect: () => [
        isA<ConnectionErrorState>()
            .having((state) => state.error, 'error', 'Test error'),
      ],
    );

    blocTest<ConnectionBloc, ConnectionState>(
      'emits [ConnectedState] when ConnectionEstablishedEvent is added',
      build: () => ConnectionBloc(),
      act: (bloc) => bloc.add(const ConnectionEstablishedEvent()),
      expect: () => [isA<ConnectedState>()],
    );

    test('exposes transport after initialization', () {
      // Initially no transport
      expect(bloc.transport, isNull);
      // Transport will be set when hosting/joining (requires actual WebRTC)
    });

    test('can transition from connected to idle on disconnect', () async {
      // First go to connected state
      bloc.add(const ConnectionEstablishedEvent());
      await expectLater(
        bloc.stream,
        emits(isA<ConnectedState>()),
      );
      
      // Then disconnect
      bloc.add(const DisconnectEvent());
      await expectLater(
        bloc.stream,
        emits(isA<ConnectionIdleState>()),
      );
    });

    group('Message Handling', () {
      blocTest<ConnectionBloc, ConnectionState>(
        'ConnectedState tracks received messages',
        build: () => ConnectionBloc(),
        seed: () => const ConnectedState(),
        act: (bloc) {
          bloc.add(const MessageReceivedEvent({'type': 'test', 'text': 'message1'}));
          bloc.add(const MessageReceivedEvent({'type': 'test', 'text': 'message2'}));
        },
        expect: () => [
          isA<ConnectedState>()
              .having((s) => s.receivedMessages.length, 'message count', 1),
          isA<ConnectedState>()
              .having((s) => s.receivedMessages.length, 'message count', 2),
        ],
      );

      test('ConnectedState copyWithMessage preserves existing messages', () {
        const state = ConnectedState();
        final msg1 = {'type': 'test', 'msg': 'first'};
        final msg2 = {'type': 'test', 'msg': 'second'};
        
        final state1 = state.copyWithMessage(msg1);
        expect(state1.receivedMessages.length, equals(1));
        expect(state1.receivedMessages.first, equals(msg1));
        
        final state2 = state1.copyWithMessage(msg2);
        expect(state2.receivedMessages.length, equals(2));
        expect(state2.receivedMessages[0], equals(msg1));
        expect(state2.receivedMessages[1], equals(msg2));
      });
    });

    group('Cleanup', () {
      test('closes all streams on dispose', () async {
        final testBloc = ConnectionBloc();
        
        // Subscribe to ensure streams are active
        final subscription = testBloc.stream.listen((_) {});
        
        // Close the bloc
        await testBloc.close();
        
        // Verify stream is closed
        expect(testBloc.isClosed, isTrue);
        
        await subscription.cancel();
      });

      test('can safely disconnect multiple times', () {
        final testBloc = ConnectionBloc();
        
        // Disconnect multiple times - should not throw
        expect(
          () {
            testBloc.add(const DisconnectEvent());
            testBloc.add(const DisconnectEvent());
            testBloc.add(const DisconnectEvent());
          },
          returnsNormally,
        );
        
        testBloc.close();
      });
    });
  });

  group('Connection States', () {
    test('HostingState preserves mode and optional data', () {
      const state = HostingState(
        mode: SignalingMode.manual,
        offerString: 'test-offer-data',
      );
      
      expect(state.mode, equals(SignalingMode.manual));
      expect(state.offerString, equals('test-offer-data'));
    });

    test('HostingState supports auto mode with session code', () {
      const state = HostingState(
        mode: SignalingMode.auto,
        sessionCode: '1234',
      );
      
      expect(state.mode, equals(SignalingMode.auto));
      expect(state.sessionCode, equals('1234'));
    });

    test('ManualWaitingForAnswerState preserves offer', () {
      const offer = 'test-offer-data';
      const state = ManualWaitingForAnswerState(offer);
      
      expect(state.offerString, equals(offer));
    });

    test('ConnectionErrorState preserves error message', () {
      const error = 'Test error message';
      const state = ConnectionErrorState(error);
      
      expect(state.error, equals(error));
    });

    test('ConnectedState starts with empty messages', () {
      const state = ConnectedState();
      
      expect(state.receivedMessages, isEmpty);
    });

    test('states are equatable', () {
      // Same states should be equal
      expect(
        const ConnectionIdleState(),
        equals(const ConnectionIdleState()),
      );
      
      expect(
        const HostingState(
          mode: SignalingMode.manual,
          offerString: 'data',
        ),
        equals(const HostingState(
          mode: SignalingMode.manual,
          offerString: 'data',
        )),
      );
      
      expect(
        const ConnectedState(),
        equals(const ConnectedState()),
      );
      
      // Different states should not be equal
      expect(
        const HostingState(
          mode: SignalingMode.manual,
          offerString: 'data1',
        ),
        isNot(equals(const HostingState(
          mode: SignalingMode.manual,
          offerString: 'data2',
        ))),
      );
    });
  });
}
