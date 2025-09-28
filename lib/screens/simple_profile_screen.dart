// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../data/store_catalog.dart';
import '../models/cringe_entry.dart';
import '../models/user_model.dart';
import '../services/cringe_entry_service.dart';
import '../services/store_service.dart';
import '../services/user_service.dart';
import '../widgets/animated_bubble_background.dart';
import '../widgets/modern_cringe_card.dart';
import '../widgets/store_inventory_card.dart';
import 'cringe_store_screen.dart';
import 'modern_login_screen.dart';
import 'profile_edit_screen.dart';

class SimpleProfileScreen extends StatefulWidget {
  final String? userId;
  final User? initialUser;

  const SimpleProfileScreen({super.key, this.userId, this.initialUser});

  @override
  State<SimpleProfileScreen> createState() => _SimpleProfileScreenState();
}

class _BadgeChip extends StatelessWidget {
  final StoreItemEffect effect;

  const _BadgeChip({required this.effect});

  @override
  Widget build(BuildContext context) {
    final background = effect.badgeColor ?? const Color(0xFF7C4DFF);
    final textColor = effect.badgeTextColor ?? Colors.white;
    final icon = effect.badgeIcon ?? Icons.auto_awesome;
    final label = effect.badgeLabel ?? 'Rozet';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: background.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleProfileScreenState extends State<SimpleProfileScreen> {
  late Future<User?> _profileFuture;
  final StoreService _storeService = StoreService.instance;

  String? get _requestedUserId => widget.userId ?? widget.initialUser?.id;

  bool _isSelfProfileTarget(String? targetId) {
    if (targetId == null || targetId.isEmpty) return true;
    final currentId = UserService.instance.currentUser?.id;
    if (currentId != null && currentId == targetId) return true;
    final firebaseId = UserService.instance.firebaseUser?.uid;
    if (firebaseId != null && firebaseId == targetId) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileUser();
  }

  @override
  void didUpdateWidget(covariant SimpleProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.userId ?? oldWidget.initialUser?.id;
    final newId = _requestedUserId;
    if (oldId != newId) {
      _profileFuture = _loadProfileUser();
    }
  }

  Future<User?> _loadProfileUser() async {
    final targetId = _requestedUserId;
    if (_isSelfProfileTarget(targetId)) {
      final currentUser = UserService.instance.currentUser;
      if (currentUser != null) {
        print('_loadProfileUser - Using cached self: ${currentUser.username}');
        return currentUser;
      }

      final firebaseUser = UserService.instance.firebaseUser;
      if (firebaseUser != null) {
        print(
          '_loadProfileUser - Loading Firebase user: ${firebaseUser.uid}',
        );
        await UserService.instance.loadUserData(firebaseUser.uid);
        return UserService.instance.currentUser;
      }

      print('_loadProfileUser - No authenticated user found');
      return null;
    }

    final resolvedId = targetId?.trim() ?? '';
    if (resolvedId.isEmpty) {
      return widget.initialUser;
    }

    final fetched = await UserService.instance.getUserById(
      resolvedId,
      forceRefresh: widget.initialUser == null,
    );

    if (fetched != null) {
      return fetched;
    }

    return widget.initialUser;
  }

  void _navigateToEditProfile(User user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileEditScreen(user: user)),
    );

    if (result != null && result is User) {
      // Profil güncellendi, Firebase'den yeniden yükle
      final firebaseUser = UserService.instance.firebaseUser;
      if (firebaseUser != null) {
        await UserService.instance.loadUserData(firebaseUser.uid);
      }
      // Sayfayı yenile
      if (!mounted) return;
      setState(() {
        _profileFuture = _loadProfileUser();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Firebase user var mı kontrol et
    final firebaseUser = UserService.instance.firebaseUser;
    print('Profile Screen - Firebase User: ${firebaseUser?.uid}');

    return FutureBuilder<User?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        print('Profile Screen - Future data: ${snapshot.data?.username}');
        print(
          'Profile Screen - Future connectionState: ${snapshot.connectionState}',
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: AnimatedBubbleBackground(
              child: const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            ),
          );
        }

        final user = snapshot.data;
        final targetId = _requestedUserId;
        final isOwnProfileTarget = _isSelfProfileTarget(targetId);

        if (user == null) {
          return isOwnProfileTarget
              ? _buildLoginScreen()
              : _buildUserNotFoundScreen();
        }

        return _buildProfileScreen(user);
      },
    );
  }

  Widget _buildLoginScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBubbleBackground(
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_outline,
                    color: Colors.orange,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Profil Sayfası',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Profilinizi görüntülemek için\ngiriş yapmanız gerekiyor',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ModernLoginScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Giriş Yap'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
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
  }

  Widget _buildUserNotFoundScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBubbleBackground(
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.person_off_outlined,
                    color: Colors.orange,
                    size: 56,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Kullanıcı bulunamadı',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Aradığınız kullanıcı kaldırılmış veya mevcut değil.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileScreen(User user) {
    return Scaffold(
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
            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    centerTitle: false,
                    iconTheme: const IconThemeData(color: Colors.white70),
                    title: Image.asset(
                      'assets/images/logo.png',
                      height: 32,
                      width: 120,
                      fit: BoxFit.contain,
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.store_rounded,
                            size: 18,
                            color: Colors.black,
                          ),
                          label: const Text(
                            'Cringe Store',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 3,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CringeStoreScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderCard(user),
                          const SizedBox(height: 12),
                          _buildStatsGrid(user),
                          const SizedBox(height: 16),
                          StoreInventoryCard(user: user),
                          const SizedBox(height: 16),
                          _buildUserEntriesSection(user),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildHeaderCard(User user) {
    final theme = Theme.of(context);
    final displayName =
        user.fullName.isNotEmpty ? user.fullName : user.username;
    final frameEffect = _storeService.resolveFrameEffect(user);
    final backgroundEffect = _storeService.resolveBackgroundEffect(user);
    final badgeEffects = _storeService.resolveBadgeEffects(user);
    final nameColor = _storeService.resolveNameColor(user);
    final backgroundGlow = backgroundEffect.backgroundGlow ?? const <Color>[];

    const baseGradient = LinearGradient(
      colors: [Color(0xFF1C1A24), Color(0xFF14111C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
      color: (backgroundGlow.isNotEmpty
          ? backgroundGlow.first
          : Colors.orange)
        .withValues(alpha: 0.25),
            blurRadius: 42,
            spreadRadius: 2,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(gradient: baseGradient),
              ),
            ),
            if (backgroundGlow.isNotEmpty)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
            ...backgroundGlow
              .map((color) => color.withValues(alpha: 0.35)),
                        Colors.transparent,
                      ],
                      radius: 1.05,
                      center: Alignment.topLeft,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -24),
                        child: _buildAvatar(
                          user,
                          frameEffect: frameEffect,
                          backgroundEffect: backgroundEffect,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: nameColor ?? Colors.white,
                                fontWeight: FontWeight.w700,
                                shadows: nameColor != null
                                    ? [
                                        Shadow(
                      color:
                        nameColor.withValues(alpha: 0.35),
                                          blurRadius: 16,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  '@${user.username}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                                if (user.isVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: Colors.purpleAccent,
                                  ),
                                ],
                              ],
                            ),
                            if (badgeEffects.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: badgeEffects
                                    .map((effect) => _BadgeChip(effect: effect))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (user.bio.trim().isNotEmpty)
                    Text(
                      user.bio,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.84),
                        height: 1.5,
                      ),
                    )
                  else
                    Text(
                      'Profiline birkaç cümle ile renk kat. Kendini tanıt, ilgi alanlarını paylaş.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Profili Düzenle'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB74D),
                            foregroundColor: Colors.black,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => _navigateToEditProfile(user),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.rocket_launch_outlined),
                          label: const Text('Krep Paylaş'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Yakında: Hızlı krep paylaşımı!',
                                ),
                                backgroundColor: Colors.orange.shade400,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(
    User user, {
    required StoreItemEffect frameEffect,
    required StoreItemEffect backgroundEffect,
  }) {
    final avatarRadius = 46.0;
    final bytes = _decodeAvatar(user.avatar);

    final frameGradient = frameEffect.frameGradient ??
        const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
        );
  final frameBorder =
    frameEffect.frameBorderWidth.clamp(2.0, 12.0).toDouble();
    final glowColors = backgroundEffect.backgroundGlow ?? const <Color>[];
    final glowColor =
        glowColors.isNotEmpty ? glowColors.first : const Color(0xFFFFA726);

    return Stack(
      alignment: Alignment.center,
      children: [
        if (glowColors.isNotEmpty)
          Container(
            width: avatarRadius * 2 + 36,
            height: avatarRadius * 2 + 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  ...glowColors.map(
                    (color) => color.withValues(alpha: 0.35),
                  ),
                  Colors.transparent,
                ],
                radius: 0.9,
              ),
            ),
          ),
        Container(
          width: avatarRadius * 2,
          height: avatarRadius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: frameGradient,
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Container(
            margin: EdgeInsets.all(frameBorder),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 2.4,
                ),
            ),
            child: ClipOval(
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2C3350), Color(0xFF1F2538)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _buildAvatarFallbackInitial(user),
                          style: const TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  String _buildAvatarFallbackInitial(User user) {
    final source = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()
        : user.username.trim().isNotEmpty
            ? user.username.trim()
            : user.email.trim();

    if (source.isEmpty) {
      return '👤';
    }

    final firstRune = source.runes.isNotEmpty ? source.runes.first : null;
    if (firstRune == null) {
      return '👤';
    }

    return String.fromCharCode(firstRune).toUpperCase();
  }

  Uint8List? _decodeAvatar(String rawAvatar) {
    if (!rawAvatar.startsWith('data:image')) {
      return null;
    }

    final commaIndex = rawAvatar.indexOf(',');
    if (commaIndex == -1 || commaIndex >= rawAvatar.length - 1) {
      return null;
    }

    final base64Segment = rawAvatar.substring(commaIndex + 1).trim();
    if (base64Segment.isEmpty) {
      return null;
    }

    try {
      return base64Decode(base64Segment);
    } catch (error) {
      print('⚠️ Avatar decode failed: $error');
      return null;
    }
  }



  Widget _buildStatsGrid(User user) {
    final stats = [
      {
        'label': 'Takipçi',
        'value': user.followersCount,
        'icon': Icons.groups_rounded,
        'color': const Color(0xFF4FC3F7),
      },
      {
        'label': 'Takip',
        'value': user.followingCount,
        'icon': Icons.person_add_alt_1_rounded,
        'color': const Color(0xFFFFAB91),
      },
      {
        'label': 'Krepler',
        'value': user.entriesCount,
        'icon': Icons.bakery_dining_outlined,
        'color': const Color(0xFFA5D6A7),
      },
    ];

    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 3,
      crossAxisSpacing: 3,
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 8,
        backgroundColor:
          (stat['color'] as Color).withValues(alpha: 0.18),
                child: Icon(
                  stat['icon'] as IconData,
                  color: stat['color'] as Color,
                  size: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                (stat['value'] as num).toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                stat['label'] as String,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }







  Widget _buildUserEntriesSection(User user) {
    final isOwnProfile = _isSelfProfileTarget(user.id);
    final fallbackUserId = UserService.instance.firebaseUser?.uid ?? '';
    final userId = user.id.isNotEmpty ? user.id : fallbackUserId;

    if (userId.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSimpleEntriesInfoMessage(
            'Kullanıcı bilgileri alınamadı. Lütfen tekrar giriş yapmayı deneyin.',
            icon: Icons.lock_outline,
          ),
        ],
      );
    }

    final effectiveUser = user.id == userId ? user : user.copyWith(id: userId);

    return StreamBuilder<List<CringeEntry>>(
      stream: CringeEntryService.instance.getUserEntriesStream(effectiveUser),
      builder: (context, snapshot) {
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final hasError = snapshot.hasError;
        final entries = snapshot.data ?? <CringeEntry>[];

        Widget content;
        if (isLoading) {
          content = const SizedBox(
            key: ValueKey('entries-loading'),
            height: 160,
            child: Center(
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          );
        } else if (hasError) {
          content = KeyedSubtree(
            key: const ValueKey('entries-error'),
            child: _buildSimpleEntriesInfoMessage(
              'Paylaşımları yüklerken bir sorun oluştu. Lütfen daha sonra tekrar deneyin.',
              icon: Icons.error_outline,
            ),
          );
        } else if (entries.isEmpty) {
          final emptyMessage = isOwnProfile
              ? 'Henüz paylaştığın bir krep yok. İlk kremini paylaşarak topluluğa katıl!'
              : 'Bu kullanıcı henüz krep paylaşmamış.';
          content = KeyedSubtree(
            key: const ValueKey('entries-empty'),
            child: _buildSimpleEntriesInfoMessage(
              emptyMessage,
              icon: Icons.bakery_dining_outlined,
            ),
          );
        } else {
          content = ListView.separated(
            key: ValueKey('entries-${entries.length}'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ModernCringeCard(entry: entry);
            },
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: content,
            ),
          ],
        );
      },
    );
  }



  Widget _buildSimpleEntriesInfoMessage(
    String message, {
    IconData icon = Icons.info_outline,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withValues(alpha: 0.18),
            ),
            child: Icon(icon, color: Colors.orangeAccent, size: 28),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
