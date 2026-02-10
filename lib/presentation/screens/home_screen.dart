import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../infrastructure/persistence/profile_repository.dart';
import '../blocs/connection_bloc/connection_bloc.dart';
import '../widgets/app_button.dart';
import 'lobby_screen.dart';
import 'profile_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';

/// Home screen with game mode selection
class HomeScreen extends StatefulWidget {
  final ProfileRepository profileRepository;

  const HomeScreen({super.key, required this.profileRepository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.orbitron(
      fontSize: responsiveTextSize(context, 46),
      fontWeight: FontWeight.w700,
      letterSpacing: 4,
      color: AppColors.primary,
    );
    final subtitleStyle = GoogleFonts.orbitron(
      fontSize: responsiveTextSize(context, 14),
      letterSpacing: 2,
      color: AppColors.textSecondary,
    );

    return Scaffold(
      body: TechBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                    color: AppColors.primary,
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
                    color: AppColors.warning,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Coming in Phase 5!'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Menu buttons
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16,
                    children: [
                      AppButton.secondary(
                        text: 'Profile',
                        icon: Icons.person,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProfileScreen(
                                profileRepository: widget.profileRepository,
                              ),
                            ),
                          );
                        },
                        width: 140,
                      ),
                      AppButton.secondary(
                        text: 'Help',
                        icon: Icons.help_outline,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const HelpScreen(),
                            ),
                          );
                        },
                        width: 140,
                      ),
                      AppButton.secondary(
                        text: 'About',
                        icon: Icons.info_outline,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AboutScreen(),
                            ),
                          );
                        },
                        width: 140,
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
          crossAxisAlignment: CrossAxisAlignment.center,
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
                    style: GoogleFonts.orbitron(
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


