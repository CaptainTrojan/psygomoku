import 'package:flutter/material.dart';

/// Side panel with action buttons (chat, forfeit)
class SideButtonPanel extends StatelessWidget {
  final VoidCallback onChatPressed;
  final VoidCallback onForfeitPressed;
  final int unreadChatCount;

  const SideButtonPanel({
    super.key,
    required this.onChatPressed,
    required this.onForfeitPressed,
    this.unreadChatCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E27),
        border: Border(
          left: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Chat button
          _SidePanelButton(
            icon: Icons.chat_bubble,
            onPressed: onChatPressed,
            badgeCount: unreadChatCount,
            color: const Color(0xFF00E5FF),
          ),
          const SizedBox(height: 16),
          // Forfeit button
          _SidePanelButton(
            icon: Icons.flag,
            onPressed: onForfeitPressed,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }
}

class _SidePanelButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;
  final Color color;

  const _SidePanelButton({
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
          ),
        ),
        // Badge for unread count
        if (badgeCount > 0)
          Positioned(
            top: -4,
            right: -4,
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
                  badgeCount > 9 ? '9+' : '$badgeCount',
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
    );
  }
}
