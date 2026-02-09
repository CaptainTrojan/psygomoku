import 'package:equatable/equatable.dart';
import 'board.dart';
import 'player.dart';
import 'position.dart';
import 'stone.dart';

/// Reason for game ending
enum GameEndReason {
  win,              // 5-in-a-row achieved
  timeout,          // Player ran out of time
  forfeit,          // Player manually forfeited
  cheatDetected,    // Hash verification failed or timer cheat
  disconnect,       // Connection lost
  draw;             // Board full, no winner

  /// Display text for UI
  String get displayText {
    switch (this) {
      case GameEndReason.win:
        return 'Win by 5-in-a-row';
      case GameEndReason.timeout:
        return 'Win by timeout';
      case GameEndReason.forfeit:
        return 'Win by forfeit';
      case GameEndReason.cheatDetected:
        return 'Win by opponent cheating';
      case GameEndReason.disconnect:
        return 'Win by disconnect';
      case GameEndReason.draw:
        return 'Draw - Board full';
    }
  }

  /// Converts enum to JSON string
  String toJson() => name;

  /// Creates enum from JSON string
  static GameEndReason fromJson(String json) {
    return GameEndReason.values.firstWhere((e) => e.name == json);
  }
}

/// Represents the outcome of a game
class GameResult extends Equatable {
  /// The winning player (null for draw)
  final Player? winner;

  /// The losing player (null for draw)
  final Player? loser;

  /// Reason the game ended
  final GameEndReason reason;

  /// Final board state
  final Board finalBoard;

  /// The stone color that won (null for draw)
  final StoneColor? winningColor;

  /// Winning sequences (for visual highlighting)
  final List<List<Position>> winningSequences;

  /// Timestamp when game ended
  final DateTime timestamp;

  GameResult({
    required this.reason,
    required this.finalBoard,
    this.winner,
    this.loser,
    this.winningColor,
    this.winningSequences = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a win result
  factory GameResult.win({
    required Player winner,
    required Player loser,
    required Board finalBoard,
    required StoneColor winningColor,
    List<List<Position>>? winningSequences,
  }) {
    return GameResult(
      winner: winner,
      loser: loser,
      reason: GameEndReason.win,
      finalBoard: finalBoard,
      winningColor: winningColor,
      winningSequences: winningSequences ?? finalBoard.getWinningSequences(winningColor),
    );
  }

  /// Creates a timeout result
  factory GameResult.timeout({
    required Player winner,
    required Player loser,
    required Board finalBoard,
  }) {
    return GameResult(
      winner: winner,
      loser: loser,
      reason: GameEndReason.timeout,
      finalBoard: finalBoard,
    );
  }

  /// Creates a forfeit result
  factory GameResult.forfeit({
    required Player winner,
    required Player loser,
    required Board finalBoard,
  }) {
    return GameResult(
      winner: winner,
      loser: loser,
      reason: GameEndReason.forfeit,
      finalBoard: finalBoard,
    );
  }

  /// Creates a cheat detection result
  factory GameResult.cheatDetected({
    required Player winner,
    required Player cheater,
    required Board finalBoard,
  }) {
    return GameResult(
      winner: winner,
      loser: cheater,
      reason: GameEndReason.cheatDetected,
      finalBoard: finalBoard,
    );
  }

  /// Creates a disconnect result
  factory GameResult.disconnect({
    required Player winner,
    required Player disconnector,
    required Board finalBoard,
  }) {
    return GameResult(
      winner: winner,
      loser: disconnector,
      reason: GameEndReason.disconnect,
      finalBoard: finalBoard,
    );
  }

  /// Creates a draw result
  factory GameResult.draw({
    required Board finalBoard,
    required Player player1,
    required Player player2,
  }) {
    return GameResult(
      reason: GameEndReason.draw,
      finalBoard: finalBoard,
    );
  }

  /// Whether this result is a draw
  bool get isDraw => reason == GameEndReason.draw;

  /// Whether this result is from cheating
  bool get isCheating => reason == GameEndReason.cheatDetected;

  /// Whether this result is from disconnection
  bool get isDisconnect => reason == GameEndReason.disconnect;

  /// Gets result text from perspective of a player
  String getResultText(Player player) {
    if (isDraw) return 'Draw';
    if (winner?.id == player.id) return 'You Won!';
    return 'You Lost';
  }

  /// Gets detailed result description
  String get detailedDescription {
    if (isDraw) {
      return 'Game ended in a draw - board is full';
    }
    
    final winnerName = winner?.nickname ?? 'Winner';
    
    switch (reason) {
      case GameEndReason.win:
        return '$winnerName achieved 5-in-a-row';
      case GameEndReason.timeout:
        return '$winnerName won - opponent ran out of time';
      case GameEndReason.forfeit:
        return '$winnerName won - opponent forfeited';
      case GameEndReason.cheatDetected:
        return '$winnerName won - opponent caught cheating';
      case GameEndReason.disconnect:
        return '$winnerName won - opponent disconnected';
      case GameEndReason.draw:
        return 'Draw - Board full';
    }
  }

  /// Converts to JSON-serializable map
  Map<String, dynamic> toJson() => {
        'winner': winner?.toJson(),
        'loser': loser?.toJson(),
        'reason': reason.toJson(),
        'finalBoard': finalBoard.toJson(),
        'winningColor': winningColor?.toJson(),
        'winningSequences': winningSequences
            .map((seq) => seq.map((pos) => pos.toJson()).toList())
            .toList(),
        'timestamp': timestamp.toIso8601String(),
      };

  /// Creates result from JSON map
  factory GameResult.fromJson(Map<String, dynamic> json) {
    return GameResult(
      winner: json['winner'] != null
          ? Player.fromJson(json['winner'] as Map<String, dynamic>)
          : null,
      loser: json['loser'] != null
          ? Player.fromJson(json['loser'] as Map<String, dynamic>)
          : null,
      reason: GameEndReason.fromJson(json['reason'] as String),
      finalBoard: Board.fromJson(json['finalBoard'] as Map<String, dynamic>),
      winningColor: json['winningColor'] != null
          ? StoneColor.fromJson(json['winningColor'] as String)
          : null,
      winningSequences: (json['winningSequences'] as List<dynamic>?)
              ?.map((seq) => (seq as List<dynamic>)
                  .map((pos) => Position.fromJson(pos as Map<String, dynamic>))
                  .toList())
              .toList() ??
          const [],
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  List<Object?> get props => [
        winner,
        loser,
        reason,
        finalBoard,
        winningColor,
        winningSequences,
        timestamp,
      ];

  @override
  String toString() {
    if (isDraw) return 'GameResult(Draw)';
    return 'GameResult(${winner?.nickname} won by ${reason.displayText})';
  }
}
