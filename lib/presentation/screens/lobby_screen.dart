import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../infrastructure/persistence/profile_repository.dart';
import '../blocs/connection_bloc/connection_bloc.dart';
import '../blocs/connection_bloc/connection_event.dart' as bloc_event;
import '../blocs/connection_bloc/connection_state.dart' as bloc_state;
import '../widgets/app_button.dart';
import 'game_session_screen.dart';
import 'connection_mode_screen.dart';

/// Lobby screen for hosting or joining a game
class LobbyScreen extends StatefulWidget {
  final ProfileRepository profileRepository;

  const LobbyScreen({super.key, required this.profileRepository});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _joinCodeController = TextEditingController();
  final _manualOfferController = TextEditingController();
  final _manualAnswerController = TextEditingController();
  bool _isJoinView = false;

  @override
  void dispose() {
    _joinCodeController.dispose();
    _manualOfferController.dispose();
    _manualAnswerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online P2P'),
      ),
      body: TechBackground(
        child: BlocConsumer<ConnectionBloc, bloc_state.ConnectionState>(
        listenWhen: (previous, current) {
          // Only trigger listener when we transition TO ConnectedState
          return previous is! bloc_state.ConnectedState && 
                 current is bloc_state.ConnectedState;
        },
        listener: (context, state) {
          if (state is bloc_state.ConnectedState) {
            // Connection established, navigate to game session screen
            final connectionBloc = context.read<ConnectionBloc>();
            final transport = connectionBloc.transport;
            
            if (transport != null) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider.value(value: connectionBloc),
                    ],
                    child: GameSessionScreen(
                      transport: transport,
                      isHost: connectionBloc.isHost,
                      profileRepository: widget.profileRepository,
                    ),
                  ),
                ),
              );
            }
          } else if (state is bloc_state.ConnectionErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.error}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is bloc_state.HostingState) {
            if (state.mode == bloc_state.SignalingMode.auto) {
              return _buildHostAutoView(context, state.sessionCode!);
            } else {
              return _buildLoadingView('Generating offer...');
            }
          } else if (state is bloc_state.ManualWaitingForAnswerState) {
            return _buildHostManualView(context, state.offerString);
          } else if (state is bloc_state.JoiningState) {
            return _buildLoadingView('Connecting...');
          } else if (state is bloc_state.ManualAnswerReadyState) {
            return _buildJoinManualAnswerView(context, state.answerString);
          } else if (state is bloc_state.ConnectedState) {
            return _buildLoadingView('Connected!');
          } else if (state is bloc_state.ConnectionErrorState) {
            return _buildErrorView(context, state.error);
          } else {
            return _buildModeSelectionView(context);
          }
        },
        ),
      ),
    );
  }

  Widget _buildModeSelectionView(BuildContext context) {
    if (_isJoinView) {
      return _buildJoinModeSelection(context);
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          Text(
            'PSYGOMOKU',
            style: GoogleFonts.orbitron(
              fontSize: responsiveTextSize(context, 46),
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Psychic Gomoku',
            style: GoogleFonts.orbitron(
              fontSize: responsiveTextSize(context, 14),
              letterSpacing: 2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 80),
          
          // Host button
          AppButton.primary(
            text: 'HOST GAME',
            icon: Icons.add_circle_outline,
            onPressed: () => _onHostPressed(context),
            width: 280,
          ),
          const SizedBox(height: 24),
          
          // Join button
          AppButton.secondary(
            text: 'JOIN GAME',
            icon: Icons.login,
            onPressed: () {
              setState(() {
                _isJoinView = true;
              });
            },
            width: 280,
          ),
          
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHostAutoView(BuildContext context, String sessionCode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'YOUR SESSION CODE',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          
          // Session code display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.backgroundMedium,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Text(
              sessionCode,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 64,
                fontWeight: FontWeight.bold,
                letterSpacing: 16,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Copy button
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: sessionCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Code copied!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            icon: Icon(Icons.copy, color: AppColors.primary),
            label: Text(
              'COPY CODE',
              style: TextStyle(color: AppColors.primary, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 48),
          
          // Waiting indicator
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Waiting for opponent to join...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 48),
          
          // Cancel button
          TextButton(
            onPressed: () {
              context.read<ConnectionBloc>().add(const bloc_event.ResetConnectionEvent());
            },
            child: Text(
              'CANCEL',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostManualView(BuildContext context, String offerString) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'STEP 1: SHARE YOUR OFFER',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              letterSpacing: 2,
            ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Offer field
              Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundMedium,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: SelectableText(
              offerString,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontFamily: 'Courier',
              ),
                maxLines: 6,
              ),
              ),
              const SizedBox(height: 12),
              
              AppButton.primary(
            text: 'COPY OFFER',
            icon: Icons.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: offerString));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Offer copied!'),
                  backgroundColor: AppColors.primary,
                  ),
                );
              },
              ),
              const SizedBox(height: 40),
              
              const Text(
                'STEP 2: PASTE OPPONENT\'S ANSWER',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              letterSpacing: 2,
            ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _manualAnswerController,
                decoration: InputDecoration(
                  hintText: 'Paste answer string here...',
                  filled: true,
                  fillColor: AppColors.backgroundMedium,
                ),
                style: TextStyle(color: AppColors.textPrimary, fontSize: 10),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              
              AppButton.primary(
                text: 'CONNECT',
                icon: Icons.link,
                onPressed: () {
                  final answer = _manualAnswerController.text.trim();
                  if (answer.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please paste the answer'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }
                  context.read<ConnectionBloc>().add(
                    bloc_event.ManualHostReceiveAnswerEvent(answer),
                  );
                },
              ),
              const SizedBox(height: 24),
              
              TextButton(
                onPressed: () {
                  context.read<ConnectionBloc>().add(const bloc_event.ResetConnectionEvent());
                },
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinManualAnswerView(BuildContext context, String answerString) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Text(
            'YOUR ANSWER',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Copy this and send it to the host:',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundMedium,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: SelectableText(
              answerString,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontFamily: 'Courier',
              ),
              maxLines: 6,
            ),
          ),
          const SizedBox(height: 12),
          
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: answerString));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Answer copied!')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('COPY ANSWER'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 32),
          
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            'Waiting for connection...',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(String message) {
    return BlocBuilder<ConnectionBloc, bloc_state.ConnectionState>(
      builder: (context, state) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Connection progress widget
                _ConnectionProgressWidget(state: state, message: message),
                const SizedBox(height: 24),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: responsiveTextSize(context, 16),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 64),
          const SizedBox(height: 24),
          Text(
            error,
            style: const TextStyle(color: AppColors.error, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              context.read<ConnectionBloc>().add(const bloc_event.ResetConnectionEvent());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinModeSelection(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          const SizedBox(height: 40),
          const Text(
            'JOIN GAME',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
            textAlign:TextAlign.center,
          ),
          const SizedBox(height: 48),
          
          // Auto mode: Enter code
          const Text(
            'AUTO MODE',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 4-digit code from your opponent',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _joinCodeController,
            decoration: InputDecoration(
                    hintText: '1234',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
                    filled: true,
                    fillColor: AppColors.backgroundMedium,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                    ),
                  ),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    letterSpacing: 8,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          const SizedBox(height: 16),
          AppButton.primary(
            text: 'JOIN',
            onPressed: () {
                  final code = _joinCodeController.text.trim();
                  if (code.length != 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a 4-digit code')),
                    );
                  return;
                }
                context.read<ConnectionBloc>().add(
                bloc_event.JoinGameEvent(
                    mode: bloc_state.SignalingMode.auto,
                    sessionCode: code,
                  ),
                );
              },
            ),
          const SizedBox(height: 40),
          
          Divider(color: AppColors.backgroundMedium, thickness: 2),
          const SizedBox(height: 40),
          
          // Manual mode: Enter offer
          const Text(
            'MANUAL MODE',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste the offer string from your opponent',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _manualOfferController,
            decoration: InputDecoration(
              hintText: 'Paste offer here...',
              hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
              filled: true,
              fillColor: AppColors.backgroundMedium,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              ),
            ),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 10),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          
          AppButton.primary(
            text: 'JOIN WITH MANUAL CODE',
            icon: Icons.login,
            onPressed: () {
              final offer = _manualOfferController.text.trim();
              if (offer.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please paste the offer')),
                );
                return;
              }
              context.read<ConnectionBloc>().add(
                bloc_event.JoinGameEvent(
                  mode: bloc_state.SignalingMode.manual,
                  offerString: offer,
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          
          TextButton(
            onPressed: () {
              setState(() {
                _isJoinView = false;
              });
            },
            child: const Text(
              'BACK',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }

  Future<void> _onHostPressed(BuildContext context) async {
    // Show mode selection dialog
    final mode = await Navigator.push<bloc_state.SignalingMode>(
      context,
      MaterialPageRoute(builder: (_) => const ConnectionModeScreen()),
    );
    
    if (mode != null && mounted) {
      context.read<ConnectionBloc>().add(bloc_event.HostGameEvent(mode));
    }
  }
}

/// Detailed WebRTC connection progress widget
class _ConnectionProgressWidget extends StatefulWidget {
  final bloc_state.ConnectionState state;
  final String message;

  const _ConnectionProgressWidget({
    required this.state,
    required this.message,
  });

  @override
  State<_ConnectionProgressWidget> createState() => _ConnectionProgressWidgetState();
}

class _ConnectionProgressWidgetState extends State<_ConnectionProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _getProgress();
    final steps = _getConnectionSteps();
    final currentStep = (progress * steps.length).floor().clamp(0, steps.length - 1);
    
    // Check if taking too long (>30 seconds)
    final duration = DateTime.now().difference(_startTime ?? DateTime.now());
    final isSlow = duration.inSeconds > 30;

    return Column(
      children: [
        // Progress bar
        SizedBox(
          width: 280,
          child: Column(
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.backgroundMedium,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 16),
              // Current step indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    steps[currentStep].icon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    steps[currentStep].label,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isSlow) ...[
          const SizedBox(height: 16),
          Text(
            'Taking longer than usual...',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  double _getProgress() {
    final state = widget.state;
    if (state is bloc_state.HostingState) {
      if (state.mode == bloc_state.SignalingMode.auto) {
        return 0.4; // Hosting with session code
      } else {
        return 0.2; // Generating offer
      }
    } else if (state is bloc_state.ManualWaitingForAnswerState) {
      return 0.5; // Waiting for answer
    } else if (state is bloc_state.JoiningState) {
      return 0.6; // Joining
    } else if (state is bloc_state.ManualAnswerReadyState) {
      return 0.8; // Answer ready
    } else if (state is bloc_state.ConnectedState) {
      return 1.0; // Connected!
    }
    return 0.1; // Initializing
  }

  List<_ConnectionStep> _getConnectionSteps() {
    return [
      _ConnectionStep(Icons.settings, 'Initializing'),
      _ConnectionStep(Icons.upload, 'Creating offer'),
      _ConnectionStep(Icons.pending, 'Waiting for peer'),
      _ConnectionStep(Icons.sync, 'Connecting'),
      _ConnectionStep(Icons.link, 'Establishing link'),
      _ConnectionStep(Icons.check_circle, 'Connected'),
    ];
  }
}

class _ConnectionStep {
  final IconData icon;
  final String label;

  _ConnectionStep(this.icon, this.label);
}
