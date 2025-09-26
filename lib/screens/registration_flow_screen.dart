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

class _RegistrationFlowScreenState extends State<RegistrationFlowScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();

  RegistrationStep _step = RegistrationStep.email;
  bool _isLoading = false;

  String? _pendingEmail;
  String? _pendingPassword;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_buildTitle()), backgroundColor: Colors.black),
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentStep(),
                ),
              ),
            ],
          ),
        ),
      ),
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
                          : Colors.white.withValues(alpha: 0.2),
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
                                    AppTheme.primaryColor.withValues(
                                      alpha: 0.7,
                                    ),
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.1),
                                    Colors.white.withValues(alpha: 0.1),
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
                      : Colors.white.withValues(alpha: 0.5),
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
    return _buildCard(
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
        ),
        const SizedBox(height: 18),
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Şifre Tekrar',
          hint: 'Şifrenizi doğrulayın',
          obscureText: true,
          icon: Icons.lock_reset,
        ),
        const Spacer(),
        _buildPrimaryButton(
          label: 'Devam Et',
          onPressed: _isLoading ? null : _submitEmailStep,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return _buildCard(
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
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _isLoading ? null : _resendOtp,
              child: const Text('Kodu Tekrar Gönder'),
            ),
            _buildPrimaryButton(
              label: 'Doğrula',
              onPressed: _isLoading ? null : _verifyOtpStep,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileStep() {
    return _buildCard(
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
        ),
        const Spacer(),
        _buildPrimaryButton(
          label: 'Hesabı Oluştur',
          onPressed: _isLoading ? null : _finalizeRegistration,
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
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
  }) {
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
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            counterText: '',
            prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.7)),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.35),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.accentColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(label),
      ),
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
