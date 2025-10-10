import 'package:flutter/material.dart';

import 'animated_bubble_background.dart';

class CringeDefaultBackground extends StatelessWidget {
  final Widget child;
  final bool keepAnimatedBubbles;
  final int bubbleCount;
  final Color bubbleColor;

  const CringeDefaultBackground({
    super.key,
    required this.child,
    this.keepAnimatedBubbles = true,
    this.bubbleCount = 18,
    this.bubbleColor = const Color(0xFF2C2F3E),
  });

  @override
  Widget build(BuildContext context) {
    final background = _DecoratedBackground(child: child);

    if (!keepAnimatedBubbles) {
      return background;
    }

    return AnimatedBubbleBackground(
      bubbleCount: bubbleCount,
      bubbleColor: bubbleColor,
      child: background,
    );
  }
}

class _DecoratedBackground extends StatelessWidget {
  final Widget child;

  const _DecoratedBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF121B2E), Color(0xFF090C14)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -80,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withOpacity(0.18),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.pinkAccent.withOpacity(0.12),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
