import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psygomoku/domain/entities/game_config.dart';
import 'package:psygomoku/domain/entities/game_result.dart';
import 'package:psygomoku/domain/entities/player.dart';
import 'package:psygomoku/domain/entities/position.dart';
import 'package:psygomoku/domain/entities/stone.dart';
import 'package:psygomoku/domain/services/crypto_service.dart';
import 'package:psygomoku/infrastructure/transport/i_game_transport.dart' as transport_pkg;
import 'package:psygomoku/presentation/blocs/game_bloc/game_bloc.dart';
import 'package:psygomoku/presentation/blocs/game_bloc/game_event.dart';
import 'package:psygomoku/presentation/blocs/game_bloc/game_state.dart';

class FakeTransport implements transport_pkg.IGameTransport {
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();
  final _stateController = StreamController<transport_pkg.ConnectionState>.broadcast();
  final sentMessages = <Map<String, dynamic>>[];

  @override
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  @override
  Stream<void> get onDisconnect => _disconnectController.stream;

  @override
  Stream<transport_pkg.ConnectionState> get onStateChanged => _stateController.stream;

  @override
  transport_pkg.ConnectionState get connectionState => transport_pkg.ConnectionState.connected;

  @override
  Future<void> connect(String signalData) async {}

  @override
  Future<bool> send(Map<String, dynamic> data) async {
    sentMessages.add(data);
    return true;
  }

  @override
  Future<void> dispose() async {
    await _messageController.close();
    await _disconnectController.close();
    await _stateController.close();
  }
}

void main() {
  group('GameBloc', () {
    late FakeTransport transport;
    late GameBloc bloc;

    setUp(() {
      transport = FakeTransport();
      bloc = GameBloc(transport: transport);
    });

    tearDown(() async {
      await bloc.close();
      await transport.dispose();
    });

    blocTest<GameBloc, GameState>(
      'guest receives opponent mark and enters GuessingState',
      build: () => bloc,
      act: (bloc) {
        final local = Player.create(nickname: 'Guest', avatarColor: '#6B5B95')
          .copyWith(isHost: false, stoneColor: StoneColor.magenta);
        final remote = Player.create(nickname: 'Host', avatarColor: '#4C4C4C')
          .copyWith(isHost: true, stoneColor: StoneColor.cyan);
        bloc.add(StartGameEvent(localPlayer: local, remotePlayer: remote, config: GameConfig.casual()));
        bloc.add(OpponentMarkedEvent(hash: 'hash', timestamp: DateTime.now()));
        bloc.add(SelectPositionEvent(Position(5, 5)));
      },
      expect: () => [
        isA<OpponentMarkingState>(),
        isA<GuessingState>(),  // guest goes directly to guessing
        isA<GuessingState>(),  // with selected position
      ],
    );

    test('sending guess emits transport message', () async {
        final local = Player.create(nickname: 'Guest', avatarColor: '#6B5B95')
          .copyWith(isHost: false, stoneColor: StoneColor.magenta);
        final remote = Player.create(nickname: 'Host', avatarColor: '#4C4C4C')
          .copyWith(isHost: true, stoneColor: StoneColor.cyan);
      bloc.add(StartGameEvent(localPlayer: local, remotePlayer: remote, config: GameConfig.casual()));
      bloc.add(OpponentMarkedEvent(hash: 'hash', timestamp: DateTime.now()));

      // Guest is in GuessingState after opponent marks
      await bloc.stream.firstWhere((state) => state is GuessingState);

      bloc.add(SelectPositionEvent(Position(4, 4)));
      bloc.add(const ConfirmGuessEvent());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(transport.sentMessages.any((m) => m['type'] == 'guess'), isTrue);
    });

    test('verifies opponent reveal with valid hash', () async {
      final crypto = CryptoService();
      final opponentPosition = Position(7, 7);
      final commitment = crypto.generateCommitment(opponentPosition);

        final local = Player.create(nickname: 'Guest', avatarColor: '#6B5B95')
          .copyWith(isHost: false, stoneColor: StoneColor.magenta);
        final remote = Player.create(nickname: 'Host', avatarColor: '#4C4C4C')
          .copyWith(isHost: true, stoneColor: StoneColor.cyan);

      bloc.add(StartGameEvent(localPlayer: local, remotePlayer: remote, config: GameConfig.casual()));
      bloc.add(OpponentMarkedEvent(hash: commitment.hash, timestamp: DateTime.now()));

      // Guest is in GuessingState after opponent marks
      await bloc.stream.firstWhere((state) => state is GuessingState);

      bloc.add(SelectPositionEvent(Position(7, 7)));
      bloc.add(const ConfirmGuessEvent());

      // After guessing, guest waits in OpponentRevealingState for the reveal
      await bloc.stream.firstWhere((state) => state is OpponentRevealingState);

      // Host reveals
      bloc.add(OpponentRevealedEvent(
        revealedPosition: opponentPosition,
        salt: commitment.salt,
        timestamp: DateTime.now(),
      ));

      // After reveal: guest guessed correctly → host (marker) lost → host marks again
      // So guest should be in OpponentMarkingState (waiting for host to mark)
      await bloc.stream.firstWhere((state) => state is OpponentMarkingState);

      final currentState = bloc.state;
      expect(currentState, isA<OpponentMarkingState>());
      if (currentState is GameActiveState) {
        expect(currentState.board.stones.isNotEmpty, isTrue);
      }
    });

    group('Disconnect handling', () {
      blocTest<GameBloc, GameState>(
        'local player disconnects - they lose',
        build: () => bloc,
        act: (bloc) {
          final local = Player.create(nickname: 'Local', avatarColor: '#6B5B95')
            .copyWith(isHost: true, stoneColor: StoneColor.cyan);
          final remote = Player.create(nickname: 'Remote', avatarColor: '#4C4C4C')
            .copyWith(isHost: false, stoneColor: StoneColor.magenta);
          bloc.add(StartGameEvent(localPlayer: local, remotePlayer: remote, config: GameConfig.casual()));
          bloc.add(const DisconnectEvent());
        },
        verify: (bloc) {
          final state = bloc.state as GameOverState;
          expect(state.result.reason, equals(GameEndReason.disconnect));
          expect(state.result.loser?.nickname, equals('Local'));
          expect(state.result.winner?.nickname, equals('Remote'));
        },
      );

      blocTest<GameBloc, GameState>(
        'opponent disconnects - they lose',
        build: () => bloc,
        act: (bloc) {
          final local = Player.create(nickname: 'Local', avatarColor: '#6B5B95')
            .copyWith(isHost: true, stoneColor: StoneColor.cyan);
          final remote = Player.create(nickname: 'Remote', avatarColor: '#4C4C4C')
            .copyWith(isHost: false, stoneColor: StoneColor.magenta);
          bloc.add(StartGameEvent(localPlayer: local, remotePlayer: remote, config: GameConfig.casual()));
          bloc.add(const OpponentDisconnectedEvent());
        },
        verify: (bloc) {
          final state = bloc.state as GameOverState;
          expect(state.result.reason, equals(GameEndReason.disconnect));
          expect(state.result.loser?.nickname, equals('Remote'));
          expect(state.result.winner?.nickname, equals('Local'));
        },
      );

      test('disconnect event sends correct winner/loser', () async {
        final local = Player.create(nickname: 'Local', avatarColor: '#6B5B95')
          .copyWith(isHost: true, stoneColor: StoneColor.cyan);
        final remote = Player.create(nickname: 'Remote', avatarColor: '#4C4C4C')
          .copyWith(isHost: false, stoneColor: StoneColor.magenta);
        
        bloc.add(StartGameEvent(localPlayer: local, remotePlayer: remote, config: GameConfig.casual()));
        await bloc.stream.firstWhere((state) => state is MarkingState);
        
        bloc.add(const DisconnectEvent());
        final state = await bloc.stream.firstWhere((state) => state is GameOverState) as GameOverState;
        
        expect(state.result.winner?.id, equals(remote.id));
        expect(state.result.loser?.id, equals(local.id));
        expect(state.result.reason, equals(GameEndReason.disconnect));
      });

      test('opponent disconnect event sends correct winner/loser', () async {
        final local = Player.create(nickname: 'Local', avatarColor: '#6B5B95')
          .copyWith(isHost: true, stoneColor: StoneColor.cyan);
        final remote = Player.create(nickname: 'Remote', avatarColor: '#4C4C4C')
          .copyWith(isHost: false, stoneColor: StoneColor.magenta);
        
        bloc.add(StartGameEvent(localPlayer: local, remotePlayer: remote, config: GameConfig.casual()));
        await bloc.stream.firstWhere((state) => state is MarkingState);
        
        bloc.add(const OpponentDisconnectedEvent());
        final state = await bloc.stream.firstWhere((state) => state is GameOverState) as GameOverState;
        
        expect(state.result.winner?.id, equals(local.id));
        expect(state.result.loser?.id, equals(remote.id));
        expect(state.result.reason, equals(GameEndReason.disconnect));
      });
    });
  });
}
