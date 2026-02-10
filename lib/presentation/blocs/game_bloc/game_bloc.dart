import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/board.dart';
import '../../../domain/entities/position.dart';
import '../../../domain/entities/move.dart';
import '../../../domain/entities/game_result.dart';
import '../../../domain/entities/game_config.dart';
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
    on<OpponentForfeitedEvent>(_onOpponentForfeited);
    on<DisconnectEvent>(_onDisconnect);
    on<OpponentDisconnectedEvent>(_onOpponentDisconnected);
    on<CheatDetectedEvent>(_onCheatDetected);
    on<InitiateGuessPhaseEvent>(_onInitiateGuessPhase);
    on<StartNextTurnEvent>(_onStartNextTurn);
    on<RequestRematchEvent>(_onRequestRematch);
    on<OpponentRequestedRematchEvent>(_onOpponentRequestedRematch);
  }

  @override
  Future<void> close() {
    _gameTimer?.cancel();
    return super.close();
  }

  /// Start a new game
  Future<void> _onStartGame(StartGameEvent event, Emitter<GameState> emit) async {
    const board = Board();
    
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
    
    // After marking, wait for opponent to guess
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
    
    // After guessing, wait for opponent (marker) to reveal
    emit(OpponentRevealingState(
      localPlayer: currentState.localPlayer,
      remotePlayer: currentState.remotePlayer,
      board: currentState.board,
      config: currentState.config,
      moveHistory: currentState.moveHistory,
      ourGuess: _currentGuess!,
      opponentHash: currentState.opponentHash,
      remainingSeconds: currentState.remainingSeconds,
    ));
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
    
    // Opponent marked, we should guess (we're the guesser this turn)
    if (state is GameActiveState) {
      final currentState = state as GameActiveState;
      
      // Reset timer for guessing phase
      _phaseStartTime = DateTime.now();
      
      emit(GuessingState(
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        board: currentState.board,
        config: currentState.config,
        moveHistory: currentState.moveHistory,
        opponentHash: _opponentHash!,
        remainingSeconds: currentState.config.isTimed ? currentState.config.initialSeconds : null,
      ));
    }
  }

  /// Received opponent's guess
  Future<void> _onOpponentGuessed(OpponentGuessedEvent event, Emitter<GameState> emit) async {
    _opponentGuess = event.guessedPosition;
    
    if (state is! GameActiveState) return;
    final currentState = state as GameActiveState;
    
    // Check timer anti-cheat
    if (_phaseStartTime != null) {
      final elapsed = event.timestamp.difference(_phaseStartTime!).inSeconds;
      
      if (currentState.config.isTimed) {
        final expectedMax = currentState.config.initialSeconds + 2;
        if (elapsed > expectedMax) {
          add(const CheatDetectedEvent('Opponent exceeded time limit'));
          return;
        }
      }
    }
    
    // Immediately send reveal message (auto-reveal)
    await _sendGameMessage({
      'type': 'reveal',
      'position': _currentMarkedPosition!.toJson(),
      'salt': _currentSalt,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Apply turn results inline
    final theyGuessedCorrectly = _opponentGuess == _currentMarkedPosition;
    
    Board newBoard = currentState.board;
    
    // We marked this turn, they guessed
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
    
    // Create Move record for history
    final move = Move.create(
      markerColor: currentState.localPlayer.stoneColor!,
      markedPosition: _currentMarkedPosition!,
      hash: _currentHash!,
      salt: _currentSalt!,
    ).withGuess(
      _opponentGuess!,
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
    
    // Continue to next turn - LOSER marks next
    _cleanupTurn();
    _phaseStartTime = DateTime.now();
    
    if (theyGuessedCorrectly) {
      // They (guesser) won, we (marker) lost → we mark again
      emit(MarkingState(
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        board: newBoard,
        config: currentState.config,
        moveHistory: updatedHistory,
        remainingSeconds: currentState.config.isTimed ? currentState.config.initialSeconds : null,
      ));
    } else {
      // They guessed wrong, we (marker) won → turn switches (they mark next)
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
    
    // Get current state (should be OpponentRevealingState after guesser sent guess)
    final GameActiveState currentState;
    if (state is OpponentRevealingState) {
      currentState = state as OpponentRevealingState;
    } else if (state is GuessingState) {
      // Reveal arrived before we finished guessing (race condition)
      currentState = state as GuessingState;
    } else {
      return;
    }
    
    // Apply turn results inline
    // We are the guesser (opponent marked, we guessed, opponent revealed)
    final opponentRevealedPos = event.revealedPosition;
    final weGuessedCorrectly = _currentGuess == opponentRevealedPos;
    
    Board newBoard = currentState.board;
    
    // Apply stone to board based on whether we guessed correctly
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
    
    // Create Move record for history
    final move = Move.create(
      markerColor: currentState.remotePlayer.stoneColor!,
      markedPosition: opponentRevealedPos,
      hash: _opponentHash!,
      salt: '', // We don't store opponent's salt
    ).withGuess(
      _currentGuess!,
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
    
    // Continue to next turn - LOSER marks next
    _cleanupTurn();
    _phaseStartTime = DateTime.now();
    
    if (weGuessedCorrectly) {
      // We (guesser) won, they (marker) lost → they mark again
      emit(OpponentMarkingState(
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        board: newBoard,
        config: currentState.config,
        moveHistory: updatedHistory,
        remainingSeconds: currentState.config.isTimed ? currentState.config.initialSeconds : null,
      ));
    } else {
      // We guessed wrong, they (marker) won → turn switches (we mark next)
      emit(MarkingState(
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
    
    // Notify opponent
    await _sendGameMessage({
      'type': 'forfeit',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
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

  /// Opponent forfeited
  Future<void> _onOpponentForfeited(OpponentForfeitedEvent event, Emitter<GameState> emit) async {
    if (state is! GameActiveState) return;
    
    final currentState = state as GameActiveState;
    
    final result = GameResult.forfeit(
      winner: currentState.localPlayer,
      loser: currentState.remotePlayer,
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

  /// Connection lost - we are disconnecting
  Future<void> _onDisconnect(DisconnectEvent event, Emitter<GameState> emit) async {
    if (state is! GameActiveState) return;
    
    final currentState = state as GameActiveState;
    
    // When WE disconnect, THEY win and WE are the disconnector
    final result = GameResult.disconnect(
      winner: currentState.remotePlayer,
      disconnector: currentState.localPlayer,
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

  /// Opponent disconnected
  Future<void> _onOpponentDisconnected(OpponentDisconnectedEvent event, Emitter<GameState> emit) async {
    // Only handle disconnect if game is still active
    // If game already ended (GameOverState), ignore disconnect - no victory for opponent leaving after game ends
    if (state is GameActiveState) {
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
    // If already in GameOverState, do nothing - game is already finished
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

  /// Request rematch
  Future<void> _onRequestRematch(RequestRematchEvent event, Emitter<GameState> emit) async {
    if (state is! GameOverState) return;
    
    final currentState = state as GameOverState;
    
    // Update state to show we want rematch
    final updatedState = currentState.copyWith(localWantsRematch: true);
    emit(updatedState);
    
    // Send rematch request to opponent
    await _transport.send({
      'type': 'rematch_request',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // If opponent already wants rematch, start the game
    if (updatedState.remoteWantsRematch) {
      _restartGame(updatedState, emit);
    }
  }

  /// Opponent requested rematch
  Future<void> _onOpponentRequestedRematch(OpponentRequestedRematchEvent event, Emitter<GameState> emit) async {
    if (state is! GameOverState) return;
    
    final currentState = state as GameOverState;
    
    // Update state to show opponent wants rematch
    final updatedState = currentState.copyWith(remoteWantsRematch: true);
    emit(updatedState);
    
    // If we also want rematch, start the game
    if (updatedState.localWantsRematch) {
      _restartGame(updatedState, emit);
    }
  }

  /// Restart game with swapped starting roles
  void _restartGame(GameOverState currentState, Emitter<GameState> emit) {
    const board = Board();
    _cleanupTurn();
    _gameTimer?.cancel();
    _phaseStartTime = DateTime.now();
    
    // Use default config for rematch
    final config = GameConfig.defaultConfig();
    
    // Swap who starts (if host started first game, guest starts second)
    final hostStarted = currentState.localPlayer.isHost;
    final localPlayerStarts = !hostStarted;
    
    if (localPlayerStarts) {
      emit(MarkingState(
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        board: board,
        config: config,
        moveHistory: [],
        remainingSeconds: config.isTimed ? config.initialSeconds : null,
      ));
      
      if (config.isTimed) {
        _startTimer(config.initialSeconds);
      }
    } else {
      emit(OpponentMarkingState(
        localPlayer: currentState.localPlayer,
        remotePlayer: currentState.remotePlayer,
        board: board,
        config: config,
        moveHistory: [],
        remainingSeconds: config.isTimed ? config.initialSeconds : null,
      ));
      
      if (config.isTimed) {
        _startTimer(config.initialSeconds);
      }
    }
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
