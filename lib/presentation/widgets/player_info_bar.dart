import 'package:flutter/material.dart';
import '../../domain/entities/player.dart';

/// Displays player information (avatar, nickname, stats)
class PlayerInfoBar extends StatelessWidget {
  final Player player;
  final bool isOpponent;

  const PlayerInfoBar({
    super.key,
    required this.player,
    required this.isOpponent,
  });

  @override
  Widget build(BuildContext context) {
    final stoneColor = player.stoneColor;
    final avatarColorValue = int.tryParse(player.avatarColor.replaceFirst('#', ''), radix: 16);
    final avatarColor = avatarColorValue != null
        ? Color(0xFF000000 + avatarColorValue)
        : Colors.grey;

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E3E),
        borderRadius: BorderRadius.circular(12),
        border: stoneColor != null
            ? Border.all(
                color: stoneColor.color.withOpacity(0.5),
                width: 2,
              )
            : null,
        boxShadow: stoneColor != null
            ? [
                BoxShadow(
                  color: stoneColor.color.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
              border: stoneColor != null
                  ? Border.all(
                      color: stoneColor.color,
                      width: 1.5,
                    )
                  : null,
            ),
            child: Center(
              child: Text(
                player.initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.nickname,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (player.isHost) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.amber, width: 1),
                        ),
                        child: const Text(
                          'HOST',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${player.wins}W ${player.losses}L ${player.draws}D • ${player.winRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Stone color indicator
          if (stoneColor != null)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    stoneColor.color.withOpacity(0.9),
                    stoneColor.color.withOpacity(0.5),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: stoneColor.color.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
