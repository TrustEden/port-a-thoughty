import 'package:flutter/material.dart';

/// A widget that adds a press/scale micro-interaction to its child
///
/// Scales down slightly when pressed for tactile feedback
class PressableWidget extends StatefulWidget {
  const PressableWidget({
    super.key,
    required this.child,
    this.onPressed,
    this.scaleWhenPressed = 0.95,
    this.duration = const Duration(milliseconds: 100),
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double scaleWhenPressed;
  final Duration duration;

  @override
  State<PressableWidget> createState() => _PressableWidgetState();
}

class _PressableWidgetState extends State<PressableWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onPressed != null ? (_) {
        setState(() => _isPressed = true);
      } : null,
      onTapUp: widget.onPressed != null ? (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      } : null,
      onTapCancel: widget.onPressed != null ? () {
        setState(() => _isPressed = false);
      } : null,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleWhenPressed : 1.0,
        duration: disableAnimations ? Duration.zero : widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
