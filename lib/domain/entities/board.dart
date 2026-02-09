import 'package:equatable/equatable.dart';
import 'position.dart';
import 'stone.dart';

/// Represents the 15x15 Gomoku game board
class Board extends Equatable {
  static const int size = 15;
  
  /// Stones currently on the board
  /// Map from Position to Stone for O(1) lookup
  final Map<Position, Stone> stones;

  const Board({this.stones = const {}});

  /// Creates an empty board
  factory Board.empty() => const Board();

  /// Gets the stone at a specific position, or null if empty
  Stone? getStone(Position position) => stones[position];

  /// Checks if a position is occupied
  bool isOccupied(Position position) => stones.containsKey(position);

  /// Checks if a position is valid and empty
  bool isValidMove(Position position) {
    return position.isValid && !isOccupied(position);
  }

  /// Places a stone at the specified position
  /// Returns a new Board (immutable)
  Board placeStone(Stone stone) {
    if (!isValidMove(stone.position)) {
      throw ArgumentError('Position ${stone.position} is invalid or occupied');
    }
    
    final newStones = Map<Position, Stone>.from(stones);
    newStones[stone.position] = stone;
    return Board(stones: newStones);
  }

  /// Places a regular stone (not stolen)
  Board placeRegularStone({
    required Position position,
    required StoneColor color,
  }) {
    return placeStone(Stone(
      color: color,
      position: position,
    ));
  }

  /// Places a stolen stone (correct guess)
  Board placeStolenStone({
    required Position position,
    required StoneColor winnerColor,
    required StoneColor loserColor,
  }) {
    return placeStone(Stone.stolen(
      winnerColor: winnerColor,
      loserColor: loserColor,
      position: position,
    ));
  }

  /// Checks if placing a stone at position would create a win
  bool wouldWin(Position position, StoneColor color) {
    // Temporarily place the stone
    final testBoard = placeStone(Stone(color: color, position: position));
    return testBoard.getWinner() == color;
  }

  /// Gets the winner if any, returns null if no winner yet
  StoneColor? getWinner() {
    // Check all directions for each stone
    for (final entry in stones.entries) {
      final position = entry.key;
      final stone = entry.value;
      final color = stone.color;

      // Check horizontal (→)
      if (_checkLine(position, 1, 0, color)) return color;
      
      // Check vertical (↓)
      if (_checkLine(position, 0, 1, color)) return color;
      
      // Check diagonal (↘)
      if (_checkLine(position, 1, 1, color)) return color;
      
      // Check anti-diagonal (↗)
      if (_checkLine(position, 1, -1, color)) return color;
    }
    
    return null;
  }

  /// Checks if there'sa line of 5 or more stones of the same color
  /// starting from position in the direction (dx, dy)
  bool _checkLine(Position start, int dx, int dy, StoneColor color) {
    int count = 1; // Count the starting stone
    
    // Check forward direction
    count += _countInDirection(start, dx, dy, color);
    
    // Check backward direction
    count += _countInDirection(start, -dx, -dy, color);
    
    return count >= 5;
  }

  /// Counts consecutive stones of the same color in a direction
  int _countInDirection(Position start, int dx, int dy, StoneColor color) {
    int count = 0;
    int x = start.x + dx;
    int y = start.y + dy;
    
    while (x >= 0 && x < size && y >= 0 && y < size) {
      final pos = Position(x, y);
      final stone = getStone(pos);
      
      if (stone == null || stone.color != color) break;
      
      count++;
      x += dx;
      y += dy;
    }
    
    return count;
  }

  /// Gets all winning sequences (for visual highlighting)
  List<List<Position>> getWinningSequences(StoneColor color) {
    final sequences = <List<Position>>[];
    
    for (final entry in stones.entries) {
      final position = entry.key;
      final stone = entry.value;
      
      if (stone.color != color) continue;
      
      // Check each direction
      final directions = [
        (1, 0),   // Horizontal
        (0, 1),   // Vertical
        (1, 1),   // Diagonal
        (1, -1),  // Anti-diagonal
      ];
      
      for (final (dx, dy) in directions) {
        final sequence = _getLineSequence(position, dx, dy, color);
        if (sequence.length >= 5) {
          sequences.add(sequence);
        }
      }
    }
    
    return sequences;
  }

  /// Gets all positions in a line of the same color
  List<Position> _getLineSequence(Position start, int dx, int dy, StoneColor color) {
    final sequence = <Position>[start];
    
    // Forward direction
    sequence.addAll(_getPositionsInDirection(start, dx, dy, color));
    
    // Backward direction
    sequence.addAll(_getPositionsInDirection(start, -dx, -dy, color));
    
    return sequence;
  }

  /// Gets positions in a specific direction
  List<Position> _getPositionsInDirection(Position start, int dx, int dy, StoneColor color) {
    final positions = <Position>[];
    int x = start.x + dx;
    int y = start.y + dy;
    
    while (x >= 0 && x < size && y >= 0 && y < size) {
      final pos = Position(x, y);
      final stone = getStone(pos);
      
      if (stone == null || stone.color != color) break;
      
      positions.add(pos);
      x += dx;
      y += dy;
    }
    
    return positions;
  }

  /// Checks if the board is full (draw condition)
  bool get isFull => stones.length == size * size;

  /// Gets total number of stones on the board
  int get stoneCount => stones.length;

  /// Gets stones of a specific color
  List<Stone> getStonesOfColor(StoneColor color) {
    return stones.values.where((stone) => stone.color == color).toList();
  }

  /// Converts to JSON-serializable map
  Map<String, dynamic> toJson() => {
        'stones': stones.entries
            .map((e) => {
                  ...e.value.toJson(),
                })
            .toList(),
      };

  /// Creates board from JSON map
  factory Board.fromJson(Map<String, dynamic> json) {
    final stonesList = json['stones'] as List<dynamic>;
    final stonesMap = <Position, Stone>{};
    
    for (final stoneJson in stonesList) {
      final stone = Stone.fromJson(stoneJson as Map<String, dynamic>);
      stonesMap[stone.position] = stone;
    }
    
    return Board(stones: stonesMap);
  }

  @override
  List<Object?> get props => [stones];

  @override
  String toString() => 'Board(${stones.length} stones)';
}
