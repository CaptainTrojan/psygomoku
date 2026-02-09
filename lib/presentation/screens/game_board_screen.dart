import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/game_bloc/game_bloc.dart';
import '../blocs/game_bloc/game_state.dart';
import '../blocs/game_bloc/game_event.dart';
import '../widgets/game_board_widget.dart';
import '../widgets/player_info_bar.dart';
import '../widgets/timer_widget.dart';
import '../widgets/turn_indicator.dart';
import '../widgets/chat_widget.dart';

/// Main game screen showing board, player info, and timer
class GameBoardScreen extends StatelessWidget {
  const GameBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27), // Dark blue background
      body: SafeArea(
        child: BlocConsumer<GameBloc, GameState>(
          listener: (context, state) {
            // Show game over dialog
            if (state is GameOverState) {
              _showGameOverDialog(context, state);
            }
          },
          builder: (context, state) {
            if (state is GameInitial) {
              return const Center(
                child: Text(
                  'Initializing game...',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }

            if (state is! GameActiveState && state is! GameOverState) {
              return const Center(
                child: Text(
                  'Invalid game state',
                  style: TextStyle(color: Colors.red, fontSize: 18),
                ),
              );
            }

            // Determine players for display
            final localPlayer = state is GameActiveState
                ? state.localPlayer
                : (state as GameOverState).localPlayer;
            final remotePlayer = state is GameActiveState
                ? state.remotePlayer
                : (state as GameOverState).remotePlayer;
            final board = state is GameActiveState
                ? state.board
                : (state as GameOverState).finalBoard;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;

                final boardColumn = Column(
                  children: [
                    // Top padding
                    const SizedBox(height: 8),

                    // Opponent info bar (top)
                    PlayerInfoBar(
                      player: remotePlayer,
                      isOpponent: true,
                    ),

                    const SizedBox(height: 16),

                    // Timer and turn indicator
                    if (state is GameActiveState && state.hasTimer)
                      TimerWidget(
                        remainingSeconds: state.remainingSeconds!,
                        isLocalPlayerTurn: state.isLocalPlayerTurn,
                      ),

                    if (state is GameActiveState)
                      TurnIndicator(
                        state: state,
                      ),

                    const SizedBox(height: 16),

                    // Game board (centered and sized appropriately)
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 600,
                              maxHeight: 600,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: GameBoardWidget(
                                board: board,
                                onPositionTapped: state is GameActiveState &&
                                        state.isLocalPlayerTurn
                                    ? (position) {
                                        context
                                            .read<GameBloc>()
                                            .add(SelectPositionEvent(position));
                                      }
                                    : null,
                                selectedPosition: state is GameActiveState
                                    ? state.selectedPosition
                                    : null,
                                onConfirmSelection: state is GameActiveState
                                    ? () {
                                        if (state is MarkingState) {
                                          context
                                              .read<GameBloc>()
                                              .add(const ConfirmMarkEvent());
                                        } else if (state is GuessingState) {
                                          context
                                              .read<GameBloc>()
                                              .add(const ConfirmGuessEvent());
                                        }
                                      }
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Local player info bar (bottom)
                    PlayerInfoBar(
                      player: localPlayer,
                      isOpponent: false,
                    ),

                    // Bottom padding
                    const SizedBox(height: 8),

                    // Forfeit button
                    if (state is GameActiveState)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => _showForfeitDialog(context),
                          icon: const Icon(Icons.flag, color: Colors.redAccent),
                          label: const Text(
                            'Forfeit',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                        ),
                      ),
                  ],
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: boardColumn),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 320,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, right: 12, bottom: 12),
                          child: ChatWidget(compact: true),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Expanded(child: boardColumn),
                    SizedBox(
                      height: 220,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: ChatWidget(compact: true),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showForfeitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E3E),
        title: const Text(
          'Forfeit Game?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to forfeit? This will count as a loss.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<GameBloc>().add(const ForfeitEvent());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Forfeit'),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog(BuildContext context, GameOverState state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1A1E3E),
          title: Text(
            state.didLocalPlayerWin
                ? '🎉 Victory!'
                : state.isDraw
                    ? '🤝 Draw'
                    : '💔 Defeat',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.result.getResultText(state.localPlayer),
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                state.result.detailedDescription,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop(); // Return to lobby/home
              },
              child: const Text('Back to Lobby'),
            ),
          ],
        ),
      );
    });
  }
}
