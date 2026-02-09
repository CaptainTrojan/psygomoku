import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../infrastructure/persistence/profile_repository.dart';
import '../blocs/connection_bloc/connection_bloc.dart';
import '../blocs/connection_bloc/connection_event.dart';
import '../blocs/connection_bloc/connection_state.dart' as bloc_state;
import 'game_session_screen.dart';

/// Lobby screen for hosting or joining a game
class LobbyScreen extends StatefulWidget {
  final ProfileRepository profileRepository;

  const LobbyScreen({super.key, required this.profileRepository});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  @override
  void dispose() {
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
          // (not when ConnectedState updates with new messages)
          return previous is! bloc_state.ConnectedState && 
                 current is bloc_state.ConnectedState;
        },
        listener: (context, state) {
          if (state is bloc_state.ConnectedState) {
            // Connection established, navigate to chat screen
            final connectionBloc = context.read<ConnectionBloc>();
            final transport = connectionBloc.transport;
            
            if (transport != null) {
              // Navigate to game session screen
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
            return _buildHostingView(context, state.signalData);
          } else if (state is bloc_state.HostingWaitingForAnswerState) {
            return _buildHostWaitingForAnswerView(context, state.signalData);
          } else if (state is bloc_state.JoiningState) {
            return _buildJoiningView();
          } else if (state is bloc_state.JoiningWaitingForHostState) {
            return _buildJoinerShowAnswerView(context, state.answerData);
          } else if (state is bloc_state.ConnectedState) {
            // Connected state is handled by listener which navigates to chat
            // Show loading while navigation happens
            return _buildLoadingView('Connection established! Opening chat...');
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Choose Mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 60),
            
            // Host Game Button
            SizedBox(
              width: 280,
              height: 100,
              child: ElevatedButton(
                onPressed: () {
                  context.read<ConnectionBloc>().add(const HostGameEvent());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF).withOpacity(0.15),
                  foregroundColor: const Color(0xFF00E5FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF00E5FF), width: 2),
                  ),
                  elevation: 0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle_outline, size: 32),
                    const SizedBox(height: 4),
                    const Text(
                      'HOST GAME',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Create and share QR code',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF00E5FF).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Join Game Button
            SizedBox(
              width: 280,
              height: 100,
              child: ElevatedButton(
                onPressed: () {
                  // Show join options (scanning/pasting)
                  setState(() {
                    // Trigger a state change to show join view
                    // We'll use a simple navigation to a join-only view
                  });
                  // Navigate to join screen by pushing a new route
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                        value: context.read<ConnectionBloc>(),
                        child: _JoinGameScreen(
                          profileRepository: widget.profileRepository,
                        ),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4081).withOpacity(0.15),
                  foregroundColor: const Color(0xFFFF4081),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFFF4081), width: 2),
                  ),
                  elevation: 0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_scanner, size: 32),
                    const SizedBox(height: 4),
                    const Text(
                      'JOIN GAME',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Scan QR or paste code',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFFFF4081).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostingView(BuildContext context, String signalData) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Waiting for Opponent',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),

            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: signalData,
                size: 250,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 30),

            // Share Link Button
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: signalData));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Offer copied! Share with joiner.'),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('COPY OFFER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Next button to proceed to answer input
            ElevatedButton.icon(
              onPressed: () {
                // Transition to waiting for answer state
                context.read<ConnectionBloc>().add(
                  HostReadyForAnswerEvent(signalData),
                );
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('SHARED - NEXT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostWaitingForAnswerView(BuildContext context, String signalData) {
    final answerController = TextEditingController();
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Offer Shared!',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Waiting for joiner to paste their answer below',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Show the offer that was shared
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Offer (shared):',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    signalData.substring(0, 100) + '...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Paste Answer Field
            const Text(
              'Paste Answer from Joiner:',
              style: TextStyle(
                color: Color(0xFFFF4081),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answerController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Paste the answer JSON here...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF4081)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF4081), width: 2),
                ),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final answer = answerController.text.trim();
                if (answer.isNotEmpty) {
                  context.read<ConnectionBloc>().add(HostReceiveAnswerEvent(answer));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4081),
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
              ),
              child: const Text('CONNECT WITH ANSWER'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinerShowAnswerView(BuildContext context, String answerData) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Answer Generated!',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Share this answer with the host',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Answer QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: answerData,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 30),

            // Copy Answer Button
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: answerData));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Answer copied! Send it to the host.'),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('COPY ANSWER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Show answer text (scrollable, small font)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: SelectableText(
                  answerData,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Color(0xFF4CAF50),
            ),
            const SizedBox(height: 12),
            const Text(
              'Waiting for host to connect...',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildJoiningView() {
    return _buildLoadingView('Connecting to opponent...');
  }

  Widget _buildLoadingView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF00E5FF),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Failed',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('GO BACK'),
            ),
          ],
        ),
      ),
    );
  }

}

/// Separate screen for joining a game
class _JoinGameScreen extends StatefulWidget {
  final ProfileRepository profileRepository;

  const _JoinGameScreen({required this.profileRepository});

  @override
  State<_JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<_JoinGameScreen> {
  final _linkController = TextEditingController();
  bool _isScanning = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // User navigated back, reset connection state
          context.read<ConnectionBloc>().add(const DisconnectEvent());
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text('Join Game'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: BlocListener<ConnectionBloc, bloc_state.ConnectionState>(
        listenWhen: (previous, current) {
          // Only trigger listener when we transition TO ConnectedState
          // (not when ConnectedState updates with new messages)
          return previous is! bloc_state.ConnectedState && 
                 current is bloc_state.ConnectedState;
        },
        listener: (context, state) {
          if (state is bloc_state.ConnectedState) {
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
        child: BlocBuilder<ConnectionBloc, bloc_state.ConnectionState>(
          builder: (context, state) {
            if (state is bloc_state.JoiningState) {
              return _buildJoiningView();
            } else if (state is bloc_state.JoiningWaitingForHostState) {
              // Show the answer screen
              return _buildJoinerShowAnswerView(context, state.answerData);
            }
            return _buildJoinOptionsView();
          },
        ),
      ),
      ),
    );
  }

  Widget _buildJoinOptionsView() {
    return Column(
      children: [
        // Camera Scanner (Top Half)
        Expanded(
          child: Container(
            color: Colors.black,
            child: _isScanning
                ? MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final code = barcodes.first.rawValue;
                        if (code != null && code.isNotEmpty) {
                          setState(() => _isScanning = false);
                          _joinGame(code);
                        }
                      }
                    },
                  )
                : Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _isScanning = true);
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('START SCANNING'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
          ),
        ),

        // Paste Link (Bottom Half)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'OR PASTE LINK',
                  style: TextStyle(
                    color: Color(0xFFFF4081),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _linkController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Paste signaling data here...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF333333)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF333333)),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final link = _linkController.text.trim();
                    if (link.isNotEmpty) {
                      _joinGame(link);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4081),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('JOIN GAME'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJoiningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF00E5FF),
          ),
          const SizedBox(height: 24),
          const Text(
            'Processing offer and generating answer...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinerShowAnswerView(BuildContext context, String answerData) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Answer Generated!',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Share this answer with the host',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Answer QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: answerData,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 30),

            // Copy Answer Button
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: answerData));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Answer copied! Send it to the host.'),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('COPY ANSWER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Show answer text (scrollable, small font)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: SelectableText(
                  answerData,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Color(0xFF4CAF50),
            ),
            const SizedBox(height: 12),
            const Text(
              'Waiting for host to connect...',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _joinGame(String signalData) {
    context.read<ConnectionBloc>().add(JoinGameEvent(signalData));
  }
}
