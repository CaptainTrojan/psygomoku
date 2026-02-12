import 'package:flutter/material.dart';
import '../../domain/entities/board.dart';
import '../../domain/entities/position.dart';
import '../../domain/entities/stone.dart';
import 'stone_widget.dart';
import 'selection_indicator_widget.dart';

/// The 15×15 game board with interactive grid
class GameBoardWidget extends StatelessWidget {
  final Board board;
  final void Function(Position)? onPositionTapped;
  final Position? selectedPosition;
  final VoidCallback? onConfirmSelection;
  final Position?
      guessMarkerPosition; // Position where guess marker should be shown
  final Color? guessMarkerColor; // Color of the guess marker
  final Position?
      previewMarkedPosition; // Position of own mark preview (gray, smaller)
  final Position? lastPlayedPosition; // Last stone position for border
  final StoneColor? localPlayerColor;
  final StoneColor? remotePlayerColor;

  const GameBoardWidget({
    super.key,
    required this.board,
    this.onPositionTapped,
    this.selectedPosition,
    this.onConfirmSelection,
    this.guessMarkerPosition,
    this.guessMarkerColor,
    this.previewMarkedPosition,
    this.lastPlayedPosition,
    this.localPlayerColor,
    this.remotePlayerColor,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cellSize = constraints.maxWidth;
                    return Container(
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

                          // Preview mark (gray, smaller stone for marker's own mark)
                          if (previewMarkedPosition == position &&
                              stone == null)
                            Padding(
                              padding: EdgeInsets.all(cellSize *
                                  0.25), // 25% padding = smaller circle
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.withOpacity(0.3),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),

                          // Stone (if placed)
                          if (stone != null)
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: StoneWidget(
                                stone: stone,
                                isLastPlayed: lastPlayedPosition == position,
                                localPlayerColor: localPlayerColor,
                                remotePlayerColor: remotePlayerColor,
                              ),
                            ),

                          // Guess marker (cross/X) - shows even over stones
                          if (guessMarkerPosition == position)
                            Center(
                              child: Icon(
                                Icons.close,
                                size: cellSize * 0.7, // 70% of cell size
                                color: (guessMarkerColor ?? Colors.white)
                                    .withOpacity(0.9),
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
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
