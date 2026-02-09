import 'package:equatable/equatable.dart';

/// Represents a position on the 15x15 game board.
/// Coordinates are 0-indexed (0-14 for both x and y).
class Position extends Equatable {
  final int x;
  final int y;

  const Position(this.x, this.y);

  /// Validates that position is within board bounds (0-14)
  bool get isValid => x >= 0 && x < 15 && y >= 0 && y < 15;

  /// Creates a copy with optional parameter overrides
  Position copyWith({int? x, int? y}) {
    return Position(x ?? this.x, y ?? this.y);
  }

  /// Converts position to string for hashing (e.g., "7,8")
  String toHashString() => '$x,$y';

  /// Parses position from hash string (e.g., "7,8" -> Position(7, 8))
  static Position? fromHashString(String str) {
    final parts = str.split(',');
    if (parts.length != 2) return null;
    final x = int.tryParse(parts[0]);
    final y = int.tryParse(parts[1]);
    if (x == null || y == null) return null;
    return Position(x, y);
  }

  /// Converts to JSON-serializable map
  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  /// Creates position from JSON map
  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(json['x'] as int, json['y'] as int);
  }

  @override
  List<Object?> get props => [x, y];

  @override
  String toString() => 'Position($x, $y)';
}
