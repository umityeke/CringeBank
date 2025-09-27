import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_service.dart';
import 'registration_flow_screen.dart';

class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  State<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isButtonHovered = false;

  static const String _rememberedEmailKey = 'remembered_email';
  static const String _rememberedPasswordKey = 'remembered_password';
  static const String _rememberMeFlagKey = 'remember_me_enabled';

  late final AnimationController _bubbleController;
  late final List<_BubbleConfig> _bubbles;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

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

    Future.microtask(_loadRememberedCredentials);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final horizontalPadding = mediaQuery.size.width * 0.07;
    final availableWidth = mediaQuery.size.width - (horizontalPadding * 2);
    final double cardWidth = availableWidth > 0
        ? math.min(460, availableWidth)
        : 460;

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
                children: [_buildLoginCard(context, cardWidth)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context, double cardWidth) {
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
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 0),
          child: _buildCardContent(context, cardWidth),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, double cardWidth) {
    final double contentWidth = math.max(cardWidth - 56, 92.0);
  final double logoWidth = math.max(92.0, math.min(92.0 * 3.0, contentWidth));
  const double logoHeightFactor = 0.42;
    final double logoHeight = logoWidth * logoHeightFactor;
    final double liftAmount = 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.center,
          child: _LogoCropper(
            targetWidth: logoWidth,
            targetHeight: logoHeight,
          ),
        ),
        const SizedBox(height: 40),
        Transform.translate(
          offset: Offset(0, -liftAmount),
          child: _buildFormSection(context),
        ),
        SizedBox(height: liftAmount),
      ],
    );
  }

  Widget _buildFormSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Email',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        _buildInputField(
          controller: _usernameController,
          hintText: 'E-posta adresini gir',
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.emailAddress,
          icon: Icons.alternate_email,
        ),
        const SizedBox(height: 18),
        const Text(
          'Şifre',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        _buildInputField(
          controller: _passwordController,
          hintText: 'Şifreni gir',
          obscureText: true,
          textInputAction: TextInputAction.done,
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 16),
        _buildRememberForgotRow(context),
        const SizedBox(height: 26),
        _buildSignInButton(),
        const SizedBox(height: 18),
        _buildOrDivider(),
        const SizedBox(height: 18),
        _buildSocialButtons(context),
        const SizedBox(height: 24),
        _buildSignUpRow(context),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputAction textInputAction = TextInputAction.next,
    TextInputType? keyboardType,
  }) {
  final borderColor = Colors.white.withOpacity(0.12);
    const focusedBorderColor = Color(0xFF2D79F3);

    return Container(
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
              textInputAction: textInputAction,
              keyboardType: keyboardType,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              cursorColor: focusedBorderColor,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              onSubmitted: (value) {
                if (textInputAction == TextInputAction.done) {
                  _handleLogin();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRemember = prefs.getBool(_rememberMeFlagKey) ?? false;
    final savedEmail = prefs.getString(_rememberedEmailKey);
    final savedPassword = prefs.getString(_rememberedPasswordKey);

    if (!mounted) return;

    if (savedRemember && savedEmail != null && savedPassword != null) {
      setState(() {
        _rememberMe = true;
        _usernameController.text = savedEmail;
        _passwordController.text = savedPassword;
      });
      _usernameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _usernameController.text.length),
      );
      _passwordController.selection = TextSelection.fromPosition(
        TextPosition(offset: _passwordController.text.length),
      );
    }
  }

  Future<void> _updateRememberedCredentials({bool? rememberOverride}) async {
    final prefs = await SharedPreferences.getInstance();
    final remember = rememberOverride ?? _rememberMe;

    if (remember) {
      await prefs.setBool(_rememberMeFlagKey, true);
      await prefs.setString(
        _rememberedEmailKey,
        _usernameController.text.trim(),
      );
      await prefs.setString(
        _rememberedPasswordKey,
        _passwordController.text,
      );
    } else {
      await prefs.setBool(_rememberMeFlagKey, false);
      await prefs.remove(_rememberedEmailKey);
      await prefs.remove(_rememberedPasswordKey);
    }
  }

  void _handleRememberMeToggle(bool? value) {
    final newValue = value ?? false;
    if (_rememberMe == newValue) {
      // Still ensure persistence if the checkbox was tapped without change
      _updateRememberedCredentials(rememberOverride: newValue);
      return;
    }

    setState(() => _rememberMe = newValue);
    _updateRememberedCredentials(rememberOverride: newValue);
  }

  Widget _buildRememberForgotRow(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          height: 20,
          width: 20,
          child: Checkbox(
            value: _rememberMe,
            onChanged: _handleRememberMeToggle,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: const Color(0xFF2879F3),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Beni Hatırla',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: _handleForgotPassword,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
          ),
          child: const Text(
            'Şifremi Unuttum',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2D79F3),
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleForgotPassword() async {
    if (!mounted) return;

    final emailController =
        TextEditingController(text: _usernameController.text.trim());
    String? errorText;
    bool isSubmitting = false;
    bool requestSent = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Şifremi Unuttum',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'E-posta adresini gir, sıfırlama bağlantısı gönderelim.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: emailController,
                    enabled: !isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'E-posta adresi',
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                      ),
                      errorText: errorText,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFF2D79F3), width: 1.6),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.16),
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty) {
                            setState(
                              () => errorText =
                                  'Lütfen e-posta adresini gir.',
                            );
                            return;
                          }

                          const emailPattern =
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
                          if (!RegExp(emailPattern).hasMatch(email)) {
                            setState(
                              () => errorText =
                                  'Lütfen geçerli bir e-posta adresi gir.',
                            );
                            return;
                          }

                          setState(() {
                            errorText = null;
                            isSubmitting = true;
                          });

              final success =
                await UserService.instance.resetPassword(email);

              if (!context.mounted) return;

                          if (success) {
                            requestSent = true;
                            Navigator.of(context).pop();
                          } else {
                            setState(() {
                              isSubmitting = false;
                              errorText =
                                  'Şifre sıfırlama isteği gönderilemedi. Lütfen tekrar dene.';
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2D79F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Gönder'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();

    if (!mounted) return;
    if (requestSent) {
      _showInfo('Şifre sıfırlama bağlantısı e-postana gönderildi.');
    }
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      child: MouseRegion(
        cursor: _isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isButtonHovered = true),
        onExit: (_) => setState(() => _isButtonHovered = false),
        child: GestureDetector(
          onTap: _isLoading ? null : _handleLogin,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: _isButtonHovered ? [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF374151),
                  const Color(0xFF3B82F6),
                ] : [
                  const Color(0xFF000000),
                  const Color(0xFF1F2937),
                  const Color(0xFF2D79F3),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isButtonHovered
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
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Giriş Yap',
                      style: TextStyle(
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

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'ya da',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons(BuildContext context) {
    return Column(
      children: [
        _buildSocialButton(
          icon: Icons.g_translate,
          label: 'Google ile giriş yap',
          onPressed: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Google ile giriş yakında eklenecek.'),
                ),
              );
            }
          },
        ),
  const SizedBox(height: 0),
        _buildSocialButton(
          icon: Icons.apple,
          label: 'Apple ile giriş yap',
          onPressed: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Apple ile giriş yakında eklenecek.'),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.16)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Hesabın yok mu?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegistrationFlowScreen()),
            );
          },
          child: const Text(
            'Hemen kayıt ol',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D79F3),
            ),
          ),
        ),
      ],
    );
  }

  void _handleLogin() async {
    if (kDebugMode) {
      debugPrint('_handleLogin called');
    }

    final emailInput = _usernameController.text.trim();
    final passwordInput = _passwordController.text.trim();

    if (emailInput.isEmpty || passwordInput.isEmpty) {
      _showError('Lütfen tüm alanları doldurun');
      return;
    }

    const emailPattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
    if (!RegExp(emailPattern).hasMatch(emailInput)) {
      _showError('Lütfen geçerli bir e-posta adresi girin');
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (kDebugMode) {
        debugPrint('Attempting login with: $emailInput');
      }
      final success = await UserService.instance.login(
        emailInput,
        passwordInput,
      );
      if (kDebugMode) {
        debugPrint('Login result: $success');
      }

      if (!success) {
        _showError('Kullanıcı adı veya şifre hatalı!');
      } else {
        await _updateRememberedCredentials();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/main');
      }
    } catch (e) {
      _showError('Bir hata oluştu: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _LogoCropper extends StatefulWidget {
  const _LogoCropper({
    required this.targetWidth,
    required this.targetHeight,
  });

  final double targetWidth;
  final double targetHeight;

  @override
  State<_LogoCropper> createState() => _LogoCropperState();
}

class _LogoCropperState extends State<_LogoCropper> {
  late final Future<_TrimmedImage> _trimmedImageFuture;

  @override
  void initState() {
    super.initState();
    _trimmedImageFuture = _loadTrimmedImage();
  }

  Future<_TrimmedImage> _loadTrimmedImage() async {
    final data = await rootBundle.load('assets/images/logo.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      return _TrimmedImage(
        image: image,
        cropRect: ui.Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
      );
    }

  final Uint8List bytes = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    int minX = width;
    int minY = height;
    int maxX = -1;
    int maxY = -1;

  const alphaThreshold = 80;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int offset = (y * width + x) * 4;
        final int alpha = bytes[offset + 3];
        if (alpha > alphaThreshold) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX == -1 || maxY == -1) {
      return _TrimmedImage(
        image: image,
        cropRect: ui.Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
      );
    }

    const int edgeInset = 1;

    minX = math.min(width - 1, math.max(0, minX + edgeInset));
    minY = math.min(height - 1, math.max(0, minY + edgeInset));
    maxX = math.max(0, math.min(width - 1, maxX - edgeInset));
    maxY = math.max(0, math.min(height - 1, maxY - edgeInset));

    if (maxX <= minX || maxY <= minY) {
      return _TrimmedImage(
        image: image,
        cropRect: ui.Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
      );
    }

    return _TrimmedImage(
      image: image,
      cropRect: ui.Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.targetHeight,
      width: widget.targetWidth,
      child: FutureBuilder<_TrimmedImage>(
        future: _trimmedImageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              !snapshot.hasData) {
            return SizedBox(
              width: widget.targetWidth,
              height: widget.targetHeight,
            );
          }

          final trimmed = snapshot.data!;
          return CustomPaint(
            size: Size(widget.targetWidth, widget.targetHeight),
            painter: _TrimmedLogoPainter(trimmed),
          );
        },
      ),
    );
  }
}

class _TrimmedImage {
  const _TrimmedImage({required this.image, required this.cropRect});

  final ui.Image image;
  final ui.Rect cropRect;
}

class _TrimmedLogoPainter extends CustomPainter {
  _TrimmedLogoPainter(this.trimmed);

  final _TrimmedImage trimmed;
  final ui.Paint _paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.medium
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      trimmed.image,
      trimmed.cropRect,
      ui.Offset.zero & size,
      _paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrimmedLogoPainter oldDelegate) {
    return oldDelegate.trimmed.image != trimmed.image ||
        oldDelegate.trimmed.cropRect != trimmed.cropRect;
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
  _BubblesPainter({required this.bubbles, required this.progress});

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
        ).createShader(ui.Rect.fromCircle(center: center, radius: bubble.radius));

      canvas.drawCircle(center, bubble.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.bubbles != bubbles;
  }
}
