import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'stone.dart';

/// Represents a player in the game
class Player extends Equatable {
  /// Unique identifier for this player
  final String id;

  /// Display name (max 20 characters)
  final String nickname;

  /// Avatar color as hex string (e.g., "#FF4081")
  final String avatarColor;

  /// Total wins
  final int wins;

  /// Total losses
  final int losses;

  /// Total draws
  final int draws;

  /// Whether this player is the host (true) or guest (false)
  final bool isHost;

  /// The stone color for this player in the current game
  final StoneColor? stoneColor;

  const Player({
    required this.id,
    required this.nickname,
    required this.avatarColor,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.isHost = false,
    this.stoneColor,
  });

  /// Creates a new player with default values
  factory Player.create({
    required String nickname,
    required String avatarColor,
    bool isHost = false,
  }) {
    return Player(
      id: const Uuid().v4(),
      nickname: nickname,
      avatarColor: avatarColor,
      isHost: isHost,
    );
  }

  /// Creates a copy with optional parameter overrides
  Player copyWith({
    String? id,
    String? nickname,
    String? avatarColor,
    int? wins,
    int? losses,
    int? draws,
    bool? isHost,
    StoneColor? stoneColor,
  }) {
    return Player(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      avatarColor: avatarColor ?? this.avatarColor,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      isHost: isHost ?? this.isHost,
      stoneColor: stoneColor ?? this.stoneColor,
    );
  }

  /// Increments win count
  Player incrementWins() => copyWith(wins: wins + 1);

  /// Increments loss count
  Player incrementLosses() => copyWith(losses: losses + 1);

  /// Increments draw count
  Player incrementDraws() => copyWith(draws: draws + 1);

  /// Calculates win rate as percentage (0-100)
  double get winRate {
    final totalGames = wins + losses + draws;
    if (totalGames == 0) return 0.0;
    return (wins / totalGames) * 100;
  }

  /// Gets total number of games played
  int get totalGames => wins + losses + draws;

  /// Gets the first letter of nickname for avatar display
  String get initial {
    if (nickname.isEmpty) return '?';
    return nickname[0].toUpperCase();
  }

  /// Validates nickname (1-20 characters, no special chars)
  static String? validateNickname(String? nickname) {
    if (nickname == null || nickname.isEmpty) {
      return 'Nickname cannot be empty';
    }
    if (nickname.length > 20) {
      return 'Nickname must be 20 characters or less';
    }
    // Allow letters, numbers, spaces, underscores, hyphens
    final validPattern = RegExp(r'^[a-zA-Z0-9 _-]+$');
    if (!validPattern.hasMatch(nickname)) {
      return 'Nickname contains invalid characters';
    }
    return null;
  }

  /// Converts to JSON-serializable map
  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'avatarColor': avatarColor,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'isHost': isHost,
        'stoneColor': stoneColor?.toJson(),
      };

  /// Creates player from JSON map
  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      avatarColor: json['avatarColor'] as String,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      isHost: json['isHost'] as bool? ?? false,
      stoneColor: json['stoneColor'] != null
          ? StoneColor.fromJson(json['stoneColor'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, nickname, avatarColor, wins, losses, draws, isHost, stoneColor];

  @override
  String toString() => 'Player($nickname, W:$wins L:$losses D:$draws)';
}
