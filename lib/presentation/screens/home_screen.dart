import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/connection_bloc/connection_bloc.dart';
import 'lobby_screen.dart';

/// Home screen with game mode selection
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              const Text(
                'PSYGOMOKU',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E5FF),
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Psychic Gomoku',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFFF4081),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 80),

              // Online P2P Button
              _GameModeButton(
                label: 'ONLINE P2P',
                subtitle: 'Play over Internet',
                icon: Icons.public,
                color: const Color(0xFF00E5FF),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                        value: context.read<ConnectionBloc>(),
                        child: const LobbyScreen(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Nearby P2P Button (Android only - will implement in Phase 5)
              _GameModeButton(
                label: 'NEARBY P2P',
                subtitle: 'Bluetooth/Wi-Fi Direct',
                icon: Icons.bluetooth,
                color: const Color(0xFF9C27B0),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coming in Phase 5!'),
                      backgroundColor: Color(0xFF9C27B0),
                    ),
                  );
                },
              ),
              const SizedBox(height: 60),

              // Profile icon placeholder
              IconButton(
                icon: const Icon(Icons.person, color: Colors.white70),
                iconSize: 32,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile screen coming in Phase 5!'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameModeButton extends StatelessWidget {
  const _GameModeButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 80,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color, width: 2),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
