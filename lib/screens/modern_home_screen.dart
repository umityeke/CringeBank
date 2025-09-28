import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/cringe_entry.dart';
import '../models/user_model.dart';
import '../services/cringe_entry_service.dart';
import '../services/user_service.dart';
import '../widgets/animated_bubble_background.dart';

class ModernHomeScreen extends StatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  State<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  User? _currentUser;
  bool _isUserLoading = true;
  StreamSubscription<User?>? _userSubscription;
  bool _pushNotificationsEnabled = true;
  bool _emailSummaryEnabled = false;
  bool _darkModeEnabled = true;
  String? _selectedMood;
  static const double _headerExpandedHeight = 95;

  static const List<_MoodCategory> _moodCategories = [
    _MoodCategory(label: '#utanmaz', emoji: '🔥', color: Color(0xFFFF7043)),
    _MoodCategory(label: '#kampüs', emoji: '🎓', color: Color(0xFF4FC3F7)),
    _MoodCategory(label: '#işyerinde', emoji: '💼', color: Color(0xFFFFCA28)),
    _MoodCategory(label: '#ailecek', emoji: '👨‍👩‍👧', color: Color(0xFFA5D6A7)),
    _MoodCategory(label: '#ilksevgili', emoji: '💔', color: Color(0xFFFF8A80)),
  ];

  @override
  void initState() {
    super.initState();
    _initializeUserStream();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeUserStream() async {
    final cachedUser = UserService.instance.currentUser;

    if (mounted) {
      setState(() {
        _currentUser = cachedUser;
        _isUserLoading = cachedUser == null;
      });
    }

    if (cachedUser == null) {
      final firebaseUser = UserService.instance.firebaseUser;
      if (firebaseUser != null) {
        await UserService.instance.loadUserData(firebaseUser.uid);
      }

      if (mounted) {
        setState(() {
          _currentUser = UserService.instance.currentUser;
          _isUserLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isUserLoading = false);
      }
    }

    _userSubscription?.cancel();
    _userSubscription = UserService.instance.userDataStream.listen(
      (user) {
        if (!mounted) return;
        setState(() {
          _currentUser = user ?? _currentUser;
          _isUserLoading = false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isUserLoading = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      body: AnimatedBubbleBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF121B2E),
                      Color(0xFF090C14),
                    ],
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
                  color: Colors.orange.withValues(alpha: 0.18),
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
                  color: Colors.pinkAccent.withValues(alpha: 0.12),
                ),
              ),
            ),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeaderAppBar(),
                _buildFeedHeaderSliver(),
                _buildPostsFeed(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildHeaderAppBar() {
    final safeTop = MediaQuery.of(context).padding.top;
    final expandedHeight = _headerExpandedHeight + safeTop;
    final displayName = _resolveDisplayName(_currentUser, fallback: 'Misafir');

    return SliverAppBar(
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: const Color(0xFF090C14),
      automaticallyImplyLeading: false,
      leading: const SizedBox.shrink(),
      leadingWidth: 0,
      expandedHeight: expandedHeight,
      toolbarHeight: 60,
      titleSpacing: 0,
      actions: const [],
      title: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 12, right: 20, bottom: 4),
          child: Row(
            children: [
              const SizedBox(width: 20),
              const Spacer(),
              _buildTopIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Bildirimler',
                onTap: () => _showComingSoonSnack('Bildirimler'),
              ),
              const SizedBox(width: 12),
              _buildTopIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Ayarlar',
                onTap: () => _showSettingsBottomSheet(),
              ),
            ],
          ),
        ),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final t = ((constraints.maxHeight - kToolbarHeight) /
                  (expandedHeight - kToolbarHeight))
              .clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF121B2E), Color(0xFF090C14)],
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
                    color: Colors.orange.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                right: -100,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.08),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: LayoutBuilder(
                      builder: (context, cardConstraints) {
                        return ClipRect(
                          clipBehavior: Clip.hardEdge,
                          child: Opacity(
                            opacity: Curves.easeOut.transform(t),
                            child: Visibility(
                              visible: t > 0.05,
                              maintainState: true,
                              maintainAnimation: true,
                              maintainSize: false,
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                maxHeight: 72,
                                maxWidth: cardConstraints.maxWidth - 8,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: 72,
                                    maxWidth: cardConstraints.maxWidth - 8,
                                  ),
                                  child: _buildHeroCard(displayName),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar(User? user) {
    final size = 48.0;
    final borderColor = const Color(0xFFFFA726);
    final avatarData = (user?.avatar ?? '').trim();

    if (_isUserLoading) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x22FFFFFF),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        ),
      );
    }

    Widget buildInitialAvatar() {
      final displayName = _resolveDisplayName(user);
      final initial = displayName.isNotEmpty
          ? displayName[0].toUpperCase()
          : '👤';

      return Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      );
    }

    Widget buildBase64Avatar(String dataUri) {
      try {
        final base64String = dataUri.split(',').last;
        final bytes = base64Decode(base64String);
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        return buildInitialAvatar();
      }
    }

    Widget buildNetworkAvatar(String url) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => SizedBox(
            width: size,
            height: size,
            child: buildInitialAvatar(),
          ),
          errorWidget: (_, __, ___) => SizedBox(
            width: size,
            height: size,
            child: buildInitialAvatar(),
          ),
        ),
      );
    }

    Widget avatarChild;
    if (avatarData.startsWith('data:image')) {
      avatarChild = buildBase64Avatar(avatarData);
    } else if (avatarData.startsWith('http')) {
      avatarChild = buildNetworkAvatar(avatarData);
    } else if (avatarData.isNotEmpty && avatarData.length <= 3) {
      avatarChild = Center(
        child: Text(
          avatarData,
          style: const TextStyle(color: Colors.white, fontSize: 26),
        ),
      );
    } else {
      avatarChild = buildInitialAvatar();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x33FF6B6B),
  border: Border.all(color: borderColor, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: avatarChild,
    );
  }

  String _resolveDisplayName(User? user, {String fallback = 'Misafir'}) {
    if (user == null) return fallback;

    final fullName = user.fullName.trim();
    if (fullName.isNotEmpty) return fullName;

    final username = user.username.trim();
    if (username.isNotEmpty) return username;

    final email = user.email.trim();
    if (email.isNotEmpty) {
      final localPart = email.split('@').first;
      if (localPart.isNotEmpty) return localPart;
    }

    return fallback;
  }

  void _showComingSoonSnack(String feature) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1F2336),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(
            '$feature çok yakında!'
            ' 🎉',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _showSettingsBottomSheet() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final mediaQuery = MediaQuery.of(modalContext);
        return Padding(
          padding: EdgeInsets.only(
            bottom: mediaQuery.viewInsets.bottom,
          ),
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1424),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: _buildSettingsContent(modalContext),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(String displayName) {
    final user = _currentUser;
    final isLoading = _isUserLoading;
    final username = user?.username.trim().isNotEmpty == true
        ? user!.username
        : 'cringebankasi';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: const BoxConstraints(
        maxHeight: 68,
        minHeight: 68,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: _buildAvatar(user),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isLoading
                    ? _buildSkeletonLine(width: 140, height: 20)
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (user?.isPremium ?? false) ...[
                            const SizedBox(width: 8),
                            _buildHeroBadge(
                              icon: Icons.workspace_premium_outlined,
                              colors: const [
                                Color(0xFFFFC107),
                                Color(0xFFFF8F00),
                              ],
                              label: 'Premium',
                            ),
                          ],
                        ],
                      ),
                const SizedBox(height: 2),
                isLoading
                    ? _buildSkeletonLine(width: 110)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '@$username',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.64),
                                    letterSpacing: 0.4,
                                  ),
                            ),
                          ),
                          if (user?.isVerified ?? false) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: Colors.purple,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext modalContext) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFA726),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.white),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ayarlar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Profilini ve deneyimini kişiselleştir',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.of(modalContext).maybePop(),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0x22FFFFFF), height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Profil & Hesap'),
                  _buildSettingsTile(
                    icon: Icons.person_outline,
                    title: 'Profilini düzenle',
                    subtitle: 'Avatarını, kullanıcı adını ve bio\'nu güncelle',
                    onTap: () {
                      Navigator.of(modalContext).maybePop();
                      _showComingSoonSnack('Profilini düzenle');
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Cringe+ Premium',
                    subtitle: 'Özel rozetler ve sınırsız erişim',
                    trailing: _buildComingSoonTag(),
                    onTap: () {
                      Navigator.of(modalContext).maybePop();
                      _showComingSoonSnack('Cringe+ Premium');
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Bildirimler'),
                  _buildToggleTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Push bildirimleri',
                    subtitle: 'Yeni paylaşılan cringe anlarında haber al',
                    value: _pushNotificationsEnabled,
                    onChanged: (value) => setState(() => _pushNotificationsEnabled = value),
                  ),
                  _buildToggleTile(
                    icon: Icons.email_outlined,
                    title: 'Haftalık özet e-postası',
                    subtitle: 'Her pazartesi en popüler cringe anları gelsin',
                    value: _emailSummaryEnabled,
                    onChanged: (value) => setState(() => _emailSummaryEnabled = value),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Deneyim'),
                  _buildToggleTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Koyu tema',
                    subtitle: 'Gece kullanımında göz konforu',
                    value: _darkModeEnabled,
                    onChanged: (value) => setState(() => _darkModeEnabled = value),
                  ),
                  _buildSettingsTile(
                    icon: Icons.translate_outlined,
                    title: 'Dil ve bölge',
                    subtitle: 'Uygulamayı farklı bir dilde kullan',
                    onTap: () {
                      Navigator.of(modalContext).maybePop();
                      _showComingSoonSnack('Dil ve bölge');
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Destek'),
                  _buildSettingsTile(
                    icon: Icons.help_outline,
                    title: 'Yardım merkezi',
                    subtitle: 'Sık sorulan sorulara göz at',
                    onTap: () {
                      Navigator.of(modalContext).maybePop();
                      _showComingSoonSnack('Yardım merkezi');
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.feedback_outlined,
                    title: 'Geri bildirim gönder',
                    subtitle: 'Geliştirme önerini ekibe ulaştır',
                    onTap: () {
                      Navigator.of(modalContext).maybePop();
                      _showComingSoonSnack('Geri bildirim gönder');
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Hesap'),
                  _buildSettingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Çıkış yap',
                    subtitle: 'Hesabından güvenli şekilde çık',
                    onTap: () async {
                      Navigator.of(modalContext).maybePop();
                      await UserService.instance.logout();
                      if (!mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Color(0x22FFFFFF), height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Yakında',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Parti modu, canlı cringe izlemeleri ve daha fazlası hazırlanıyor! 🎬',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildHeroBadge({
    required IconData icon,
    required List<Color> colors,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.38),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLine({double? width, double height = 14}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildFeedHeaderSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Topluluk Akışı',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _showComingSoonSnack('Arama & filtre'),
                  icon:
                      const Icon(Icons.filter_list_rounded, color: Colors.white60),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _selectedMood == null
                  ? 'Bugünün en taze cringe anıları.'
                  : '${_selectedMood!.replaceFirst('#', '').toUpperCase()} modunda paylaşımları gösteriyoruz.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.white.withValues(alpha: 0.68),
                    height: 1.3,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMoodChip(
                  value: null,
                  label: 'Tümü',
                  emoji: '🌌',
                  color: const Color(0xFF7C4DFF),
                  isActive: _selectedMood == null,
                ),
                for (final category in _moodCategories)
                  _buildMoodChip(
                    value: category.label,
                    label: category.label,
                    emoji: category.emoji,
                    color: category.color,
                    isActive: _selectedMood == category.label,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodChip({
    required String? value,
    required String label,
    required String emoji,
    required Color color,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (value == null) {
            _selectedMood = null;
          } else if (_selectedMood == value) {
            _selectedMood = null;
          } else {
            _selectedMood = value;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.7),
                    color.withValues(alpha: 0.45),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0x22121B2E), Color(0x22121B2E)],
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2033), Color(0xFF141A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22121B2E)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22121B2E),
            blurRadius: 14,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        leading: Container(
          height: 44,
          width: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x33FFA726),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  height: 1.3,
                ),
              )
            : null,
        trailing: trailing ??
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2033), Color(0xFF141A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22121B2E)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        leading: Container(
          height: 44,
          width: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x33FFA726),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  height: 1.3,
                ),
              )
            : null,
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFFFFA726),
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? Colors.white24
                : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonTag([String label = 'Yakında']) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x33FFA726),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFFA726),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPostsFeed() {
    return StreamBuilder<List<CringeEntry>>(
      stream: CringeEntryService.instance.entriesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            (!snapshot.hasData || snapshot.data!.isEmpty)) {
          return SliverToBoxAdapter(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(50),
                padding: const EdgeInsets.all(24),
                child: const Column(
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFFFFA726),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Cringe anılar yükleniyor...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(50),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.error_rounded,
                        color: Color(0xFFFF8A80), size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Hata oluştu!',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFA726),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(50),
              padding: const EdgeInsets.all(32),
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_emotions_outlined,
                      size: 48,
                      color: Colors.white70,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Henüz paylaşım yok',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'İlk utanç verici anını paylaş!',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final entries = snapshot.data!;
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= entries.length) return null;
            return _buildPostCard(entries[index]);
          }, childCount: entries.length),
        );
      },
    );
  }

  Widget _buildPostCard(CringeEntry entry) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildPostAvatar(entry),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      entry.authorHandle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getCringeLevelColor(entry.krepSeviyesi.round()),
                      _getCringeLevelColor(entry.krepSeviyesi.round())
                          .withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${entry.krepSeviyesi.round()}/10',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            entry.baslik,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            entry.aciklama,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.thumb_up_alt_rounded,
                  color: Color(0xFF66BB6A), size: 18),
              const SizedBox(width: 4),
              Text(
                entry.begeniSayisi.toString(),
                style: const TextStyle(
                  color: Color(0xFF66BB6A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.mode_comment_outlined,
                  color: Color(0xFF4FC3F7), size: 18),
              const SizedBox(width: 4),
              Text(
                entry.yorumSayisi.toString(),
                style: const TextStyle(
                  color: Color(0xFF4FC3F7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.repeat_rounded,
                  color: Color(0xFFFFA726), size: 18),
              const SizedBox(width: 4),
              Text(
                entry.retweetSayisi.toString(),
                style: const TextStyle(
                  color: Color(0xFFFFA726),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded,
                    color: Colors.white54),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostAvatar(CringeEntry entry) {
    const size = 36.0;
    final borderColor = const Color(0xFFFFA726);
    final avatarData = (entry.authorAvatarUrl ?? '').trim();

    Widget buildInitialAvatar() {
      final initial = entry.authorName.isNotEmpty
          ? entry.authorName[0].toUpperCase()
          : 'U';

      return Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      );
    }

    Widget buildBase64Avatar(String dataUri) {
      try {
        final base64String = dataUri.split(',').last;
        final bytes = base64Decode(base64String);
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        return buildInitialAvatar();
      }
    }

    Widget buildNetworkAvatar(String url) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => SizedBox(
            width: size,
            height: size,
            child: buildInitialAvatar(),
          ),
          errorWidget: (_, __, ___) => SizedBox(
            width: size,
            height: size,
            child: buildInitialAvatar(),
          ),
        ),
      );
    }

    Widget avatarChild;
    if (avatarData.startsWith('data:image')) {
      avatarChild = buildBase64Avatar(avatarData);
    } else if (avatarData.startsWith('http')) {
      avatarChild = buildNetworkAvatar(avatarData);
    } else if (avatarData.isNotEmpty && avatarData.length <= 3) {
      avatarChild = Center(
        child: Text(
          avatarData,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    } else {
      avatarChild = buildInitialAvatar();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x33FF6B6B),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 0),
          ),
          const BoxShadow(
            color: Color(0x55000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: avatarChild,
    );
  }

  Color _getCringeLevelColor(int level) {
    if (level <= 3) return Colors.green;
    if (level <= 6) return Colors.orange;
    return Colors.red;
  }
}

class _MoodCategory {
  final String label;
  final String emoji;
  final Color color;

  const _MoodCategory({
    required this.label,
    required this.emoji,
    required this.color,
  });
}

