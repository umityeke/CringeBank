import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../data/store_catalog.dart';
import '../models/try_on_session.dart';
import '../models/user_model.dart';
import '../services/store_service.dart';
import '../services/user_service.dart';
import '../widgets/animated_bubble_background.dart';
import '../widgets/store_inventory_card.dart';
import '../widgets/store_item_artwork.dart';
import '../widgets/try_on_preview_sheet.dart';

class CringeStoreScreen extends StatefulWidget {
  const CringeStoreScreen({super.key});

  @override
  State<CringeStoreScreen> createState() => _CringeStoreScreenState();
}

class _CringeStoreScreenState extends State<CringeStoreScreen> {
  final StoreService _storeService = StoreService.instance;
  final UserService _userService = UserService.instance;
  final Set<String> _processingItems = <String>{};
  final Set<String> _tryOnLoadingItems = <String>{};
  final Map<String, List<String>> _previewUrlCache =
      <String, List<String>>{};
  StreamSubscription<TryOnSession?>? _tryOnSubscription;
  TryOnSession? _currentTryOnSession;

  @override
  void initState() {
    super.initState();
    _currentTryOnSession = _storeService.activeTryOnSession;
    _tryOnSubscription =
        _storeService.tryOnSessionStream.listen((TryOnSession? session) {
      if (!mounted) return;
      setState(() {
        _currentTryOnSession = session;
      });
    });
  }

  @override
  void dispose() {
    _tryOnSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBubbleBackground(
        child: SafeArea(
          child: StreamBuilder<User?>(
            stream: _userService.userDataStream,
            initialData: _userService.currentUser,
            builder: (context, snapshot) {
              final user = snapshot.data ?? _userService.currentUser;
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting &&
                      user == null;

              if (isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                );
              }

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    centerTitle: false,
                    iconTheme: const IconThemeData(color: Colors.white70),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Cringe Store',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroBanner(user),
                          if (user != null) ...[
                            const SizedBox(height: 18),
                            StoreInventoryCard(user: user),
                          ],
                          const SizedBox(height: 24),
                          _buildCategories(user),
                          const SizedBox(height: 24),
                          _buildPackagesSection(user),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(User? user) {
  final ownedCount = user?.ownedStoreItems.length ?? 0;
  final subtitle = user != null
    ? 'Envanterinde $ownedCount ürün var. Yeni efektlerle profilini güçlendir.'
    : 'Giriş yaparak satın aldığın efektleri profilinde hemen kullan.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1B2E), Color(0xFF171321)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CRINGE BANKASI · Pazar Alanı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: StoreCatalog.categories
                .map(
                  (category) => _CategoryChip(
                    icon: category.icon,
                    label: category.title,
                    color: category.color,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(User? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: StoreCatalog.categories
          .map(
            (category) => _buildCategoryCard(category, user),
          )
          .toList(),
    );
  }

  Widget _buildCategoryCard(StoreCategory category, User? user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
  color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: category.color.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  category.icon,
                  color: category.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (category.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      category.subtitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < category.items.length; i++)
            _buildItemCard(
              item: category.items[i],
              accentColor: category.color,
              user: user,
              margin: EdgeInsets.only(top: i == 0 ? 0 : 14),
            ),
        ],
      ),
    );
  }

  Widget _buildPackagesSection(User? user) {
    if (StoreCatalog.packages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💎 Paketler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < StoreCatalog.packages.length; i++)
          _buildItemCard(
            item: StoreCatalog.packages[i].item,
            accentColor: StoreCatalog.packages[i].color,
            user: user,
            margin: EdgeInsets.only(top: i == 0 ? 0 : 16),
          ),
      ],
    );
  }

  Widget _buildItemCard({
    required StoreItem item,
    required Color accentColor,
    required User? user,
    EdgeInsetsGeometry margin = const EdgeInsets.only(top: 14),
  }) {
  final ownedItems = user?.ownedStoreItems ?? const <String>[];
  final owned = ownedItems.contains(item.id);
    final isEquipped =
        user != null ? _storeService.isEquipped(user, item) : false;
    final canEquip =
        user != null ? _storeService.canEquip(user, item) : false;
    final busy = _processingItems.contains(item.id);
  final tryOnBusy = _tryOnLoadingItems.contains(item.id);
  final tryOnActive = _currentTryOnSession?.itemId == item.id &&
    (_currentTryOnSession?.isActive ?? false);

    final statusChips = <Widget>[];
    if (owned) {
      statusChips.add(
        _StatusPill(
          label: 'Sahip',
          color: accentColor.withValues(alpha: 0.2),
          textColor: Colors.white,
        ),
      );
    }
    if (isEquipped) {
      statusChips.add(
        const _StatusPill(
          label: 'Aktif',
          color: Colors.white,
          textColor: Colors.black,
        ),
      );
    }
    if (item.highlighted) {
      statusChips.add(
        const _StatusPill(
          label: 'Popüler',
          color: Color(0xFF7C4DFF),
          textColor: Colors.white,
        ),
      );
    }
    if (!owned && tryOnActive) {
      statusChips.add(
        _StatusPill(
          label: 'Deneme aktif',
          color: accentColor.withValues(alpha: 0.16),
          textColor: accentColor,
        ),
      );
    }

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
  color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(
            alpha: item.highlighted ? 0.6 : 0.2,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StoreItemArtworkCard(
            item: item,
            isOwned: owned,
            isEquipped: isEquipped,
            dimmed: !owned && !isEquipped,
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
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.tag != null && item.tag!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _StatusPill(
                        label: item.tag!,
                        color: accentColor.withValues(alpha: 0.16),
                        textColor: accentColor,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.priceLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.note!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (item.features.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...item.features.map(
                    (feature) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (statusChips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: statusChips,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildActionArea(
            item: item,
            user: user,
            accentColor: accentColor,
            busy: busy,
            tryOnBusy: tryOnBusy,
            owned: owned,
            isEquipped: isEquipped,
            canEquip: canEquip,
            tryOnActive: tryOnActive,
          ),
        ],
      ),
    );
  }

  Widget _buildActionArea({
    required StoreItem item,
    required User? user,
    required Color accentColor,
    required bool busy,
    required bool tryOnBusy,
    required bool owned,
    required bool isEquipped,
    required bool canEquip,
    required bool tryOnActive,
  }) {
    if (busy) {
      return const SizedBox(
        width: 110,
        height: 48,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (user == null) {
      return SizedBox(
        width: 140,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _primaryButton(
              label: 'Satın al',
              color: accentColor,
              onPressed: _showRequiresLogin,
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              label: 'Önizle & Dene',
              color: accentColor,
              onPressed: _showRequiresLogin,
            ),
          ],
        ),
      );
    }

    if (!owned) {
      final tryOnLabel = tryOnActive ? 'Önizlemeyi Aç' : 'Önizle & Dene';
      return SizedBox(
        width: 140,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _primaryButton(
              label: 'Satın al',
              color: accentColor,
              onPressed: () => _showPurchaseSheet(item),
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              label: tryOnLabel,
              color: accentColor,
              onPressed: tryOnBusy ? () {} : () => _handleTryOn(item),
              busy: tryOnBusy,
              active: tryOnActive,
            ),
          ],
        ),
      );
    }

    if (isEquipped) {
      return _statusBadge(
        icon: Icons.check_circle,
        label: 'Aktif',
  background: accentColor.withValues(alpha: 0.14),
        textColor: accentColor,
  borderColor: accentColor.withValues(alpha: 0.4),
      );
    }

    if (canEquip) {
      return SizedBox(
        width: 120,
        child: OutlinedButton(
          onPressed: () => _handleEquip(item),
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor.withValues(alpha: 0.8)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text(
            'Aktifleştir',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return _statusBadge(
      icon: Icons.inventory_2_outlined,
      label: 'Sende',
  background: Colors.white.withValues(alpha: 0.04),
  textColor: Colors.white,
  borderColor: Colors.white.withValues(alpha: 0.18),
    );
  }

  Widget _primaryButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 120,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required Color color,
    VoidCallback? onPressed,
    bool busy = false,
    bool active = false,
  }) {
    if (busy) {
      return const SizedBox(
        width: 140,
        height: 42,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.0),
        ),
      );
    }

    return SizedBox(
      width: 140,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: active ? color : color,
          backgroundColor:
              active ? color.withValues(alpha: 0.12) : Colors.transparent,
          side: BorderSide(color: color.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? Icons.timelapse_rounded : Icons.visibility_outlined,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge({
    required IconData icon,
    required String label,
    required Color background,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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

  void _showRequiresLogin() {
    _showSnack(
      'Satın almak için giriş yapman gerekiyor.',
      icon: Icons.lock_outline,
      accentColor: Colors.orangeAccent,
    );
  }

  void _showPurchaseSheet(StoreItem item) {
    final accent = _accentColorFor(item);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PurchaseSheet(
        item: item,
        accentColor: accent,
        onConfirm: () {
          Navigator.of(context).pop();
          _handlePurchase(item);
        },
      ),
    );
  }

  Future<void> _handlePurchase(StoreItem item) async {
    setState(() {
      _processingItems.add(item.id);
    });

    try {
      await _storeService.purchaseItem(item);
      if (!mounted) return;
      _showSnack(
        '${item.name} satın alındı! 🎉',
        icon: Icons.check_circle,
        accentColor: _accentColorFor(item),
      );
    } catch (error) {
      if (!mounted) return;
      _showErrorSnack(error);
    } finally {
      if (mounted) {
        setState(() {
          _processingItems.remove(item.id);
        });
      } else {
        _processingItems.remove(item.id);
      }
    }
  }

  Future<void> _handleTryOn(StoreItem item) async {
    final user = _userService.currentUser;
    if (user == null) {
      _showRequiresLogin();
      return;
    }

    final existingSession = _currentTryOnSession;
    if (existingSession != null &&
        existingSession.itemId == item.id &&
        existingSession.isActive) {
      final previewUrls = await _ensurePreviewUrls(item);
      if (!mounted) return;
      await _showTryOnSheet(
        item: item,
        session: existingSession,
        previewUrls: previewUrls,
      );
      return;
    }

    setState(() {
      _tryOnLoadingItems.add(item.id);
    });

    try {
      final session = await _storeService.startTryOn(item);
      final previewUrls = await _ensurePreviewUrls(item);
      if (!mounted) return;
      await _showTryOnSheet(
        item: item,
        session: session,
        previewUrls: previewUrls,
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.message ?? 'Try-on oturumu başlatılamadı.';
      _showSnack(
        message,
        icon: Icons.error_outline,
        accentColor: Colors.redAccent,
      );
    } catch (error) {
      if (!mounted) return;
      _showErrorSnack(error);
    } finally {
      if (mounted) {
        setState(() {
          _tryOnLoadingItems.remove(item.id);
        });
      } else {
        _tryOnLoadingItems.remove(item.id);
      }
    }
  }

  Future<List<String>> _ensurePreviewUrls(StoreItem item) async {
    final cached = _previewUrlCache[item.id];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final urls = await _storeService.resolvePreviewImageUrls(item);
    _previewUrlCache[item.id] = urls;
    return urls;
  }

  Future<void> _showTryOnSheet({
    required StoreItem item,
    required TryOnSession session,
    required List<String> previewUrls,
  }) async {
    final previewAssets = _storeService.previewAssetsFor(item);
    final config = _storeService.activeTryOnConfig ?? item.tryOnConfig;
    var triesRemaining = _storeService.activeTryOnTriesRemainingToday;
    if (triesRemaining < 0) {
      triesRemaining = 0;
    } else if (triesRemaining > config.maxDailyTries) {
      triesRemaining = config.maxDailyTries;
    }

    var cooldownRemaining = _storeService.activeTryOnCooldownRemainingSec;
    if (cooldownRemaining < 0) {
      cooldownRemaining = 0;
    } else if (cooldownRemaining > config.cooldownSec) {
      cooldownRemaining = config.cooldownSec;
    }
    final reusedSession = _storeService.reusedTryOnSession;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return TryOnPreviewSheet(
          item: item,
          session: session,
          previewUrls: previewUrls,
          previewAssets: previewAssets,
          config: config,
          triesRemaining: triesRemaining,
          cooldownRemaining: cooldownRemaining,
          reusedSession: reusedSession,
          onPurchase: () {
            Navigator.of(context).pop();
            _showPurchaseSheet(item);
          },
        );
      },
    );
  }

  Future<void> _handleEquip(StoreItem item) async {
    setState(() {
      _processingItems.add(item.id);
    });

    try {
      await _storeService.equipItem(item);
      if (!mounted) return;
      _showSnack(
        '${item.name} aktif edildi.',
        icon: Icons.auto_awesome,
        accentColor: _accentColorFor(item),
      );
    } catch (error) {
      if (!mounted) return;
      _showErrorSnack(error);
    } finally {
      if (mounted) {
        setState(() {
          _processingItems.remove(item.id);
        });
      } else {
        _processingItems.remove(item.id);
      }
    }
  }

  void _showErrorSnack(Object error) {
    final message = error is StateError ? error.message : error.toString();
    _showSnack(
      message,
      icon: Icons.error_outline,
      accentColor: Colors.redAccent,
    );
  }

  void _showSnack(
    String message, {
    required IconData icon,
    required Color accentColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Color _accentColorFor(StoreItem item) {
    if (item.artwork.colors.isNotEmpty) {
      return item.artwork.colors.last;
    }
    return Colors.orangeAccent;
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
  color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
  border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PurchaseSheet extends StatelessWidget {
  final StoreItem item;
  final Color accentColor;
  final VoidCallback onConfirm;

  const _PurchaseSheet({
    required this.item,
    required this.accentColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1B2E), Color(0xFF171321)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: StoreItemArtworkCard(
                item: item,
                isOwned: true,
                isEquipped: true,
                size: 96,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toplam tutar: ${item.priceLabel}',
              style: TextStyle(
                color: accentColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (item.description != null &&
                item.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                item.description!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Vazgeç'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Satın al',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

