import 'package:flutter/material.dart';

/// Displays countdown timer for timed games
class TimerWidget extends StatelessWidget {
  final int remainingSeconds;
  final bool isLocalPlayerTurn;

  const TimerWidget({
    super.key,
    required this.remainingSeconds,
    required this.isLocalPlayerTurn,
  });

  @override
  Widget build(BuildContext context) {
    final isLowTime = remainingSeconds < 10;
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isLowTime
            ? Colors.red.withOpacity(0.2)
            : const Color(0xFF1A1E3E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLowTime ? Colors.red : Colors.white.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: isLowTime
            ? [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            color: isLowTime ? Colors.red : Colors.white,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            timeText,
            style: TextStyle(
              color: isLowTime ? Colors.red : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
