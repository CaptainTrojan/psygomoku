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

    if (state is MarkingState) {
      phaseText = 'Mark your position';
      phaseColor = const Color(0xFF00E5FF); // Cyan
      phaseIcon = Icons.add_circle_outline;
    } else if (state is OpponentMarkingState) {
      phaseText = 'Opponent is marking...';
      phaseColor = const Color(0xFFFF4081); // Magenta
      phaseIcon = Icons.hourglass_empty;
    } else if (state is GuessingState) {
      phaseText = 'Guess opponent\'s position';
      phaseColor = Colors.amber;
      phaseIcon = Icons.search;
    } else if (state is OpponentGuessingState) {
      phaseText = 'Opponent is guessing...';
      phaseColor = Colors.purple;
      phaseIcon = Icons.hourglass_empty;
    } else if (state is RevealingState) {
      phaseText = 'Revealing...';
      phaseColor = Colors.green;
      phaseIcon = Icons.visibility;
    } else {
      phaseText = 'Unknown phase';
      phaseColor = Colors.grey;
      phaseIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: phaseColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: phaseColor.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            phaseIcon,
            color: phaseColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            phaseText,
            style: TextStyle(
              color: phaseColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
