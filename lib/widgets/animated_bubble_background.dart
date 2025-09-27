import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBubbleBackground extends StatefulWidget {
  final Widget child;
  final int bubbleCount;
  final Color bubbleColor;

  const AnimatedBubbleBackground({
    super.key,
    required this.child,
    this.bubbleCount = 15,
    this.bubbleColor = const Color(0xFF333333),
  });

  @override
  State<AnimatedBubbleBackground> createState() =>
      _AnimatedBubbleBackgroundState();
}

class _AnimatedBubbleBackgroundState extends State<AnimatedBubbleBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<BubbleData> _bubbles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    
    _initializeBubbles();
    _controller.repeat();
  }

  void _initializeBubbles() {
    _bubbles = List.generate(widget.bubbleCount, (index) {
      return BubbleData(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 8 + _random.nextDouble() * 15, // 8-23 pixel (çok daha küçük)
        speed: 0.2 + _random.nextDouble() * 0.5,
        opacity: 0.3 + _random.nextDouble() * 0.3, // 0.3-0.6 (biraz daha az görünür)
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Siyah arkaplan
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
        ),
        // Animasyonlu baloncuklar
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: BubblePainter(
                bubbles: _bubbles,
                animation: _controller.value,
                bubbleColor: widget.bubbleColor,
              ),
              size: Size.infinite,
            );
          },
        ),
        // Ana içerik
        widget.child,
      ],
    );
  }
}

class BubblePainter extends CustomPainter {
  final List<BubbleData> bubbles;
  final double animation;
  final Color bubbleColor;

  BubblePainter({
    required this.bubbles,
    required this.animation,
    required this.bubbleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var bubble in bubbles) {
      final paint = Paint()
        ..color = bubbleColor.withOpacity(bubble.opacity)
        ..style = PaintingStyle.fill;

      // Y pozisyonunu animasyon ile güncelle (yukarı doğru hareket)
      double currentY = (bubble.y - animation * bubble.speed) % 1.2;
      if (currentY < -0.2) currentY = currentY + 1.2;

      final center = Offset(
        bubble.x * size.width,
        currentY * size.height,
      );

      // Glow efekti
      final glowPaint = Paint()
        ..color = bubbleColor.withOpacity(bubble.opacity * 0.1)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, bubble.size * 1.3, glowPaint);
      
      // Ana baloncuk
      canvas.drawCircle(center, bubble.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BubbleData {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  BubbleData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}