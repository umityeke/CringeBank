import 'package:flutter/material.dart';
import '../services/cringe_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_bubble_background.dart';

class CringeNotificationItem {
  CringeNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestampLabel,
    required this.icon,
    required this.accentColor,
    this.category,
    this.isUnread = true,
  });

  final String id;
  final String title;
  final String message;
  final String timestampLabel;
  final IconData icon;
  final Color accentColor;
  final String? category;
  final bool isUnread;

  CringeNotificationItem copyWith({
    bool? isUnread,
  }) {
    return CringeNotificationItem(
      id: id,
      title: title,
      message: message,
      timestampLabel: timestampLabel,
      icon: icon,
      accentColor: accentColor,
      category: category,
      isUnread: isUnread ?? this.isUnread,
    );
  }
}

class ModernNotificationsScreen extends StatefulWidget {
  const ModernNotificationsScreen({
    super.key,
    required this.notifications,
  });

  final List<CringeNotificationItem> notifications;

  @override
  State<ModernNotificationsScreen> createState() =>
      _ModernNotificationsScreenState();
}

class _ModernNotificationsScreenState extends State<ModernNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _headerOpacity;
  late final Animation<double> _listOpacity;
  String? _errorMessage;
  bool _isInitialized = false;
  late List<CringeNotificationItem> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = widget.notifications
        .map((item) => item.copyWith())
        .toList(growable: false);
    _setupAnimations();
    _initializeNotifications();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _headerOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _listOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeNotifications() async {
    if (mounted) {
      setState(() {
        _errorMessage = null;
        _isInitialized = false;
      });
    }

    try {
      await CringeNotificationService.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitialized = false;
        _errorMessage =
            'Bildirim servisi başlatılamadı. Lütfen izinleri kontrol et.';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _unreadCount =>
      _notifications.where((item) => item.isUnread).length;

  void _toggleRead(int index) {
    setState(() {
      final item = _notifications[index];
      _notifications[index] = item.copyWith(isUnread: !item.isUnread);
    });
  }

  void _markAllAsRead() {
    setState(() {
      _notifications = _notifications
          .map((item) => item.copyWith(isUnread: false))
          .toList(growable: false);
    });
  }

  Future<void> _sendTestNotification() async {
    try {
      await CringeNotificationService.sendTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test bildirimi gönderildi! 🎉'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test bildirimi gönderilemedi: $error'),
        ),
      );
    }
  }

  void _closeScreen() {
    Navigator.of(context).pop(_notifications);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _closeScreen();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: AnimatedBubbleBackground(
          bubbleCount: 24,
          bubbleColor: Colors.white.withOpacity(0.08),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _headerOpacity,
                    child: _buildHeader(),
                  ),
                  const SizedBox(height: 18),
                  if (_errorMessage != null)
                    _buildErrorBanner(_errorMessage!),
                  Expanded(
                    child: FadeTransition(
                      opacity: _listOpacity,
                      child: _notifications.isEmpty
                          ? _buildEmptyState()
                          : _buildNotificationList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFooter(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildGlassIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: _closeScreen,
          tooltip: 'Geri dön',
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bildirimler',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
        _unreadCount > 0
          ? '$_unreadCount yeni bildirim'
          : 'Tüm bildirimleri görüntüledin',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (_unreadCount > 0)
          TextButton(
            onPressed: _markAllAsRead,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.secondaryColor,
            ),
            child: const Text('Hepsini okundu yap'),
          ),
      ],
    );
  }

  Widget _buildNotificationList() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final item = _notifications[index];
        return _NotificationCard(
          item: item,
          onToggleRead: () => _toggleRead(index),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: _notifications.length,
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Expanded(
          child: _buildGlassButton(
            label: 'Test bildirimi gönder',
            icon: Icons.play_arrow_rounded,
            onTap: _sendTestNotification,
            isEnabled: _isInitialized,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGlassButton(
            label: 'Bildirim ayarları',
            icon: Icons.tune_rounded,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bildirim ayarları yakında!'),
                ),
              );
            },
            isEnabled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.heroGradient,
              boxShadow: AppTheme.glowShadow(AppTheme.secondaryColor),
            ),
            child: const Icon(
              Icons.notifications_off_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Burada şimdilik sakinlik var',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Yeni bir cringe olduğunda seni ilk biz haberdar edeceğiz.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
  color: AppTheme.statusError.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.statusError.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.statusError,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.statusError,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _initializeNotifications,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.statusError,
            ),
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isEnabled ? onTap : null,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withOpacity(0.08),
              border: Border.all(
                color: Colors.white.withOpacity(0.14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.23),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onToggleRead,
  });

  final CringeNotificationItem item;
  final VoidCallback onToggleRead;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppAnimations.fast,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppTheme.cardColor.withOpacity(
          item.isUnread ? 0.75 : 0.5,
        ),
        border: Border.all(
          color: item.isUnread
              ? item.accentColor.withOpacity(0.6)
              : Colors.white.withOpacity(0.1),
          width: 1.2,
        ),
        boxShadow: AppTheme.glowShadow(
          item.isUnread ? item.accentColor : Colors.black,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  item.accentColor.withOpacity(0.85),
                  item.accentColor.withOpacity(0.45),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(item.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.timestampLabel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (item.category != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: item.accentColor.withOpacity(0.2),
                      border: Border.all(
                        color: item.accentColor.withOpacity(0.18),
                      ),
                    ),
                    child: Text(
                      item.category!,
                      style: TextStyle(
                        color: item.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onToggleRead,
                    icon: Icon(
                      item.isUnread
                          ? Icons.radio_button_unchecked
                          : Icons.check_circle,
                      color: item.isUnread
                          ? Colors.white70
                          : AppTheme.secondaryColor,
                      size: 18,
                    ),
                    label: Text(
                      item.isUnread ? 'Okundu işaretle' : 'Okunmadı yap',
                      style: TextStyle(
                        color: item.isUnread
                            ? Colors.white70
                            : AppTheme.secondaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
