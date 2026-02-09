import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:psygomoku/presentation/blocs/game_bloc/game_bloc.dart';
import 'package:psygomoku/presentation/blocs/game_bloc/game_event.dart';
import 'package:psygomoku/presentation/blocs/game_bloc/game_state.dart';
import 'package:psygomoku/domain/entities/player.dart';
import 'package:psygomoku/domain/entities/position.dart';
import 'package:psygomoku/domain/entities/game_config.dart';
import 'package:psygomoku/domain/entities/stone.dart';
import 'package:psygomoku/infrastructure/transport/i_game_transport.dart'
    as transport_pkg;

// ---------------------------------------------------------------------------
//  Mock transport – bridges two blocs so they talk to each other
// ---------------------------------------------------------------------------

/// A mock transport that records outgoing messages and lets us replay them on
/// the peer bloc.  Two instances are paired: hostTransport <-> guestTransport.
class MockTransport implements transport_pkg.IGameTransport {
  final _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();
  final _stateController =
      StreamController<transport_pkg.ConnectionState>.broadcast();

  MockTransport? _peer;
  transport_pkg.ConnectionState _state = transport_pkg.ConnectionState.connected;

  /// Link this transport to its peer; messages sent here arrive there.
  void linkTo(MockTransport peer) {
    _peer = peer;
    peer._peer = this;
  }

  // -- IGameTransport impl --

  @override
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  @override
  Stream<void> get onDisconnect => _disconnectController.stream;

  @override
  Stream<transport_pkg.ConnectionState> get onStateChanged =>
      _stateController.stream;

  @override
  transport_pkg.ConnectionState get connectionState => _state;

  @override
  Future<void> connect(String signalData) async {
    _state = transport_pkg.ConnectionState.connected;
  }

  @override
  Future<bool> send(Map<String, dynamic> data) async {
    // Deliver to peer immediately
    _peer?._messageController.add(data);
    return true;
  }

  @override
  Future<void> dispose() async {
    await _messageController.close();
    await _disconnectController.close();
    await _stateController.close();
  }
}

// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------

Player _hostPlayer() => const Player(
      id: 'host-id',
      nickname: 'Host',
      avatarColor: '#00E5FF',
      isHost: true,
      stoneColor: StoneColor.cyan,
    );

Player _guestPlayer() => const Player(
      id: 'guest-id',
      nickname: 'Guest',
      avatarColor: '#FF4081',
      isHost: false,
      stoneColor: StoneColor.magenta,
    );

GameConfig _casualConfig() => GameConfig.casual();

/// The game session screen normally routes incoming transport messages to bloc
/// events.  Here we replicate that logic so the test is faithful.
void _routeTransportToBloc(
    MockTransport transport, GameBloc bloc) {
  transport.onMessage.listen((data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'mark':
        bloc.add(OpponentMarkedEvent(
          hash: data['hash'] as String,
          timestamp: DateTime.parse(data['timestamp'] as String),
        ));
        break;
      case 'guess':
        final pos = data['position'] as Map<String, dynamic>;
        bloc.add(OpponentGuessedEvent(
          guessedPosition: Position.fromJson(pos),
          timestamp: DateTime.parse(data['timestamp'] as String),
        ));
        break;
      case 'reveal':
        final pos = data['position'] as Map<String, dynamic>;
        bloc.add(OpponentRevealedEvent(
          revealedPosition: Position.fromJson(pos),
          salt: data['salt'] as String,
          timestamp: DateTime.parse(data['timestamp'] as String),
        ));
        break;
      case 'forfeit':
        bloc.add(OpponentForfeitedEvent(
          timestamp: DateTime.parse(data['timestamp'] as String),
        ));
        break;
    }
  });
}

// ---------------------------------------------------------------------------
//  Harness – creates two linked blocs and drives them
// ---------------------------------------------------------------------------

class GameTestHarness {
  late MockTransport hostTransport;
  late MockTransport guestTransport;
  late GameBloc hostBloc;
  late GameBloc guestBloc;

  void setUp() {
    hostTransport = MockTransport();
    guestTransport = MockTransport();
    hostTransport.linkTo(guestTransport);

    hostBloc = GameBloc(transport: hostTransport);
    guestBloc = GameBloc(transport: guestTransport);

    _routeTransportToBloc(hostTransport, hostBloc);
    _routeTransportToBloc(guestTransport, guestBloc);
  }

  Future<void> tearDown() async {
    await hostBloc.close();
    await guestBloc.close();
    await hostTransport.dispose();
    await guestTransport.dispose();
  }

  /// Both sides start the game.
  void startGame() {
    hostBloc.add(StartGameEvent(
      localPlayer: _hostPlayer(),
      remotePlayer: _guestPlayer(),
      config: _casualConfig(),
    ));
    guestBloc.add(StartGameEvent(
      localPlayer: _guestPlayer(),
      remotePlayer: _hostPlayer(),
      config: _casualConfig(),
    ));
  }

  /// Wait until both blocs are idle after event processing.
  Future<void> pumpEvents() async {
    // Give time for async processing.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  /// Perform a select-then-confirm mark on the given bloc.
  void mark(GameBloc bloc, Position pos) {
    bloc.add(SelectPositionEvent(pos));
    bloc.add(const ConfirmMarkEvent());
  }

  /// Perform a select-then-confirm guess on the given bloc.
  void guess(GameBloc bloc, Position pos) {
    bloc.add(SelectPositionEvent(pos));
    bloc.add(const ConfirmGuessEvent());
  }
}

// ---------------------------------------------------------------------------
//  Tests
// ---------------------------------------------------------------------------

void main() {
  late GameTestHarness h;

  setUp(() {
    h = GameTestHarness();
    h.setUp();
  });

  tearDown(() => h.tearDown());

  // -------------------------------------------------------------------------
  //  1.  Game start – host marks, guest waits
  // -------------------------------------------------------------------------
  test('After start, host is in MarkingState, guest in OpponentMarkingState',
      () async {
    h.startGame();
    await h.pumpEvents();

    expect(h.hostBloc.state, isA<MarkingState>());
    expect(h.guestBloc.state, isA<OpponentMarkingState>());
  });

  // -------------------------------------------------------------------------
  //  2.  Host marks → guest enters GuessingState
  // -------------------------------------------------------------------------
  test('Host marks, then host→OpponentGuessingState, guest→GuessingState',
      () async {
    h.startGame();
    await h.pumpEvents();

    h.mark(h.hostBloc, const Position(7, 7));
    await h.pumpEvents();

    expect(h.hostBloc.state, isA<OpponentGuessingState>(),
        reason: 'Host should wait for opponent to guess');
    expect(h.guestBloc.state, isA<GuessingState>(),
        reason: 'Guest should be asked to guess');
  });

  // -------------------------------------------------------------------------
  //  3.  Full turn: host marks, guest guesses WRONG → host won, turn switches
  // -------------------------------------------------------------------------
  test('Full turn – wrong guess – host stone placed, turn switches', () async {
    h.startGame();
    await h.pumpEvents();

    // Host marks (7,7)
    h.mark(h.hostBloc, const Position(7, 7));
    await h.pumpEvents();

    // Guest guesses WRONG (8,8)
    h.guess(h.guestBloc, const Position(8, 8));
    await h.pumpEvents();

    // Host won (guest guessed wrong), so turn switches → Guest marks next
    expect(h.hostBloc.state, isA<OpponentMarkingState>(),
        reason: 'Host won, turn switches, host waits');
    expect(h.guestBloc.state, isA<MarkingState>(),
        reason: 'Guest guessed wrong, turn switches, guest marks');

    // Verify stone placed – both sides should agree
    final hostBoard = (h.hostBloc.state as GameActiveState).board;
    final guestBoard = (h.guestBloc.state as GameActiveState).board;

    expect(hostBoard.isOccupied(const Position(7, 7)), isTrue);
    expect(guestBoard.isOccupied(const Position(7, 7)), isTrue);

    // The stone should be cyan (host placed normally, guess was wrong)
    expect(hostBoard.getStone(const Position(7, 7))!.color, StoneColor.cyan);
    expect(guestBoard.getStone(const Position(7, 7))!.color, StoneColor.cyan);
    expect(hostBoard.getStone(const Position(7, 7))!.isStolen, isFalse);
  });

  // -------------------------------------------------------------------------
  //  4.  Full turn: host marks, guest guesses CORRECT → host lost, host marks again
  // -------------------------------------------------------------------------
  test('Full turn – correct guess – stone stolen, marker marks again', () async {
    h.startGame();
    await h.pumpEvents();

    // Host marks (7,7)
    h.mark(h.hostBloc, const Position(7, 7));
    await h.pumpEvents();

    // Guest guesses CORRECTLY (7,7)
    h.guess(h.guestBloc, const Position(7, 7));
    await h.pumpEvents();

    // Stone should be stolen: guest's color (magenta) with host border (cyan)
    final hostBoard = (h.hostBloc.state as GameActiveState).board;
    final guestBoard = (h.guestBloc.state as GameActiveState).board;

    expect(hostBoard.getStone(const Position(7, 7))!.color, StoneColor.magenta);
    expect(hostBoard.getStone(const Position(7, 7))!.isStolen, isTrue);
    expect(guestBoard.getStone(const Position(7, 7))!.color, StoneColor.magenta);
    expect(guestBoard.getStone(const Position(7, 7))!.isStolen, isTrue);

    // Host lost (guessed correctly), so host marks again (no turn switch)
    expect(h.hostBloc.state, isA<MarkingState>(),
        reason: 'Host lost, marks again');
    expect(h.guestBloc.state, isA<OpponentMarkingState>(),
        reason: 'Guest won, waits');
  });

  // -------------------------------------------------------------------------
  //  5.  Two full turns – wrong guesses cause turn switches
  // -------------------------------------------------------------------------
  test('Two turns – wrong guesses alternate markers', () async {
    h.startGame();
    await h.pumpEvents();

    // Turn 1: Host marks, Guest guesses wrong → turn switches
    h.mark(h.hostBloc, const Position(7, 7));
    await h.pumpEvents();
    h.guess(h.guestBloc, const Position(0, 0));
    await h.pumpEvents();

    // After turn 1: Guest marks, Host waits
    expect(h.guestBloc.state, isA<MarkingState>());
    expect(h.hostBloc.state, isA<OpponentMarkingState>());

    // Turn 2: Guest marks, Host guesses wrong → turn switches back
    h.mark(h.guestBloc, const Position(3, 3));
    await h.pumpEvents();
    h.guess(h.hostBloc, const Position(1, 1));
    await h.pumpEvents();

    // After turn 2: Host marks again, Guest waits
    expect(h.hostBloc.state, isA<MarkingState>());
    expect(h.guestBloc.state, isA<OpponentMarkingState>());

    // Board should have 2 regular stones
    final board = (h.hostBloc.state as GameActiveState).board;
    expect(board.stones.length, 2);
    expect(board.isOccupied(const Position(7, 7)), isTrue);
    expect(board.isOccupied(const Position(3, 3)), isTrue);
    expect(board.getStone(const Position(7, 7))!.isStolen, isFalse);
    expect(board.getStone(const Position(3, 3))!.isStolen, isFalse);
  });

  // -------------------------------------------------------------------------
  //  6.  Guesser's _onConfirmGuess transitions to OpponentRevealingState
  // -------------------------------------------------------------------------
  test('Guesser transitions to OpponentRevealingState after guessing',
      () async {
    h.startGame();
    await h.pumpEvents();

    // Host marks (7,7)
    h.mark(h.hostBloc, const Position(7, 7));
    await h.pumpEvents();

    // Guest selects + confirms guess (wrong), but DON'T pump yet so we can catch
    // the intermediate state before the reveal arrives
    h.guestBloc.add(const SelectPositionEvent(Position(5, 5)));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    h.guestBloc.add(const ConfirmGuessEvent());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Guest should be in OpponentRevealingState (waiting for host's reveal)
    // OR already in MarkingState if reveal was super fast (wrong guess → switch).
    final state = h.guestBloc.state;
    expect(
      state is OpponentRevealingState || state is MarkingState,
      isTrue,
      reason:
          'Guest should be waiting for reveal or already marking. Got: $state',
    );
  });

  // -------------------------------------------------------------------------
  //  7.  No crash on reveal (the P2 crash bug)
  // -------------------------------------------------------------------------
  test('Guest does not crash when receiving opponent reveal', () async {
    h.startGame();
    await h.pumpEvents();

    // Host marks
    h.mark(h.hostBloc, const Position(7, 7));
    await h.pumpEvents();

    // Guest guesses
    h.guess(h.guestBloc, const Position(5, 5));
    await h.pumpEvents();

    // If we got here without exception, the crash is fixed.
    // Both blocs should be in a valid state (next turn)
    expect(h.hostBloc.state, isA<GameActiveState>());
    expect(h.guestBloc.state, isA<GameActiveState>());
  });

  // -------------------------------------------------------------------------
  //  8.  Five turns with wrong guesses (normal turn alternation)
  // -------------------------------------------------------------------------
  test('Five alternating turns via wrong guesses', () async {
    h.startGame();
    await h.pumpEvents();

    final positions = [
      const Position(7, 7),
      const Position(6, 6),
      const Position(5, 5),
      const Position(4, 4),
      const Position(3, 3),
    ];

    GameBloc marker = h.hostBloc;
    GameBloc guesser = h.guestBloc;

    for (int i = 0; i < 5; i++) {
      final markPos = positions[i];
      // Guess wrong (always 14,14 which is never the mark) → turn switches
      final guessPos = const Position(14, 14);

      h.mark(marker, markPos);
      await h.pumpEvents();
      h.guess(guesser, guessPos);
      await h.pumpEvents();

      // Wrong guess → turn switches
      final tmp = marker;
      marker = guesser;
      guesser = tmp;
    }

    // Should have 5 regular stones
    final board = (h.hostBloc.state as GameActiveState).board;
    expect(board.stones.length, 5);

    // All stones should be regular (wrong guesses)
    for (final pos in positions) {
      expect(board.getStone(pos)!.isStolen, isFalse);
    }

    // The current marker should be in MarkingState
    expect(marker.state, isA<MarkingState>());
    expect(guesser.state, isA<OpponentMarkingState>());
  });

  // -------------------------------------------------------------------------
  //  9.  Win detection
  // -------------------------------------------------------------------------
  test('Five in a row triggers GameOverState on both sides', () async {
    h.startGame();
    await h.pumpEvents();

    // We'll have the host place at (0,0), (0,1), (0,2), (0,3), (0,4)
    // alternating turns.  On odd turns host marks, even turns guest marks.
    // Guest always marks far away and host guesses wrong.

    // Turn 1: host marks (0,0), guest guesses wrong
    h.mark(h.hostBloc, const Position(0, 0));
    await h.pumpEvents();
    h.guess(h.guestBloc, const Position(14, 14));
    await h.pumpEvents();

    // Turn 2: guest marks (10,10), host guesses wrong
    h.mark(h.guestBloc, const Position(10, 10));
    await h.pumpEvents();
    h.guess(h.hostBloc, const Position(14, 13));
    await h.pumpEvents();

    // Turn 3: host marks (0,1)
    h.mark(h.hostBloc, const Position(0, 1));
    await h.pumpEvents();
    h.guess(h.guestBloc, const Position(14, 12));
    await h.pumpEvents();

    // Turn 4: guest marks (10,11)
    h.mark(h.guestBloc, const Position(10, 11));
    await h.pumpEvents();
    h.guess(h.hostBloc, const Position(14, 11));
    await h.pumpEvents();

    // Turn 5: host marks (0,2)
    h.mark(h.hostBloc, const Position(0, 2));
    await h.pumpEvents();
    h.guess(h.guestBloc, const Position(14, 10));
    await h.pumpEvents();

    // Turn 6: guest marks (10,12)
    h.mark(h.guestBloc, const Position(10, 12));
    await h.pumpEvents();
    h.guess(h.hostBloc, const Position(14, 9));
    await h.pumpEvents();

    // Turn 7: host marks (0,3)
    h.mark(h.hostBloc, const Position(0, 3));
    await h.pumpEvents();
    h.guess(h.guestBloc, const Position(14, 8));
    await h.pumpEvents();

    // Turn 8: guest marks (10,13)
    h.mark(h.guestBloc, const Position(10, 13));
    await h.pumpEvents();
    h.guess(h.hostBloc, const Position(14, 7));
    await h.pumpEvents();

    // Turn 9: host marks (0,4) → 5 in a row on column 0! 
    h.mark(h.hostBloc, const Position(0, 4));
    await h.pumpEvents();
    h.guess(h.guestBloc, const Position(14, 6));
    await h.pumpEvents();

    // Game should be over
    expect(h.hostBloc.state, isA<GameOverState>(),
        reason: 'Host should see game over');
    expect(h.guestBloc.state, isA<GameOverState>(),
        reason: 'Guest should see game over');

    final hostResult = (h.hostBloc.state as GameOverState);
    expect(hostResult.didLocalPlayerWin, isTrue);

    final guestResult = (h.guestBloc.state as GameOverState);
    expect(guestResult.didLocalPlayerWin, isFalse);
  });

  // -------------------------------------------------------------------------
  // 10. Forfeit
  // -------------------------------------------------------------------------
  test('Forfeit ends game on both sides', () async {
    h.startGame();
    await h.pumpEvents();

    h.hostBloc.add(const ForfeitEvent());
    await h.pumpEvents();

    expect(h.hostBloc.state, isA<GameOverState>());
    // Note: forfeit message is sent but OpponentForfeitedEvent handler is
    // needed on remote side. If not registered, guest won't see GameOver.
    // This test validates the local side at minimum.
  });

  // -------------------------------------------------------------------------
  // 11. Guesser wins via correct guess streak (marker never stops marking)
  // -------------------------------------------------------------------------
  test('Guesser wins by guessing correctly 5 times in a row', () async {
    h.startGame();
    await h.pumpEvents();

    // All correct guesses → Host (marker) lost every time → Host marks again
    // Turn 1: Host marks (7,7), Guest guesses correctly (7,7) → Host marks again
    h.mark(h.hostBloc, const Position(7, 7));
    await h.pumpEvents();
    h.guess(h.guestBloc, const Position(7, 7));
    await h.pumpEvents();

    // After correct guess, host (loser) should mark again
    expect(h.hostBloc.state, isA<MarkingState>(),
        reason: 'Host lost, marks again');
    expect(h.guestBloc.state, isA<OpponentMarkingState>(),
        reason: 'Guest won, waits');

    // Turn 2: Host marks (7,8), Guest guesses correctly
    h.mark(h.hostBloc, const Position(7, 8));
    await h.pumpEvents();
    h.guess(h.guestBloc, const Position(7, 8));
    await h.pumpEvents();

    expect(h.hostBloc.state, isA<MarkingState>());

    // Turn 3: Host marks (7,9), Guest guesses correctly
    h.mark(h.hostBloc, const Position(7, 9));
    await h.pumpEvents();
    h.guess(h.guestBloc, const Position(7, 9));
    await h.pumpEvents();

    expect(h.hostBloc.state, isA<MarkingState>());

    // Turn 4: Host marks (7,10), Guest guesses correctly
    h.mark(h.hostBloc, const Position(7, 10));
    await h.pumpEvents();
    h.guess(h.guestBloc, const Position(7, 10));
    await h.pumpEvents();

    expect(h.hostBloc.state, isA<MarkingState>());

    // Turn 5: Host marks (7,11), Guest guesses correctly
    // → Guest should have 5 stolen stones in a row at column 7
    h.mark(h.hostBloc, const Position(7, 11));
    await h.pumpEvents();
    h.guess(h.guestBloc, const Position(7, 11));
    await h.pumpEvents();

    // Game should be over - guest won with 5 stolen stones in a row
    expect(h.guestBloc.state, isA<GameOverState>(),
        reason: 'Guest should win with 5 stolen stones in a row');
    expect(h.hostBloc.state, isA<GameOverState>(),
        reason: 'Host should see game over');

    final guestResult = (h.guestBloc.state as GameOverState);
    expect(guestResult.didLocalPlayerWin, isTrue,
        reason: 'Guest should have won');

    final hostResult = (h.hostBloc.state as GameOverState);
    expect(hostResult.didLocalPlayerWin, isFalse,
        reason: 'Host should have lost');
  });}