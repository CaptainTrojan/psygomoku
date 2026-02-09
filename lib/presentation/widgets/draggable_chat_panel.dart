import 'package:flutter/material.dart';
import 'chat_widget.dart';

/// Draggable chat panel that slides from top
class DraggableChatPanel extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const DraggableChatPanel({
    super.key,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  State<DraggableChatPanel> createState() => _DraggableChatPanelState();
}

class _DraggableChatPanelState extends State<DraggableChatPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragPosition = 0.0;
  static const double _panelHeight = 400.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(DraggableChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Add drag delta (negative when swiping up)
      _dragPosition -= details.delta.dy;
      // Clamp between 0 (closed) and _panelHeight (fully open)
      _dragPosition = _dragPosition.clamp(0.0, _panelHeight);
      // Update controller based on drag position
      _controller.value = _dragPosition / _panelHeight;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    
    // If swiped fast, use velocity to decide
    if (velocity.abs() > 500) {
      if (velocity < 0) {
        // Fast swipe up - open
        _controller.forward();
        if (!widget.isOpen) {
          widget.onToggle();
        }
      } else {
        // Fast swipe down - close
        _controller.reverse();
        if (widget.isOpen) {
          widget.onToggle();
        }
      }
    } else {
      // Use position threshold
      if (_dragPosition > _panelHeight / 2) {
        // Dragged more than halfway, keep it open
        _controller.forward();
        if (!widget.isOpen) {
          widget.onToggle();
        }
      } else {
        // Dragged less than halfway, close it
        _controller.reverse();
        if (widget.isOpen) {
          widget.onToggle();
        }
      }
    }
    
    setState(() {
      _dragPosition = widget.isOpen ? _panelHeight : 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final offset = -_panelHeight * (1 - _animation.value);
        return Positioned(
          top: offset,
          left: 0,
          right: 0,
          height: _panelHeight,
          child: GestureDetector(
            onVerticalDragUpdate: _handleDragUpdate,
            onVerticalDragEnd: _handleDragEnd,
            child: Material(
              elevation: 8,
              color: const Color(0xFF1A1E3E),
              child: Column(
                children: [
                  // Chat content
                  const Expanded(
                    child: ChatWidget(compact: false),
                  ),
                  // Drag handle (at bottom for sliding from top)
                  Container(
                    height: 40,
                    alignment: Alignment.center,
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
