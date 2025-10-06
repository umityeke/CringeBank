import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cringe_entry.dart';
import '../models/user_model.dart';
import '../services/cringe_entry_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_bubble_background.dart';
import '../widgets/entry_comments_sheet.dart';
import '../widgets/modern_cringe_card.dart';
import '../widgets/modern_components.dart';
import '../utils/entry_actions.dart';
import 'direct_message_thread_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final User user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late User _user;
  late Stream<List<CringeEntry>> _entriesStream;
  bool _isLoadingUser = false;
  bool _isRefreshing = false;
  bool _isMessaging = false;
  final Set<String> _deletingEntryIds = <String>{};

  bool get _isViewingOwnProfile {
    final current = UserService.instance.currentUser;
    if (current == null) {
      return false;
    }

    final currentId = current.id.trim();
    final targetId = _user.id.trim();
    return currentId.isNotEmpty && currentId == targetId;
  }

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _entriesStream = CringeEntryService.instance.getUserEntriesStream(_user);
    _loadLatestUser();
  }

  Future<void> _loadLatestUser({bool forceRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      _isLoadingUser = true;
      if (forceRefresh) {
        _isRefreshing = true;
      }
    });

    try {
      final previousId = _user.id;
      final latest = await UserService.instance.getUserById(
        _user.id.isNotEmpty ? _user.id : widget.user.id,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      if (latest != null) {
        setState(() {
          _user = latest;
          if (latest.id != previousId && latest.id.isNotEmpty) {
            _entriesStream = CringeEntryService.instance.getUserEntriesStream(
              latest,
            );
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _onRefresh() => _loadLatestUser(forceRefresh: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBubbleBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: AppTheme.cringeOrange,
            onRefresh: _onRefresh,
            child: StreamBuilder<List<CringeEntry>>(
              stream: _entriesStream,
              builder: (context, snapshot) {
                final entries = snapshot.data ?? <CringeEntry>[];
                final isLoadingEntries =
                    snapshot.connectionState == ConnectionState.waiting &&
                    entries.isEmpty;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingL,
                    vertical: AppTheme.spacingL,
                  ),
                  children: [
                    _buildTopBar(context),
                    const SizedBox(height: AppTheme.spacingM),
                    _buildProfileHeader(context),
                    if (_isLoadingUser) ...[
                      const SizedBox(height: AppTheme.spacingS),
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: AppTheme.cringeOrange,
                        backgroundColor: Colors.transparent,
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacingXL),
                    _buildEntriesSection(
                      context: context,
                      entries: entries,
                      isLoading: isLoadingEntries,
                    ),
                    const SizedBox(height: AppTheme.spacingXXL),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).maybePop();
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: Text(
            'Profil',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isRefreshing ? 1 : 0,
          child: _isRefreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.cringeOrange,
                  ),
                )
              : const SizedBox(width: 20, height: 20),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.68),
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModernAvatar(
                imageUrl: _user.avatarUrl,
                initials: _buildInitials(),
                size: 72,
                isOnline: _user.isActive,
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _user.displayName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_user.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: AppTheme.spacingXS),
                            child: Icon(
                              Icons.verified,
                              color: AppTheme.accentBlue,
                              size: 20,
                            ),
                          ),
                        if (_user.isPremium)
                          const Padding(
                            padding: EdgeInsets.only(left: AppTheme.spacingXS),
                            child: Icon(
                              Icons.star_rounded,
                              color: AppTheme.accentPink,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text('@${_user.username}', style: subtitleStyle),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      _user.bio.isNotEmpty
                          ? _user.bio
                          : 'Bu kullanıcı henüz bir bio eklemedi.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildStatsRow(),
          const SizedBox(height: AppTheme.spacingL),
          _buildLevelCard(theme),
          const SizedBox(height: AppTheme.spacingM),
          _buildMetaInfo(theme),
          if (_user.rozetler.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingL),
            Wrap(
              spacing: AppTheme.spacingS,
              runSpacing: AppTheme.spacingS,
              children: _user.rozetler
                  .map((badge) => _buildBadgeChip(badge))
                  .toList(),
            ),
          ],
          if (!_isViewingOwnProfile) ...[
            const SizedBox(height: AppTheme.spacingL),
            _buildProfileActions(context),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileActions(BuildContext context) {
    final borderColor = Colors.white.withValues(alpha: 0.4);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isMessaging ? null : _messageUser,
            icon: _isMessaging
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.mail_outline),
            label: const Text(
              'Mesaj Gönder',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
              foregroundColor: Colors.white,
              side: BorderSide(color: borderColor),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatTile(
          icon: Icons.group_outlined,
          label: 'Takipçi',
          value: _formatCount(_user.followersCount),
        ),
        _buildStatTile(
          icon: Icons.person_add_alt,
          label: 'Takip',
          value: _formatCount(_user.followingCount),
        ),
        _buildStatTile(
          icon: Icons.post_add,
          label: 'Krep',
          value: _formatCount(_user.entriesCount),
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppTheme.cringeOrange, size: 20),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Seviye ${_user.krepLevel} · ${_user.seviyeAdi}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _user.seviyeIlerlemesi,
              minHeight: 6,
              color: AppTheme.cringeOrange,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(ThemeData theme) {
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.7),
    );

    return Wrap(
      spacing: AppTheme.spacingL,
      runSpacing: AppTheme.spacingS,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: AppTheme.spacingXS),
            Text(_user.memberSince, style: textStyle),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: AppTheme.spacingXS),
            Text(_user.lastActiveString, style: textStyle),
          ],
        ),
      ],
    );
  }

  Widget _buildBadgeChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7A18), Color(0xFFAF002D)],
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEntriesSection({
    required BuildContext context,
    required List<CringeEntry> entries,
    required bool isLoading,
  }) {
    final theme = Theme.of(context);

    final children = <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Krepler',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${entries.length} sonuç',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacingM),
    ];

    if (isLoading) {
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXL),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: AppTheme.cringeOrange),
        ),
      );
    } else if (entries.isEmpty) {
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXL),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_rounded,
                color: Colors.white.withValues(alpha: 0.45),
                size: 48,
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Bu kullanıcı henüz krep paylaşmamış.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      for (final entry in entries) {
        final canManageEntry = EntryActionHelper.canManageEntry(entry);
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingL),
            child: ModernCringeCard(
              entry: entry,
              onTap: () => _openEntryDetail(entry),
              onLike: () => _likeEntry(entry),
              onComment: () => _commentOnEntry(entry),
              onMessage: () => _messageEntryAuthor(entry),
              onShare: () => _shareEntry(entry),
              onEdit: canManageEntry ? () => _handleEditEntry(entry) : null,
              onDelete: canManageEntry ? () => _handleDeleteEntry(entry) : null,
              isDeleteInProgress: _deletingEntryIds.contains(entry.id),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  void _openEntryDetail(CringeEntry entry) async {
    HapticFeedback.selectionClick();

    // Görüntülenme sayısını artır
    await CringeEntryService.instance.incrementViewCount(entry.id);

    if (!mounted) return;

    // Detail ekranına git
    await Navigator.pushNamed(context, '/entry-detail', arguments: entry);
  }

  void _likeEntry(CringeEntry entry) async {
    HapticFeedback.lightImpact();

    try {
      // Backend'de like durumunu kontrol et
      final isLiked = await CringeEntryService.instance.isLikedByUser(entry.id);

      if (isLiked) {
        await CringeEntryService.instance.unlikeEntry(entry.id);
      } else {
        await CringeEntryService.instance.likeEntry(entry.id);
      }

      if (!mounted) return;

      // Stream otomatik güncellenecek
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beğeni işlemi başarısız. Tekrar deneyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _commentOnEntry(CringeEntry entry) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EntryCommentsSheet(
        entry: entry,
        onCommentAdded: () {
          if (!mounted) return;
          setState(() {});
        },
      ),
    );
  }

  void _shareEntry(CringeEntry entry) async {
    HapticFeedback.mediumImpact();

    // Share count'u artır
    await CringeEntryService.instance.incrementShareCount(entry.id);

    if (!mounted) return;

    // Share sheet göster
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paylaş',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.message, color: Color(0xFFFFA726)),
              title: const Text(
                'Mesaj Gönder',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/direct-messages');
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Color(0xFFFFA726)),
              title: const Text(
                'Linki Kopyala',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link kopyalandı!'),
                    backgroundColor: Color(0xFFFFA726),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _messageEntryAuthor(CringeEntry entry) async {
    HapticFeedback.mediumImpact();

    final targetId = entry.userId.trim();
    if (targetId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı bilgisi bulunamadı.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final firebaseUser = UserService.instance.firebaseUser;
    if (firebaseUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesaj göndermek için giriş yapmalısın.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final currentId = firebaseUser.uid.trim();
    if (currentId == targetId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kendine mesaj gönderemezsin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      if (UserService.instance.currentUser == null ||
          UserService.instance.currentUser?.id != currentId) {
        await UserService.instance.loadUserData(currentId);
        if (!mounted) return;
      }

      // Entry sahibinin user bilgisini al
      final targetUser = await UserService.instance.getUserById(targetId);
      if (targetUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı bulunamadı.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DirectMessageThreadScreen(
            otherUserId: targetId,
            initialUser: targetUser,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesaj kutusu açılamadı: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _messageUser() async {
    HapticFeedback.mediumImpact();

    final targetId = _user.id.trim();
    if (targetId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu kullanıcı bilgileri yüklenemedi.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final firebaseUser = UserService.instance.firebaseUser;
    if (firebaseUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesaj göndermek için giriş yapmalısın.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final currentId = firebaseUser.uid.trim();
    if (currentId == targetId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kendine mesaj gönderemezsin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isMessaging = true);

    try {
      if (UserService.instance.currentUser == null ||
          UserService.instance.currentUser?.id != currentId) {
        await UserService.instance.loadUserData(currentId);
        if (!mounted) return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DirectMessageThreadScreen(
            otherUserId: targetId,
            initialUser: _user,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesaj kutusu açılamadı: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMessaging = false);
      }
    }
  }

  Future<void> _handleEditEntry(CringeEntry entry) async {
    final edited = await EntryActionHelper.editEntry(context, entry);
    if (!mounted) return;
    if (edited) {
      setState(() {});
    }
  }

  Future<void> _handleDeleteEntry(CringeEntry entry) async {
    if (_deletingEntryIds.contains(entry.id)) {
      return;
    }

    setState(() => _deletingEntryIds.add(entry.id));

    final deleted = await EntryActionHelper.confirmAndDeleteEntry(
      context,
      entry,
    );

    if (!mounted) {
      _deletingEntryIds.remove(entry.id);
      return;
    }

    setState(() => _deletingEntryIds.remove(entry.id));

    if (deleted) {
      setState(() {});
    }
  }

  String _buildInitials() {
    final name = _user.displayName.trim();
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      final buffer = StringBuffer();
      for (final part in parts) {
        if (part.isEmpty) continue;
        buffer.write(part[0]);
        if (buffer.length == 2) break;
      }
      if (buffer.isNotEmpty) {
        return buffer.toString().toUpperCase();
      }
    }

    final username = _user.username.trim();
    if (username.length >= 2) {
      return username.substring(0, 2).toUpperCase();
    }

    return 'CB';
  }

  String _formatCount(int value) {
    if (value < 1000) return value.toString();
    if (value < 1000000) {
      final formatted = (value / 1000).toStringAsFixed(1);
      return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}B';
    }
    final formatted = (value / 1000000).toStringAsFixed(1);
    return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}M';
  }
}
