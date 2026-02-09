import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'position.dart';

/// Represents the two player colors in the game
enum StoneColor {
  cyan,    // Player 1 / Host (#00E5FF)
  magenta; // Player 2 / Guest (#FF4081)

  /// Returns the Flutter Color for this stone color
  Color get color {
    switch (this) {
      case StoneColor.cyan:
        return const Color(0xFF00E5FF);
      case StoneColor.magenta:
        return const Color(0xFFFF4081);
    }
  }

  /// Returns the opposite color
  StoneColor get opposite {
    return this == StoneColor.cyan ? StoneColor.magenta : StoneColor.cyan;
  }

  /// Converts enum to JSON string
  String toJson() => name;

  /// Creates enum from JSON string
  static StoneColor fromJson(String json) {
    return StoneColor.values.firstWhere((e) => e.name == json);
  }
}

/// Represents a stone placed on the board
class Stone extends Equatable {
  /// The color of this stone
  final StoneColor color;

  /// Optional border color (used for "stolen" pieces)
  /// When a guesser correctly predicts the mark, the stone appears
  /// in the guesser's color but with the marker's color as border
  final StoneColor? borderColor;

  /// Position where this stone is placed
  final Position position;

  /// Timestamp when the stone was placed
  final DateTime timestamp;

  Stone({
    required this.color,
    required this.position,
    this.borderColor,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a "stolen" stone (correct guess)
  /// Stone is in winner's color with loser's border
  factory Stone.stolen({
    required StoneColor winnerColor,
    required StoneColor loserColor,
    required Position position,
  }) {
    return Stone(
      color: winnerColor,
      borderColor: loserColor,
      position: position,
    );
  }

  /// Creates a copy with optional parameter overrides
  Stone copyWith({
    StoneColor? color,
    StoneColor? borderColor,
    Position? position,
    DateTime? timestamp,
  }) {
    return Stone(
      color: color ?? this.color,
      borderColor: borderColor ?? this.borderColor,
      position: position ?? this.position,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Whether this is a "stolen" piece (has border)
  bool get isStolen => borderColor != null;

  /// Converts to JSON-serializable map
  Map<String, dynamic> toJson() => {
        'color': color.toJson(),
        'borderColor': borderColor?.toJson(),
        'position': position.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };

  /// Creates stone from JSON map
  factory Stone.fromJson(Map<String, dynamic> json) {
    return Stone(
      color: StoneColor.fromJson(json['color'] as String),
      borderColor: json['borderColor'] != null
          ? StoneColor.fromJson(json['borderColor'] as String)
          : null,
      position: Position.fromJson(json['position'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  List<Object?> get props => [color, borderColor, position, timestamp];

  @override
  String toString() => 'Stone($color at $position${isStolen ? ' [stolen]' : ''})';
}
