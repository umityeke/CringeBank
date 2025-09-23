import 'package:flutter/material.dart';
import '../services/user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _handleAuth() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showError('Lütfen tüm alanları doldurun');
      return;
    }

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 1)); // Mock delay

    if (_isLogin) {
      // UserService kullanarak giriş yap
      final success = await UserService.instance.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (success) {
        if (mounted) Navigator.pushReplacementNamed(context, '/main');
      } else {
        _showError('Kullanıcı adı veya şifre hatalı!');
      }
    } else {
      // UserService kullanarak kayıt ol
      final success = await UserService.instance.register(
        _usernameController.text.trim(),
        '${_usernameController.text}@cringe.com',
        _passwordController.text.trim(),
      );

      if (success) {
        if (mounted) Navigator.pushReplacementNamed(context, '/main');
      } else {
        _showError('Bu kullanıcı adı zaten alınmış!');
      }
    }

    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.black),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Şifremi Unuttum'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kullanıcı adını gir ve yeni şifreni belirle:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Şifre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (usernameController.text.trim().isEmpty ||
                          newPasswordController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lütfen tüm alanları doldurun!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      // Kullanıcı var mı kontrol et
                      if (!UserService.instance.userExists(
                        usernameController.text.trim(),
                      )) {
                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bu kullanıcı adı bulunamadı!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Şifre sıfırlama işlemi
                      final success = await UserService.instance.resetPassword(
                        usernameController.text.trim(),
                        newPasswordController.text.trim(),
                      );

                      setState(() => isLoading = false);

                      if (success && mounted) {
                        Navigator.pop(context);
                        _showSuccess(
                          'Şifren başarıyla değiştirildi! Yeni şifrenle giriş yapabilirsin.',
                        );
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Şifre sıfırlama işlemi başarısız!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Şifreyi Değiştir'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo ve başlık
                Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.emoji_emotions_outlined,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'CRINGE BANKASI',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? 'Utanç dolu anlarına hoş geldin'
                          : 'Utanç topluluğuna katıl',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8E8E8E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // Form alanları
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı adı',
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Şifre',
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 24),

                // Giriş/Kayıt butonu
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : Text(
                          _isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                const SizedBox(height: 16),

                // Şifremi Unuttum butonu (sadece giriş modunda)
                if (_isLogin)
                  TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text(
                      'Şifremi Unuttum?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E8E),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Geçiş butonu
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _usernameController.clear();
                      _passwordController.clear();
                    });
                  },
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E8E),
                      ),
                      children: [
                        TextSpan(
                          text: _isLogin
                              ? 'Hesabın yok mu? '
                              : 'Zaten hesabın var mı? ',
                        ),
                        TextSpan(
                          text: _isLogin ? 'Kayıt Ol' : 'Giriş Yap',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
