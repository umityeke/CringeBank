// cringe_logos.dart
// Tüm logo widget'larını içeren ana dosya
// Her logo ayrı bir widget olarak tanımlanmış durumda

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../screens/main_navigation.dart';

// LOGO 1: Klasik Utanç Yüz
class ClassicCringeLogo extends StatefulWidget {
  final double size;
  final bool animate;

  const ClassicCringeLogo({
    super.key,
    this.size = 150,
    this.animate = true,
  });

  @override
  State<ClassicCringeLogo> createState() => _ClassicCringeLogoState();
}

class _ClassicCringeLogoState extends State<ClassicCringeLogo>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _blinkController;
  late AnimationController _sweatController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _blinkAnimation;
  late Animation<double> _sweatAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _blinkController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _sweatController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _blinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeInOut,
    ));

    _sweatAnimation = Tween<double>(
      begin: 0.0,
      end: 20.0,
    ).animate(CurvedAnimation(
      parent: _sweatController,
      curve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _blinkController.dispose();
    _sweatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _pulseAnimation,
          _blinkAnimation,
          _sweatAnimation,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: widget.animate ? _pulseAnimation.value : 1.0,
            child: CustomPaint(
              painter: ClassicCringePainter(
                blinkValue: widget.animate ? _blinkAnimation.value : 1.0,
                sweatOffset: widget.animate ? _sweatAnimation.value : 0.0,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ClassicCringePainter extends CustomPainter {
  final double blinkValue;
  final double sweatOffset;

  ClassicCringePainter({
    required this.blinkValue,
    required this.sweatOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // Face gradient
    final facePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF6B6B), Color(0xFFFF4444)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    // Face shadow
    final shadowPaint = Paint()
      ..color = Color(0xFFFF4444).withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawCircle(center.translate(0, 5), radius, shadowPaint);
    canvas.drawCircle(center, radius, facePaint);

    // Eyes
    final eyePaint = Paint()
      ..color = Color(0xFF2D3436)
      ..style = PaintingStyle.fill;

    final leftEyeCenter = center.translate(-radius * 0.25, -radius * 0.15);
    final rightEyeCenter = center.translate(radius * 0.25, -radius * 0.15);

    canvas.drawOval(
      Rect.fromCenter(
        center: leftEyeCenter,
        width: 8,
        height: 20 * blinkValue,
      ),
      eyePaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: rightEyeCenter,
        width: 8,
        height: 20 * blinkValue,
      ),
      eyePaint,
    );

    // Mouth
    final mouthPaint = Paint()
      ..color = Color(0xFF2D3436)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(center.dx - 20, center.dy + radius * 0.2)
      ..quadraticBezierTo(
        center.dx,
        center.dy + radius * 0.35,
        center.dx + 20,
        center.dy + radius * 0.2,
      );

    canvas.drawPath(mouthPath, mouthPaint);

    // Sweat drops
    if (sweatOffset < 15) {
      final sweatPaint = Paint()
        ..color = Color(0xFF74B9FF).withOpacity(1 - sweatOffset / 20)
        ..style = PaintingStyle.fill;

      final sweatCenter = center.translate(radius * 0.6, -radius * 0.4);
      final sweatPath = Path()
        ..moveTo(sweatCenter.dx, sweatCenter.dy + sweatOffset)
        ..quadraticBezierTo(
          sweatCenter.dx - 7,
          sweatCenter.dy + 5 + sweatOffset,
          sweatCenter.dx,
          sweatCenter.dy + 15 + sweatOffset,
        )
        ..quadraticBezierTo(
          sweatCenter.dx + 7,
          sweatCenter.dy + 5 + sweatOffset,
          sweatCenter.dx,
          sweatCenter.dy + sweatOffset,
        );

      canvas.drawPath(sweatPath, sweatPaint);
    }
  }

  @override
  bool shouldRepaint(ClassicCringePainter oldDelegate) =>
      blinkValue != oldDelegate.blinkValue ||
      sweatOffset != oldDelegate.sweatOffset;
}

// LOGO 2: Krep Kasası
class SafeCringeLogo extends StatefulWidget {
  final double size;
  final bool animate;

  const SafeCringeLogo({
    super.key,
    this.size = 150,
    this.animate = true,
  });

  @override
  State<SafeCringeLogo> createState() => _SafeCringeLogoState();
}

class _SafeCringeLogoState extends State<SafeCringeLogo>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _floatController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0), weight: 90),
      TweenSequenceItem(tween: Tween(begin: 0, end: -5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5, end: -5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5, end: 0), weight: 2),
    ]).animate(_shakeController);

    _floatAnimation = Tween<double>(
      begin: 0,
      end: -10,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Safe box
          Container(
            width: widget.size * 0.8,
            height: widget.size * 0.8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDFE6E9), Color(0xFFB2BEC3)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.5),
                  blurRadius: 10,
                  offset: Offset(-5, -5),
                  blurStyle: BlurStyle.inner,
                ),
              ],
            ),
          ),
          // Dial with emoji
          Positioned(
            left: widget.size * 0.2,
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: widget.animate
                      ? _shakeAnimation.value * math.pi / 180
                      : 0,
                  child: Container(
                    width: widget.size * 0.3,
                    height: widget.size * 0.3,
                    decoration: BoxDecoration(
                      color: Color(0xFF2D3436),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '😬',
                        style: TextStyle(fontSize: widget.size * 0.15),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Floating emoji
          Positioned(
            right: widget.size * 0.15,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, widget.animate ? _floatAnimation.value : 0),
                  child: Text(
                    '😳',
                    style: TextStyle(fontSize: widget.size * 0.2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// LOGO 3: Modern Minimal CB
class ModernCBLogo extends StatefulWidget {
  final double size;
  final bool animate;

  const ModernCBLogo({
    super.key,
    this.size = 150,
    this.animate = true,
  }) ;

  @override
  State<ModernCBLogo> createState() => _ModernCBLogoState();
}

class _ModernCBLogoState extends State<ModernCBLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _gradientAnimation;
  late Animation<double> _lineAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _gradientAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_controller);

    _lineAnimation = Tween<double>(
      begin: 100.0,
      end: 120.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // CB Text with gradient
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF6B6B),
                      Color(0xFFFF4444),
                      Color(0xFFFF6B6B),
                    ],
                    stops: [
                      0.0,
                      widget.animate ? _gradientAnimation.value : 0.5,
                      1.0,
                    ],
                  ).createShader(bounds);
                },
                child: Text(
                  'CB',
                  style: TextStyle(
                    fontSize: widget.size * 0.4,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -5,
                  ),
                ),
              ),
              // Animated line
              Positioned(
                bottom: widget.size * 0.25,
                child: Container(
                  width: widget.animate ? _lineAnimation.value : 100,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF6B6B).withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// LOGO 4: Utangaç Kumbara
class PiggyBankLogo extends StatefulWidget {
  final double size;
  final bool animate;

  const PiggyBankLogo({
    super.key,
    this.size = 150,
    this.animate = true,
  }) ;

  @override
  State<PiggyBankLogo> createState() => _PiggyBankLogoState();
}

class _PiggyBankLogoState extends State<PiggyBankLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _blushController;
  late Animation<double> _blushAnimation;

  @override
  void initState() {
    super.initState();

    _blushController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _blushAnimation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _blushController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _blushController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _blushAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: PiggyBankPainter(
              blushOpacity: widget.animate ? _blushAnimation.value : 0.3,
            ),
          );
        },
      ),
    );
  }
}

class PiggyBankPainter extends CustomPainter {
  final double blushOpacity;

  PiggyBankPainter({required this.blushOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Body
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFAAAA), Color(0xFFFF7979)],
      ).createShader(
        Rect.fromCenter(center: center, width: size.width * 0.7, height: size.height * 0.5),
      );

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: size.width * 0.7, height: size.height * 0.5),
      Radius.circular(50),
    );

    // Shadow
    final shadowPaint = Paint()
      ..color = Color(0xFFFF7979).withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawRRect(
      bodyRect.shift(Offset(0, 8)),
      shadowPaint,
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Snout
    final snoutPaint = Paint()..color = Color(0xFFFF6B6B);
    final snoutCenter = center.translate(-size.width * 0.25, 0);
    canvas.drawOval(
      Rect.fromCenter(center: snoutCenter, width: 40, height: 30),
      snoutPaint,
    );

    // Nostrils
    final nostrilPaint = Paint()..color = Color(0xFFD63031);
    canvas.drawCircle(snoutCenter.translate(-8, 0), 3, nostrilPaint);
    canvas.drawCircle(snoutCenter.translate(8, 0), 3, nostrilPaint);

    // Coin slot
    final slotPaint = Paint()
      ..color = Color(0xFF2D3436)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center.translate(-20, -size.height * 0.2),
      center.translate(20, -size.height * 0.2),
      slotPaint,
    );

    // Eyes (simple dots)
    final eyePaint = Paint()..color = Color(0xFF2D3436);
    canvas.drawCircle(center.translate(-15, -10), 4, eyePaint);
    canvas.drawCircle(center.translate(15, -10), 4, eyePaint);

    // Blush cheeks
    final blushPaint = Paint()
      ..color = Colors.red.withOpacity(blushOpacity);
    canvas.drawCircle(center.translate(-30, 5), 12, blushPaint);
    canvas.drawCircle(center.translate(30, 5), 12, blushPaint);

    // Legs (simple lines)
    final legPaint = Paint()
      ..color = Color(0xFFFF6B6B)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center.translate(-20, size.height * 0.2),
      center.translate(-20, size.height * 0.3),
      legPaint,
    );
    canvas.drawLine(
      center.translate(20, size.height * 0.2),
      center.translate(20, size.height * 0.3),
      legPaint,
    );
  }

  @override
  bool shouldRepaint(PiggyBankPainter oldDelegate) =>
      blushOpacity != oldDelegate.blushOpacity;
}

// LOGO 5: Emoji Galaxy
class EmojiGalaxyLogo extends StatefulWidget {
  final double size;
  final bool animate;

  const EmojiGalaxyLogo({
    super.key,
    this.size = 150,
    this.animate = true,
  }) ;

  @override
  State<EmojiGalaxyLogo> createState() => _EmojiGalaxyLogoState();
}

class _EmojiGalaxyLogoState extends State<EmojiGalaxyLogo>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _orbitController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _orbitAnimation;

  final List<String> orbitEmojis = ['😬', '😳', '🫣', '😅'];

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _orbitController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_rotationController);

    _orbitAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_orbitController);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center emoji (bank)
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: widget.animate ? _rotationAnimation.value : 0,
                child: Text(
                  '🏦',
                  style: TextStyle(fontSize: widget.size * 0.4),
                ),
              );
            },
          ),
          // Orbiting emojis
          ...List.generate(orbitEmojis.length, (index) {
            final delay = (index * math.pi / 2);
            return AnimatedBuilder(
              animation: _orbitAnimation,
              builder: (context, child) {
                final angle = widget.animate
                    ? _orbitAnimation.value + delay
                    : delay;
                final x = math.cos(angle) * widget.size * 0.35;
                final y = math.sin(angle) * widget.size * 0.35;
                
                return Transform.translate(
                  offset: Offset(x, y),
                  child: Transform.rotate(
                    angle: -angle, // Counter-rotate to keep emoji upright
                    child: Text(
                      orbitEmojis[index],
                      style: TextStyle(fontSize: widget.size * 0.15),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

// Ana Logo Widget - İstediğinizi seçebilirsiniz
class CringeBankLogo extends StatelessWidget {
  final LogoType type;
  final double size;
  final bool animate;

  const CringeBankLogo({
    super.key,
    this.type = LogoType.classic,
    this.size = 150,
    this.animate = true,
  }) ;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case LogoType.classic:
        return ClassicCringeLogo(size: size, animate: animate);
      case LogoType.safe:
        return SafeCringeLogo(size: size, animate: animate);
      case LogoType.modern:
        return ModernCBLogo(size: size, animate: animate);
      case LogoType.piggy:
        return PiggyBankLogo(size: size, animate: animate);
      case LogoType.galaxy:
        return EmojiGalaxyLogo(size: size, animate: animate);
    }
  }
}

enum LogoType {
  classic,
  safe,
  modern,
  piggy,
  galaxy,
}

// Kullanım örneği için demo sayfa
class LogoDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Instagram beyaz zemin
      appBar: AppBar(
        title: Text(
          'Logo Galerisi',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildLogoCard(
              'Klasik Utanç',
              CringeBankLogo(type: LogoType.classic),
            ),
            SizedBox(height: 20),
            _buildLogoCard(
              'Krep Kasası',
              CringeBankLogo(type: LogoType.safe),
            ),
            SizedBox(height: 20),
            _buildLogoCard(
              'Modern Minimal',
              CringeBankLogo(type: LogoType.modern),
            ),
            SizedBox(height: 20),
            _buildLogoCard(
              'Utangaç Kumbara',
              CringeBankLogo(type: LogoType.piggy),
            ),
            SizedBox(height: 20),
            _buildLogoCard(
              'Emoji Galaksi',
              CringeBankLogo(type: LogoType.galaxy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoCard(String title, Widget logo) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 20),
          logo,
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Instagram tarzı butonlar
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFDBDBDB)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Animasyon',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFDBDBDB)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Boyut',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Splash Screen örneği
class CringeSplashScreen extends StatefulWidget {
  @override
  State<CringeSplashScreen> createState() => _CringeSplashScreenState();
}

class _CringeSplashScreenState extends State<CringeSplashScreen> {
  @override
  void initState() {
    super.initState();
    // 3 saniye sonra ana sayfaya geç
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Instagram tarzı beyaz zemin
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animasyonlu logo
            CringeBankLogo(
              type: LogoType.modern,
              size: 120,
              animate: true,
            ),
            SizedBox(height: 40),
            // Uygulama adı (Instagram tarzı siyah)
            Text(
              'CRINGE BANKASI',
              style: TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 8),
            // Alt yazı
            Text(
              'Utanç anılarınız güvende',
              style: TextStyle(
                color: Color(0xFF8E8E8E),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 60),
            // Loading indicator (Instagram tarzı)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
