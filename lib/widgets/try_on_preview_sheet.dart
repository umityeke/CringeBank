import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../data/store_catalog.dart';
import '../models/try_on_session.dart';

class TryOnPreviewSheet extends StatefulWidget {
  const TryOnPreviewSheet({
    super.key,
    required this.item,
    required this.session,
    required this.previewUrls,
    required this.previewAssets,
    required this.config,
    required this.triesRemaining,
    required this.cooldownRemaining,
    required this.reusedSession,
    required this.onPurchase,
  });

  final StoreItem item;
  final TryOnSession session;
  final List<String> previewUrls;
  final StoreItemPreviewAssets previewAssets;
  final StoreItemTryOnConfig config;
  final int triesRemaining;
  final int cooldownRemaining;
  final bool reusedSession;
  final VoidCallback onPurchase;

  @override
  State<TryOnPreviewSheet> createState() => _TryOnPreviewSheetState();
}

class _TryOnPreviewSheetState extends State<TryOnPreviewSheet> {
  late Duration _remaining;
  Timer? _timer;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _remaining = widget.session.remaining;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = widget.session.remaining;
      });
      if (_remaining.inMilliseconds <= 0) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final remainingText = _formatDuration(_remaining);
    final previewUrls = widget.previewUrls;
    final bottomPadding = mediaQuery.viewInsets.bottom + 24;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: bottomPadding,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1627), Color(0xFF120E1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: widget.item.artwork.colors.isNotEmpty
              ? widget.item.artwork.colors.last.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(remainingText),
            const SizedBox(height: 16),
            _buildPreviewCarousel(previewUrls),
            const SizedBox(height: 16),
            _buildInfoChips(),
            const SizedBox(height: 20),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String remainingText) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.visibility_outlined,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Deneme süresi: $remainingText',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCarousel(List<String> urls) {
    final hasImages = urls.isNotEmpty;
    final pages = hasImages ? urls.length : 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 220,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.05),
            child: hasImages
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: urls.length,
                    itemBuilder: (context, index) {
                      return Image.network(
                        urls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _fallbackPreview();
                        },
                      );
                    },
                  )
                : _fallbackPreview(),
          ),
        ),
        if (pages > 1) ...[
          const SizedBox(height: 12),
          SmoothPageIndicator(
            controller: _pageController,
            count: pages,
            effect: ExpandingDotsEffect(
              dotHeight: 6,
              dotWidth: 6,
              dotColor: Colors.white.withValues(alpha: 0.25),
              activeDotColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _fallbackPreview() {
    return Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 48,
        color: Colors.white.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildInfoChips() {
    final chips = <Widget>[];

    chips.add(_infoChip(
      icon: Icons.bolt_rounded,
      label: widget.previewAssets.watermark
          ? 'Filigranlı önizleme'
          : 'Filigransız önizleme',
    ));

    chips.add(_infoChip(
      icon: Icons.timer_outlined,
      label: 'Süre ${widget.config.durationSec} sn',
    ));

    chips.add(_infoChip(
      icon: Icons.repeat_on_rounded,
      label: 'Günlük ${widget.config.maxDailyTries} deneme',
    ));

    if (widget.triesRemaining > 0) {
      chips.add(_infoChip(
        icon: Icons.check_circle_outline,
        label: 'Kalan deneme: ${widget.triesRemaining}',
      ));
    } else {
      chips.add(_infoChip(
        icon: Icons.hourglass_empty,
        label: 'Günlük limit doldu',
      ));
    }

    if (widget.reusedSession) {
      chips.add(_infoChip(
        icon: Icons.history_toggle_off,
        label: 'Aktif deneme yeniden açıldı',
      ));
    }

    if (widget.cooldownRemaining > 0) {
      chips.add(_infoChip(
        icon: Icons.autorenew,
        label:
            'Sonraki deneme ${_formatDuration(Duration(seconds: widget.cooldownRemaining))}',
      ));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.onPurchase,
            style: FilledButton.styleFrom(
              backgroundColor:
                  widget.item.artwork.colors.isNotEmpty
                      ? widget.item.artwork.colors.last
                      : const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'Satın al ve kalıcı yap',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.8),
            ),
            child: const Text('Kapat'),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final clamped = duration.isNegative ? Duration.zero : duration;
    final totalMinutes = clamped.inMinutes;
    final seconds = clamped.inSeconds.remainder(60);
    final formattedMinutes = totalMinutes.toString().padLeft(2, '0');
    final formattedSeconds = seconds.toString().padLeft(2, '0');
    return '$formattedMinutes:$formattedSeconds';
  }
}
