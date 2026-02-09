import 'package:equatable/equatable.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/position.dart';
import '../../../domain/entities/game_config.dart';

/// Events that can occur during a game
abstract class GameEvent extends Equatable {
  const GameEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize a new game
class StartGameEvent extends GameEvent {
  final Player localPlayer;
  final Player remotePlayer;
  final GameConfig config;

  const StartGameEvent({
    required this.localPlayer,
    required this.remotePlayer,
    required this.config,
  });

  @override
  List<Object?> get props => [localPlayer, remotePlayer, config];
}

/// Update remote player profile during a session
class UpdateRemotePlayerEvent extends GameEvent {
  final Player remotePlayer;

  const UpdateRemotePlayerEvent(this.remotePlayer);

  @override
  List<Object?> get props => [remotePlayer];
}

/// User taps a position (first tap in two-step confirmation)
class SelectPositionEvent extends GameEvent {
  final Position position;

  const SelectPositionEvent(this.position);

  @override
  List<Object?> get props => [position];
}

/// User confirms their marked position (second tap)
class ConfirmMarkEvent extends GameEvent {
  const ConfirmMarkEvent();
}

/// Cancel the current selection
class CancelSelectionEvent extends GameEvent {
  const CancelSelectionEvent();
}

/// User confirms their guess (second tap)
class ConfirmGuessEvent extends GameEvent {
  const ConfirmGuessEvent();
}

/// Received opponent's mark (hash only, position hidden)
class OpponentMarkedEvent extends GameEvent {
  final String hash;
  final DateTime timestamp;

  const OpponentMarkedEvent({
    required this.hash,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [hash, timestamp];
}

/// Received opponent's guess
class OpponentGuessedEvent extends GameEvent {
  final Position guessedPosition;
  final DateTime timestamp;

  const OpponentGuessedEvent({
    required this.guessedPosition,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [guessedPosition, timestamp];
}

/// It's time to reveal our marked position
class RevealMoveEvent extends GameEvent {
  const RevealMoveEvent();
}

/// Received opponent's reveal (position + salt)
class OpponentRevealedEvent extends GameEvent {
  final Position revealedPosition;
  final String salt;
  final DateTime timestamp;

  const OpponentRevealedEvent({
    required this.revealedPosition,
    required this.salt,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [revealedPosition, salt, timestamp];
}

/// Timer tick (countdown)
class TimerTickEvent extends GameEvent {
  final int remainingSeconds;

  const TimerTickEvent(this.remainingSeconds);

  @override
  List<Object?> get props => [remainingSeconds];
}

/// Player forfeits the game
class ForfeitEvent extends GameEvent {
  const ForfeitEvent();
}

/// Opponent forfeited the game
class OpponentForfeitedEvent extends GameEvent {
  final DateTime timestamp;

  const OpponentForfeitedEvent({required this.timestamp});

  @override
  List<Object?> get props => [timestamp];
}

/// Connection to opponent lost
class DisconnectEvent extends GameEvent {
  final String reason;

  const DisconnectEvent([this.reason = 'Connection lost']);

  @override
  List<Object?> get props => [reason];
}

/// Opponent disconnected
class OpponentDisconnectedEvent extends GameEvent {
  const OpponentDisconnectedEvent();
}

/// Cheat detected (hash mismatch or timer violation)
class CheatDetectedEvent extends GameEvent {
  final String reason;

  const CheatDetectedEvent(this.reason);

  @override
  List<Object?> get props => [reason];
}

/// Move to guessing phase after opponent has marked
class InitiateGuessPhaseEvent extends GameEvent {
  const InitiateGuessPhaseEvent();
}

/// Start next turn after current turn is complete
class StartNextTurnEvent extends GameEvent {
  const StartNextTurnEvent();
}
