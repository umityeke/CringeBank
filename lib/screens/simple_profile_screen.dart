import 'dart:convert';
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
      print('_getCurrentUser - Firebase user exists, loading data for: ${firebaseUser.uid}');
      await UserService.instance.loadUserData(firebaseUser.uid);
      return UserService.instance.currentUser;
    }
    
    print('_getCurrentUser - No user found');
    return null;
  }

  void _navigateToEditProfile(User user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(user: user),
      ),
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
        print('Profile Screen - Future connectionState: ${snapshot.connectionState}');
        
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
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
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
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          user.username,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => _navigateToEditProfile(user),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              UserService.instance.logout();
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
      body: AnimatedBubbleBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profil Kartı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange.withValues(alpha: 0.2),
                          border: Border.all(
                            color: Colors.orange,
                            width: 2,
                          ),
                        ),
                        child: user.avatar.startsWith('data:image')
                            ? ClipOval(
                                child: Image.memory(
                                  base64Decode(user.avatar.split(',')[1]),
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.orange,
                                size: 40,
                              ),
                      ),
                      const SizedBox(height: 16),
                      // Kullanıcı Adı
                      Text(
                        user.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // İstatistikler
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.orange,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.krepScore.toString(),
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Krep Skoru',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.trending_up,
                              color: Colors.blue,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.seviyeAdi,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Seviye',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _buildUserEntriesSection(user),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserEntriesSection(User user) {
    final fallbackUserId = UserService.instance.firebaseUser?.uid ?? '';
    final userId = user.id.isNotEmpty ? user.id : fallbackUserId;

    if (userId.isEmpty) {
      return _buildEntriesInfoMessage(
        'Kullanıcı bilgileri alınamadı. Lütfen tekrar giriş yapmayı deneyin.',
        icon: Icons.lock_outline,
      );
    }

    return StreamBuilder<List<CringeEntry>>(
      stream: CringeEntryService.instance.getUserEntriesStream(userId),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
        final hasError = snapshot.hasError;
        final entries = snapshot.data ?? <CringeEntry>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEntriesHeader(entriesCount: snapshot.hasData ? entries.length : null),
            const SizedBox(height: 12),
            if (isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              )
            else if (hasError)
              Expanded(
                child: _buildEntriesInfoMessage(
                  'Paylaşımları yüklerken bir sorun oluştu. Lütfen daha sonra tekrar deneyin.',
                  icon: Icons.error_outline,
                ),
              )
            else if (entries.isEmpty)
              Expanded(
                child: _buildEntriesInfoMessage(
                  'Henüz paylaştığın bir krep yok. İlk kremini paylaşarak topluluğa katıl!',
                  icon: Icons.bakery_dining_outlined,
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return ModernCringeCard(entry: entry);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEntriesHeader({int? entriesCount}) {
    return Row(
      children: [
        const Text(
          'Paylaşılan Krepler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (entriesCount != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$entriesCount',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEntriesInfoMessage(String message, {IconData icon = Icons.info_outline}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.orange,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}