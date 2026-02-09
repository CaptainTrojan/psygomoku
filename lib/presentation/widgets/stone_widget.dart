import 'package:flutter/material.dart';
import '../../domain/entities/stone.dart';

/// Renders a 3D marble-like stone with optional colored border on last played stone
class StoneWidget extends StatelessWidget {
  final Stone stone;
  final bool isLastPlayed;
  final StoneColor? localPlayerColor;
  final StoneColor? remotePlayerColor;

  const StoneWidget({
    super.key,
    required this.stone,
    this.isLastPlayed = false,
    this.localPlayerColor,
    this.remotePlayerColor,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = stone.color.color;
    
    // Determine border: only show on last played stone
    // If stolen, use opponent's color; otherwise use subtle highlight
    Color? borderColor;
    double borderWidth = 0;
    
    if (isLastPlayed) {
      if (stone.isStolen && stone.borderColor != null) {
        // Stolen stone - use the border color (opponent's color)
        borderColor = stone.borderColor!.color;
        borderWidth = 3;
      } else {
        // Regular last stone - subtle white border
        borderColor = Colors.white.withOpacity(0.6);
        borderWidth = 2;
      }
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // 3D gradient effect - light at top-left, dark at bottom-right
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3), // Light source from top-left
          radius: 0.8,
          colors: [
            fillColor.withOpacity(1.0), // Bright center
            fillColor.withOpacity(0.95), // Slightly dimmer
            fillColor.withOpacity(0.7),  // Darker edges
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        boxShadow: [
          // Shine/reflection effect at top
          BoxShadow(
            color: Colors.white.withOpacity(0.4),
            blurRadius: 6,
            spreadRadius: -4,
            offset: const Offset(-2, -2),
          ),
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
        border: borderWidth > 0 && borderColor != null
            ? Border.all(
                color: borderColor,
                width: borderWidth,
              )
            : null,
      ),
      // Add a subtle shine overlay
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.3), // Shine at top
              Colors.transparent,
              Colors.black.withOpacity(0.2), // Shadow at bottom
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}