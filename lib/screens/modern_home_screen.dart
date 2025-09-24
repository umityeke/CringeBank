import 'dart:async';
import 'dart:convert';
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
  User? _currentUser;
  bool _isUserLoading = true;
  StreamSubscription<User?>? _userSubscription;

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
      backgroundColor: Colors.black,
      body: AnimatedBubbleBackground(
        bubbleCount: 28,
        bubbleColor: const Color(0xFF444444),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            _buildPostsFeed(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 110,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatar(_currentUser),
                const SizedBox(width: 16),
                Expanded(child: _buildWelcomeSection(_currentUser)),
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white70,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(User? user) {
    final size = 56.0;
    final borderColor = const Color(0xFFFF6B6B);
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
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        ),
      );
    }

    Widget buildInitialAvatar() {
      final displayName = _resolveDisplayName(user);
      final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '👤';

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
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => buildInitialAvatar(),
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
          ),
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
        border: Border.all(color: borderColor, width: 2),
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

  Widget _buildWelcomeSection(User? user) {
    if (_isUserLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 14,
            width: 90,
            decoration: BoxDecoration(
              color: const Color(0x22FFFFFF),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 18,
            width: 140,
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      );
    }

    final welcomeName = _resolveDisplayName(user, fallback: 'Misafir');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Hoşgeldin',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          welcomeName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFFFF6B6B),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text('Cringe anılar yükleniyor...', 
                         style: TextStyle(color: Colors.white, fontSize: 16)),
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
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text('Hata oluştu!', 
                               style: TextStyle(color: Colors.white, fontSize: 18)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
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
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
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
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final entries = snapshot.data!;
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= entries.length) return null;
              return _buildPostCard(entries[index]);
            },
            childCount: entries.length,
          ),
        );
      },
    );
  }

  Widget _buildPostCard(CringeEntry entry) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFFF6B6B),
                child: Text(
                  entry.authorName.isNotEmpty 
                      ? entry.authorName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
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
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      entry.authorHandle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCringeLevelColor(entry.krepSeviyesi.round()),
                  borderRadius: BorderRadius.circular(8),
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            entry.aciklama,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Icon(Icons.thumb_up_outlined, color: Colors.green, size: 18),
              const SizedBox(width: 4),
              Text(
                entry.begeniSayisi.toString(),
                style: const TextStyle(color: Colors.green, fontSize: 14),
              ),
              const SizedBox(width: 16),
              Icon(Icons.comment_outlined, color: Colors.blue, size: 18),
              const SizedBox(width: 4),
              Text(
                entry.yorumSayisi.toString(),
                style: const TextStyle(color: Colors.blue, fontSize: 14),
              ),
              const SizedBox(width: 16),
              Icon(Icons.repeat, color: Colors.orange, size: 18),
              const SizedBox(width: 4),
              Text(
                entry.retweetSayisi.toString(),
                style: const TextStyle(color: Colors.orange, fontSize: 14),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white60),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCringeLevelColor(int level) {
    if (level <= 3) return Colors.green;
    if (level <= 6) return Colors.orange;
    return Colors.red;
  }
}