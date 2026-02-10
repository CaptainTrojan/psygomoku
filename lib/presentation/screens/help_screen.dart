import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_button.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Play'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: TechBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _buildSection(
                  'Objective',
                  'Be the first player to form an unbroken line of five stones horizontally, vertically, or diagonally.',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Game Setup',
                  '• The game is played on a 15x15 grid\n'
                  '• Two players take turns placing stones\n'
                  '• Black always goes first\n'
                  '• Players can choose their stone color in the profile',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'How to Play',
                  '1. Tap a cell on the board to place your stone\n'
                  '2. Wait for your opponent to make their move\n'
                  '3. Continue taking turns until someone wins\n'
                  '4. The first player to get five in a row wins!',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Connection Modes',
                  '• Online P2P: Play with anyone via the internet using WebRTC\n'
                  '• Nearby P2P: Play with someone on the same local network\n'
                  '• Host or Join: Host creates a session code that others can join',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Game Rules',
                  '• No move can be on an occupied cell\n'
                  '• You cannot undo a move once placed\n'
                  '• The game ends when someone wins or the board is full\n'
                  '• You can forfeit at any time using the forfeit button',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Tips & Strategy',
                  '• Control the center of the board early\n'
                  '• Watch for your opponent\'s threats\n'
                  '• Create multiple threats at once when possible\n'
                  '• Block your opponent\'s four-in-a-row immediately',
                ),
                const SizedBox(height: 32),
                Center(
                  child: AppButton.primary(
                    text: 'Got It!',
                    onPressed: () => Navigator.pop(context),
                    width: 200,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
      ),
    );
  }
  
  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
