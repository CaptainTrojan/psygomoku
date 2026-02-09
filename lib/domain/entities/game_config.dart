import 'package:equatable/equatable.dart';

/// Time control presets for the game
enum TimeControl {
  bullet,   // 1 minute per player
  blitz,    // 3 minutes per player
  rapid,    // 5 minutes per player
  casual;   // Unlimited time

  /// Gets the initial time in seconds for this control
  int get initialSeconds {
    switch (this) {
      case TimeControl.bullet:
        return 60;
      case TimeControl.blitz:
        return 180;
      case TimeControl.rapid:
        return 300;
      case TimeControl.casual:
        return 0; // 0 means unlimited
    }
  }

  /// Gets display name for UI
  String get displayName {
    switch (this) {
      case TimeControl.bullet:
        return 'Bullet (1 min)';
      case TimeControl.blitz:
        return 'Blitz (3 min)';
      case TimeControl.rapid:
        return 'Rapid (5 min)';
      case TimeControl.casual:
        return 'Casual (∞)';
    }
  }

  /// Whether this time control has a time limit
  bool get isTimed => this != TimeControl.casual;

  /// Converts enum to JSON string
  String toJson() => name;

  /// Creates enum from JSON string
  static TimeControl fromJson(String json) {
    return TimeControl.values.firstWhere((e) => e.name == json);
  }
}

/// Configuration for a game session
class GameConfig extends Equatable {
  /// Time control for the game
  final TimeControl timeControl;

  /// Board size (default 15x15)
  final int boardSize;

  /// Custom initial time in seconds (overrides timeControl if set)
  /// Use for custom time controls
  final int? customInitialSeconds;

  const GameConfig({
    this.timeControl = TimeControl.casual,
    this.boardSize = 15,
    this.customInitialSeconds,
  });

  /// Creates config with default settings
  factory GameConfig.defaultConfig() => const GameConfig();

  /// Creates config for quick game (1 minute)
  factory GameConfig.bullet() => const GameConfig(timeControl: TimeControl.bullet);

  /// Creates config for standard game (3 minutes)
  factory GameConfig.blitz() => const GameConfig(timeControl: TimeControl.blitz);

  /// Creates config for longer game (5 minutes)
  factory GameConfig.rapid() => const GameConfig(timeControl: TimeControl.rapid);

  /// Creates config with unlimited time
  factory GameConfig.casual() => const GameConfig(timeControl: TimeControl.casual);

  /// Gets the actual initial time in seconds
  int get initialSeconds => customInitialSeconds ?? timeControl.initialSeconds;

  /// Whether this game has a time limit
  bool get isTimed => timeControl.isTimed || (customInitialSeconds != null && customInitialSeconds! > 0);

  /// Creates a copy with optional parameter overrides
  GameConfig copyWith({
    TimeControl? timeControl,
    int? boardSize,
    int? customInitialSeconds,
  }) {
    return GameConfig(
      timeControl: timeControl ?? this.timeControl,
      boardSize: boardSize ?? this.boardSize,
      customInitialSeconds: customInitialSeconds ?? this.customInitialSeconds,
    );
  }

  /// Converts to JSON-serializable map
  Map<String, dynamic> toJson() => {
        'timeControl': timeControl.toJson(),
        'boardSize': boardSize,
        'customInitialSeconds': customInitialSeconds,
      };

  /// Creates config from JSON map
  factory GameConfig.fromJson(Map<String, dynamic> json) {
    return GameConfig(
      timeControl: TimeControl.fromJson(json['timeControl'] as String),
      boardSize: json['boardSize'] as int? ?? 15,
      customInitialSeconds: json['customInitialSeconds'] as int?,
    );
  }

  @override
  List<Object?> get props => [timeControl, boardSize, customInitialSeconds];

  @override
  String toString() => 'GameConfig(${timeControl.displayName}, ${boardSize}x$boardSize)';
}
