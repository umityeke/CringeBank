import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/feed_providers.dart';
import '../../domain/models/feed_entry.dart';
import '../../domain/models/feed_segment.dart';
import '../../domain/models/sponsor_campaign.dart';
import '../controllers/feed_lazy_loader.dart';
import '../../../../core/telemetry/telemetry_providers.dart';
import '../../../../core/telemetry/telemetry_service.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  FeedSegment _selectedSegment = FeedSegment.following;
  late final ScrollController _scrollController;
  bool _hasLoggedScrollEvent = false;

  String _buildSubtitle(List<FeedEntry>? entries) {
    if (entries == null || entries.isEmpty) {
      return 'Son aktiviteler, trendler ve etkileşimler tek akışta.';
    }

    final top = entries.first;
    final reasons = top.rankingReasons.take(3).join(', ');
    final strategy = top.rankingStrategy ?? _selectedSegment.name;
    if (reasons.isEmpty) {
      return 'Sıralama modu: $strategy';
    }
    return 'Sıralama modu: $strategy · Nedenler: $reasons';
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScrollTelemetry);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollTelemetry);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScrollTelemetry() {
    if (!_scrollController.hasClients) {
      return;
    }

    final direction = _scrollController.position.userScrollDirection;
    if (!_hasLoggedScrollEvent && direction != ScrollDirection.idle) {
      _recordScrollEvent(direction);
      _hasLoggedScrollEvent = true;
    }

    if (direction == ScrollDirection.idle) {
      return;
    }

    final position = _scrollController.position;
    const threshold = 240.0;
    final remaining = position.maxScrollExtent - position.pixels;
    if (remaining <= threshold) {
      _maybeRequestMore();
    }
  }

  void _recordScrollEvent(ScrollDirection direction) {
    final telemetry = ref.read(telemetryServiceProvider);
    final directionCode = switch (direction) {
      ScrollDirection.forward => 'forward',
      ScrollDirection.reverse => 'reverse',
      _ => 'unknown',
    };
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.feedScrolled,
          timestamp: DateTime.now().toUtc(),
          attributes: <String, Object?>{
            'segment': _selectedSegment.name,
            'direction': directionCode,
            'position_px': _scrollController.position.pixels,
          },
        ),
      ),
    );
  }

  void _recordInteraction(TelemetryEventName name, FeedEntry entry, {Map<String, Object?>? extra}) {
    final telemetry = ref.read(telemetryServiceProvider);
    final attributes = <String, Object?>{
      'segment': _selectedSegment.name,
      'entry_id': entry.id,
      'tag': entry.tag,
      'author': entry.author,
      if (extra != null) ...extra,
    };
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: name,
          timestamp: DateTime.now().toUtc(),
          attributes: attributes,
        ),
      ),
    );
  }

  void _maybeRequestMore() {
    final entries = ref.read(feedEntriesProvider(_selectedSegment)).asData?.value;
    if (entries == null || entries.isEmpty) {
      return;
    }
    ref.read(feedLazyLoaderProvider(_selectedSegment).notifier).extend(entries.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entriesAsync = ref.watch(feedEntriesProvider(_selectedSegment));
    final sponsorsAsync = ref.watch(feedSponsorCampaignsProvider);
    final rankingHints = entriesAsync.asData?.value;
    final lazyLoaderState = ref.watch(feedLazyLoaderProvider(_selectedSegment));
    final lazyLoader = ref.read(feedLazyLoaderProvider(_selectedSegment).notifier);

    final headerTitle = _selectedSegment == FeedSegment.following
        ? 'Takip Ettiklerin'
        : 'Sana Özel Öneriler';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akış'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Ara',
            onPressed: () {},
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FeedSegmentSelector(
                    selected: _selectedSegment,
                    onChanged: (segment) {
                      setState(() {
                        _selectedSegment = segment;
                        _hasLoggedScrollEvent = false;
                      });
                      if (segment == FeedSegment.recommended) {
                        unawaited(
                          ref.read(feedRefreshRecommendedProvider.future),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  _SponsorCarousel(data: sponsorsAsync),
                  const SizedBox(height: 24),
                  Text(headerTitle, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    _buildSubtitle(rankingHints),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          entriesAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const SliverToBoxAdapter(
                  child: _EmptyFeedState(),
                );
              }
              var visibleCount = lazyLoaderState.visibleCount.clamp(0, entries.length);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                lazyLoader.syncWithTotal(entries.length);
              });
              final latestState = ref.read(feedLazyLoaderProvider(_selectedSegment));
              if (latestState.visibleCount != lazyLoaderState.visibleCount) {
                visibleCount = latestState.visibleCount.clamp(0, entries.length);
              }

              final hasMore = visibleCount < entries.length;
              final childCount = visibleCount + (hasMore ? 1 : 0);

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= childCount) {
                        return null;
                      }

                      if (index >= visibleCount) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRequestMore());
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final entry = entries[index];
                      final showSponsoredBadge = entry.tag.toLowerCase() == 'sponsor';

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == visibleCount - 1 && !hasMore ? 0 : 16,
                        ),
                        child: _FeedEntryCard(
                          entry: entry,
                          rank: index + 1,
                          showSponsoredBadge: showSponsoredBadge,
                          onLike: () => _recordInteraction(
                            TelemetryEventName.feedEntryLiked,
                            entry,
                          ),
                          onShare: () => _recordInteraction(
                            TelemetryEventName.feedEntryShared,
                            entry,
                          ),
                          onReport: () => _recordInteraction(
                            TelemetryEventName.feedEntryReported,
                            entry,
                          ),
                        ),
                      );
                    },
                    childCount: childCount,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, stackTrace) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: _FeedErrorState(message: error.toString()),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _FeedSegmentSelector extends StatelessWidget {
  const _FeedSegmentSelector({
    required this.selected,
    required this.onChanged,
  });

  final FeedSegment selected;
  final ValueChanged<FeedSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SegmentedButton<FeedSegment>(
      style: SegmentedButton.styleFrom(side: BorderSide(color: theme.dividerColor)),
      segments: const [
        ButtonSegment<FeedSegment>(
          value: FeedSegment.following,
          label: Text('Takip Edilenler'),
          icon: Icon(Icons.people_outline_rounded),
        ),
        ButtonSegment<FeedSegment>(
          value: FeedSegment.recommended,
          label: Text('Önerilenler'),
          icon: Icon(Icons.auto_awesome_rounded),
        ),
      ],
      selected: <FeedSegment>{selected},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          onChanged(selection.first);
        }
      },
    );
  }
}

class _SponsorCarousel extends StatelessWidget {
  const _SponsorCarousel({required this.data});

  final AsyncValue<List<SponsorCampaign>> data;

  @override
  Widget build(BuildContext context) {
    return data.when(
      data: (campaigns) {
        if (campaigns.isEmpty) {
          return const SizedBox.shrink();
        }
        return _SponsorCarouselContent(campaigns: campaigns);
      },
      loading: () => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Sponsor verisi alınamadı: $error',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        ),
      ),
    );
  }
}

class _SponsorCarouselContent extends StatelessWidget {
  const _SponsorCarouselContent({required this.campaigns});

  final List<SponsorCampaign> campaigns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sponsor Vitrini', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: campaigns.length,
            separatorBuilder: (context, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              return _SponsorCard(campaign: campaign);
            },
          ),
        ),
      ],
    );
  }
}

class _SponsorCard extends StatelessWidget {
  const _SponsorCard({required this.campaign});

  final SponsorCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = LinearGradient(
      colors: [campaign.startColor, campaign.endColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      width: 240,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campaign.title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              campaign.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimary.withOpacity(0.9),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onPrimary,
              backgroundColor: theme.colorScheme.onPrimary.withOpacity(0.18),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: campaign.targetUrl == null ? null : () {},
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(campaign.ctaText),
          ),
        ],
      ),
    );
  }
}

class _FeedEntryCard extends StatelessWidget {
  const _FeedEntryCard({
    required this.entry,
    required this.rank,
    required this.showSponsoredBadge,
    required this.onLike,
    required this.onShare,
    required this.onReport,
  });

  final FeedEntry entry;
  final int rank;
  final bool showSponsoredBadge;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: entry.accentColor, width: 4)),
            ),
            child: Row(
              children: [
                _RankPill(rank: rank),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: entry.accentColor.withOpacity(0.18),
                  foregroundColor: entry.accentColor.darken(),
                  child: Text(entry.authorInitials),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.author,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.relativeTime} · ${entry.tag}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(entry.excerpt, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _FeedStatButton(
                      icon: Icons.favorite_border_rounded,
                      label: '${entry.likeCount}',
                      onTap: onLike,
                    ),
                    const SizedBox(width: 16),
                    _FeedStatButton(
                      icon: Icons.mode_comment_outlined,
                      label: '${entry.commentCount}',
                      onTap: null,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      tooltip: 'Paylaş',
                      onPressed: onShare,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.flag_outlined),
                      tooltip: 'Şikayet et',
                      onPressed: onReport,
                      visualDensity: VisualDensity.compact,
                    ),
                    if (showSponsoredBadge)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Sponsorlu İçerik',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () {},
                        child: const Text('Profili Gör'),
                      ),
                    if (entry.computedScore != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Tooltip(
                          message: 'Skor: ${entry.computedScore!.toStringAsFixed(2)}',
                          triggerMode: TooltipTriggerMode.longPress,
                          child: Icon(
                            Icons.leaderboard_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                if (entry.rankingReasons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: entry.rankingReasons
                          .take(4)
                          .map(
                            (reason) => Chip(
                              label: Text(reason),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              labelStyle: theme.textTheme.labelSmall,
                            ),
                          )
                          .toList(growable: false),
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

class _RankPill extends StatelessWidget {
  const _RankPill({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '#$rank',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FeedStatButton extends StatelessWidget {
  const _FeedStatButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Column(
        children: [
          Icon(Icons.dynamic_feed_outlined, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Henüz içerik yok',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni paylaşımlar yüklendiğinde akış otomatik olarak güncellenecek.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedErrorState extends StatelessWidget {
  const _FeedErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Akış yüklenirken sorun oluştu.',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

extension on Color {
  Color darken([double amount = 0.16]) {
    final factor = 1 - amount;
    int tone(int channel) {
      final tinted = (channel * factor).round();
      if (tinted < 0) {
        return 0;
      }
      if (tinted > 255) {
        return 255;
      }
      return tinted;
    }

    return Color.fromARGB(
      alpha,
      tone(red),
      tone(green),
      tone(blue),
    );
  }
}
