import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Unified button component for consistent UI across the app
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonStyle style;
  final double? width;
  final double? height;
  
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    required this.style,
    this.width,
    this.height,
  });
  
  /// Primary button - green background with dark text
  factory AppButton.primary({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    double? width,
    double? height,
  }) {
    return AppButton(
      key: key,
      text: text,
      onPressed: onPressed,
      icon: icon,
      style: AppButtonStyles.primary(),
      width: width,
      height: height,
    );
  }
  
  /// Secondary button - outlined with green border
  factory AppButton.secondary({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    double? width,
    double? height,
  }) {
    return AppButton(
      key: key,
      text: text,
      onPressed: onPressed,
      icon: icon,
      style: AppButtonStyles.secondary(),
      width: width,
      height: height,
    );
  }
  
  /// Danger button - red background for destructive actions
  factory AppButton.danger({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    double? width,
    double? height,
  }) {
    return AppButton(
      key: key,
      text: text,
      onPressed: onPressed,
      icon: icon,
      style: AppButtonStyles.danger(),
      width: width,
      height: height,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    Widget buttonChild;
    
    if (icon != null) {
      // Button with icon and text
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    } else {
      // Text-only button
      buttonChild = Text(text);
    }
    
    final button = ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: buttonChild,
    );
    
    // Apply width/height constraints if specified
    if (width != null || height != null) {
      return SizedBox(
        width: width,
        height: height,
        child: button,
      );
    }
    
    return button;
  }
}
