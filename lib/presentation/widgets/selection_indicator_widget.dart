import 'package:flutter/material.dart';

/// Animated pulsing ring for two-step move confirmation
class SelectionIndicatorWidget extends StatefulWidget {
  const SelectionIndicatorWidget({super.key});

  @override
  State<SelectionIndicatorWidget> createState() => _SelectionIndicatorWidgetState();
}

class _SelectionIndicatorWidgetState extends State<SelectionIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.7, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Center(
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.yellowAccent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow (
                      color: Colors.yellowAccent.withOpacity(0.5),
                      blurRadius: 4, // Sharper
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
