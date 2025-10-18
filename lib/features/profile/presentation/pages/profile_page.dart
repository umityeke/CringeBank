import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cringebank/core/config/theme_mode_controller.dart';
import 'package:cringebank/core/session/session_providers.dart';
import 'package:cringebank/features/login/application/login_providers.dart';
import 'package:cringebank/shared/widgets/app_card.dart';

import '../../domain/models/profile_activity.dart';
import '../../domain/models/profile_badge.dart';
import '../../domain/models/profile_connection.dart';
import '../../domain/models/profile_highlight.dart';
import '../../domain/models/profile_insight.dart';
import '../../domain/models/profile_opportunity.dart';
import '../../domain/models/profile_social_link.dart';
import '../../domain/models/user_profile.dart';
import '../../profile_providers.dart';
import '../../application/tag_approval_providers.dart';
import '../../domain/models/tag_approval_entry.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Yeni cringe paylaş',
            onPressed: () => context.push('/profile/compose'),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Yeni kullanıcı kaydı',
            onPressed: () => _navigateToRegistration(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış yap',
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => _ProfileContent(profile: profile),
        error: (error, stackTrace) => _ProfileError(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

void _navigateToRegistration(BuildContext context) {
  context.push('/register');
}

void _logout(BuildContext context, WidgetRef ref) {
  unawaited(ref.read(sessionControllerProvider.notifier).reset());
  ref.read(loginControllerProvider.notifier).reset();
  context.go('/login');
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final avatarData = _decodeImage(profile.avatarUrl);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: avatarData != null
                          ? MemoryImage(avatarData)
                          : null,
                      child: avatarData == null
                          ? const Icon(Icons.person_outline, size: 48)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.handle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(profile.bio, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _StatChip(
                                label: 'Takipçi',
                                value: _formatNumber(profile.followers),
                              ),
                              const SizedBox(width: 12),
                              _StatChip(
                                label: 'Takip',
                                value: _formatNumber(profile.following),
                              ),
                              const SizedBox(width: 12),
                              _StatChip(
                                label: 'Toplam CG',
                                value:
                                    '${_formatNumber(profile.totalSalesCg)} CG',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _InsightsStrip(insights: profile.insights),
                const SizedBox(height: 20),
                const _ThemePreferenceSection(),
                const SizedBox(height: 16),
                const _TagApprovalSection(),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Text('Başarılar', style: theme.textTheme.titleMedium),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 158,
            child: _HighlightCarousel(highlights: profile.highlights),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Öne Çıkan Ürünler',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: profile.featuredProducts.isEmpty
                ? Text(
                    'Henüz vitrine eklenmiş ürün yok.',
                    style: theme.textTheme.bodyMedium,
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: profile.featuredProducts
                        .map<Widget>(
                          (product) => Chip(
                            label: Text(product),
                            avatar: const Icon(Icons.star, size: 18),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Text('Networküm', style: theme.textTheme.titleMedium),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 120,
            child: _ConnectionsStrip(connections: profile.connections),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              'İş Birliği Fırsatları',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _OpportunitiesSection(opportunities: profile.opportunities),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Text('Rozetlerim', style: theme.textTheme.titleMedium),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _BadgesSection(badges: profile.badges),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Sosyal Bağlantılar',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SocialLinksSection(links: profile.socialLinks),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Text('Güncel Aktivite', style: theme.textTheme.titleMedium),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _ActivityList(activities: profile.recentActivities),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Uint8List? _decodeImage(String url) {
    if (!url.startsWith('data:image')) {
      return null;
    }
    return Uri.parse(url).data?.contentAsBytes();
  }

  String _formatNumber(int value) {
    if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagApprovalSection extends ConsumerWidget {
  const _TagApprovalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tagApprovalControllerProvider);
    final controller = ref.read(tagApprovalControllerProvider.notifier);
    final theme = Theme.of(context);
    final pending = state.pending;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Etiket Onayı', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Topluluk üyelerinin seni etiketlediği içerikleri yayınlamadan önce incele.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: state.requireApproval,
            onChanged: state.updatingPreference
                ? null
                : (value) => unawaited(controller.toggleRequireApproval(value)),
            contentPadding: EdgeInsets.zero,
            title: const Text('Etiketler için onay iste'),
            subtitle: const Text(
              'Kapalıyken tüm etiketler otomatik olarak yayınlanır.',
            ),
          ),
          if (state.updatingPreference)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else
            const SizedBox(height: 12),
          if (state.errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          if (state.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (!state.requireApproval)
            Text(
              'Onay kuyruğu kapalı. Etiketler otomatik olarak profilinde yayınlanır.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else if (pending.isEmpty)
            Text(
              'Şu anda onay bekleyen etiket yok.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            Text('Onay bekleyenler', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Column(
              children: pending
                  .map(
                    (entry) => _PendingTagTile(
                      entry: entry,
                      isProcessing: state.processingEntryIds.contains(entry.id),
                      onApprove: () => controller.approve(entry.id),
                      onReject: () => controller.reject(entry.id),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingTagTile extends StatelessWidget {
  const _PendingTagTile({
    required this.entry,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final TagApprovalEntry entry;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarBytes = _decodeDataUri(entry.avatarUrl);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: avatarBytes != null
                    ? MemoryImage(avatarBytes)
                    : null,
                child: avatarBytes == null
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${entry.username} · ${_formatRelativeTime(entry.requestedAt)}',
                      style: subtitleStyle,
                    ),
                    if (entry.flagReason != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          entry.flagReason!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isProcessing ? null : onReject,
                  icon: const Icon(Icons.block),
                  label: const Text('Reddet'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isProcessing ? null : onApprove,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Onayla'),
                ),
              ),
            ],
          ),
          if (isProcessing)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  static Uint8List? _decodeDataUri(String uri) {
    if (!uri.startsWith('data:image')) {
      return null;
    }
    return Uri.parse(uri).data?.contentAsBytes();
  }

  static String _formatRelativeTime(DateTime timestamp) {
    final delta = DateTime.now().difference(timestamp);
    if (delta.inMinutes < 1) {
      return 'az önce';
    }
    if (delta.inMinutes < 60) {
      return '${delta.inMinutes} dk önce';
    }
    if (delta.inHours < 24) {
      return '${delta.inHours} sa önce';
    }
    return '${delta.inDays} gün önce';
  }
}

class _ThemePreferenceSection extends ConsumerWidget {
  const _ThemePreferenceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final controller = ref.read(themeModeControllerProvider.notifier);
    final theme = Theme.of(context);

    Future<void> handleChange(ThemeMode mode) {
      return controller.setThemeMode(mode);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tema Tercihi', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Uygulama temasını cihaz ayarına bırakabilir veya manuel olarak seçebilirsin.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _ThemeModeTile(
            mode: ThemeMode.system,
            groupValue: themeMode,
            title: 'Otomatik',
            subtitle: 'Cihazının gece/gündüz moduna uyum sağlar.',
            icon: Icons.smartphone,
            onChanged: handleChange,
          ),
          _ThemeModeTile(
            mode: ThemeMode.light,
            groupValue: themeMode,
            title: 'Gündüz',
            subtitle: 'Beyaz zemin ve turuncu vurgulu CG paleti.',
            icon: Icons.wb_sunny_outlined,
            onChanged: handleChange,
          ),
          _ThemeModeTile(
            mode: ThemeMode.dark,
            groupValue: themeMode,
            title: 'Gece',
            subtitle: 'Siyah zemin ve amber vurgulu CG paleti.',
            icon: Icons.nightlight_round,
            onChanged: handleChange,
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.mode,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
  });

  final ThemeMode mode;
  final ThemeMode groupValue;
  final String title;
  final String subtitle;
  final IconData icon;
  final Future<void> Function(ThemeMode mode) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = groupValue == mode;
    final textTheme = theme.textTheme;

    return InkWell(
      onTap: () => unawaited(onChanged(mode)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, size: 48),
            const SizedBox(height: 16),
            Text(
              'Profil bilgisi alınamadı.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightCarousel extends StatelessWidget {
  const _HighlightCarousel({required this.highlights});

  final List<ProfileHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          'Yeni başarılar yakında burada olacak.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      scrollDirection: Axis.horizontal,
      itemBuilder: (context, index) =>
          _HighlightCard(highlight: highlights[index]),
      separatorBuilder: (context, _) => const SizedBox(width: 12),
      itemCount: highlights.length,
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.highlight});

  final ProfileHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_resolveIcon(highlight.type), size: 28, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            highlight.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            highlight.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  IconData _resolveIcon(ProfileHighlightType type) {
    switch (type) {
      case ProfileHighlightType.trophy:
        return Icons.emoji_events_outlined;
      case ProfileHighlightType.trending:
        return Icons.trending_up;
      case ProfileHighlightType.lightning:
        return Icons.bolt;
    }
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});

  final List<ProfileActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Text(
        'Toplulukta hareketler yakında burada listelenecek.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < activities.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == activities.length - 1 ? 0 : 12,
            ),
            child: _ActivityTile(activity: activities[i], theme: theme),
          ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity, required this.theme});

  final ProfileActivity activity;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final iconData = _resolveIcon(activity.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: scheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(activity.subtitle, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text(
                  _formatTimestamp(activity.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _resolveIcon(ProfileActivityType type) {
    switch (type) {
      case ProfileActivityType.post:
        return Icons.mic_external_on_outlined;
      case ProfileActivityType.sale:
        return Icons.shopping_bag_outlined;
      case ProfileActivityType.badge:
        return Icons.workspace_premium_outlined;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final monthNames = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    final paddedMinute = timestamp.minute.toString().padLeft(2, '0');
    return '${timestamp.day} ${monthNames[timestamp.month - 1]} ${timestamp.year} • ${timestamp.hour}:$paddedMinute';
  }
}

class _SocialLinksSection extends StatelessWidget {
  const _SocialLinksSection({required this.links});

  final List<ProfileSocialLink> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return Text(
        'Sosyal bağlantılar yakında eklenecek.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: links.map((link) => _SocialLinkChip(link: link)).toList(),
    );
  }
}

class _SocialLinkChip extends StatelessWidget {
  const _SocialLinkChip({required this.link});

  final ProfileSocialLink link;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.tonalIcon(
      onPressed: () {
        // Gelecekte gerçek derin link veya dış tarayıcı entegrasyonu yapılacak.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı açılıyor: ${link.url}')),
        );
      },
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: Icon(_resolveIcon(link.platform)),
      label: Text(
        link.label,
        style: TextStyle(color: scheme.onSecondaryContainer),
      ),
    );
  }

  IconData _resolveIcon(ProfileSocialPlatform platform) {
    switch (platform) {
      case ProfileSocialPlatform.tiktok:
        return Icons.music_note;
      case ProfileSocialPlatform.youtube:
        return Icons.play_circle_outline;
      case ProfileSocialPlatform.instagram:
        return Icons.camera_alt_outlined;
      case ProfileSocialPlatform.website:
        return Icons.public;
    }
  }
}

class _BadgesSection extends StatelessWidget {
  const _BadgesSection({required this.badges});

  final List<ProfileBadge> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return Text(
        'Kazandığın rozetler burada görüntülenecek.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final theme = Theme.of(context);
    return Column(
      children: badges
          .map(
            (badge) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BadgeTile(badge: badge, theme: theme),
            ),
          )
          .toList(),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.theme});

  final ProfileBadge badge;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.secondaryContainer,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BadgeIcon(
            identifier: badge.icon,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  badge.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
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

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.identifier, required this.color});

  final String identifier;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = _resolveIcon(identifier);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color),
    );
  }

  IconData _resolveIcon(String identifier) {
    switch (identifier) {
      case 'mentor':
        return Icons.school_outlined;
      case 'hustler':
        return Icons.trending_up;
      case 'community':
        return Icons.groups_2_outlined;
      default:
        return Icons.workspace_premium_outlined;
    }
  }
}

class _ConnectionsStrip extends StatelessWidget {
  const _ConnectionsStrip({required this.connections});

  final List<ProfileConnection> connections;

  @override
  Widget build(BuildContext context) {
    if (connections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Henüz bağlantı eklenmedi.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemBuilder: (context, index) =>
          _ConnectionCard(connection: connections[index]),
      separatorBuilder: (context, index) => const SizedBox(width: 12),
      itemCount: connections.length,
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.connection});

  final ProfileConnection connection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataBytes = Uri.parse(connection.avatarUrl).data?.contentAsBytes();

    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: dataBytes != null
                    ? MemoryImage(dataBytes)
                    : null,
                child: dataBytes == null
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connection.handle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(connection.relation, style: theme.textTheme.bodyMedium),
          const Spacer(),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Bağlantı detayları yakında eklenecek.'),
                ),
              );
            },
            child: const Text('Profili Aç'),
          ),
        ],
      ),
    );
  }
}

class _OpportunitiesSection extends StatelessWidget {
  const _OpportunitiesSection({required this.opportunities});

  final List<ProfileOpportunity> opportunities;

  @override
  Widget build(BuildContext context) {
    if (opportunities.isEmpty) {
      return Text(
        'Yeni iş birlikleri için beklemede kal.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final theme = Theme.of(context);
    return Column(
      children: opportunities
          .map(
            (opportunity) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OpportunityCard(opportunity: opportunity, theme: theme),
            ),
          )
          .toList(),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.opportunity, required this.theme});

  final ProfileOpportunity opportunity;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final statusChip = _buildStatusChip(opportunity.status, scheme);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  opportunity.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              statusChip,
            ],
          ),
          const SizedBox(height: 8),
          Text(opportunity.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                _formatDeadline(opportunity.deadline),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${opportunity.title} başvurusu hazırlanıyor.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_outward),
                label: const Text('Detaylar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ProfileOpportunityStatus status, ColorScheme scheme) {
    late final String label;
    late final Color color;

    switch (status) {
      case ProfileOpportunityStatus.open:
        label = 'Açık';
        color = scheme.primary;
        break;
      case ProfileOpportunityStatus.closingSoon:
        label = 'Son Günler';
        color = scheme.tertiary;
        break;
      case ProfileOpportunityStatus.waitlist:
        label = 'Yedek Liste';
        color = scheme.secondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDeadline(DateTime deadline) {
    final months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${deadline.day} ${months[deadline.month - 1]}';
  }
}

class _InsightsStrip extends StatelessWidget {
  const _InsightsStrip({required this.insights});

  final List<ProfileInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) => _InsightCard(insight: insights[index]),
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemCount: insights.length,
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final ProfileInsight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trendColor = _trendColor(insight.trend, scheme);
    final trendIcon = _trendIcon(insight.trend);
    final percentText = insight.changePercent == 0
        ? 'Sabit'
        : '${insight.changePercent.toStringAsFixed(1)}%';

    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            insight.value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(trendIcon, size: 18, color: trendColor),
              const SizedBox(width: 6),
              Text(
                percentText,
                style: theme.textTheme.bodyMedium?.copyWith(color: trendColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _trendIcon(ProfileInsightTrend trend) {
    switch (trend) {
      case ProfileInsightTrend.up:
        return Icons.arrow_upward;
      case ProfileInsightTrend.down:
        return Icons.arrow_downward;
      case ProfileInsightTrend.stable:
        return Icons.remove;
    }
  }

  Color _trendColor(ProfileInsightTrend trend, ColorScheme scheme) {
    switch (trend) {
      case ProfileInsightTrend.up:
        return scheme.primary;
      case ProfileInsightTrend.down:
        return scheme.error;
      case ProfileInsightTrend.stable:
        return scheme.onSurfaceVariant;
    }
  }
}
