import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/chat_bloc/chat_bloc.dart';
import '../blocs/chat_bloc/chat_state.dart';
import 'chat_widget.dart';

/// Collapsible chat overlay with notification badge
class CollapsibleChatWidget extends StatefulWidget {
  const CollapsibleChatWidget({super.key});

  @override
  State<CollapsibleChatWidget> createState() => _CollapsibleChatWidgetState();
}

class _CollapsibleChatWidgetState extends State<CollapsibleChatWidget>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  int _unreadCount = 0;
  int _lastSeenMessageCount = 0;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _toggleChat() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        // Reset unread count when opening chat
        _unreadCount = 0;
      }
    });
  }

  void _onNewMessage(ChatState state) {
    final currentCount = state.messages.length;
    if (!_isOpen && currentCount > _lastSeenMessageCount) {
      setState(() {
        _unreadCount = currentCount - _lastSeenMessageCount;
      });
      // Trigger shake animation
      _shakeController.forward(from: 0);
    }
    if (_isOpen) {
      _lastSeenMessageCount = currentCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Chat overlay (full screen when open)
        if (_isOpen)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.9),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: _toggleChat,
                            icon: const Icon(Icons.close),
                            color: Colors.white,
                            iconSize: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Chat widget
                      Expanded(
                        child: ChatWidget(compact: false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Floating chat button (bottom-right)
        Positioned(
          bottom: 16,
          right: 16,
          child: BlocListener<ChatBloc, ChatState>(
            listener: (context, state) {
              _onNewMessage(state);
            },
            child: AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final shakeOffset = _shakeController.value * 10 *
                    (1 - _shakeController.value) *
                    ((_shakeController.value * 4).floor() % 2 == 0 ? 1 : -1);
                
                return Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: child,
                );
              },
              child: FloatingActionButton(
                onPressed: _toggleChat,
                backgroundColor: const Color(0xFF00E5FF),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.chat_bubble,
                        color: Colors.black,
                        size: 28,
                      ),
                    ),
                    // Notification badge
                    if (_unreadCount > 0 && !_isOpen)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              _unreadCount > 9 ? '9+' : '$_unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
