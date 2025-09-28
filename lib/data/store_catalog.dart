import 'package:flutter/material.dart';

/// Ürünlerin profil üzerindeki etkisini belirleyen türler.
enum StoreItemEffectType {
  none,
  frame,
  badge,
  nameColor,
  profileBackground,
}

enum StoreItemType {
  subscription,
  frame,
  profileEffect,
  badge,
  tool,
  bundle,
}

class StoreItemEffect {
  final StoreItemEffectType type;
  final LinearGradient? frameGradient;
  final double frameBorderWidth;
  final Color? nameColor;
  final IconData? badgeIcon;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final String? badgeLabel;
  final List<Color>? backgroundGlow;

  const StoreItemEffect({
    required this.type,
    this.frameGradient,
    this.frameBorderWidth = 4,
    this.nameColor,
    this.badgeIcon,
    this.badgeColor,
    this.badgeTextColor,
    this.badgeLabel,
    this.backgroundGlow,
  });

  static const none = StoreItemEffect(type: StoreItemEffectType.none);
}

class StoreItemArtwork {
  final List<Color> colors;
  final IconData icon;
  final Alignment begin;
  final Alignment end;
  final double blurSigma;

  const StoreItemArtwork({
    required this.colors,
    required this.icon,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.blurSigma = 18,
  });
}

class StoreItem {
  final String id;
  final String name;
  final String priceLabel;
  final String categoryId;
  final StoreItemType type;
  final StoreItemEffect effect;
  final StoreItemArtwork artwork;
  final String? description;
  final String? tag;
  final String? note;
  final bool highlighted;
  final List<String> features;

  const StoreItem({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.categoryId,
    required this.type,
    required this.effect,
    required this.artwork,
    this.description,
    this.tag,
    this.note,
    this.highlighted = false,
    this.features = const [],
  });
}

class StoreCategory {
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final List<StoreItem> items;

  const StoreCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    this.subtitle,
    this.items = const [],
  });
}

class StorePackage {
  final StoreItem item;
  final Color color;

  const StorePackage({
    required this.item,
    required this.color,
  });
}

class StoreCatalog {
  static final List<StoreItem> _allItems = [
    // Mor Tik abonelikleri
    StoreItem(
      id: 'mor_tik_basic',
      name: 'Mor Tik',
      priceLabel: '29.99₺/ay',
      categoryId: 'mor_tik',
      type: StoreItemType.subscription,
      description: 'Premium rozet ve öncelikli görünürlük',
      effect: StoreItemEffect(
        type: StoreItemEffectType.badge,
        badgeIcon: Icons.bolt_rounded,
        badgeColor: const Color(0xFF7C4DFF),
        badgeTextColor: Colors.white,
        badgeLabel: 'Mor Tik',
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF512DA8), Color(0xFF9575CD)],
        icon: Icons.verified_outlined,
      ),
      highlighted: true,
    ),
    StoreItem(
      id: 'mor_tik_plus',
      name: 'Mor Plus',
      priceLabel: '49.99₺/ay',
      categoryId: 'mor_tik',
      type: StoreItemType.subscription,
      description: 'Ekstra keşfet vitrini ve günde 5 boost',
      effect: StoreItemEffect(
        type: StoreItemEffectType.badge,
        badgeIcon: Icons.auto_awesome_rounded,
        badgeColor: const Color(0xFFB388FF),
        badgeTextColor: Colors.black,
        badgeLabel: 'Mor Plus',
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF7B1FA2), Color(0xFFE040FB)],
        icon: Icons.auto_awesome_rounded,
      ),
    ),
    StoreItem(
      id: 'mor_tik_elite',
      name: 'Mor Elite',
      priceLabel: '99.99₺/ay',
      categoryId: 'mor_tik',
      type: StoreItemType.subscription,
      description: 'Özel etkinlik davetleri ve sınırsız boost',
      effect: StoreItemEffect(
        type: StoreItemEffectType.badge,
        badgeIcon: Icons.workspace_premium_outlined,
        badgeColor: const Color(0xFF311B92),
        badgeTextColor: Colors.white,
        badgeLabel: 'Mor Elite',
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF4527A0), Color(0xFFB388FF)],
        icon: Icons.workspace_premium_outlined,
      ),
    ),
    StoreItem(
      id: 'mor_tik_yearly',
      name: 'Mor Yıllık',
      priceLabel: '299₺',
      categoryId: 'mor_tik',
      type: StoreItemType.subscription,
      tag: '2 ay bedava',
      description: 'Tüm yıl boyunca Mor Tik ayrıcalıkları',
      effect: StoreItemEffect(
        type: StoreItemEffectType.badge,
        badgeIcon: Icons.diamond_rounded,
        badgeColor: const Color(0xFF9575CD),
        badgeTextColor: Colors.white,
        badgeLabel: 'Mor Yıllık',
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF673AB7), Color(0xFFD1C4E9)],
        icon: Icons.diamond_rounded,
      ),
    ),

    // Çerçeveler
    StoreItem(
      id: 'frame_classic',
      name: 'Klasik Set (5 adet)',
      priceLabel: '9.99₺',
      categoryId: 'personalization',
      type: StoreItemType.frame,
      tag: 'Çerçeve',
      effect: StoreItemEffect(
        type: StoreItemEffectType.frame,
        frameGradient: const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
        ),
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
        icon: Icons.crop_square_rounded,
      ),
    ),
    StoreItem(
      id: 'frame_animated',
      name: 'Animasyonlu Çerçeve',
      priceLabel: '19.99₺',
      categoryId: 'personalization',
      type: StoreItemType.frame,
      tag: 'Çerçeve',
      effect: StoreItemEffect(
        type: StoreItemEffectType.frame,
        frameGradient: const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF7E57C2), Color(0xFFFFA726)],
        ),
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF42A5F5), Color(0xFF7E57C2)],
        icon: Icons.all_inclusive_rounded,
      ),
      note: 'Dalgalanan neon animasyon',
    ),
    StoreItem(
      id: 'frame_premium',
      name: 'Premium Çerçeve',
      priceLabel: '24.99₺',
      categoryId: 'personalization',
      type: StoreItemType.frame,
      tag: 'Çerçeve',
      effect: StoreItemEffect(
        type: StoreItemEffectType.frame,
        frameGradient: const LinearGradient(
          colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFFD81B60), Color(0xFF9C27B0)],
        icon: Icons.style_rounded,
      ),
    ),
    StoreItem(
      id: 'frame_exclusive',
      name: 'Mor Exclusive',
      priceLabel: '34.99₺',
      categoryId: 'personalization',
      type: StoreItemType.frame,
      tag: 'Çerçeve',
      effect: StoreItemEffect(
        type: StoreItemEffectType.frame,
        frameGradient: const LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF9575CD), Color(0xFFB39DDB)],
        ),
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF7C4DFF), Color(0xFFB39DDB)],
        icon: Icons.hexagon_outlined,
      ),
      highlighted: true,
    ),

    // Profil efektleri
    StoreItem(
      id: 'profile_color',
      name: 'Renkli İsim',
      priceLabel: '12.99₺',
      categoryId: 'personalization',
      type: StoreItemType.profileEffect,
      tag: 'Profil',
      effect: StoreItemEffect(
        type: StoreItemEffectType.nameColor,
        nameColor: const Color(0xFFFFC107),
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFFFFA000), Color(0xFFFFD54F)],
        icon: Icons.format_color_text_rounded,
      ),
    ),
    StoreItem(
      id: 'profile_animated',
      name: 'Animasyonlu Profil',
      priceLabel: '19.99₺',
      categoryId: 'personalization',
      type: StoreItemType.profileEffect,
      tag: 'Profil',
      effect: StoreItemEffect(
        type: StoreItemEffectType.profileBackground,
        backgroundGlow: [
          const Color(0xFF00BCD4),
          const Color(0xFF7C4DFF),
          const Color(0xFFFFC107),
        ],
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF26C6DA), Color(0xFF7E57C2)],
        icon: Icons.blur_circular_rounded,
      ),
      note: 'Avatar arkası dinamik ışık',
    ),
    StoreItem(
      id: 'profile_background',
      name: 'Özel Arkaplan',
      priceLabel: '14.99₺',
      categoryId: 'personalization',
      type: StoreItemType.profileEffect,
      tag: 'Profil',
      effect: StoreItemEffect(
        type: StoreItemEffectType.profileBackground,
        backgroundGlow: [
          const Color(0xFF311B92),
          const Color(0xFFFD5678),
        ],
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF311B92), Color(0xFFE91E63)],
        icon: Icons.gradient_rounded,
      ),
    ),

    // Rozetler
    StoreItem(
      id: 'badge_basic',
      name: 'Temel Rozet Paketi',
      priceLabel: '14.99₺',
      categoryId: 'badges',
      type: StoreItemType.badge,
      effect: StoreItemEffect(
        type: StoreItemEffectType.badge,
        badgeIcon: Icons.emoji_events_outlined,
        badgeColor: const Color(0xFFFFD54F),
        badgeTextColor: Colors.black,
        badgeLabel: 'Temel',
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFFFFF176), Color(0xFFFFC107)],
        icon: Icons.emoji_events_outlined,
      ),
    ),
    StoreItem(
      id: 'badge_premium',
      name: 'Premium Rozetler',
      priceLabel: '29.99₺',
      categoryId: 'badges',
      type: StoreItemType.badge,
      effect: StoreItemEffect(
        type: StoreItemEffectType.badge,
        badgeIcon: Icons.workspace_premium,
        badgeColor: const Color(0xFFFFAB40),
        badgeTextColor: Colors.black,
        badgeLabel: 'Premium',
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFFFFAB40), Color(0xFFFFD180)],
        icon: Icons.workspace_premium_outlined,
      ),
    ),
    StoreItem(
      id: 'badge_lord',
      name: '"Krep Lord" Rozeti',
      priceLabel: '49.99₺',
      categoryId: 'badges',
      type: StoreItemType.badge,
      effect: StoreItemEffect(
        type: StoreItemEffectType.badge,
        badgeIcon: Icons.shield_moon_outlined,
        badgeColor: const Color(0xFFAB47BC),
        badgeTextColor: Colors.white,
        badgeLabel: 'Krep Lord',
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF8E24AA), Color(0xFFCE93D8)],
        icon: Icons.shield_moon_outlined,
      ),
      highlighted: true,
    ),
    StoreItem(
      id: 'badge_custom',
      name: 'Özel Tasarım',
      priceLabel: '99.99₺',
      categoryId: 'badges',
      type: StoreItemType.badge,
      tag: 'Limitli',
      effect: StoreItemEffect(
        type: StoreItemEffectType.badge,
        badgeIcon: Icons.auto_fix_high,
        badgeColor: const Color(0xFFFF4081),
        badgeTextColor: Colors.white,
        badgeLabel: 'Özel',
      ),
      artwork: const StoreItemArtwork(
        colors: [Color(0xFFFF4081), Color(0xFFFF80AB)],
        icon: Icons.auto_fix_high,
      ),
    ),

    // Araçlar
    StoreItem(
      id: 'tool_filters',
      name: 'Pro Filtreler',
      priceLabel: '14.99₺',
      categoryId: 'tools',
      type: StoreItemType.tool,
      description: 'Krep paylaşımlarına sinematik filtreler',
      effect: StoreItemEffect.none,
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF26C6DA), Color(0xFF00ACC1)],
        icon: Icons.filter_vintage_rounded,
      ),
    ),
    StoreItem(
      id: 'tool_stickers',
      name: 'Sticker Pack',
      priceLabel: '19.99₺',
      categoryId: 'tools',
      type: StoreItemType.tool,
      description: '50+ özel sticker ve GIF paketi',
      effect: StoreItemEffect.none,
      artwork: const StoreItemArtwork(
        colors: [Color(0xFFFF7043), Color(0xFFFFB74D)],
        icon: Icons.emoji_emotions_outlined,
      ),
    ),
    StoreItem(
      id: 'tool_watermark',
      name: 'Watermark Kaldırma',
      priceLabel: '29.99₺',
      categoryId: 'tools',
      type: StoreItemType.tool,
      description: 'Paylaşımlarında Cringe Bankası imzası görünmesin',
      note: 'İçeriğin tertemiz kalsın',
      effect: StoreItemEffect.none,
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF26A69A), Color(0xFF80CBC4)],
        icon: Icons.water_drop_outlined,
      ),
    ),
    StoreItem(
      id: 'tool_hd',
      name: 'HD Export',
      priceLabel: '19.99₺',
      categoryId: 'tools',
      type: StoreItemType.tool,
      description: 'Kreplerini 4K çözünürlükte indir',
      effect: StoreItemEffect.none,
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
        icon: Icons.high_quality_outlined,
      ),
    ),

    // Paketler (StoreItemType.bundle)
    StoreItem(
      id: 'package_starter',
      name: '"Başlangıç" Paketi',
      priceLabel: '39.99₺',
      categoryId: 'packages',
      type: StoreItemType.bundle,
      description: 'Mor Tik (1 ay), 5 çerçeve ve temel rozetler',
      effect: StoreItemEffect.none,
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF8E24AA), Color(0xFFBA68C8)],
        icon: Icons.start_rounded,
      ),
      features: const [
        '✓ Mor Tik (1 ay)',
        '✓ 5 Çerçeve',
        '✓ Temel Rozetler',
      ],
      highlighted: true,
    ),
    StoreItem(
      id: 'package_pro',
      name: '"Pro" Paketi',
      priceLabel: '99.99₺',
      categoryId: 'packages',
      type: StoreItemType.bundle,
      description: 'Mor Plus (2 ay), tüm çerçeveler, tüm filtreler, premium rozetler',
      effect: StoreItemEffect.none,
      artwork: const StoreItemArtwork(
        colors: [Color(0xFF00ACC1), Color(0xFF4DD0E1)],
        icon: Icons.workspace_premium_outlined,
      ),
      features: const [
        '✓ Mor Plus (2 ay)',
        '✓ Tüm Çerçeveler',
        '✓ Tüm Filtreler',
        '✓ Premium Rozetler',
      ],
      highlighted: true,
    ),
  ];

  static final List<StoreCategory> categories = [
    StoreCategory(
      id: 'mor_tik',
      title: '💜 Mor Tik',
      subtitle: 'Abonelikler',
      icon: Icons.verified_outlined,
      color: const Color(0xFF7C4DFF),
      items: _filterByCategory('mor_tik'),
    ),
    StoreCategory(
      id: 'personalization',
      title: '🎨 Kişiselleştirme',
      subtitle: 'Çerçeveler & Profil',
      icon: Icons.color_lens_outlined,
      color: const Color(0xFF42A5F5),
      items: _filterByCategory('personalization'),
    ),
    StoreCategory(
      id: 'badges',
      title: '🏆 Rozetler',
      subtitle: 'İtibar göstergeleri',
      icon: Icons.emoji_events_outlined,
      color: const Color(0xFFFFCA28),
      items: _filterByCategory('badges'),
    ),
    StoreCategory(
      id: 'tools',
      title: '📸 Araçlar',
      subtitle: 'Paylaşım güçlendiriciler',
      icon: Icons.auto_awesome_outlined,
      color: const Color(0xFF26C6DA),
      items: _filterByCategory('tools'),
    ),
  ];

  static final List<StorePackage> packages = [
    StorePackage(
      color: const Color(0xFF8E24AA),
      item: _findById('package_starter')!,
    ),
    StorePackage(
      color: const Color(0xFF00ACC1),
      item: _findById('package_pro')!,
    ),
  ];

  static List<StoreItem> _filterByCategory(String categoryId) {
    return _allItems
        .where((item) => item.categoryId == categoryId)
        .toList(growable: false);
  }

  static StoreItem? _findById(String id) {
    try {
      return _allItems.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  static StoreItem? itemById(String id) => _findById(id);

  static StoreItemEffect effectForItem(String? id) {
    if (id == null) return StoreItemEffect.none;
    return _findById(id)?.effect ?? StoreItemEffect.none;
  }

  static Iterable<StoreItem> itemsFromIds(Iterable<String> ids) {
    return ids.map(_findById).whereType<StoreItem>();
  }
}
