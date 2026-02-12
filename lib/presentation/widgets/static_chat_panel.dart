import 'package:flutter/material.dart';
import 'chat_widget.dart';

/// Static chat panel for desktop (no dragging, always visible)
class StaticChatPanel extends StatelessWidget {
  const StaticChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFF1A1E3E),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: const ChatWidget(compact: false),
      ),
    );
  }
}
