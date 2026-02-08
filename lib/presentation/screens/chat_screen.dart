import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/connection_bloc/connection_bloc.dart';
import '../blocs/connection_bloc/connection_event.dart';
import '../widgets/chat_widget.dart';

/// Screen shown when P2P connection is established
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  void _handleDisconnect(BuildContext context) {
    // Disconnect transport
    context.read<ConnectionBloc>().add(const DisconnectEvent());
    
    // Pop back to lobby
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleDisconnect(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text('P2P Chat'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _handleDisconnect(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Connection status indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFF4CAF50),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Connected to opponent',
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Chat widget
              const Expanded(
                child: ChatWidget(),
              ),

              const SizedBox(height: 16),

              // Info text
              Text(
                'This is a proof-of-concept WebRTC chat.\nThe game features will be added next!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
