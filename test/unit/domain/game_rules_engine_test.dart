import 'package:flutter_test/flutter_test.dart';
import 'package:psygomoku/domain/entities/board.dart';
import 'package:psygomoku/domain/entities/position.dart';
import 'package:psygomoku/domain/entities/stone.dart';
import 'package:psygomoku/domain/services/game_rules_engine.dart';

void main() {
  group('GameRulesEngine', () {
    test('detects horizontal win', () {
      final engine = GameRulesEngine();
      var board = const Board();

      for (var x = 0; x < 5; x++) {
        board = board.placeRegularStone(
          position: Position(x, 7),
          color: StoneColor.cyan,
        );
      }

      final winner = board.getWinner();
      expect(winner, StoneColor.cyan);
      expect(engine.getWinningSequences(board, StoneColor.cyan).length, greaterThan(0));
    });

    test('rejects occupied move', () {
      final engine = GameRulesEngine();
      final board = const Board().placeRegularStone(
        position: const Position(2, 2),
        color: StoneColor.magenta,
      );

      expect(engine.isValidMove(board, const Position(2, 2)), isFalse);
      expect(engine.isValidMove(board, const Position(3, 2)), isTrue);
    });
  });
}
