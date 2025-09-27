// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/cringe_entry.dart';
import '../models/user_model.dart';
import '../services/cringe_entry_service.dart';
import '../services/user_service.dart';
import '../widgets/animated_bubble_background.dart';
import '../widgets/modern_cringe_card.dart';
import 'modern_login_screen.dart';
import 'profile_edit_screen.dart';

class SimpleProfileScreen extends StatefulWidget {
  const SimpleProfileScreen({super.key});

  @override
  State<SimpleProfileScreen> createState() => _SimpleProfileScreenState();
}

class _SimpleProfileScreenState extends State<SimpleProfileScreen> {
  Future<User?> _getCurrentUser() async {
    final currentUser = UserService.instance.currentUser;
    if (currentUser != null) {
      print('_getCurrentUser - Using cached user: ${currentUser.username}');
      return currentUser;
    }

    final firebaseUser = UserService.instance.firebaseUser;
    if (firebaseUser != null) {
      print(
        '_getCurrentUser - Firebase user exists, loading data for: ${firebaseUser.uid}',
      );
      await UserService.instance.loadUserData(firebaseUser.uid);
      return UserService.instance.currentUser;
    }

    print('_getCurrentUser - No user found');
    return null;
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
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Firebase user var mı kontrol et
    final firebaseUser = UserService.instance.firebaseUser;
    print('Profile Screen - Firebase User: ${firebaseUser?.uid}');

    return FutureBuilder<User?>(
      future: _getCurrentUser(),
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

        if (user == null) {
          return _buildLoginScreen();
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
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                  color: Colors.orange.withOpacity(0.18),
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
                  color: Colors.pinkAccent.withOpacity(0.12),
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
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Profili düzenle',
                        onPressed: () => _navigateToEditProfile(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                        tooltip: 'Çıkış yap',
                        onPressed: () async {
                          await UserService.instance.logout();
                          if (!mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ModernLoginScreen(),
                            ),
                          );
                        },
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
    final displayName = user.fullName.isNotEmpty ? user.fullName : user.username;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.18),
            blurRadius: 40,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
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
                        child: _buildAvatar(user),
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
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  '@${user.username}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                if (user.isVerified) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: Colors.purple,
                                  ),
                                ],
                              ],
                            ),

                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (user.bio.trim().isNotEmpty)
                    Text(
                      user.bio,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.84),
                        height: 1.5,
                      ),
                    )
                  else
                    Text(
                      'Profiline birkaç cümle ile renk kat. Kendini tanıt, ilgi alanlarını paylaş.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.6),
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
                            side: BorderSide(color: Colors.white.withOpacity(0.35)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Yakında: Hızlı krep paylaşımı!'),
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

  Widget _buildAvatar(User user) {
    final avatarRadius = 46.0;
    final bytes = _decodeAvatar(user.avatar);

    return Container(
      width: avatarRadius * 2,
      height: avatarRadius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.45), width: 2.4),
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 2.2,
      ),
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
          (stat['color'] as Color).withOpacity(0.18),
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
                  color: Colors.white.withOpacity(0.7),
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
          content = KeyedSubtree(
            key: const ValueKey('entries-empty'),
            child: _buildSimpleEntriesInfoMessage(
              'Henüz paylaştığın bir krep yok. İlk kremini paylaşarak topluluğa katıl!',
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
              color: Colors.orange.withOpacity(0.18),
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
