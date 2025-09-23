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
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  late List<Bubble> _bubbles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeBubbles();
  }

  void _initializeBubbles() {
    _controllers = [];
    _animations = [];
    _bubbles = [];

    for (int i = 0; i < widget.bubbleCount; i++) {
      // Her baloncuk için controller oluştur
      final controller = AnimationController(
        duration: Duration(
          milliseconds: 3000 + _random.nextInt(4000), // 3-7 saniye
        ),
        vsync: this,
      );

      // Y pozisyonu animasyonu (yukarı doğru hareket)
      final animation = Tween<double>(
        begin: 1.2, // Ekranın altından başla
        end: -0.2, // Ekranın üstünde bitir
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.linear,
      ));

      _controllers.add(controller);
      _animations.add(animation);

      // Baloncuk özellikleri
      _bubbles.add(Bubble(
        x: _random.nextDouble(), // 0-1 arası X pozisyonu
        size: 10 + _random.nextDouble() * 30, // 10-40 pixel arası boyut
        opacity: 0.1 + _random.nextDouble() * 0.3, // 0.1-0.4 arası opacity
        speed: 0.5 + _random.nextDouble() * 0.5, // Farklı hızlar
      ));

      // Animasyonu başlat (gecikme ile)
      Future.delayed(Duration(milliseconds: _random.nextInt(2000)), () {
        if (mounted) {
          controller.repeat();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF000000), // Siyah arkaplan
      child: Stack(
        children: [
          // Baloncuklar
          ...List.generate(widget.bubbleCount, (index) {
            return AnimatedBuilder(
              animation: _animations[index],
              builder: (context, child) {
                final bubble = _bubbles[index];
                return Positioned(
                  left: MediaQuery.of(context).size.width * bubble.x,
                  top: MediaQuery.of(context).size.height * _animations[index].value,
                  child: Container(
                    width: bubble.size,
                    height: bubble.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.bubbleColor.withOpacity(bubble.opacity),
                      boxShadow: [
                        BoxShadow(
                          color: widget.bubbleColor.withOpacity(bubble.opacity * 0.5),
                          blurRadius: bubble.size * 0.3,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
          // Ana içerik
          widget.child,
        ],
      ),
    );
  }
}

class Bubble {
  final double x;
  final double size;
  final double opacity;
  final double speed;

  Bubble({
    required this.x,
    required this.size,
    required this.opacity,
    required this.speed,
  });
}