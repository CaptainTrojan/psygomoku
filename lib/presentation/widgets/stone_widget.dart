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
        color: fillColor, // Solid fill for stones
        boxShadow: [
          // Subtle inner shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            spreadRadius: -1,
          ),
          // Minimal outer glow
          BoxShadow(
            color: fillColor.withOpacity(0.4),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
        border: hasBorder && borderColor != null
            ? Border.all(
                color: borderColor,
                width: 3,
              )
            : Border.all(
                color: fillColor.withOpacity(0.3),
                width: 1,
              ),
      ),
    );
  }
}
