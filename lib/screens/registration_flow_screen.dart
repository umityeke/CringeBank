import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/email_otp_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

enum RegistrationStep { email, otp, profile }

class RegistrationFlowScreen extends StatefulWidget {
  const RegistrationFlowScreen({super.key});

  @override
  State<RegistrationFlowScreen> createState() => _RegistrationFlowScreenState();
}

class _RegistrationFlowScreenState extends State<RegistrationFlowScreen>
  with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();

  RegistrationStep _step = RegistrationStep.email;
  bool _isLoading = false;
  late final AnimationController _bubbleController;
  late final List<_BubbleConfig> _bubbles;

  String? _pendingEmail;
  String? _pendingPassword;

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _bubbles = [
      _BubbleConfig(
        origin: const Offset(0.2, 0.25),
        radius: 110,
        horizontalShift: 0.06,
        verticalShift: 0.08,
        speed: 1.0,
        phase: 0.0,
        colors: [
          const Color(0xFF3C8CE7).withOpacity(0.55),
          const Color(0xFF00EAFF).withOpacity(0.25),
        ],
      ),
      _BubbleConfig(
        origin: const Offset(0.75, 0.2),
        radius: 140,
        horizontalShift: 0.08,
        verticalShift: 0.06,
        speed: 0.75,
        phase: 0.35,
        colors: [
          const Color(0xFF6A11CB).withOpacity(0.45),
          const Color(0xFF2575FC).withOpacity(0.22),
        ],
      ),
      _BubbleConfig(
        origin: const Offset(0.3, 0.75),
        radius: 90,
        horizontalShift: 0.05,
        verticalShift: 0.07,
        speed: 1.25,
        phase: 0.6,
        colors: [
          const Color(0xFF00B4DB).withOpacity(0.5),
          const Color(0xFF0083B0).withOpacity(0.2),
        ],
      ),
      _BubbleConfig(
        origin: const Offset(0.8, 0.72),
        radius: 120,
        horizontalShift: 0.07,
        verticalShift: 0.09,
        speed: 0.9,
        phase: 0.9,
        colors: [
          const Color(0xFFE96443).withOpacity(0.42),
          const Color(0xFF904E95).withOpacity(0.18),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final horizontalPadding = mediaQuery.size.width * 0.07;
    final availableWidth = mediaQuery.size.width - (horizontalPadding * 2);
    final double cardWidth = availableWidth > 0
        ? math.min(480, availableWidth)
        : 480;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF111827),
                    Color(0xFF0B1120),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bubbleController,
              builder: (context, _) => CustomPaint(
                painter: _BubblesPainter(
                  bubbles: _bubbles,
                  progress: _bubbleController.value,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: mediaQuery.padding.top + 40,
                bottom: 40,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRegistrationCard(context, cardWidth),
                ],
              ),
            ),
          ),
          if (canPop)
            Positioned(
              top: mediaQuery.padding.top + 16,
              left: horizontalPadding,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: Colors.white.withOpacity(0.9),
                  splashRadius: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRegistrationCard(BuildContext context, double cardWidth) {
  final cardColor = Colors.white.withOpacity(0.04);
  final borderColor = Colors.white.withOpacity(0.08);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 30,
                offset: const Offset(0, 22),
                spreadRadius: -18,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: _buildCardContent(context),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _buildTitle(),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'CRINGE Bankası\'na katılmak için birkaç adım kaldı.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.65),
          ),
        ),
        const SizedBox(height: 28),
        _buildStepIndicator(),
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: _buildCurrentStep(),
        ),
      ],
    );
  }

  String _buildTitle() {
    switch (_step) {
      case RegistrationStep.email:
        return 'E-posta ile Başla';
      case RegistrationStep.otp:
        return 'E-postanı Doğrula';
      case RegistrationStep.profile:
        return 'Profilini Oluştur';
    }
  }

  Widget _buildStepIndicator() {
    return Row(
      children: RegistrationStep.values.map((step) {
        final index = RegistrationStep.values.indexOf(step) + 1;
        final isActive = step.index <= _step.index;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppTheme.accentColor
                          : Colors.white.withOpacity(0.2),
                    ),
                    child: Text(
                      '$index',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (step != RegistrationStep.values.last)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isActive
                                ? [
                                    AppTheme.accentColor,
                                    AppTheme.primaryColor.withOpacity(0.7),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.1),
                                  ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _stepLabel(step),
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _stepLabel(RegistrationStep step) {
    switch (step) {
      case RegistrationStep.email:
        return 'E-posta';
      case RegistrationStep.otp:
        return 'Doğrulama';
      case RegistrationStep.profile:
        return 'Profil';
    }
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case RegistrationStep.email:
        return _buildEmailStep();
      case RegistrationStep.otp:
        return _buildOtpStep();
      case RegistrationStep.profile:
        return _buildProfileStep();
    }
  }

  Widget _buildEmailStep() {
    return Column(
      key: const ValueKey('emailStep'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _emailController,
          label: 'E-posta',
          hint: 'ornek@email.com',
          keyboardType: TextInputType.emailAddress,
          icon: Icons.alternate_email,
        ),
        const SizedBox(height: 18),
        _buildTextField(
          controller: _passwordController,
          label: 'Şifre',
          hint: 'En az 6 karakter',
          obscureText: true,
          icon: Icons.lock_outline,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 18),
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Şifre Tekrar',
          hint: 'Şifrenizi doğrulayın',
          obscureText: true,
          icon: Icons.lock_reset,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 26),
        _GradientButton(
          label: 'Devam Et',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _submitEmailStep,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('otpStep'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'E-postana 6 haneli bir doğrulama kodu gönderdik. Lütfen gelen kutunu ve spam klasörünü kontrol et.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _otpController,
          label: 'Doğrulama Kodu',
          hint: '123456',
          keyboardType: TextInputType.number,
          maxLength: 6,
          icon: Icons.verified_user_outlined,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            TextButton(
              onPressed: _isLoading ? null : _resendOtp,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2D79F3),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Kodu Tekrar Gönder'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _GradientButton(
                label: 'Doğrula',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _verifyOtpStep,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileStep() {
    return Column(
      key: const ValueKey('profileStep'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _usernameController,
          label: 'Kullanıcı Adı',
          hint: 'Örn. cringe_master',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 18),
        _buildTextField(
          controller: _fullNameController,
          label: 'Ad Soyad (Opsiyonel)',
          hint: 'İsteğe bağlı',
          icon: Icons.person_outline,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 26),
        _GradientButton(
          label: 'Hesabı Oluştur',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _finalizeRegistration,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
  final borderColor = Colors.white.withOpacity(0.12);
    const focusedBorderColor = Color(0xFF2D79F3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.4),
            color: Colors.white.withOpacity(0.06),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(icon, size: 20, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  maxLength: maxLength,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  cursorColor: focusedBorderColor,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: hint,
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submitEmailStep() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (!email.contains('@') || email.length < 5) {
      _showMessage('Lütfen geçerli bir e-posta adresi girin');
      return;
    }

    if (password.length < 6) {
      _showMessage('Şifre en az 6 karakter olmalıdır');
      return;
    }

    if (password != confirm) {
      _showMessage('Şifreler eşleşmiyor');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isAvailable = await UserService.instance.isEmailAvailable(email);
      if (!isAvailable) {
        _showMessage('Bu e-posta zaten kullanılıyor');
        return;
      }

      final otpCode = await EmailOtpService.sendOtp(email);

      _pendingEmail = email;
      _pendingPassword = password;
      _otpController.clear();

      setState(() {
        _step = RegistrationStep.otp;
      });

      _showMessage('Doğrulama kodu e-posta adresine gönderildi');

      if (kDebugMode && otpCode != null) {
        _showMessage('DEV OTP: $otpCode');
      }
    } catch (e) {
      _showMessage('Kod gönderilirken hata oluştu: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_pendingEmail == null) return;

    setState(() => _isLoading = true);
    try {
      final otpCode = await EmailOtpService.resendOtp(_pendingEmail!);
      _showMessage('Kod yeniden gönderildi');

      if (kDebugMode && otpCode != null) {
        _showMessage('DEV OTP: $otpCode');
      }
    } catch (e) {
      _showMessage('Kod gönderilemedi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtpStep() async {
    final code = _otpController.text.trim();

    if (code.length != 6) {
      _showMessage('Lütfen 6 haneli kodu girin');
      return;
    }

    if (_pendingEmail == null) {
      _showMessage('E-posta doğrulaması için geri dönün');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await EmailOtpService.verifyOtp(_pendingEmail!, code);
      if (!result.success) {
        final message = _mapOtpFailureToMessage(result);
        if (result.isExpired || result.isNotFound || result.isTooManyAttempts) {
          _otpController.clear();
        }

        _showMessage(message);
        return;
      }

      setState(() {
        _step = RegistrationStep.profile;
      });

      _showMessage(
        'E-posta doğrulandı, şimdi kullanıcı adı oluşturabilirsiniz',
      );
    } catch (e) {
      _showMessage('Doğrulama başarısız: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizeRegistration() async {
    final username = _usernameController.text.trim();
    final fullName = _fullNameController.text.trim();

    if (username.length < 3) {
      _showMessage('Kullanıcı adı en az 3 karakter olmalıdır');
      return;
    }

    if (!_isValidUsername(username)) {
      _showMessage('Kullanıcı adı harf, rakam ve alt çizgi içerebilir');
      return;
    }

    if (_pendingEmail == null || _pendingPassword == null) {
      _showMessage('Kayıt adımlarını yeniden başlatın');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isAvailable = await UserService.instance.isUsernameAvailable(
        username,
      );
      if (!isAvailable) {
        _showMessage('Bu kullanıcı adı zaten alınmış');
        return;
      }

      final success = await UserService.instance.register(
        email: _pendingEmail!,
        username: username,
        password: _pendingPassword!,
        fullName: fullName,
      );

      if (!success) {
        _showMessage('Kayıt oluşturulamadı, lütfen tekrar deneyin');
        return;
      }

      if (!mounted) return;

      _showMessage('Hesabınız başarıyla oluşturuldu');

      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    } catch (e) {
      _showMessage('Hesap oluşturulamadı: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isValidUsername(String username) {
    final regex = RegExp(r'^[a-zA-Z0-9_\.]+$');
    return regex.hasMatch(username);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _mapOtpFailureToMessage(EmailOtpVerificationResult result) {
    if (result.isExpired) {
      return 'Kodun süresi dolmuş. Lütfen yeni bir kod iste.';
    }

    if (result.isTooManyAttempts) {
      return 'Çok fazla hatalı deneme yapıldı. Güvenlik için yeni kod istemen gerekiyor.';
    }

    if (result.isNotFound) {
      return 'Kod bulunamadı. Lütfen yeni bir kod gönder.';
    }

    if (result.isInvalidCode) {
      final remaining = result.remainingAttempts ?? 0;
      if (remaining > 0) {
        return 'Kod hatalı. $remaining deneme hakkın kaldı.';
      }
      return 'Kod hatalı. Lütfen yeni bir kod iste.';
    }

    return 'Kod doğrulanamadı. Lütfen tekrar dene.';
  }
}

class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _isHovered = false;

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    setState(() => _isHovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null;
    final List<Color> colors = isDisabled
        ? const [
            Color(0xFF1F2937),
            Color(0xFF1F2937),
            Color(0xFF1F2937),
          ]
        : _isHovered
            ? const [
                Color(0xFF1A1A1A),
                Color(0xFF374151),
                Color(0xFF3B82F6),
              ]
            : const [
                Color(0xFF000000),
                Color(0xFF1F2937),
                Color(0xFF2D79F3),
              ];

    return SizedBox(
      height: 56,
      width: double.infinity,
      child: MouseRegion(
        cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          onTap: isDisabled || widget.isLoading ? null : widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: colors,
                stops: const [0.0, 0.4, 1.0],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: !isDisabled && _isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2D79F3).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleConfig {
  const _BubbleConfig({
    required this.origin,
    required this.radius,
    required this.horizontalShift,
    required this.verticalShift,
    required this.speed,
    required this.phase,
    required this.colors,
  });

  final Offset origin;
  final double radius;
  final double horizontalShift;
  final double verticalShift;
  final double speed;
  final double phase;
  final List<Color> colors;
}

class _BubblesPainter extends CustomPainter {
  const _BubblesPainter({required this.bubbles, required this.progress});

  final List<_BubbleConfig> bubbles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      final animationPhase =
          (progress * bubble.speed + bubble.phase) * 2 * math.pi;
      final dx =
          (bubble.origin.dx +
                  math.cos(animationPhase) * bubble.horizontalShift) *
              size.width;
      final dy =
          (bubble.origin.dy + math.sin(animationPhase) * bubble.verticalShift) *
              size.height;

      final center = Offset(dx, dy);
      final paint = ui.Paint()
        ..shader = RadialGradient(
          colors: bubble.colors,
          stops: const [0.0, 1.0],
        ).createShader(
          ui.Rect.fromCircle(center: center, radius: bubble.radius),
        );

      canvas.drawCircle(center, bubble.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.bubbles != bubbles;
  }
}
