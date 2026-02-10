import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/game_bloc/game_bloc.dart';
import '../blocs/game_bloc/game_state.dart';
import '../blocs/game_bloc/game_event.dart';
import '../blocs/chat_bloc/chat_bloc.dart';
import '../blocs/chat_bloc/chat_state.dart';
import '../blocs/connection_bloc/connection_bloc.dart';
import '../blocs/connection_bloc/connection_event.dart' as connection_events;
import '../../domain/entities/game_result.dart';
import '../../domain/entities/position.dart';
import '../widgets/game_board_widget.dart';
import '../widgets/player_info_bar.dart';
import '../widgets/timer_widget.dart';
import '../widgets/turn_indicator.dart';
import '../widgets/draggable_chat_panel.dart';
import '../widgets/game_footer_bar.dart';

/// Main game screen showing board, player info, and timer
class GameBoardScreen extends StatefulWidget {
  const GameBoardScreen({super.key});

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  bool _isChatOpen = false;
  int _unreadCount = 0;
  int _lastSeenMessageCount = 0;
  bool _isDialogShowing = false;

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
      if (_isChatOpen) {
        _unreadCount = 0;
        _lastSeenMessageCount = 0; // Reset when opening
      }
    });
  }

  /// Leave the game and return to main menu, notifying opponent
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27), // Dark blue background
      body: SafeArea(
        child: Stack(
          children: [
            // Chat message listener (separate from builder to avoid setState during build)
            BlocListener<ChatBloc, ChatState>(
              listener: (context, chatState) {
                final currentCount = chatState.messages.length;
                if (!_isChatOpen && currentCount > _lastSeenMessageCount) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _unreadCount = currentCount - _lastSeenMessageCount;
                      });
                    }
                  });
                }
                if (_isChatOpen) {
                  _lastSeenMessageCount = currentCount;
                }
              },
              child: BlocConsumer<GameBloc, GameState>(
                listener: (context, state) {
                  // Close dialog when game restarts (rematch accepted)
                  if (_isDialogShowing && state is! GameOverState) {
                    _isDialogShowing = false;
                    Navigator.of(context).pop(); // Close the dialog
                  }

                  // Show game over dialog only for non-disconnect endings
                  if (state is GameOverState && !_isDialogShowing) {
                    // For disconnects, just navigate back silently (snackbar already shown)
                    if (state.result.reason == GameEndReason.disconnect) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      });
                    } else {
                      // Show dialog for normal game endings (win, draw, forfeit, cheat)
                      _showGameOverDialog(context, state);
                    }
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
                  final localPlayer =
                      state is GameActiveState
                          ? state.localPlayer
                          : (state as GameOverState).localPlayer;
                  final remotePlayer =
                      state is GameActiveState
                          ? state.remotePlayer
                          : (state as GameOverState).remotePlayer;
                  final board =
                      state is GameActiveState
                          ? state.board
                          : (state as GameOverState).finalBoard;
                  final moveHistory =
                      state is GameActiveState
                          ? state.moveHistory
                          : (state as GameOverState).moveHistory;

                  // ============================================================
                  // SIMPLIFIED INDICATOR LOGIC
                  // Only show indicators in MarkingState or OpponentMarkingState
                  // ============================================================
                  final bool isInMarkingPhase =
                      state is MarkingState || state is OpponentMarkingState;
                  final lastMove =
                      moveHistory.isNotEmpty ? moveHistory.last : null;

                  // Last move indicators (border + cross) - ONLY in marking phase
                  Position? lastMarkPosition;
                  Position? lastGuessPosition;
                  Color? guessMarkerColor;

                  if (isInMarkingPhase &&
                      lastMove != null &&
                      lastMove.guess != null) {
                    lastMarkPosition = lastMove.markedPosition;
                    lastGuessPosition = lastMove.guess;

                    // Guesser color is the opposite of marker color
                    guessMarkerColor =
                        lastMove.markerColor == localPlayer.stoneColor
                            ? remotePlayer.stoneColor?.color
                            : localPlayer.stoneColor?.color;
                  }

                  // Cross only shows if guess missed (different position than mark)
                  final bool guessMissed =
                      lastGuessPosition != null &&
                      lastMarkPosition != null &&
                      lastGuessPosition != lastMarkPosition;

                  // Preview position - when we marked but opponent hasn't guessed yet
                  Position? previewMarkedPosition;
                  if (state is OpponentGuessingState) {
                    previewMarkedPosition = state.ourMarkedPosition;
                  }

                  return Column(
                    children: [
                      // Main game area
                      Expanded(
                        child: Column(
                          children: [
                            // Top padding
                            const SizedBox(height: 8),

                            // Opponent info bar
                            PlayerInfoBar(
                              player: remotePlayer,
                              isOpponent: true,
                            ),

                            // STATIC opponent status indicator area (always 60px)
                            Container(
                              height: 60,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child:
                                  state is GameActiveState &&
                                          !state.isLocalPlayerTurn &&
                                          state is! OpponentRevealingState &&
                                          state is! RevealingState
                                      ? TurnIndicator(state: state)
                                      : const SizedBox.shrink(),
                            ),

                            // Timer (if active)
                            if (state is GameActiveState && state.hasTimer)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TimerWidget(
                                  remainingSeconds: state.remainingSeconds!,
                                  isLocalPlayerTurn: state.isLocalPlayerTurn,
                                ),
                              ),

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
                                        onPositionTapped:
                                            state is GameActiveState &&
                                                    state.isLocalPlayerTurn
                                                ? (position) {
                                                  context.read<GameBloc>().add(
                                                    SelectPositionEvent(
                                                      position,
                                                    ),
                                                  );
                                                }
                                                : null,
                                        selectedPosition:
                                            state is GameActiveState
                                                ? state.selectedPosition
                                                : null,
                                        guessMarkerPosition:
                                            guessMissed
                                                ? lastGuessPosition
                                                : null,
                                        guessMarkerColor:
                                            guessMissed
                                                ? guessMarkerColor
                                                : null,
                                        previewMarkedPosition:
                                            previewMarkedPosition,
                                        lastPlayedPosition:
                                            isInMarkingPhase
                                                ? lastMarkPosition
                                                : null,
                                        localPlayerColor:
                                            localPlayer.stoneColor,
                                        remotePlayerColor:
                                            remotePlayer.stoneColor,
                                        onConfirmSelection:
                                            state is GameActiveState
                                                ? () {
                                                  if (state is MarkingState) {
                                                    context.read<GameBloc>().add(
                                                      const ConfirmMarkEvent(),
                                                    );
                                                  } else if (state
                                                      is GuessingState) {
                                                    context.read<GameBloc>().add(
                                                      const ConfirmGuessEvent(),
                                                    );
                                                  }
                                                }
                                                : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // STATIC local status indicator area (always 60px)
                            Container(
                              height: 60,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child:
                                  state is GameActiveState &&
                                          state.isLocalPlayerTurn &&
                                          state is! OpponentRevealingState &&
                                          state is! RevealingState
                                      ? TurnIndicator(state: state)
                                      : const SizedBox.shrink(),
                            ),

                            // Local player info bar
                            PlayerInfoBar(
                              player: localPlayer,
                              isOpponent: false,
                            ),

                            // Bottom padding
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),

                      // Footer bar with buttons
                      GameFooterBar(
                        onChatPressed: _toggleChat,
                        onForfeitPressed: () => _showForfeitDialog(context),
                        unreadChatCount: _unreadCount,
                      ),
                    ],
                  );
                },
              ),
            ),

            // Draggable chat panel overlay
            DraggableChatPanel(isOpen: _isChatOpen, onToggle: _toggleChat),
          ],
        ),
      ),
    );
  }

  void _showForfeitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
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

  void _showGameOverDialog(BuildContext parentContext, GameOverState state) {
    final gameBloc = parentContext.read<GameBloc>();
    final connectionBloc = parentContext.read<ConnectionBloc>();
    _isDialogShowing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog(
        context: parentContext,
        barrierDismissible: false,
        builder:
            (dialogContext) => BlocProvider.value(
              value: gameBloc,
              child: BlocBuilder<GameBloc, GameState>(
                builder: (context, currentState) {
                  // If not in game over state, show loading (dialog will close via parent listener)
                  if (currentState is! GameOverState) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final isDisconnect =
                      currentState.result.reason == GameEndReason.disconnect;

                  return AlertDialog(
                    backgroundColor: const Color(0xFF1A1E3E),
                    title: Text(
                      currentState.didLocalPlayerWin
                          ? '🎉 Victory!'
                          : currentState.isDraw
                          ? '🤝 Draw'
                          : '💔 Defeat',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentState.result.getResultText(
                            currentState.localPlayer,
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          currentState.result.getDetailedDescription(
                            currentState.localPlayer,
                          ),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    actions:
                        isDisconnect
                            ? [
                              // Disconnect only shows Okay button
                              // No need to send disconnect - opponent already left
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton(
                                  onPressed: () {
                                    _isDialogShowing = false;
                                    // Clean up connection and go to main menu
                                    connectionBloc.add(
                                      const connection_events.DisconnectEvent(),
                                    );
                                    Navigator.of(dialogContext).popUntil(
                                      (route) => route.isFirst,
                                    );
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF00E5FF),
                                    foregroundColor: Colors.black,
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  child: const Text('Okay'),
                                ),
                              ),
                            ]
                            : [
                              // Large stacked buttons like lichess
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Play Again / Waiting / Accept button
                                  SizedBox(
                                    height: 48,
                                    child: _buildRematchButton(
                                      context,
                                      currentState,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Back to Lobby button
                                  SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        _isDialogShowing = false;
                                        // Notify opponent and go to main menu
                                        final transport = connectionBloc.transport;
                                        transport?.send({
                                          'type': 'disconnect',
                                          'timestamp': DateTime.now().toIso8601String(),
                                        });
                                        connectionBloc.add(
                                          const connection_events.DisconnectEvent(),
                                        );
                                        Navigator.of(dialogContext).popUntil(
                                          (route) => route.isFirst,
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Colors.white54,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      child: const Text('Back to Lobby'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                  );
                },
              ),
            ),
      );
    });
  }

  Widget _buildRematchButton(
    BuildContext context,
    GameOverState state,
  ) {
    // Both want rematch - game will restart automatically
    if (state.localWantsRematch && state.remoteWantsRematch) {
      return FilledButton(
        onPressed: null, // Disabled while transitioning
        style: FilledButton.styleFrom(
          backgroundColor: Colors.grey.shade700,
          foregroundColor: Colors.white54,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: const Text('Starting game...'),
      );
    }

    // We want rematch, waiting for opponent
    if (state.localWantsRematch) {
      return FilledButton(
        onPressed: null, // Disabled
        style: FilledButton.styleFrom(
          backgroundColor: Colors.grey.shade700,
          foregroundColor: Colors.white54,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
            ),
            SizedBox(width: 12),
            Text('Waiting for opponent...'),
          ],
        ),
      );
    }

    // Opponent wants rematch, asking us to accept
    if (state.remoteWantsRematch) {
      return FilledButton(
        onPressed: () {
          context.read<GameBloc>().add(const RequestRematchEvent());
        },
        style: FilledButton.styleFrom(
          backgroundColor: const Color(
            0xFF4CAF50,
          ), // Green to indicate acceptance
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: const Text('✓ Opponent wants rematch - Accept?'),
      );
    }

    // Normal state - neither has clicked yet
    return FilledButton(
      onPressed: () {
        context.read<GameBloc>().add(const RequestRematchEvent());
      },
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      child: const Text('Play Again'),
    );
  }
}
