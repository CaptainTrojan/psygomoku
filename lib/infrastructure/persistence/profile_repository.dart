import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/game_result.dart';
import 'player_adapter.dart';

/// Repository for managing local player profile with Hive
class ProfileRepository {
  static const String _profileBoxName = 'profile';
  static const String _profileKey = 'local_player';
  static const String _matchHistoryBoxName = 'match_history';
  
  late Box<Player> _profileBox;
  late Box<Map> _matchHistoryBox;
  bool _initialized = false;

  /// Initialize Hive boxes
  Future<void> initialize() async {
    if (_initialized) return;

    // Register adapter if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PlayerAdapter());
    }

    _profileBox = await Hive.openBox<Player>(_profileBoxName);
    _matchHistoryBox = await Hive.openBox<Map>(_matchHistoryBoxName);
    _initialized = true;

    // Create default profile if none exists
    if (!_profileBox.containsKey(_profileKey)) {
      await _createDefaultProfile();
    }
  }

  /// Get the local player profile
  Player? getLocalPlayer() {
    if (!_initialized) {
      throw StateError('ProfileRepository not initialized. Call initialize() first.');
    }
    return _profileBox.get(_profileKey);
  }

  /// Update local player profile
  Future<void> updateProfile({
    String? nickname,
    String? avatarColor,
  }) async {
    if (!_initialized) {
      throw StateError('ProfileRepository not initialized. Call initialize() first.');
    }

    final currentPlayer = getLocalPlayer();
    if (currentPlayer == null) {
      await _createDefaultProfile();
      return;
    }

    final updatedPlayer = currentPlayer.copyWith(
      nickname: nickname,
      avatarColor: avatarColor,
    );

    await _profileBox.put(_profileKey, updatedPlayer);
  }

  /// Update player stats after a game
  Future<void> updateStats(GameResult result) async {
    if (!_initialized) {
      throw StateError('ProfileRepository not initialized. Call initialize() first.');
    }

    final currentPlayer = getLocalPlayer();
    if (currentPlayer == null) return;

    Player updatedPlayer;

    if (result.isDraw) {
      updatedPlayer = currentPlayer.incrementDraws();
    } else if (result.winner?.id == currentPlayer.id) {
      updatedPlayer = currentPlayer.incrementWins();
    } else {
      updatedPlayer = currentPlayer.incrementLosses();
    }

    await _profileBox.put(_profileKey, updatedPlayer);

    // Add to match history (keep last 20 games)
    await _addMatchToHistory(result);
  }

  /// Get match history (last 20 games)
  List<Map<String, dynamic>> getMatchHistory() {
    if (!_initialized) {
      throw StateError('ProfileRepository not initialized. Call initialize() first.');
    }

    final history = <Map<String, dynamic>>[];
    for (var i = 0; i < _matchHistoryBox.length; i++) {
      final match = _matchHistoryBox.getAt(i);
      if (match != null) {
        history.add(Map<String, dynamic>.from(match));
      }
    }

    // Return in reverse order (most recent first)
    return history.reversed.toList();
  }

  /// Clear match history
  Future<void> clearMatchHistory() async {
    if (!_initialized) {
      throw StateError('ProfileRepository not initialized. Call initialize() first.');
    }
    await _matchHistoryBox.clear();
  }

  /// Reset profile to default
  Future<void> resetProfile() async {
    if (!_initialized) {
      throw StateError('ProfileRepository not initialized. Call initialize() first.');
    }
    await _profileBox.clear();
    await _matchHistoryBox.clear();
    await _createDefaultProfile();
  }

  /// Create default profile
  Future<void> _createDefaultProfile() async {
    final defaultPlayer = Player(
      id: const Uuid().v4(),
      nickname: 'Player${DateTime.now().millisecondsSinceEpoch % 10000}',
      avatarColor: '#6B5B95', // Default purple
      wins: 0,
      losses: 0,
      draws: 0,
      isHost: false,
    );

    await _profileBox.put(_profileKey, defaultPlayer);
  }

  /// Add match to history (keep only last 20)
  Future<void> _addMatchToHistory(GameResult result) async {
    final matchData = {
      'timestamp': DateTime.now().toIso8601String(),
      'result': result.reason.name,
      'opponentNickname': result.winner?.id == getLocalPlayer()?.id
          ? result.loser?.nickname ?? 'Unknown'
          : result.winner?.nickname ?? 'Unknown',
      'didWin': result.winner?.id == getLocalPlayer()?.id,
      'isDraw': result.isDraw,
    };

    await _matchHistoryBox.add(matchData);

    // Keep only last 20 matches
    while (_matchHistoryBox.length > 20) {
      await _matchHistoryBox.deleteAt(0);
    }
  }

  /// Close boxes
  Future<void> close() async {
    if (_initialized) {
      await _profileBox.close();
      await _matchHistoryBox.close();
      _initialized = false;
    }
  }
}
