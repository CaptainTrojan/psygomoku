import '../entities/board.dart';
import '../entities/position.dart';
import '../entities/stone.dart';

/// Game rules engine for Gomoku/Psygomoku
/// Provides validation and win detection logic
class GameRulesEngine {
  static final GameRulesEngine _instance = GameRulesEngine._internal();
  factory GameRulesEngine() => _instance;
  GameRulesEngine._internal();

  /// Minimum stones in a row to win
  static const int winLength = 5;

  /// Board size (15x15)
  static const int boardSize = 15;

  /// Validates that a move is legal
  /// - Position must be in bounds (0-14)
  /// - Position must not be occupied
  bool isValidMove(Board board, Position position) {
    return position.isValid && board.isValidMove(position);
  }

  /// Checks if placing a stone at position would create a win for the color
  bool wouldCreateWin(Board board, Position position, StoneColor color) {
    // Create a temporary board with the stone placed
    try {
      final testStone = Stone(color: color, position: position);
      final testBoard = board.placeStone(testStone);
      return testBoard.getWinner() == color;
    } catch (e) {
      return false; // Invalid position
    }
  }

  /// Gets all winning sequences for a color
  /// Returns list of position lists, each representing a 5+ stone sequence
  List<List<Position>> getWinningSequences(Board board, StoneColor color) {
    return board.getWinningSequences(color);
  }

  /// Checks if the board is full (draw condition, assuming no winner)
  bool isBoardFull(Board board) {
    return board.isFull;
  }

  /// Gets all valid moves (empty positions) on the board
  List<Position> getValidMoves(Board board) {
    final validMoves = <Position>[];
    
    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize; y++) {
        final position = Position(x, y);
        if (board.isValidMove(position)) {
          validMoves.add(position);
        }
      }
    }
    
    return validMoves;
  }

  /// Gets neighboring positions (8 directions) that are within bounds
  List<Position> getNeighbors(Position position) {
    final neighbors = <Position>[];
    
    // 8 directions: N, NE, E, SE, S, SW, W, NW
    final directions = [
      (-1, -1), (0, -1), (1, -1),
      (-1,  0),          (1,  0),
      (-1,  1), (0,  1), (1,  1),
    ];
    
    for (final (dx, dy) in directions) {
      final newPos = Position(position.x + dx, position.y + dy);
      if (newPos.isValid) {
        neighbors.add(newPos);
      }
    }
    
    return neighbors;
  }

  /// Gets positions in a specific direction from start position
  /// Stops at board edge or when maxLength is reached
  List<Position> getLineInDirection({
    required Position start,
    required int dx,
    required int dy,
    int maxLength = winLength,
  }) {
    final positions = <Position>[];
    int x = start.x + dx;
    int y = start.y + dy;
    
    while (positions.length < maxLength) {
      final pos = Position(x, y);
      if (!pos.isValid) break;
      
      positions.add(pos);
      x += dx;
      y += dy;
    }
    
    return positions;
  }

  /// Counts consecutive stones of the same color in a direction
  /// Used for pattern recognition and threats
  int countConsecutiveStones({
    required Board board,
    required Position start,
    required StoneColor color,
    required int dx,
    required int dy,
  }) {
    int count = 0;
    int x = start.x + dx;
    int y = start.y + dy;
    
    while (true) {
      final pos = Position(x, y);
      if (!pos.isValid) break;
      
      final stone = board.getStone(pos);
      if (stone == null || stone.color != color) break;
      
      count++;
      x += dx;
      y += dy;
    }
    
    return count;
  }

  /// Detects if there's a threat (4-in-a-row) that must be blocked
  /// Returns the position where the threat can be completed, or null
  Position? detectThreat(Board board, StoneColor threateningColor) {
    // Check all stones of the threatening color
    for (final stone in board.getStonesOfColor(threateningColor)) {
      // Check all 4 directions (horizontal, vertical, 2 diagonals)
      final directions = [
        (1, 0),   // Horizontal
        (0, 1),   // Vertical
        (1, 1),   // Diagonal
        (1, -1),  // Anti-diagonal
      ];
      
      for (final (dx, dy) in directions) {
        // Count stones in both directions
        final forward = countConsecutiveStones(
          board: board,
          start: stone.position,
          color: threateningColor,
          dx: dx,
          dy: dy,
        );
        
        final backward = countConsecutiveStones(
          board: board,
          start: stone.position,
          color: threateningColor,
          dx: -dx,
          dy: -dy,
        );
        
        final total = forward + backward + 1; // +1 for the stone itself
        
        if (total >= 4) {
          // Check if there's an empty spot that would complete the line
          final forwardPos = Position(
            stone.position.x + dx * (forward + 1),
            stone.position.y + dy * (forward + 1),
          );
          
          if (forwardPos.isValid && board.isValidMove(forwardPos)) {
            return forwardPos;
          }
          
          final backwardPos = Position(
            stone.position.x - dx * (backward + 1),
            stone.position.y - dy * (backward + 1),
          );
          
          if (backwardPos.isValid && board.isValidMove(backwardPos)) {
            return backwardPos;
          }
        }
      }
    }
    
    return null;
  }

  /// Validates game state consistency
  /// Ensures no impossible situations (e.g., both colors winning)
  bool isValidGameState(Board board) {
    final cyanWins = board.getWinner() == StoneColor.cyan;
    final magentaWins = board.getWinner() == StoneColor.magenta;
    
    // Can't have both players winning
    if (cyanWins && magentaWins) return false;
    
    // Stone counts should be relatively balanced
    // (difference of at most 1 since players alternate)
    final cyanCount = board.getStonesOfColor(StoneColor.cyan).length;
    final magentaCount = board.getStonesOfColor(StoneColor.magenta).length;
    final difference = (cyanCount - magentaCount).abs();
    
    if (difference > 1) return false;
    
    return true;
  }
}
