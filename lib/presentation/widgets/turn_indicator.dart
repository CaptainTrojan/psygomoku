import 'package:flutter/material.dart';
import '../blocs/game_bloc/game_state.dart';

/// Shows whose turn it is and the current game phase
class TurnIndicator extends StatelessWidget {
  final GameActiveState state;

  const TurnIndicator({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    String phaseText;
    Color phaseColor;
    IconData phaseIcon;

    // Determine whose turn it is and use their stone color
    if (state is MarkingState) {
      phaseText = 'Mark your position';
      phaseColor = state.localPlayer.stoneColor?.color ?? const Color(0xFF00E5FF);
      phaseIcon = Icons.add_circle_outline;
    } else if (state is OpponentMarkingState) {
      phaseText = 'Opponent is marking...';
      phaseColor = state.remotePlayer.stoneColor?.color ?? const Color(0xFFFF4081);
      phaseIcon = Icons.hourglass_empty;
    } else if (state is GuessingState) {
      phaseText = 'Guess opponent\'s position';
      phaseColor = state.localPlayer.stoneColor?.color ?? const Color(0xFF00E5FF);
      phaseIcon = Icons.search;
    } else if (state is OpponentGuessingState) {
      phaseText = 'Opponent is guessing...';
      phaseColor = state.remotePlayer.stoneColor?.color ?? const Color(0xFFFF4081);
      phaseIcon = Icons.hourglass_empty;
    } else if (state is OpponentRevealingState) {
      phaseText = 'Waiting for opponent...';
      phaseColor = state.remotePlayer.stoneColor?.color ?? const Color(0xFFFF4081);
      phaseIcon = Icons.hourglass_empty;
    } else if (state is RevealingState) {
      // This should never be shown (revealing is instant)
      phaseText = 'Processing...';
      phaseColor = state.localPlayer.stoneColor?.color ?? const Color(0xFF00E5FF);
      phaseIcon = Icons.sync;
    } else {
      phaseText = 'Unknown phase';
      phaseColor = Colors.grey;
      phaseIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: phaseColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: phaseColor.withOpacity(0.6),
          width: 2.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            phaseIcon,
            color: phaseColor,
            size: 26,
          ),
          const SizedBox(width: 12),
          Text(
            phaseText,
            style: TextStyle(
              color: phaseColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
