import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/board.dart';
import '../../../domain/entities/position.dart';
import '../../../domain/entities/move.dart';
import '../../../domain/entities/game_result.dart';
import '../../../domain/services/crypto_service.dart';
import '../../../domain/services/game_rules_engine.dart';
import '../../../infrastructure/transport/i_game_transport.dart' as transport_pkg;
import 'game_event.dart';
import 'game_state.dart';

/// Manages the game state machine and orchestrates the Mark→Guess→Reveal→Verify protocol
class GameBloc extends Bloc<GameEvent, GameState> {
  final CryptoService _cryptoService = CryptoService();
  final GameRulesEngine _rulesEngine = GameRulesEngine();
  final transport_pkg.IGameTransport _transport;
  
  Timer? _gameTimer;
  DateTime? _phaseStartTime; // Track start time for anti-cheat
  
  // Temporary storage for current turn
  String? _currentHash;
  String? _currentSalt;
  Position? _currentMarkedPosition;
  Position? _currentGuess;
  String? _opponentHash;
  Position? _opponentGuess;

  GameBloc({required transport_pkg.IGameTransport transport})
      : _transport = transport,
        super(const GameInitial()) {
    on<StartGameEvent>(_onStartGame);
    on<UpdateRemotePlayerEvent>(_onUpdateRemotePlayer);
    on<SelectPositionEvent>(_onSelectPosition);
    on<ConfirmMarkEvent>(_onConfirmMark);
    on<CancelSelectionEvent>(_onCancelSelection);
    on<ConfirmGuessEvent>(_onConfirmGuess);
    on<OpponentMarkedEvent>(_onOpponentMarked);
    on<OpponentGuessedEvent>(_onOpponentGuessed);
    on<RevealMoveEvent>(_onRevealMove);
    on<OpponentRevealedEvent>(_onOpponentRevealed);
    on<TimerTickEvent>(_onTimerTick);
    on<ForfeitEvent>(_onForfeit);
    on<DisconnectEvent>(_onDisconnect);
    on<CheatDetectedEvent>(_onCheatDetected);
    on<InitiateGuessPhaseEvent>(_onInitiateGuessPhase);
    on<StartNextTurnEvent>(_onStartNextTurn);
  }

  @override
  Future<void> close() {
    _gameTimer?.cancel();
    return super.close();
  }

  /// Start a new game
  Future<void> _onStartGame(StartGameEvent event, Emitter<GameState> emit) async {
    final board = Board();
    
    // Host (Player 1) marks first
    final isHostTurn = event.localPlayer.isHost;
    
    _phaseStartTime = DateTime.now();
    
    if (isHostTurn) {
      // Local player marks first
      emit(MarkingState(
        localPlayer: event.localPlayer,
        remotePlayer: event.remotePlayer,
        board: board,
        config: event.config,
        moveHistory: [],
        remainingSeconds: event.config.isTimed ? event.config.initialSeconds : null,
      ));
      
      if (event.config.isTimed) {
        _startTimer(event.config.initialSeconds);
      }
    } else {
      // Wait for opponent to mark
      emit(OpponentMarkingState(
        localPlayer: event.localPlayer,
        remotePlayer: event.remotePlayer,
        board: board,
        config: event.config,
        moveHistory: [],
        remainingSeconds: event.config.isTimed ? event.config.initialSeconds : null,
      ));
      
      if (event.config.isTimed) {
        _startTimer(event.config.initialSeconds);
      }
    }
  }

  /// User taps a position (first tap in two-step confirmation)
  Future<void> _onSelectPosition(SelectPositionEvent event, Emitter<GameState> emit) async {
    if (state is! GameActiveState) return;
    
    final currentState = state as GameActiveState;
    
    // Validate move
    if (!_rulesEngine.isValidMove(currentState.board, event.position)) {
      return; // Invalid position, ignore
    }
    
    // Update state with selected position
    if (state is MarkingState) {
      emit((state as MarkingState).copyWith(selectedPosition: event.position));
    } else if (state is GuessingState) {
      emit((state as GuessingState).copyWith(selectedPosition: event.position));
    }
  }

  /// User confirms their marked position (second tap)
  Future<void> _onConfirmMark(ConfirmMarkEvent event, Emitter<GameState> emit) async {
    if (state is! MarkingState) return;
    
    final currentState = state as MarkingState;
    if (currentState.selectedPosition == null) return;
    
    // Generate commitment
    final commitment = _cryptoService.generateCommitment(currentState.selectedPosition!);
    _currentHash = commitment.hash;
    _currentSalt = commitment.salt;
    _currentMarkedPosition = currentState.selectedPosition;
    
    await _sendGameMessage({
      'type': 'mark',
      'hash': _currentHash,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Transition to waiting for opponent to mark (if they haven't already)
    if (_opponentHash == null) {
      emit(OpponentMarkingState(
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        board: currentState.board,
        config: currentState.config,
        moveHistory: currentState.moveHistory,
        remainingSeconds: currentState.remainingSeconds,
      ));
    } else {
      // Opponent already marked, move to guessing
      add(const InitiateGuessPhaseEvent());
    }
  }

  /// Cancel current selection
  Future<void> _onCancelSelection(CancelSelectionEvent event, Emitter<GameState> emit) async {
    if (state is MarkingState) {
      emit((state as MarkingState).copyWith(selectedPosition: null));
    } else if (state is GuessingState) {
      emit((state as GuessingState).copyWith(selectedPosition: null));
    }
  }

  /// User confirms their guess (second tap)
  Future<void> _onConfirmGuess(ConfirmGuessEvent event, Emitter<GameState> emit) async {
    if (state is! GuessingState) return;
    
    final currentState = state as GuessingState;
    if (currentState.selectedPosition == null) return;
    
    _currentGuess = currentState.selectedPosition;
    
    await _sendGameMessage({
      'type': 'guess',
      'position': _currentGuess!.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Wait for opponent to guess (if they haven't already)
    if (_opponentGuess == null) {
      emit(OpponentGuessingState(
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        board: currentState.board,
        config: currentState.config,
        moveHistory: currentState.moveHistory,
        ourHash: _currentHash!,
        ourMarkedPosition: _currentMarkedPosition!,
        ourSalt: _currentSalt!,
        remainingSeconds: currentState.remainingSeconds,
      ));
    } else {
      // Opponent already guessed, move to revealing
      add(const RevealMoveEvent());
    }
  }

  /// Received opponent's mark (hash)
  Future<void> _onOpponentMarked(OpponentMarkedEvent event, Emitter<GameState> emit) async {
    _opponentHash = event.hash;
    
    // Check timer anti-cheat (±2 second tolerance)
    if (_phaseStartTime != null && state is GameActiveState) {
      final elapsed = event.timestamp.difference(_phaseStartTime!).inSeconds;
      final currentState = state as GameActiveState;
      
      if (currentState.config.isTimed) {
        final expectedMax = currentState.config.initialSeconds + 2;
        if (elapsed > expectedMax) {
          add(CheatDetectedEvent('Opponent exceeded time limit by ${elapsed - currentState.config.initialSeconds} seconds'));
          return;
        }
      }
    }
    
    // If we already marked, move to guessing. Otherwise allow local to mark.
    if (_currentHash != null) {
      add(const InitiateGuessPhaseEvent());
    } else if (state is GameActiveState) {
      final currentState = state as GameActiveState;
      emit(MarkingState(
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        board: currentState.board,
        config: currentState.config,
        moveHistory: currentState.moveHistory,
        remainingSeconds: currentState.remainingSeconds,
      ));
    }
  }

  /// Received opponent's guess
  Future<void> _onOpponentGuessed(OpponentGuessedEvent event, Emitter<GameState> emit) async {
    _opponentGuess = event.guessedPosition;
    
    // Check timer anti-cheat
    if (_phaseStartTime != null && state is GameActiveState) {
      final elapsed = event.timestamp.difference(_phaseStartTime!).inSeconds;
      final currentState = state as GameActiveState;
      
      if (currentState.config.isTimed) {
        final expectedMax = currentState.config.initialSeconds + 2;
        if (elapsed > expectedMax) {
          add(const CheatDetectedEvent('Opponent exceeded time limit'));
          return;
        }
      }
    }
    
    // If we already guessed, move to revealing
    if (_currentGuess != null) {
      add(const RevealMoveEvent());
    }
  }

  /// Move to guessing phase
  Future<void> _onInitiateGuessPhase(InitiateGuessPhaseEvent event, Emitter<GameState> emit) async {
    if (state is! GameActiveState) return;
    
    final currentState = state as GameActiveState;
    
    // Reset timer for guessing phase
    _phaseStartTime = DateTime.now();
    
    // Determine whose turn to guess first (host guesses first if they were Player 2)
    final isLocalPlayerHost = currentState.localPlayer.isHost;
    final turnNumber = currentState.turnNumber;
    final isEvenTurn = turnNumber % 2 == 0;
    
    // Host marks on odd turns, guest marks on even turns
    // So: Host guesses on even turns, guest guesses on odd turns
    final shouldLocalPlayerGuessFirst = isLocalPlayerHost ? isEvenTurn : !isEvenTurn;
    
    if (shouldLocalPlayerGuessFirst) {
      emit(GuessingState(
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        board: currentState.board,
        config: currentState.config,
        moveHistory: currentState.moveHistory,
        opponentHash: _opponentHash!,
        remainingSeconds: currentState.config.isTimed ? currentState.config.initialSeconds : null,
      ));
    } else {
      emit(OpponentGuessingState(
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        board: currentState.board,
        config: currentState.config,
        moveHistory: currentState.moveHistory,
        ourHash: _currentHash!,
        ourMarkedPosition: _currentMarkedPosition!,
        ourSalt: _currentSalt!,
        remainingSeconds: currentState.config.isTimed ? currentState.config.initialSeconds : null,
      ));
    }
  }

  /// Reveal marked position
  Future<void> _onRevealMove(RevealMoveEvent event, Emitter<GameState> emit) async {
    if (state is! GameActiveState) return;
    
    final currentState = state as GameActiveState;
    
    await _sendGameMessage({
      'type': 'reveal',
      'position': _currentMarkedPosition!.toJson(),
      'salt': _currentSalt,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    emit(RevealingState(
      localPlayer: currentState.localPlayer,
      remotePlayer: currentState.remotePlayer,
      board: currentState.board,
      config: currentState.config,
      moveHistory: currentState.moveHistory,
      ourMarkedPosition: _currentMarkedPosition!,
      ourSalt: _currentSalt!,
      ourGuess: _currentGuess!,
      remainingSeconds: currentState.remainingSeconds,
    ));
  }

  /// Received opponent's reveal
  Future<void> _onOpponentRevealed(OpponentRevealedEvent event, Emitter<GameState> emit) async {
    if (state is! RevealingState) {
      // We might be in OpponentGuessingState, transition to RevealingState first
      if (state is OpponentGuessingState) {
        final currentState = state as OpponentGuessingState;
        emit(RevealingState(
          localPlayer: currentState.localPlayer,
          remotePlayer: currentState.remotePlayer,
          board: currentState.board,
          config: currentState.config,
          moveHistory: currentState.moveHistory,
          ourMarkedPosition: currentState.ourMarkedPosition,
          ourSalt: currentState.ourSalt,
          ourGuess: _opponentGuess!,
          opponentRevealedPosition: event.revealedPosition,
          isVerifying: true,
          remainingSeconds: currentState.remainingSeconds,
        ));
      } else {
        return;
      }
    } else {
      final currentState = state as RevealingState;
      emit(currentState.copyWith(
        opponentRevealedPosition: event.revealedPosition,
        isVerifying: true,
      ));
    }
    
    // Verify opponent's reveal
    final isValid = _cryptoService.verifyMove(
      originalHash: _opponentHash!,
      revealedPosition: event.revealedPosition,
      revealedSalt: event.salt,
    );
    
    if (!isValid) {
      add(const CheatDetectedEvent('Opponent provided invalid position/salt (hash mismatch)'));
      return;
    }
    
    // Both players have revealed, now apply stones to board
    _applyTurnResults(emit);
  }

  /// Apply turn results to board (place stones, check win)
  void _applyTurnResults(Emitter<GameState> emit) {
    if (state is! RevealingState) return;
    
    final currentState = state as RevealingState;
    if (!currentState.hasOpponentRevealed) return;
    
    final opponentRevealedPos = currentState.opponentRevealedPosition!;
    
    // Determine if guesses were correct
    final weGuessedCorrectly = _currentGuess == opponentRevealedPos;
    final theyGuessedCorrectly = _opponentGuess == _currentMarkedPosition;
    
    Board newBoard = currentState.board;
    
    // Determine whose turn it was to mark (host marks on odd turns)
    final turnNumber = currentState.turnNumber;
    final isOddTurn = turnNumber % 2 == 1;
    final hostMarkedThisTurn = isOddTurn;
    final weMarkedThisTurn = currentState.localPlayer.isHost == hostMarkedThisTurn;
    
    // Apply stones based on correct guesses
    if (weMarkedThisTurn) {
      // We marked, they guessed
      if (theyGuessedCorrectly) {
        // They stole our stone
        newBoard = newBoard.placeStolenStone(
          position: _currentMarkedPosition!,
          winnerColor: currentState.remotePlayer.stoneColor!,
          loserColor: currentState.localPlayer.stoneColor!,
        );
      } else {
        // We place normally
        newBoard = newBoard.placeRegularStone(
          position: _currentMarkedPosition!,
          color: currentState.localPlayer.stoneColor!,
        );
      }
    } else {
      // They marked, we guessed
      if (weGuessedCorrectly) {
        // We stole their stone
        newBoard = newBoard.placeStolenStone(
          position: opponentRevealedPos,
          winnerColor: currentState.localPlayer.stoneColor!,
          loserColor: currentState.remotePlayer.stoneColor!,
        );
      } else {
        // They place normally
        newBoard = newBoard.placeRegularStone(
          position: opponentRevealedPos,
          color: currentState.remotePlayer.stoneColor!,
        );
      }
    }
    
    // Create Move record for history
    final move = Move.create(
      markerColor: weMarkedThisTurn ? currentState.localPlayer.stoneColor! : currentState.remotePlayer.stoneColor!,
      markedPosition: weMarkedThisTurn ? _currentMarkedPosition! : opponentRevealedPos,
      hash: weMarkedThisTurn ? _currentHash! : _opponentHash!,
      salt: weMarkedThisTurn ? _currentSalt! : '', // We don't store opponent's salt
    ).withGuess(
      weMarkedThisTurn ? _opponentGuess! : _currentGuess!,
    ).revealed();
    
    final updatedHistory = [...currentState.moveHistory, move];
    
    // Check for win
    final winner = newBoard.getWinner();
    if (winner != null) {
      final winningPlayer = winner == currentState.localPlayer.stoneColor
          ? currentState.localPlayer
          : currentState.remotePlayer;
      final losingPlayer = winner == currentState.localPlayer.stoneColor
          ? currentState.remotePlayer
          : currentState.localPlayer;
      
      final result = GameResult.win(
        winner: winningPlayer,
        loser: losingPlayer,
        finalBoard: newBoard,
        winningColor: winner,
      );
      
      _cleanupTurn();
      _gameTimer?.cancel();
      
      emit(GameOverState(
        result: result,
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        finalBoard: newBoard,
        moveHistory: updatedHistory,
      ));
      return;
    }
    
    // Check for draw
    if (_rulesEngine.isBoardFull(newBoard)) {
      final result = GameResult.draw(
        player1: currentState.localPlayer,
        player2: currentState.remotePlayer,
        finalBoard: newBoard,
      );
      
      _cleanupTurn();
      _gameTimer?.cancel();
      
      emit(GameOverState(
        result: result,
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        finalBoard: newBoard,
        moveHistory: updatedHistory,
      ));
      return;
    }
    
    // Continue to next turn
    _cleanupTurn();
    _phaseStartTime = DateTime.now();
    
    // Next turn - roles swap
    final nextIsLocalPlayerMarking = !weMarkedThisTurn;
    
    if (nextIsLocalPlayerMarking) {
      emit(MarkingState(
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        board: newBoard,
        config: currentState.config,
        moveHistory: updatedHistory,
        remainingSeconds: currentState.config.isTimed ? currentState.config.initialSeconds : null,
      ));
    } else {
      emit(OpponentMarkingState(
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        board: newBoard,
        config: currentState.config,
        moveHistory: updatedHistory,
        remainingSeconds: currentState.config.isTimed ? currentState.config.initialSeconds : null,
      ));
    }
  }

  /// Timer tick
  Future<void> _onTimerTick(TimerTickEvent event, Emitter<GameState> emit) async {
    if (state is! GameActiveState) return;
    
    final currentState = state as GameActiveState;
    
    if (event.remainingSeconds <= 0) {
      // Timeout
      final result = GameResult.timeout(
        winner: currentState.remotePlayer,
        loser: currentState.localPlayer,
        finalBoard: currentState.board,
      );
      
      _gameTimer?.cancel();
      
      emit(GameOverState(
        result: result,
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        finalBoard: currentState.board,
        moveHistory: currentState.moveHistory,
      ));
      return;
    }
    
    // Update remaining time
    if (state is MarkingState) {
      emit((state as MarkingState).copyWith(remainingSeconds: event.remainingSeconds));
    } else if (state is OpponentMarkingState) {
      emit((state as OpponentMarkingState).copyWith(remainingSeconds: event.remainingSeconds));
    } else if (state is GuessingState) {
      emit((state as GuessingState).copyWith(remainingSeconds: event.remainingSeconds));
    } else if (state is OpponentGuessingState) {
      emit((state as OpponentGuessingState).copyWith(remainingSeconds: event.remainingSeconds));
    } else if (state is RevealingState) {
      emit((state as RevealingState).copyWith(remainingSeconds: event.remainingSeconds));
    }
  }

  /// Player forfeits
  Future<void> _onForfeit(ForfeitEvent event, Emitter<GameState> emit) async {
    if (state is! GameActiveState) return;
    
    final currentState = state as GameActiveState;
    
    final result = GameResult.forfeit(
      winner: currentState.remotePlayer,
      loser: currentState.localPlayer,
      finalBoard: currentState.board,
    );
    
    _gameTimer?.cancel();
    
    emit(GameOverState(
      result: result,
      localPlayer: currentState.localPlayer,
      remotePlayer: currentState.remotePlayer,
      finalBoard: currentState.board,
      moveHistory: currentState.moveHistory,
    ));
  }

  /// Connection lost
  Future<void> _onDisconnect(DisconnectEvent event, Emitter<GameState> emit) async {
    if (state is! GameActiveState) return;
    
    final currentState = state as GameActiveState;
    
    final result = GameResult.disconnect(
      winner: currentState.localPlayer,
      disconnector: currentState.remotePlayer,
      finalBoard: currentState.board,
    );
    
    _gameTimer?.cancel();
    
    emit(GameOverState(
      result: result,
      localPlayer: currentState.localPlayer,
      remotePlayer: currentState.remotePlayer,
      finalBoard: currentState.board,
      moveHistory: currentState.moveHistory,
    ));
  }

  /// Cheat detected
  Future<void> _onCheatDetected(CheatDetectedEvent event, Emitter<GameState> emit) async {
    if (state is! GameActiveState) return;
    
    final currentState = state as GameActiveState;
    
    final result = GameResult.cheatDetected(
      winner: currentState.localPlayer,
      cheater: currentState.remotePlayer,
      finalBoard: currentState.board,
    );
    
    _gameTimer?.cancel();
    
    emit(GameOverState(
      result: result,
      localPlayer: currentState.localPlayer,
      remotePlayer: currentState.remotePlayer,
      finalBoard: currentState.board,
      moveHistory: currentState.moveHistory,
    ));
  }

  /// Start next turn (unused, integrated into _applyTurnResults)
  Future<void> _onStartNextTurn(StartNextTurnEvent event, Emitter<GameState> emit) async {
    // Implementation moved into _applyTurnResults
  }

  Future<void> _onUpdateRemotePlayer(
    UpdateRemotePlayerEvent event,
    Emitter<GameState> emit,
  ) async {
    final currentState = state;
    if (currentState is MarkingState) {
      emit(currentState.copyWith(remotePlayer: event.remotePlayer));
    } else if (currentState is OpponentMarkingState) {
      emit(currentState.copyWith(remotePlayer: event.remotePlayer));
    } else if (currentState is GuessingState) {
      emit(currentState.copyWith(remotePlayer: event.remotePlayer));
    } else if (currentState is OpponentGuessingState) {
      emit(currentState.copyWith(remotePlayer: event.remotePlayer));
    } else if (currentState is RevealingState) {
      emit(currentState.copyWith(remotePlayer: event.remotePlayer));
    } else if (currentState is GameOverState) {
      emit(GameOverState(
        result: currentState.result,
        localPlayer: currentState.localPlayer,
        remotePlayer: event.remotePlayer,
        finalBoard: currentState.finalBoard,
        moveHistory: currentState.moveHistory,
      ));
    }
  }

  /// Start countdown timer
  void _startTimer(int seconds) {
    _gameTimer?.cancel();
    
    int remaining = seconds;
    add(TimerTickEvent(remaining));
    
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      add(TimerTickEvent(remaining));
      
      if (remaining <= 0) {
        timer.cancel();
      }
    });
  }

  /// Cleanup turn-specific state
  void _cleanupTurn() {
    _currentHash = null;
    _currentSalt = null;
    _currentMarkedPosition = null;
    _currentGuess = null;
    _opponentHash = null;
    _opponentGuess = null;
  }

  Future<void> _sendGameMessage(Map<String, dynamic> message) async {
    await _transport.send(message);
  }
}
