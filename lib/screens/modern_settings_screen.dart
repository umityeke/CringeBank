import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import 'modern_trade_screen.dart';

class ModernSettingsScreen extends StatefulWidget {
  const ModernSettingsScreen({super.key});

  @override
  State<ModernSettingsScreen> createState() => _ModernSettingsScreenState();
}

class _ModernSettingsScreenState extends State<ModernSettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _floatingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _floatingAnimation;

  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  double _sensitivity = 0.7;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
    ));

    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
    _floatingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Stack(
        children: [
          // Animated Background
          _buildAnimatedBackground(),
          
          // Content
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),
                      _buildProfileSection(),
                      const SizedBox(height: 30),
                      _buildSettingsSection('Görünüm', [
                        _buildSwitchTile(
                          'Karanlık Mod',
                          'Gözlerinizi yormaması için',
                          Icons.dark_mode_outlined,
                          _isDarkMode,
                          (value) => setState(() => _isDarkMode = value),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _buildSettingsSection('Bildirimler', [
                        _buildSwitchTile(
                          'Push Bildirimleri',
                          'Yeni krep ve yorumlar için',
                          Icons.notifications_outlined,
                          _notificationsEnabled,
                          (value) => setState(() => _notificationsEnabled = value),
                        ),
                        _buildSwitchTile(
                          'Ses',
                          'Bildirim sesleri',
                          Icons.volume_up_outlined,
                          _soundEnabled,
                          (value) => setState(() => _soundEnabled = value),
                        ),
                        _buildSwitchTile(
                          'Titreşim',
                          'Haptik geri bildirim',
                          Icons.vibration_outlined,
                          _vibrationEnabled,
                          (value) => setState(() => _vibrationEnabled = value),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _buildSliderSection(),
                      const SizedBox(height: 20),
                      _buildSettingsSection('Hesap', [
                        _buildActionTile(
                          'Profil Düzenle',
                          'Bilgilerinizi güncelleyin',
                          Icons.edit_outlined,
                          () {},
                        ),
                        _buildActionTile(
                          'Gizlilik',
                          'Gizlilik ayarlarınız',
                          Icons.privacy_tip_outlined,
                          () {},
                        ),
                        _buildActionTile(
                          'Güvenlik',
                          'Şifre ve güvenlik',
                          Icons.security_outlined,
                          () {},
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _buildSettingsSection('Diğer', [
                        _buildActionTile(
                          'Krep Takası',
                          'Hikayelerinizi takasla',
                          Icons.swap_horiz,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ModernTradeScreen(),
                              ),
                            );
                          },
                        ),
                        _buildActionTile(
                          'Yardım & Destek',
                          'SSS ve iletişim',
                          Icons.help_outline,
                          () {},
                        ),
                        _buildActionTile(
                          'Hakkında',
                          'Uygulama bilgileri',
                          Icons.info_outline,
                          () {},
                        ),
                        _buildActionTile(
                          'Çıkış Yap',
                          'Hesabınızdan çıkın',
                          Icons.logout_outlined,
                          () {},
                          isDestructive: true,
                        ),
                      ]),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
            ),
            ...List.generate(8, (index) {
              final offset = _floatingAnimation.value * 2 * math.pi;
              final x = (index % 4) * 0.25 + 0.125;
              final y = (index ~/ 4) * 0.5 + 0.25;
              return Positioned(
                left: MediaQuery.of(context).size.width * x + 
                      30 * math.sin(offset + index),
                top: MediaQuery.of(context).size.height * y + 
                     20 * math.cos(offset + index * 0.7),
                child: Container(
                  width: 80 + (index % 3) * 20,
                  height: 80 + (index % 3) * 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.accentColor.withValues(alpha: 0.1),
                        AppTheme.accentColor.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black12,
              ],
            ),
          ),
        ),
      ),
      title: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: const Text(
              'Ayarlar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          );
        },
      ),
      leading: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileSection() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Krep Master',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Premium Üye',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accentColor,
                              AppTheme.accentColor.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                        child: const Text(
                          '✨ PRO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Column(
                        children: children.map((child) {
                          final isLast = children.indexOf(child) == 
                                         children.length - 1;
                          return Column(
                            children: [
                              child,
                              if (!isLast)
                                Divider(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.accentColor.withValues(alpha: 0.2),
        ),
        child: Icon(
          icon,
          color: AppTheme.accentColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
                    activeThumbColor: AppTheme.accentColor,
        inactiveThumbColor: Colors.white.withValues(alpha: 0.7),
        inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDestructive 
              ? Colors.red.withValues(alpha: 0.2)
              : AppTheme.accentColor.withValues(alpha: 0.2),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : AppTheme.accentColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDestructive 
              ? Colors.red.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: isDestructive 
            ? Colors.red.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.5),
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSliderSection() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Hassasiyet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.accentColor.withValues(alpha: 0.2),
                                ),
                                child: Icon(
                                  Icons.tune,
                                  color: AppTheme.accentColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Krep Hassasiyeti',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Ne kadar utanç verici olsun?',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${(_sensitivity * 100).round()}%',
                                style: TextStyle(
                                  color: AppTheme.accentColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppTheme.accentColor,
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                              thumbColor: AppTheme.accentColor,
                              overlayColor: AppTheme.accentColor.withValues(alpha: 0.2),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 10,
                              ),
                              trackHeight: 6,
                            ),
                            child: Slider(
                              value: _sensitivity,
                              onChanged: (value) {
                                setState(() => _sensitivity = value);
                              },
                              min: 0.0,
                              max: 1.0,
                              divisions: 10,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Hafif',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Aşırı',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}