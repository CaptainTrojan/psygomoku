import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide color palette with green tech theme
class AppColors {
  // Primary green palette
  static const Color primary = Color(0xFF00FF7F); // Spring green
  static const Color primaryDark = Color(0xFF00CC66);
  static const Color primaryLight = Color(0xFF66FFB2);
  
  // Background colors
  static const Color backgroundDark = Color(0xFF000A05); // Very dark green (darker)
  static const Color backgroundMedium = Color(0xFF001A0F); // Dark green
  static const Color backgroundLight = Color(0xFF003D1F);
  
  // Accent colors
  static const Color accent = Color(0xFF00FFAA); // Cyan-green
  static const Color error = Color(0xFFFF4444); // Red for errors
  static const Color warning = Color(0xFFFFAA00); // Orange for warnings
  
  // UI element colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3FFD9);
  static const Color border = Color(0xFF00FF7F);
  
  // Game-specific colors
  static const Color gameBoardBackground = Color(0xFF0A0E27); // Dark blue for game board
}

/// Responsive text sizing utility
double responsiveTextSize(BuildContext context, double baseSize) {
  final width = MediaQuery.of(context).size.width;
  
  // Mobile small (< 360px)
  if (width < 360) {
    return baseSize * 0.75;
  }
  // Mobile regular (360px - 600px)
  else if (width < 600) {
    return baseSize * 0.85;
  }
  // Tablet and desktop (>= 600px)
  else {
    return baseSize;
  }
}

/// Unified button styles for consistent UI
class AppButtonStyles {
  static ButtonStyle primary({double borderRadius = 12.0}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.backgroundDark,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      textStyle: GoogleFonts.orbitron(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      elevation: 4,
    );
  }
  
  static ButtonStyle secondary({double borderRadius = 12.0}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.backgroundMedium,
      foregroundColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      side: const BorderSide(color: AppColors.primary, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      textStyle: GoogleFonts.orbitron(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      elevation: 2,
    );
  }
  
  static ButtonStyle danger({double borderRadius = 12.0}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.error,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      textStyle: GoogleFonts.orbitron(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      elevation: 4,
    );
  }
}

/// Tech-themed background with static gradient and subtle pattern
class TechBackground extends StatelessWidget {
  final Widget child;
  
  const TechBackground({
    super.key,
    required this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.backgroundDark,
                AppColors.backgroundMedium,
                AppColors.backgroundDark,
              ],
            ),
          ),
        ),
        // Static subtle pattern
        CustomPaint(
          painter: TechBackgroundPainter(),
          size: Size.infinite,
        ),
        // Content
        child,
      ],
    );
  }
}

/// Custom painter for subtle dot pattern background
class TechBackgroundPainter extends CustomPainter {
  TechBackgroundPainter();
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.03)
      ..style = PaintingStyle.fill;
    
    const dotSpacing = 60.0;
    const dotSize = 1.5;
    
    for (double x = 0; x < size.width; x += dotSpacing) {
      for (double y = 0; y < size.height; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }
  
  @override
  bool shouldRepaint(TechBackgroundPainter oldDelegate) {
    return false;
  }
}

/// App-wide theme configuration
ThemeData getAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // Color scheme
    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      error: AppColors.error,
      background: AppColors.backgroundDark,
      surface: AppColors.backgroundMedium,
    ),
    
    // Default text theme using Orbitron
    textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    
    // AppBar theme
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.backgroundDark,
      elevation: 0,
      titleTextStyle: GoogleFonts.orbitron(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    ),
    
    // Card theme
    cardTheme: CardThemeData(
      color: AppColors.backgroundMedium,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
    ),
    
    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.backgroundMedium,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: GoogleFonts.orbitron(color: AppColors.textSecondary),
      hintStyle: GoogleFonts.orbitron(color: AppColors.textSecondary.withOpacity(0.5)),
    ),
  );
}
