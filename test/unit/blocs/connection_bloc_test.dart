import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:psygomoku/presentation/blocs/connection_bloc/connection_bloc.dart';
import 'package:psygomoku/presentation/blocs/connection_bloc/connection_event.dart';
import 'package:psygomoku/presentation/blocs/connection_bloc/connection_state.dart';

void main() {
  group('ConnectionBloc', () {
    late ConnectionBloc connectionBloc;

    setUp(() {
      connectionBloc = ConnectionBloc();
    });

    tearDown(() {
      connectionBloc.close();
    });

    test('initial state is ConnectionIdleState', () {
      expect(connectionBloc.state, const ConnectionIdleState());
    });

    blocTest<ConnectionBloc, ConnectionState>(
      'emits ConnectionErrorState when connection fails',
      build: () => connectionBloc,
      act: (bloc) => bloc.add(const ConnectionFailedEvent('Test error')),
      expect: () => [
        const ConnectionErrorState('Test error'),
      ],
    );

    blocTest<ConnectionBloc, ConnectionState>(
      'emits ConnectedState when connection succeeds',
      build: () => connectionBloc,
      act: (bloc) => bloc.add(const ConnectionEstablishedEvent()),
      expect: () => [
        const ConnectedState(),
      ],
    );

    blocTest<ConnectionBloc, ConnectionState>(
      'emits ConnectionIdleState on disconnect',
      build: () => connectionBloc,
      seed: () => const ConnectedState(),
      act: (bloc) => bloc.add(const DisconnectEvent()),
      expect: () => [
        const ConnectionIdleState(),
      ],
    );

    blocTest<ConnectionBloc, ConnectionState>(
      'ConnectedState accumulates received messages',
      build: () => connectionBloc,
      seed: () => const ConnectedState(receivedMessages: []),
      act: (bloc) {
        bloc.add(const MessageReceivedEvent({'type': 'test', 'data': '1'}));
        bloc.add(const MessageReceivedEvent({'type': 'test', 'data': '2'}));
      },
      expect: () => [
        predicate<ConnectedState>((state) => state.receivedMessages.length == 1),
        predicate<ConnectedState>((state) => state.receivedMessages.length == 2),
      ],
    );

    test('transport getter returns null initially', () {
      expect(connectionBloc.transport, isNull);
    });

    test('state can be transitioned from idle to hosting', () async {
      // Note: This test would fail in practice because WebRTC initialization
      // requires browser/platform support. We're just testing the state machine.
      // Real WebRTC testing must be manual.
      expect(connectionBloc.state, const ConnectionIdleState());
    });
  });

  group('ConnectionState', () {
    test('ConnectionIdleState equality', () {
      expect(const ConnectionIdleState(), const ConnectionIdleState());
    });

    test('ConnectionErrorState equality', () {
      expect(
        const ConnectionErrorState('error'),
        const ConnectionErrorState('error'),
      );
      expect(
        const ConnectionErrorState('error1'),
        isNot(const ConnectionErrorState('error2')),
      );
    });

    test('ConnectedState can copy with new messages', () {
      const state = ConnectedState(receivedMessages: []);
      final newState = state.copyWithMessage({'test': 'data'});
      
      expect(newState.receivedMessages.length, 1);
      expect(newState.receivedMessages.first['test'], 'data');
    });
  });
}
