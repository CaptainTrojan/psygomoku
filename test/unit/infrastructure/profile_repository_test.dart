import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:psygomoku/domain/entities/board.dart';
import 'package:psygomoku/domain/entities/game_result.dart';
import 'package:psygomoku/domain/entities/player.dart';
import 'package:psygomoku/domain/entities/stone.dart';
import 'package:psygomoku/infrastructure/persistence/profile_repository.dart';

void main() {
  group('ProfileRepository', () {
    late Directory tempDir;
    late ProfileRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('psygomoku_test_');
      Hive.init(tempDir.path);
      repository = ProfileRepository();
      await repository.initialize();
    });

    tearDown(() async {
      await repository.close();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('creates default profile on init', () {
      final player = repository.getLocalPlayer();
      expect(player, isNotNull);
      expect(player!.nickname, isNotEmpty);
    });

    test('updates profile fields', () async {
      await repository.updateProfile(nickname: 'NewName', avatarColor: '#123456');
      final updated = repository.getLocalPlayer();

      expect(updated!.nickname, 'NewName');
      expect(updated.avatarColor, '#123456');
    });

    test('updates stats and writes match history', () async {
        final player = repository.getLocalPlayer()!.copyWith(stoneColor: StoneColor.cyan);
        final opponent = Player.create(nickname: 'Opponent', avatarColor: '#999999')
          .copyWith(stoneColor: StoneColor.magenta);

      final result = GameResult.win(
        winner: player,
        loser: opponent,
        finalBoard: const Board(),
        winningColor: StoneColor.cyan,
      );

      await repository.updateStats(result);

      final updated = repository.getLocalPlayer()!;
      expect(updated.wins, player.wins + 1);

      final history = repository.getMatchHistory();
      expect(history, isNotEmpty);
    });
  });
}
