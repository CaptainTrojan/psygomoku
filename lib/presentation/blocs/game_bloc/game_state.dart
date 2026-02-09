import 'package:equatable/equatable.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/board.dart';
import '../../../domain/entities/position.dart';
import '../../../domain/entities/move.dart';
import '../../../domain/entities/game_config.dart';
import '../../../domain/entities/game_result.dart';
import '../../../domain/entities/stone.dart';

/// Base class for all game states
abstract class GameState extends Equatable {
  const GameState();

  @override
  List<Object?> get props => [];
}

/// Game not yet started
class GameInitial extends GameState {
  const GameInitial();
}

/// Base class for active game states
abstract class GameActiveState extends GameState {
  final Player localPlayer;
  final Player remotePlayer;
  final Board board;
  final GameConfig config;
  final List<Move> moveHistory;
  final int? remainingSeconds;
  final Position? selectedPosition; // For two-step confirmation

  const GameActiveState({
    required this.localPlayer,
    required this.remotePlayer,
    required this.board,
    required this.config,
    required this.moveHistory,
    this.remainingSeconds,
    this.selectedPosition,
  });

  /// Get current turn number (1-indexed)
  int get turnNumber => moveHistory.length + 1;

  /// Check if timer is active
  bool get hasTimer => config.isTimed && remainingSeconds != null;

  /// Current player's color (if assigned)
  StoneColor? get currentPlayerColor => localPlayer.stoneColor;

  /// Check if it's local player's turn to act
  bool get isLocalPlayerTurn;

  @override
  List<Object?> get props => [
        localPlayer,
        remotePlayer,
        board,
        config,
        moveHistory,
        remainingSeconds,
        selectedPosition,
      ];
}

/// Local player is marking a position (hiding it with crypto)
class MarkingState extends GameActiveState {
  const MarkingState({
    required super.localPlayer,
    required super.remotePlayer,
    required super.board,
    required super.config,
    required super.moveHistory,
    super.remainingSeconds,
    super.selectedPosition,
  });

  @override
  bool get isLocalPlayerTurn => true;

  MarkingState copyWith({
    Player? localPlayer,
    Player? remotePlayer,
    Board? board,
    GameConfig? config,
    List<Move>? moveHistory,
    int? remainingSeconds,
    Position? selectedPosition,
  }) {
    return MarkingState(
      localPlayer: localPlayer ?? this.localPlayer,
      remotePlayer: remotePlayer ?? this.remotePlayer,
      board: board ?? this.board,
      config: config ?? this.config,
      moveHistory: moveHistory ?? this.moveHistory,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      selectedPosition: selectedPosition ?? this.selectedPosition,
    );
  }
}

/// Waiting for opponent to mark their position
class OpponentMarkingState extends GameActiveState {
  const OpponentMarkingState({
    required super.localPlayer,
    required super.remotePlayer,
    required super.board,
    required super.config,
    required super.moveHistory,
    super.remainingSeconds,
  });

  @override
  bool get isLocalPlayerTurn => false;

  OpponentMarkingState copyWith({
    Player? localPlayer,
    Player? remotePlayer,
    Board? board,
    GameConfig? config,
    List<Move>? moveHistory,
    int? remainingSeconds,
  }) {
    return OpponentMarkingState(
      localPlayer: localPlayer ?? this.localPlayer,
      remotePlayer: remotePlayer ?? this.remotePlayer,
      board: board ?? this.board,
      config: config ?? this.config,
      moveHistory: moveHistory ?? this.moveHistory,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }
}

/// Local player is guessing opponent's marked position
class GuessingState extends GameActiveState {
  final String opponentHash; // Opponent's commitment

  const GuessingState({
    required super.localPlayer,
    required super.remotePlayer,
    required super.board,
    required super.config,
    required super.moveHistory,
    required this.opponentHash,
    super.remainingSeconds,
    super.selectedPosition,
  });

  @override
  bool get isLocalPlayerTurn => true;

  @override
  List<Object?> get props => [...super.props, opponentHash];

  GuessingState copyWith({
    Player? localPlayer,
    Player? remotePlayer,
    Board? board,
    GameConfig? config,
    List<Move>? moveHistory,
    String? opponentHash,
    int? remainingSeconds,
    Position? selectedPosition,
  }) {
    return GuessingState(
      localPlayer: localPlayer ?? this.localPlayer,
      remotePlayer: remotePlayer ?? this.remotePlayer,
      board: board ?? this.board,
      config: config ?? this.config,
      moveHistory: moveHistory ?? this.moveHistory,
      opponentHash: opponentHash ?? this.opponentHash,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      selectedPosition: selectedPosition ?? this.selectedPosition,
    );
  }
}

/// Waiting for opponent to guess our marked position
class OpponentGuessingState extends GameActiveState {
  final String ourHash; // Our commitment
  final Position ourMarkedPosition; // Hidden from opponent
  final String ourSalt; // Our secret

  const OpponentGuessingState({
    required super.localPlayer,
    required super.remotePlayer,
    required super.board,
    required super.config,
    required super.moveHistory,
    required this.ourHash,
    required this.ourMarkedPosition,
    required this.ourSalt,
    super.remainingSeconds,
  });

  @override
  bool get isLocalPlayerTurn => false;

  @override
  List<Object?> get props => [...super.props, ourHash, ourMarkedPosition, ourSalt];

  OpponentGuessingState copyWith({
    Player? localPlayer,
    Player? remotePlayer,
    Board? board,
    GameConfig? config,
    List<Move>? moveHistory,
    String? ourHash,
    Position? ourMarkedPosition,
    String? ourSalt,
    int? remainingSeconds,
  }) {
    return OpponentGuessingState(
      localPlayer: localPlayer ?? this.localPlayer,
      remotePlayer: remotePlayer ?? this.remotePlayer,
      board: board ?? this.board,
      config: config ?? this.config,
      moveHistory: moveHistory ?? this.moveHistory,
      ourHash: ourHash ?? this.ourHash,
      ourMarkedPosition: ourMarkedPosition ?? this.ourMarkedPosition,
      ourSalt: ourSalt ?? this.ourSalt,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }
}

/// Waiting for opponent to reveal their marked position (guesser side)
class OpponentRevealingState extends GameActiveState {
  final Position ourGuess;
  final String opponentHash;

  const OpponentRevealingState({
    required super.localPlayer,
    required super.remotePlayer,
    required super.board,
    required super.config,
    required super.moveHistory,
    required this.ourGuess,
    required this.opponentHash,
    super.remainingSeconds,
  });

  @override
  bool get isLocalPlayerTurn => false;

  @override
  List<Object?> get props => [...super.props, ourGuess, opponentHash];

  OpponentRevealingState copyWith({
    Player? localPlayer,
    Player? remotePlayer,
    Board? board,
    GameConfig? config,
    List<Move>? moveHistory,
    Position? ourGuess,
    String? opponentHash,
    int? remainingSeconds,
  }) {
    return OpponentRevealingState(
      localPlayer: localPlayer ?? this.localPlayer,
      remotePlayer: remotePlayer ?? this.remotePlayer,
      board: board ?? this.board,
      config: config ?? this.config,
      moveHistory: moveHistory ?? this.moveHistory,
      ourGuess: ourGuess ?? this.ourGuess,
      opponentHash: opponentHash ?? this.opponentHash,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }
}

/// Revealing phase - marker reveals their position
class RevealingState extends GameActiveState {
  final Position ourMarkedPosition;
  final String ourSalt;
  final Position ourGuess;
  final Position? opponentRevealedPosition; // null until received
  final bool isVerifying;

  const RevealingState({
    required super.localPlayer,
    required super.remotePlayer,
    required super.board,
    required super.config,
    required super.moveHistory,
    required this.ourMarkedPosition,
    required this.ourSalt,
    required this.ourGuess,
    this.opponentRevealedPosition,
    this.isVerifying = false,
    super.remainingSeconds,
  });

  @override
  bool get isLocalPlayerTurn => false; // Automatic phase

  bool get hasOpponentRevealed => opponentRevealedPosition != null;

  @override
  List<Object?> get props => [
        ...super.props,
        ourMarkedPosition,
        ourSalt,
        ourGuess,
        opponentRevealedPosition,
        isVerifying,
      ];

  RevealingState copyWith({
    Player? localPlayer,
    Player? remotePlayer,
    Board? board,
    GameConfig? config,
    List<Move>? moveHistory,
    Position? ourMarkedPosition,
    String? ourSalt,
    Position? ourGuess,
    Position? opponentRevealedPosition,
    bool? isVerifying,
    int? remainingSeconds,
  }) {
    return RevealingState(
      localPlayer: localPlayer ?? this.localPlayer,
      remotePlayer: remotePlayer ?? this.remotePlayer,
      board: board ?? this.board,
      config: config ?? this.config,
      moveHistory: moveHistory ?? this.moveHistory,
      ourMarkedPosition: ourMarkedPosition ?? this.ourMarkedPosition,
      ourSalt: ourSalt ?? this.ourSalt,
      ourGuess: ourGuess ?? this.ourGuess,
      opponentRevealedPosition: opponentRevealedPosition ?? this.opponentRevealedPosition,
      isVerifying: isVerifying ?? this.isVerifying,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }
}

/// Game has ended
class GameOverState extends GameState {
  final GameResult result;
  final Player localPlayer;
  final Player remotePlayer;
  final Board finalBoard;
  final List<Move> moveHistory;
  final bool localWantsRematch;
  final bool remoteWantsRematch;

  const GameOverState({
    required this.result,
    required this.localPlayer,
    required this.remotePlayer,
    required this.finalBoard,
    required this.moveHistory,
    this.localWantsRematch = false,
    this.remoteWantsRematch = false,
  });

  /// Check if local player won
  bool get didLocalPlayerWin => result.winner?.id == localPlayer.id;

  /// Check if it was a draw
  bool get isDraw => result.isDraw;

  /// Copy with updated rematch requests
  GameOverState copyWith({
    bool? localWantsRematch,
    bool? remoteWantsRematch,
  }) {
    return GameOverState(
      result: result,
      localPlayer: localPlayer,
      remotePlayer: remotePlayer,
      finalBoard: finalBoard,
      moveHistory: moveHistory,
      localWantsRematch: localWantsRematch ?? this.localWantsRematch,
      remoteWantsRematch: remoteWantsRematch ?? this.remoteWantsRematch,
    );
  }

  @override
  List<Object?> get props => [result, localPlayer, remotePlayer, finalBoard, moveHistory, localWantsRematch, remoteWantsRematch];
}
