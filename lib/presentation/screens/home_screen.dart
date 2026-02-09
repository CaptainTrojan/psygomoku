import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../infrastructure/persistence/profile_repository.dart';
import '../blocs/connection_bloc/connection_bloc.dart';
import 'lobby_screen.dart';
import 'profile_screen.dart';

/// Home screen with game mode selection
class HomeScreen extends StatefulWidget {
  final ProfileRepository profileRepository;

  const HomeScreen({super.key, required this.profileRepository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.orbitron(
      fontSize: 46,
      fontWeight: FontWeight.w700,
      letterSpacing: 4,
      color: const Color(0xFF00E5FF),
    );
    final subtitleStyle = GoogleFonts.spaceMono(
      fontSize: 14,
      letterSpacing: 2,
      color: const Color(0xFFFF4081),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A0E27),
                    Color(0xFF151A3D),
                    Color(0xFF1D234F),
                  ],
                ),
              ),
            ),

            // Animated grid texture
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _NeonGridPainter(progress: _controller.value),
                  size: MediaQuery.of(context).size,
                );
              },
            ),

            // Floating glow shapes
            const Positioned(
              left: -80,
              top: 80,
              child: _GlowOrb(
                color: Color(0xFF00E5FF),
                size: 200,
                opacity: 0.15,
              ),
            ),
            const Positioned(
              right: -120,
              bottom: 120,
              child: _GlowOrb(
                color: Color(0xFFFF4081),
                size: 260,
                opacity: 0.12,
              ),
            ),

            // Main content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top row with profile icon
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.person, color: Colors.white70),
                        iconSize: 32,
                        tooltip: 'Profile',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProfileScreen(
                                profileRepository: widget.profileRepository,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Logo
                    Text('PSYGOMOKU', style: titleStyle, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Psychic Gomoku', style: subtitleStyle),
                    const SizedBox(height: 64),

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
                              child: LobbyScreen(
                                profileRepository: widget.profileRepository,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Nearby P2P Button
                    _GameModeButton(
                      label: 'NEARBY P2P',
                      subtitle: 'Bluetooth/Wi-Fi Direct',
                      icon: Icons.bluetooth,
                      color: const Color(0xFFFFB74D),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Coming in Phase 5!'),
                            backgroundColor: Color(0xFFFFB74D),
                          ),
                        );
                      },
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
      width: 300,
      height: 86,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.12),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: color, width: 2),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.orbitron(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.spaceMono(
                      fontSize: 12,
                      color: color.withOpacity(0.8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeonGridPainter extends CustomPainter {
  final double progress;

  _NeonGridPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const gridSize = 36.0;
    final offset = (progress * gridSize) * 0.5;

    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.08)
      ..strokeWidth = 1;

    for (double x = -gridSize; x <= size.width + gridSize; x += gridSize) {
      canvas.drawLine(
        Offset(x + offset, 0),
        Offset(x + offset, size.height),
        paint,
      );
    }

    for (double y = -gridSize; y <= size.height + gridSize; y += gridSize) {
      canvas.drawLine(
        Offset(0, y + offset),
        Offset(size.width, y + offset),
        paint,
      );
    }

    final diagonalPaint = Paint()
      ..color = const Color(0xFFFF4081).withOpacity(0.06)
      ..strokeWidth = 1;

    for (double d = -size.height; d <= size.width; d += gridSize * 2) {
      canvas.drawLine(
        Offset(d + offset, 0),
        Offset(d + size.height + offset, size.height),
        diagonalPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NeonGridPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}
