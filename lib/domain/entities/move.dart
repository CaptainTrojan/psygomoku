import 'package:equatable/equatable.dart';
import 'position.dart';
import 'stone.dart';

/// Represents a cryptographic move in the game (Mark -> Guess -> Reveal cycle)
class Move extends Equatable {
  /// The player's color who made this mark
  final StoneColor markerColor;

  /// The position that was secretly marked
  final Position markedPosition;

  /// SHA-256 hash commitment sent to opponent
  /// Hash = SHA256(x + y + salt)
  final String hash;

  /// Random salt for hash verification (revealed after guess)
  final String salt;

  /// The opponent's guess position
  final Position? guess;

  /// Whether the guess was correct
  final bool? wasGuessCorrect;

  /// Whether the move has been revealed to opponent
  final bool isRevealed;

  /// Timestamp when mark was made
  final DateTime timestamp;

  Move({
    required this.markerColor,
    required this.markedPosition,
    required this.hash,
    required this.salt,
    this.guess,
    this.wasGuessCorrect,
    this.isRevealed = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a new move (marking phase)
  factory Move.create({
    required StoneColor markerColor,
    required Position markedPosition,
    required String hash,
    required String salt,
  }) {
    return Move(
      markerColor: markerColor,
      markedPosition: markedPosition,
      hash: hash,
      salt: salt,
    );
  }

  /// Adds guess to the move (guessing phase)
  Move withGuess(Position guessPosition) {
    final correct = guessPosition == markedPosition;
    return Move(
      markerColor: markerColor,
      markedPosition: markedPosition,
      hash: hash,
      salt: salt,
      guess: guessPosition,
      wasGuessCorrect: correct,
      isRevealed: isRevealed,
      timestamp: timestamp,
    );
  }

  /// Marks move as revealed (reveal phase complete)
  Move revealed() {
    return Move(
      markerColor: markerColor,
      markedPosition: markedPosition,
      hash: hash,
      salt: salt,
      guess: guess,
      wasGuessCorrect: wasGuessCorrect,
      isRevealed: true,
      timestamp: timestamp,
    );
  }

  /// Creates a copy with optional parameter overrides
  Move copyWith({
    StoneColor? markerColor,
    Position? markedPosition,
    String? hash,
    String? salt,
    Position? guess,
    bool? wasGuessCorrect,
    bool? isRevealed,
    DateTime? timestamp,
  }) {
    return Move(
      markerColor: markerColor ?? this.markerColor,
      markedPosition: markedPosition ?? this.markedPosition,
      hash: hash ?? this.hash,
      salt: salt ?? this.salt,
      guess: guess ?? this.guess,
      wasGuessCorrect: wasGuessCorrect ?? this.wasGuessCorrect,
      isRevealed: isRevealed ?? this.isRevealed,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Whether this move is complete (has been guessed and revealed)
  bool get isComplete => guess != null && isRevealed;

  /// Whether the opponent successfully stole the turn
  bool get wasTurnStolen => wasGuessCorrect ?? false;

  /// Converts to JSON-serializable map
  Map<String, dynamic> toJson() => {
        'markerColor': markerColor.toJson(),
        'markedPosition': markedPosition.toJson(),
        'hash': hash,
        'salt': salt,
        'guess': guess?.toJson(),
        'wasGuessCorrect': wasGuessCorrect,
        'isRevealed': isRevealed,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Creates move from JSON map
  factory Move.fromJson(Map<String, dynamic> json) {
    return Move(
      markerColor: StoneColor.fromJson(json['markerColor'] as String),
      markedPosition: Position.fromJson(json['markedPosition'] as Map<String, dynamic>),
      hash: json['hash'] as String,
      salt: json['salt'] as String,
      guess: json['guess'] != null
          ? Position.fromJson(json['guess'] as Map<String, dynamic>)
          : null,
      wasGuessCorrect: json['wasGuessCorrect'] as bool?,
      isRevealed: json['isRevealed'] as bool? ?? false,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  List<Object?> get props => [
        markerColor,
        markedPosition,
        hash,
        salt,
        guess,
        wasGuessCorrect,
        isRevealed,
        timestamp,
      ];

  @override
  String toString() {
    if (!isComplete) {
      return 'Move(marking at $markedPosition, waiting for guess)';
    }
    return 'Move(marked: $markedPosition, guessed: $guess, ${wasTurnStolen ? 'STOLEN' : 'defended'})';
  }
}
