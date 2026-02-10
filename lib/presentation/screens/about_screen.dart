import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_button.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: TechBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // App icon/logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.3),
                        AppColors.backgroundDark,
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.grid_on,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                // App name
                Text(
                  'Psygomoku',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                // Version
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                // Description
                Text(
                  'A modern take on the classic Gomoku game, featuring peer-to-peer multiplayer with WebRTC technology.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 40),
                // Credits
                _buildInfoCard(
                  'Technology',
                  '• Built with Flutter\n'
                  '• WebRTC for P2P connections\n'
                  '• Cloudflare Workers & Durable Objects for signaling\n'
                  '• BLoC pattern for state management',
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  'Privacy',
                  'Your game data stays between you and your opponent. '
                  'We use peer-to-peer connections, so no game moves are stored on our servers.',
                ),
                const SizedBox(height: 32),
                // GitHub link
                AppButton.secondary(
                  text: 'View on GitHub',
                  icon: Icons.code,
                  onPressed: () {
                    // Copy GitHub URL to clipboard
                    Clipboard.setData(
                      const ClipboardData(text: 'https://github.com/yourusername/psygomoku'),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('GitHub URL copied to clipboard'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  width: 220,
                ),
                const SizedBox(height: 16),
                // Back button
                AppButton.primary(
                  text: 'Back to Menu',
                  onPressed: () => Navigator.pop(context),
                  width: 220,
                ),
                const SizedBox(height: 40),
                // Copyright
                Text(
                  '© 2026 Psygomoku',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
