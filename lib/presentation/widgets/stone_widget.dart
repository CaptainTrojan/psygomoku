import 'package:flutter/material.dart';
import '../../domain/entities/stone.dart';

/// Renders a neon-glowing stone with optional stolen border
class StoneWidget extends StatelessWidget {
  final Stone stone;

  const StoneWidget({super.key, required this.stone});

  @override
  Widget build(BuildContext context) {
    final fillColor = stone.color.color;
    final hasBorder = stone.isStolen;
    final borderColor = stone.borderColor?.color;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            fillColor.withOpacity(0.9),
            fillColor.withOpacity(0.7),
            fillColor.withOpacity(0.4),
          ],
          stops: const [0.3, 0.7, 1.0],
        ),
        boxShadow: [
          // Inner glow
          BoxShadow(
            color: fillColor.withOpacity(0.8),
            blurRadius: 8,
            spreadRadius: 1,
          ),
          // Outer glow
          BoxShadow(
            color: fillColor.withOpacity(0.5),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          // Intense center glow
          BoxShadow(
            color: fillColor.withOpacity(0.9),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
        border: hasBorder && borderColor != null
            ? Border.all(
                color: borderColor,
                width: 3,
              )
            : null,
      ),
      child: hasBorder
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  // Border glow for stolen pieces
                  BoxShadow(
                    color: borderColor!.withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
