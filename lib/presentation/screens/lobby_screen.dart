import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../infrastructure/persistence/profile_repository.dart';
import '../blocs/connection_bloc/connection_bloc.dart';
import '../blocs/connection_bloc/connection_event.dart' as bloc_event;
import '../blocs/connection_bloc/connection_state.dart' as bloc_state;
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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Online P2P'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocConsumer<ConnectionBloc, bloc_state.ConnectionState>(
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
                backgroundColor: Colors.red,
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
          const Text(
            'PSYGOMOKU',
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cryptographic Fog of War Gomoku',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 80),
          
          // Host button
          _PrimaryButton(
            label: 'HOST GAME',
            icon: Icons.add_circle_outline,
            color: Colors.cyan,
            onPressed: () => _onHostPressed(context),
          ),
          const SizedBox(height: 24),
          
          // Join button
          _PrimaryButton(
            label: 'JOIN GAME',
            icon: Icons.login,
            color: Colors.pinkAccent,
            onPressed: () {
              setState(() {
                _isJoinView = true;
              });
            },
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
              color: Colors.cyan,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          
          // Session code display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.cyan.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Text(
              sessionCode,
              style: const TextStyle(
                color: Colors.cyan,
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
                const SnackBar(content: Text('Code copied!')),
              );
            },
            icon: const Icon(Icons.copy, color: Colors.cyan),
            label: const Text(
              'COPY CODE',
              style: TextStyle(color: Colors.cyan, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 48),
          
          // Waiting indicator
          const CircularProgressIndicator(color: Colors.cyan),
          const SizedBox(height: 16),
          const Text(
            'Waiting for opponent to join...',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 48),
          
          // Cancel button
          TextButton(
            onPressed: () {
              context.read<ConnectionBloc>().add(const bloc_event.ResetConnectionEvent());
            },
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostManualView(BuildContext context, String offerString) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Text(
            'STEP 1: SHARE YOUR OFFER',
            style: TextStyle(
              color: Colors.cyan,
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
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyan.withOpacity(0.3)),
            ),
            child: SelectableText(
              offerString,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'Courier',
              ),
              maxLines: 6,
            ),
          ),
          const SizedBox(height: 12),
          
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: offerString));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Offer copied!')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('COPY OFFER'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 40),
          
          const Text(
            'STEP 2: PASTE OPPONENT\'S ANSWER',
            style: TextStyle(
              color: Colors.pinkAccent,
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
              hintStyle: TextStyle(color: Colors.grey[700]),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.pinkAccent.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.pinkAccent.withOpacity(0.3)),
              ),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 10),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: () {
              final answer = _manualAnswerController.text.trim();
              if (answer.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please paste the answer')),
                );
                return;
              }
              context.read<ConnectionBloc>().add(
                bloc_event.ManualHostReceiveAnswerEvent(answer),
              );
            },
            icon: const Icon(Icons.link),
            label: const Text('CONNECT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),
          
          TextButton(
            onPressed: () {
              context.read<ConnectionBloc>().add(const bloc_event.ResetConnectionEvent());
            },
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
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
              color: Colors.pinkAccent,
              fontSize: 16,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Copy this and send it to the host:',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
            ),
            child: SelectableText(
              answerString,
              style: const TextStyle(
                color: Colors.white70,
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
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 32),
          
          const CircularProgressIndicator(color: Colors.pinkAccent),
          const SizedBox(height: 16),
          const Text(
            'Waiting for connection...',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.cyan),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 24),
          Text(
            error,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              context.read<ConnectionBloc>().add(const bloc_event.ResetConnectionEvent());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinModeSelection(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Text(
            'JOIN GAME',
            style: TextStyle(
              color: Colors.pinkAccent,
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
              color: Colors.cyan,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 4-digit code from your opponent',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _joinCodeController,
                  decoration: InputDecoration(
                    hintText: '1234',
                    hintStyle: TextStyle(color: Colors.grey[700]),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.cyan.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.cyan.withOpacity(0.3)),
                    ),
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    letterSpacing: 8,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('JOIN', style: TextStyle(letterSpacing: 2)),
              ),
            ],
          ),
          const SizedBox(height: 40),
          
          Divider(color: Colors.grey[800], thickness: 2),
          const SizedBox(height: 40),
          
          // Manual mode: Enter offer
          const Text(
            'MANUAL MODE',
            style: TextStyle(
              color: Colors.pinkAccent,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste the offer string from your opponent',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _manualOfferController,
            decoration: InputDecoration(
              hintText: 'Paste offer here...',
              hintStyle: TextStyle(color: Colors.grey[700]),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.pinkAccent.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.pinkAccent.withOpacity(0.3)),
              ),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 10),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
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
            icon: const Icon(Icons.login),
            label: const Text('JOIN WITH MANUAL CODE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
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
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
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

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadowColor: color.withOpacity(0.5),
          elevation: 8,
        ),
      ),
    );
  }
}
