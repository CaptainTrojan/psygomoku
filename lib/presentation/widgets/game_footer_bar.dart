import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Footer bar with action buttons (chat, forfeit) for game screen
class GameFooterBar extends StatelessWidget {
  final VoidCallback? onChatPressed;
  final VoidCallback onForfeitPressed;
  final int unreadChatCount;

  const GameFooterBar({
    super.key,
    this.onChatPressed,
    required this.onForfeitPressed,
    this.unreadChatCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.gameBoardBackground,
          border: Border(
            top: BorderSide(
              color: AppColors.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Chat button (only show on mobile)
            if (onChatPressed != null)
              _FooterButton(
                icon: Icons.chat_bubble,
                label: 'Chat',
                onPressed: onChatPressed!,
                badgeCount: unreadChatCount,
                color: AppColors.primary,
              ),
            // Forfeit button
            _FooterButton(
              icon: Icons.flag,
              label: 'Forfeit',
              onPressed: onForfeitPressed,
              color: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final int badgeCount;
  final Color color;

  const _FooterButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.badgeCount = 0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: color.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Badge for unread count
        if (badgeCount > 0)
          Positioned(
            top: 4,
            left: 28,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
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
