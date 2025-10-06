import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../models/competition_model.dart';
import '../services/competition_service.dart';
import '../widgets/animated_bubble_background.dart';
import 'modern_cringe_deposit_screen.dart';

class ModernCompetitionsScreen extends StatefulWidget {
  const ModernCompetitionsScreen({super.key});

  @override
  State<ModernCompetitionsScreen> createState() =>
      _ModernCompetitionsScreenState();
}

class _ModernCompetitionsScreenState extends State<ModernCompetitionsScreen>
    with TickerProviderStateMixin {
  late final CompetitionService _competitionService;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  final PageController _pageController = PageController();
  StreamSubscription<List<Competition>>? _liveSubscription;

  List<Competition> _liveCompetitions = [];
  bool _isLoading = true;
  String? _loadError;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _competitionService = CompetitionService();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 1, curve: Curves.easeInOut),
      ),
    );

    _listenLiveCompetitions();
    _controller.forward();
  }

  void _listenLiveCompetitions() {
    _liveSubscription?.cancel();
    _liveSubscription = _competitionService.streamLiveCompetitions().listen(
      (items) {
        if (!mounted) return;
        setState(() {
          _liveCompetitions = items;
          _isLoading = false;
          _loadError = null;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _loadError = error.toString();
          _isLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBubbleBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) => setState(() {
                          _selectedTab = index;
                        }),
                        children: [
                          _buildActiveCompetitions(),
                          _buildLeaderboard(),
                          _buildMyCompetitions(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: 3,
                      effect: ExpandingDotsEffect(
                        dotHeight: 6,
                        dotWidth: 6,
                        spacing: 8,
                        dotColor: Colors.white.withOpacity(0.2),
                        activeDotColor: Colors.orange,
                      ),
                      onDotClicked: (index) {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.orange, Colors.deepOrange],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yarışmalar',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _headerSubtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '🔥 ${_liveCompetitions.length} Aktif',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get _headerSubtitle {
    if (_isLoading) return 'Yarışmalar yükleniyor...';
    if (_loadError != null) return 'Bir sorun oluştu';
    if (_liveCompetitions.isEmpty) return 'Yeni yarışmalar yakında burada!';
    return 'En krep anları yarışıyor';
  }

  Widget _buildTabBar() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.1),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Row(
                    children: [
                      _buildTabItem('Aktif', 0),
                      _buildTabItem('Liderlik', 1),
                      _buildTabItem('Benimkiler', 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? Colors.orange.withOpacity(0.8)
                : Colors.transparent,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCompetitions() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    if (_loadError != null) {
      return _buildErrorPlaceholder();
    }

    if (_liveCompetitions.isEmpty) {
      return _buildEmptyPlaceholder(
        title: 'Aktif yarışma yok',
        subtitle: 'Yeni yarışmalar çok yakında burada olacak.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: _liveCompetitions.length,
      itemBuilder: (context, index) {
        final competition = _liveCompetitions[index];
        return _buildCompetitionCard(competition);
      },
    );
  }

  Widget _buildCompetitionCard(Competition competition) {
    final prizeAmount = competition.prize.amount;
    final prizeLabel = prizeAmount > 0
        ? '${_formatPrizeLabel(prizeAmount)} ${competition.prize.currency}'
        : 'Prestij';
    final participants = competition.participantCount;
    final accentColor = _accentColorFor(competition.type);
    final icon = _iconFor(competition.type);
    final statusLabel = _statusLabel(competition);
    final dateRangeLabel = _formatDateRange(
      competition.startAt,
      competition.endAt,
    );
    final isLiveUpload =
        competition.status == CompetitionStatus.live &&
        competition.type == CompetitionType.upload;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withOpacity(0.2),
                      ),
                      child: Icon(icon, color: accentColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            competition.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            competition.description ??
                                _typeLabel(competition.type),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _CardStat(label: 'Ödül', value: prizeLabel),
                      ),
                      Expanded(
                        child: _CardStat(
                          label: 'Katılımcı',
                          value: participants > 0
                              ? '$participants kişi'
                              : 'Henüz katılım yok',
                        ),
                      ),
                      Expanded(
                        child: _CardStat(
                          label: 'Durum',
                          value: statusLabel,
                          secondary: dateRangeLabel,
                          highlightColor: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLiveUpload
                        ? () => _openDepositForCompetition(competition)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLiveUpload
                          ? accentColor
                          : Colors.white.withOpacity(0.15),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isLiveUpload ? 'Anımı Gönder' : 'Katılım Rehberi Yakında',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                if (!isLiveUpload)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      competition.status == CompetitionStatus.live
                          ? 'Bu yarışma için katılım yöntemi yakında eklenecek.'
                          : 'Sonuçlar ve öne çıkanlar yakında paylaşılacak.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboard() {
    return _buildEmptyPlaceholder(
      title: 'Liderlik tablosu hazırlanıyor',
      subtitle: 'Yakında topluluk puanlarını burada göreceksin.',
    );
  }

  Widget _buildMyCompetitions() {
    return _buildEmptyPlaceholder(
      title: 'Kişisel yarışma geçmişi yakında',
      subtitle: 'Katıldığın yarışmalar bu sekmede listelenecek.',
    );
  }

  Widget _buildErrorPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            const Text(
              'Yarışmalar yüklenemedi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bir şeyler ters gitti. Lütfen yeniden deneyin.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadError = null;
                });
                _listenLiveCompetitions();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder({required String title, String? subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              size: 50,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  String _formatPrizeLabel(double prize) {
    if (prize % 1 == 0) {
      return prize.toStringAsFixed(0);
    }
    return prize.toStringAsFixed(1);
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final formatter = DateFormat('dd MMM HH:mm', 'tr_TR');
    return '${formatter.format(start)} · ${formatter.format(end)}';
  }

  String _statusLabel(Competition competition) {
    final now = DateTime.now();

    if (competition.status == CompetitionStatus.live) {
      if (now.isBefore(competition.startAt)) {
        return 'Başlıyor: ${_formatDuration(competition.startAt.difference(now))}';
      }
      if (now.isBefore(competition.endAt)) {
        return 'Kalan: ${_formatDuration(competition.endAt.difference(now))}';
      }
      return 'Bitiyor: ${_formatDuration(now.difference(competition.endAt))}';
    }

    switch (competition.status) {
      case CompetitionStatus.draft:
        return 'Yakında';
      case CompetitionStatus.finished:
        return 'Tamamlandı';
      case CompetitionStatus.archived:
        return 'Arşivlendi';
      case CompetitionStatus.live:
        return 'Aktif';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays >= 1) {
      return '${duration.inDays} gün';
    }

    if (duration.inHours >= 1) {
      return '${duration.inHours} saat';
    }

    final minutes = duration.inMinutes;
    if (minutes >= 1) {
      return '$minutes dk';
    }

    return '1 dk';
  }

  Color _accentColorFor(CompetitionType type) {
    switch (type) {
      case CompetitionType.upload:
        return Colors.orange;
      case CompetitionType.vote:
        return Colors.purpleAccent;
      case CompetitionType.quiz:
        return Colors.blueAccent;
      case CompetitionType.prediction:
        return Colors.teal;
      case CompetitionType.tournament:
        return Colors.redAccent;
    }
  }

  IconData _iconFor(CompetitionType type) {
    switch (type) {
      case CompetitionType.upload:
        return Icons.photo_camera_back_outlined;
      case CompetitionType.vote:
        return Icons.how_to_vote;
      case CompetitionType.quiz:
        return Icons.quiz_outlined;
      case CompetitionType.prediction:
        return Icons.insights_outlined;
      case CompetitionType.tournament:
        return Icons.emoji_events_outlined;
    }
  }

  String _typeLabel(CompetitionType type) {
    switch (type) {
      case CompetitionType.upload:
        return 'Anı Yarışması';
      case CompetitionType.vote:
        return 'Oylama Yarışması';
      case CompetitionType.quiz:
        return 'Quiz Yarışması';
      case CompetitionType.prediction:
        return 'Tahmin Yarışması';
      case CompetitionType.tournament:
        return 'Turnuva';
    }
  }

  Future<void> _openDepositForCompetition(Competition competition) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModernCringeDepositScreen(competition: competition),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  const _CardStat({
    required this.label,
    required this.value,
    this.secondary,
    this.highlightColor,
  });

  final String label;
  final String value;
  final String? secondary;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: highlightColor ?? Colors.white,
          ),
        ),
        if (secondary != null && secondary!.isNotEmpty)
          Text(
            secondary!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
      ],
    );
  }
}
