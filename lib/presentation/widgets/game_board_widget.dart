import 'package:flutter/material.dart';
import '../../domain/entities/board.dart';
import '../../domain/entities/position.dart';
import 'stone_widget.dart';
import 'selection_indicator_widget.dart';

/// The 15×15 game board with interactive grid
class GameBoardWidget extends StatelessWidget {
  final Board board;
  final void Function(Position)? onPositionTapped;
  final Position? selectedPosition;
  final VoidCallback? onConfirmSelection;
  final Position? guessMarkerPosition; // Position where guess marker should be shown
  final Color? guessMarkerColor; // Color of the guess marker
  final Position? highlightPosition; // Recently placed stone to highlight

  const GameBoardWidget({
    super.key,
    required this.board,
    this.onPositionTapped,
    this.selectedPosition,
    this.onConfirmSelection,
    this.guessMarkerPosition,
    this.guessMarkerColor,
    this.highlightPosition,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 1.0,
      maxScale: 3.0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1E3E), // Dark board background
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 15,
              childAspectRatio: 1.0,
              crossAxisSpacing: 0,
              mainAxisSpacing: 0,
            ),
            itemCount: 225, // 15 × 15
            itemBuilder: (context, index) {
              final x = index % 15;
              final y = index ~/ 15;
              final position = Position(x, y);
              final stone = board.stones[position];

              return GestureDetector(
                onTap: onPositionTapped != null
                    ? () {
                        if (selectedPosition == position) {
                          // Second tap on same position - confirm
                          onConfirmSelection?.call();
                        } else {
                          // First tap - select
                          onPositionTapped!(position);
                        }
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Grid intersection point
                      Center(
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),

                      // Selection indicator
                      if (selectedPosition == position && stone == null)
                        const SelectionIndicatorWidget(),

                      // Stone (if placed)
                      if (stone != null)
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: StoneWidget(stone: stone),
                        ),
                      
                      // Highlight ring for newly placed stone
                      if (highlightPosition == position && stone != null)
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 2,
                            ),
                          ),
                        ),
                      
                      // Guess marker (cross/X) - shows even over stones
                      if (guessMarkerPosition == position)
                        Center(
                          child: Icon(
                            Icons.close,
                            size: 32,
                            color: (guessMarkerColor ?? Colors.white).withOpacity(0.9),
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.8),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),

                      // Hover effect (for desktop)
                      if (onPositionTapped != null && stone == null)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
