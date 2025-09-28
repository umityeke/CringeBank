import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../models/cringe_entry.dart';
import '../services/competition_service.dart';
import '../widgets/competition_quick_entry_sheet.dart';
import '../widgets/animated_bubble_background.dart';
import '../widgets/competition_entries_sheet.dart';

class ModernCompetitionsScreen extends StatefulWidget {
  const ModernCompetitionsScreen({super.key});

  @override
  State<ModernCompetitionsScreen> createState() => _ModernCompetitionsScreenState();
}

class _ModernCompetitionsScreenState extends State<ModernCompetitionsScreen>
    with TickerProviderStateMixin {
  static const int _maxCompetitionDurationDays =
      CompetitionService.maxCompetitionDurationDays;

  late AnimationController _controller;
  late AnimationController _tabController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  int _selectedTab = 0;
  final PageController _pageController = PageController();
  List<Competition> _activeCompetitions = [];
  List<Competition> _myCompetitions = [];
  String? _activeParticipationCompetitionId;
  final Set<String> _pendingCompetitionActions = <String>{};
  StreamSubscription<List<Competition>>? _competitionsSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _tabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
    ));
    _syncCompetitions(CompetitionService.currentCompetitions);

    _competitionsSubscription =
        CompetitionService.competitionsStream.listen((competitions) {
      if (!mounted) return;
      _syncCompetitions(competitions);
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _competitionsSubscription?.cancel();
    _controller.dispose();
    _tabController.dispose();
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
                        onPageChanged: (index) {
                          setState(() => _selectedTab = index);
                        },
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
      floatingActionButton: _buildFloatingActionButton(),
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
                          'En krep anları yarışıyor!',
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
                      '🔥 ${_activeCompetitions.length} Aktif',
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
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _opacityAnimation,
          child: _activeCompetitions.isEmpty
              ? _buildEmptyPlaceholder(
                  title: 'Aktif yarışma bulunmuyor',
                  subtitle: 'Yeni yarışmalar için düzenli olarak kontrol et.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _activeCompetitions.length,
                  itemBuilder: (context, index) {
                    final competition = _activeCompetitions[index];
                    return _buildCompetitionCard(competition);
                  },
                ),
        );
      },
    );
  }

  Widget _buildCompetitionCard(Competition competition, {VoidCallback? onDelete}) {
    final title = competition.title;
    final description = competition.description;
    final prize = competition.prizeKrepCoins > 0
        ? '${_formatPrizeLabel(competition.prizeKrepCoins)} 🪙'
        : '-';
    final participants = competition.participantUserIds.length;
    final accentColor = _accentColorFor(competition);
    final icon = _iconFor(competition);
    final startDate = competition.startDate;
    final endDate = competition.endDate;
    final statusLabel = _formatRemainingTime(startDate, endDate);
    final dateRangeLabel = _formatDateRange(startDate, endDate);
    final isOwnerView = onDelete != null;
    final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
  final bool isParticipant =
    userId != null && competition.participantUserIds.contains(userId);
  final bool hasSubmittedEntry = userId != null &&
    competition.entries.any((entry) => entry.userId == userId);
  final int totalCommentCount = competition.totalCommentCount;
    final int totalEntryCount = competition.entries.length;
    final bool isProcessing =
        _pendingCompetitionActions.contains(competition.id);
    final bool isJoinWindowOpen = _isJoinWindowOpen(competition);
    final bool hasOtherParticipation =
        _activeParticipationCompetitionId != null &&
            _activeParticipationCompetitionId != competition.id;
    final bool isFull =
        competition.participantUserIds.length >= competition.maxEntries;
  final bool canJoin = userId != null &&
        isJoinWindowOpen &&
        !isFull &&
        !hasOtherParticipation;
  final bool canSubmitEntry =
    isParticipant && !hasSubmittedEntry && !isProcessing && isJoinWindowOpen;

    String buttonLabel;
    Color buttonColor;
    VoidCallback? buttonAction;
    String? helperMessage;
  String? participantHelperMessage;

    if (isOwnerView) {
      buttonLabel = 'Yarışmayı Sil';
      buttonColor = Colors.redAccent;
      buttonAction = isProcessing ? null : onDelete;
    } else if (isParticipant) {
      buttonLabel = 'Yarışmadan Ayrıl';
      buttonColor = Colors.redAccent;
      buttonAction = isProcessing ? null : () => _handleLeaveCompetition(competition);
      if (hasSubmittedEntry) {
        participantHelperMessage =
            'Anını paylaştın, tekrar düzenlemek için yarışma bitimini bekle.';
      } else if (!isJoinWindowOpen) {
        participantHelperMessage = 'Yarışma şu anda anı almıyor.';
      }
    } else {
      buttonLabel = isProcessing ? 'Katılım İşleniyor…' : 'Yarışmaya Katıl';
      buttonColor = canJoin ? accentColor : Colors.white.withOpacity(0.2);
      buttonAction = isProcessing ? null : () => _handleJoinCompetition(competition);

      if (!canJoin) {
        if (userId == null) {
          helperMessage = 'Katılmak için giriş yapmalısın.';
        } else if (hasOtherParticipation) {
          helperMessage = 'Önce katıldığın diğer yarışmadan ayrılmalısın.';
        } else if (isFull) {
          helperMessage = 'Yarışma kontenjanı doldu.';
        } else if (!isJoinWindowOpen) {
          helperMessage = 'Yarışma şu anda katılıma kapalı.';
        }
      }
    }

    final Widget buttonChild = isProcessing
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Text(
            buttonLabel,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
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
                      child: Icon(
                        icon,
                        color: accentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            description,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ödül',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              prize,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Katılımcı',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              '$participants / ${competition.maxEntries} kişi',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kalan Süre',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                            if (dateRangeLabel.isNotEmpty)
                              Text(
                                dateRangeLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (competition.status == CompetitionStatus.results) ...[
                  _buildCommentWinnerSection(competition),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: buttonAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: buttonChild,
                  ),
                ),
                if (isParticipant)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: OutlinedButton.icon(
                      onPressed: canSubmitEntry
                          ? () => _openCompetitionEntry(competition)
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: canSubmitEntry
                              ? accentColor
                              : Colors.white.withOpacity(0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.edit),
                      label: Text(
                        hasSubmittedEntry
                            ? 'Anın Gönderildi'
                            : 'Anımı Yarışmaya Gönder',
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(
                    top: isParticipant ? 8.0 : 12.0,
                  ),
                  child: TextButton.icon(
                    onPressed: () => _showCompetitionEntries(competition),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.forum_outlined),
                    label: Text(
                      totalEntryCount == 0
                          ? 'Tüm yorumları gör'
                          : 'Tüm yorumları gör ($totalCommentCount)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (isParticipant && participantHelperMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      participantHelperMessage,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (helperMessage != null && !isOwnerView && !isParticipant)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      helperMessage,
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

  Widget _buildCommentWinnerSection(Competition competition) {
    return FutureBuilder<CompetitionCommentWinner?>(
      future: CompetitionService.fetchCommentWinner(competition),
      builder: (context, snapshot) {
        final decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.orangeAccent.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.orangeAccent.withValues(alpha: 0.35),
            width: 1,
          ),
        );

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: decoration,
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Yorum beğenileri analiz ediliyor…',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final winner = snapshot.data;
        if (winner == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: decoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.emoji_events_rounded,
                        color: Colors.orangeAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Yorum Kazananı',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu yarışmada henüz beğeni alan bir yorum yok.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.orangeAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Yorum Kazananı',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        color: Colors.pinkAccent.shade200,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${winner.likeCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                winner.authorName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                winner.authorHandle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                winner.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderboard() {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _opacityAnimation,
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            itemCount: 10,
            itemBuilder: (context, index) {
              return _buildLeaderboardItem(index);
            },
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardItem(int index) {
    final names = [
      'KrepMaster2024', 'UtancVerici', 'CringeKing', 'MegaShame',
      'EpicFail', 'BlushMaster', 'AwkwardMoment', 'RedFaceEmoji',
      'ShameSpiral', 'CringeLord'
    ];
    
    final scores = [2847, 2156, 1923, 1756, 1634, 1521, 1398, 1287, 1156, 1034];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: index < 3 
                      ? [Colors.amber, Colors.grey, Colors.brown][index]
                      : Colors.orange.withOpacity(0.3),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (index < 3)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Icon(
                        [Icons.emoji_events, Icons.military_tech, Icons.star][index],
                        size: 14,
                        color: [Colors.amber, Colors.grey, Colors.brown][index],
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              names[index],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              '${scores[index]} puan',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            trailing: index < 3
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: [Colors.amber, Colors.grey, Colors.brown][index]
                          .withOpacity(0.2),
                    ),
                    child: Text(
                      ['👑', '🥈', '🥉'][index],
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildMyCompetitions() {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _opacityAnimation,
          child: _myCompetitions.isEmpty
              ? _buildEmptyPlaceholder(
                  title: 'Henüz yarışma oluşturmadınız',
                  subtitle:
                      'Yeni bir yarışma başlatmak için alt bölümdeki butonu kullanın.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _myCompetitions.length,
                  itemBuilder: (context, index) {
                    final competition = _myCompetitions[index];
                    return _buildCompetitionCard(
                      competition,
                      onDelete: () =>
                          _confirmAndDeleteCompetition(competition),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FloatingActionButton.extended(
            onPressed: _handleCreateCompetition,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text(
              'Yarışma Oluştur',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCreateCompetition() async {
    if (CompetitionService.hasOngoingCompetitionForCurrentUser()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aktif bir yarışmanız var. Yeni yarışma eklemeden önce mevcut yarışmayı silmelisiniz.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final result = await _showCreateCompetitionSheet();
    if (result == null) return;

    final competition = result.toCompetition();

    final creationSuccess =
        await CompetitionService.createCompetition(competition);

    if (!mounted) return;

    if (!creationSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Yarışma oluşturulamadı. Aktif yarışmanızı kontrol edin veya daha sonra tekrar deneyin.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _selectedTab = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${result.title}" yarışması oluşturuldu!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<_CompetitionFormResult?> _showCreateCompetitionSheet() async {
    return showModalBottomSheet<_CompetitionFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CompetitionCreationSheet(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          buildInputDecoration: _buildInputDecoration,
          typeLabelBuilder: _typeLabel,
          formatDateLabel: _formatDateLabel,
          calculateMaxEndDate: _calculateMaxEndDate,
          maxDurationDays: _maxCompetitionDurationDays,
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.orange, width: 2),
      ),
    );
  }

  String _typeLabel(CompetitionType type) {
    switch (type) {
      case CompetitionType.weeklyBest:
        return 'Haftalık En İyi';
      case CompetitionType.categorySpecific:
        return 'Kategoriye Özel';
      case CompetitionType.krepLevelChallenge:
        return 'Krep Seviyesi Challenge';
      case CompetitionType.aiJudged:
        return 'AI Hakemli';
      case CompetitionType.communityChoice:
        return 'Topluluk Seçimi';
      case CompetitionType.speedRound:
        return 'Hızlı Tur';
      case CompetitionType.legendary:
        return 'Efsanevi';
    }
  }

  DateTime _calculateMaxEndDate(DateTime startDate) {
    final cappedEnd = startDate.add(const Duration(days: _maxCompetitionDurationDays));
    final globalLimit = DateTime.now().add(const Duration(days: 365));
    return cappedEnd.isBefore(globalLimit) ? cappedEnd : globalLimit;
  }

  String _formatPrizeLabel(double prize) {
    if (prize % 1 == 0) {
      return prize.toStringAsFixed(0);
    }
    return prize.toStringAsFixed(1);
  }

  Color _accentColorFor(Competition competition) {
    switch (competition.type) {
      case CompetitionType.weeklyBest:
        return Colors.orange;
      case CompetitionType.categorySpecific:
        return Colors.purple;
      case CompetitionType.krepLevelChallenge:
        return Colors.redAccent;
      case CompetitionType.aiJudged:
        return Colors.blueAccent;
      case CompetitionType.communityChoice:
        return Colors.teal;
      case CompetitionType.speedRound:
        return Colors.greenAccent.shade400;
      case CompetitionType.legendary:
        return Colors.deepOrangeAccent;
    }
  }

  IconData _iconFor(Competition competition) {
    switch (competition.type) {
      case CompetitionType.weeklyBest:
        return Icons.emoji_events;
      case CompetitionType.categorySpecific:
        return Icons.category;
      case CompetitionType.krepLevelChallenge:
        return Icons.local_fire_department;
      case CompetitionType.aiJudged:
        return Icons.smart_toy;
      case CompetitionType.communityChoice:
        return Icons.how_to_vote;
      case CompetitionType.speedRound:
        return Icons.flash_on;
      case CompetitionType.legendary:
        return Icons.workspace_premium;
    }
  }

  String _formatDateLabel(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day.$month.$year';
  }

  String _formatDateRange(DateTime start, DateTime end) {
    return '${_formatDateLabel(start)} - ${_formatDateLabel(end)}';
  }

  String _formatRemainingTime(DateTime start, DateTime end) {
    final now = DateTime.now();

    if (now.isAfter(end)) {
      return 'Tamamlandı';
    }

    if (now.isBefore(start)) {
      final diff = start.difference(now);
      return 'Başlıyor: ${_formatDuration(diff)}';
    }

    final diff = end.difference(now);
    return 'Kalan: ${_formatDuration(diff)}';
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

  Widget _buildEmptyPlaceholder({required String title, String? subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
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
          if (_selectedTab != 0) ...[
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _selectedTab = 0);
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Yarışmalara Göz At'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _syncCompetitions(List<Competition> competitions) {
    final normalizedCompetitions = competitions
        .map(_normalizeCompetitionTotals)
        .toList();

    final now = DateTime.now();
    final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    String? activeParticipationId;

    if (userId != null) {
      for (final competition in normalizedCompetitions) {
        if (!competition.participantUserIds.contains(userId)) continue;
        final bool isActivePhase = now.isBefore(competition.endDate) &&
            (competition.status == CompetitionStatus.active ||
                competition.status == CompetitionStatus.upcoming ||
                competition.status == CompetitionStatus.voting ||
                competition.status == CompetitionStatus.results);
        if (isActivePhase) {
          activeParticipationId = competition.id;
          break;
        }
      }
    }

    setState(() {
      _activeCompetitions = normalizedCompetitions
          .where((competition) => now.isBefore(competition.endDate))
          .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

      _myCompetitions = userId == null
          ? []
          : normalizedCompetitions
              .where((competition) => competition.createdByUserId == userId)
              .toList()
            ..sort((a, b) => a.startDate.compareTo(b.startDate));

      _activeParticipationCompetitionId = activeParticipationId;
    });
  }

  Competition _normalizeCompetitionTotals(Competition competition) {
    final totalFromEntries = competition.entries.fold<int>(
      0,
      (runningTotal, entry) => runningTotal + entry.yorumSayisi,
    );

    if (totalFromEntries == competition.totalCommentCount) {
      return competition;
    }

    return competition.copyWith(totalCommentCount: totalFromEntries);
  }

  void _showCompetitionEntries(Competition competition) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompetitionEntriesSheet(
        competition: competition,
        onEntriesChanged: (updatedEntries) {
          _updateCompetitionEntries(competition.id, updatedEntries);
        },
      ),
    );
  }

  void _updateCompetitionEntries(
    String competitionId,
    List<CringeEntry> updatedEntries,
  ) {
    final totalComments =
        updatedEntries.fold<int>(0, (sum, entry) => sum + entry.yorumSayisi);
  setState(() {
    _activeCompetitions = _activeCompetitions
      .map((competition) => competition.id == competitionId
        ? competition.copyWith(
          entries: updatedEntries,
          totalCommentCount: totalComments,
        )
        : competition)
      .toList();

    _myCompetitions = _myCompetitions
      .map((competition) => competition.id == competitionId
        ? competition.copyWith(
          entries: updatedEntries,
          totalCommentCount: totalComments,
        )
        : competition)
      .toList();
  });
  }

  Future<void> _openCompetitionEntry(
    Competition competition, {
    bool forceOpen = false,
  }) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Anı göndermek için giriş yapmalısın.',
          backgroundColor: Colors.redAccent);
      return;
    }

    if (!forceOpen &&
        !competition.participantUserIds.contains(user.uid)) {
      _showSnackBar('Önce yarışmaya katılmalısın.',
          backgroundColor: Colors.redAccent);
      return;
    }

    if (competition.entries.any((entry) => entry.userId == user.uid)) {
      _showSnackBar('Bu yarışmaya zaten bir anı gönderdin.');
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompetitionQuickEntrySheet(
        competition: competition,
      ),
    );

    if (result == true && mounted) {
      _showSnackBar(
        '"${competition.title}" yarışmasına anın gönderildi!',
      );
    }
  }

  Future<void> _handleJoinCompetition(Competition competition) async {
    if (_pendingCompetitionActions.contains(competition.id)) return;

    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Katılmak için giriş yapmalısın.',
          backgroundColor: Colors.redAccent);
      return;
    }

    if (!competition.participantUserIds.contains(user.uid) &&
        _activeParticipationCompetitionId != null &&
        _activeParticipationCompetitionId != competition.id) {
      _showSnackBar('Aynı anda yalnızca bir yarışmada yer alabilirsin.',
          backgroundColor: Colors.redAccent);
      return;
    }

    if (! _isJoinWindowOpen(competition)) {
      _showSnackBar('Yarışma şu anda katılıma kapalı.',
          backgroundColor: Colors.redAccent);
      return;
    }

    if (competition.participantUserIds.length >= competition.maxEntries) {
      _showSnackBar('Yarışma kontenjanı doldu.',
          backgroundColor: Colors.redAccent);
      return;
    }

    if (competition.participantUserIds.contains(user.uid)) {
      _showSnackBar('Zaten bu yarışmaya katıldın.');
      return;
    }

    setState(() {
      _pendingCompetitionActions.add(competition.id);
    });

    final result = await CompetitionService.joinCompetition(competition.id);

    if (!mounted) return;

    setState(() {
      _pendingCompetitionActions.remove(competition.id);
    });

    switch (result) {
      case CompetitionJoinResult.success:
        _showSnackBar('"${competition.title}" yarışmasına katıldın!');

        if (!mounted) {
          return;
        }

        await Future.delayed(const Duration(milliseconds: 250));

        if (!mounted) {
          return;
        }

        if (!competition.entries.any((entry) => entry.userId == user.uid)) {
          await _openCompetitionEntry(
            competition,
            forceOpen: true,
          );
        }
        break;
      case CompetitionJoinResult.limitReached:
        _showSnackBar('Aynı anda yalnızca bir yarışmaya katılabilirsin.',
            backgroundColor: Colors.redAccent);
        break;
      case CompetitionJoinResult.alreadyJoined:
        _showSnackBar('Bu yarışmaya zaten katıldın.');
        break;
      case CompetitionJoinResult.closed:
        _showSnackBar('Yarışma şu anda katılıma kapalı.',
            backgroundColor: Colors.redAccent);
        break;
      case CompetitionJoinResult.full:
        _showSnackBar('Yarışma kontenjanı doldu.',
            backgroundColor: Colors.redAccent);
        break;
      case CompetitionJoinResult.unauthorized:
        _showSnackBar('Katılmak için giriş yapmalısın.',
            backgroundColor: Colors.redAccent);
        break;
      case CompetitionJoinResult.notFound:
        _showSnackBar('Yarışma bulunamadı.',
            backgroundColor: Colors.redAccent);
        break;
    }
  }

  Future<void> _handleLeaveCompetition(Competition competition) async {
    if (_pendingCompetitionActions.contains(competition.id)) return;

    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Çıkmak için giriş yapmalısın.',
          backgroundColor: Colors.redAccent);
      return;
    }

    if (!competition.participantUserIds.contains(user.uid)) {
      _showSnackBar('Bu yarışmaya kayıtlı değilsin.',
          backgroundColor: Colors.redAccent);
      return;
    }

    setState(() {
      _pendingCompetitionActions.add(competition.id);
    });

    final result = await CompetitionService.leaveCompetition(competition.id);

    if (!mounted) return;

    setState(() {
      _pendingCompetitionActions.remove(competition.id);
    });

    switch (result) {
      case CompetitionLeaveResult.success:
        _showSnackBar('"${competition.title}" yarışmasından ayrıldın.');
        break;
      case CompetitionLeaveResult.notParticipant:
        _showSnackBar('Bu yarışmaya kayıtlı değilsin.',
            backgroundColor: Colors.redAccent);
        break;
      case CompetitionLeaveResult.unauthorized:
        _showSnackBar('Çıkmak için giriş yapmalısın.',
            backgroundColor: Colors.redAccent);
        break;
      case CompetitionLeaveResult.notFound:
        _showSnackBar('Yarışma bulunamadı.',
            backgroundColor: Colors.redAccent);
        break;
    }
  }

  bool _isJoinWindowOpen(Competition competition) {
    final now = DateTime.now();
    if (now.isAfter(competition.endDate)) {
      return false;
    }
    return competition.status == CompetitionStatus.active ||
        competition.status == CompetitionStatus.upcoming;
  }

  void _showSnackBar(String message, {Color backgroundColor = Colors.orange}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> _confirmAndDeleteCompetition(Competition competition) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                'Yarışmayı Sil',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                '"${competition.title}" yarışmasını silmek istediğine emin misin? Bu işlem geri alınamaz.',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Vazgeç'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text(
                    'Sil',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    final success = await CompetitionService.deleteCompetition(competition.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '"${competition.title}" yarışması silindi.'
            : 'Yarışma silinemedi. Lütfen tekrar deneyin.'),
        backgroundColor: success ? Colors.orange : Colors.redAccent,
      ),
    );
  }
}

class _CompetitionCreationSheet extends StatefulWidget {
  const _CompetitionCreationSheet({
    required this.padding,
    required this.buildInputDecoration,
    required this.typeLabelBuilder,
    required this.formatDateLabel,
    required this.calculateMaxEndDate,
    required this.maxDurationDays,
  });

  final EdgeInsets padding;
  final InputDecoration Function(String label) buildInputDecoration;
  final String Function(CompetitionType type) typeLabelBuilder;
  final String Function(DateTime date) formatDateLabel;
  final DateTime Function(DateTime startDate) calculateMaxEndDate;
  final int maxDurationDays;

  @override
  State<_CompetitionCreationSheet> createState() =>
      _CompetitionCreationSheetState();
}

class _CompetitionCreationSheetState
    extends State<_CompetitionCreationSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _prizeController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late DateTime _selectedStartDate;
  late DateTime _selectedEndDate;
  CompetitionType _selectedType = CompetitionType.communityChoice;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _prizeController = TextEditingController(text: '1000');
    _selectedStartDate = DateTime.now();
    _selectedEndDate =
        _selectedStartDate.add(const Duration(days: 7));
    _startDateController = TextEditingController(
      text: widget.formatDateLabel(_selectedStartDate),
    );
    _endDateController = TextEditingController(
      text: widget.formatDateLabel(_selectedEndDate),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prizeController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Yeni Yarışma',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  decoration: widget.buildInputDecoration('Yarışma Başlığı'),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Başlık gerekli';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: widget.buildInputDecoration('Açıklama'),
                  minLines: 3,
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Açıklama gerekli';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CompetitionType>(
                  value: _selectedType,
                  decoration: widget.buildInputDecoration('Yarışma Türü'),
                  dropdownColor: const Color(0xFF1A1A1A),
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white),
                  items: CompetitionType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            widget.typeLabelBuilder(type),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _prizeController,
                  decoration:
                      widget.buildInputDecoration('Ödül (Krep Coin)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ödül gerekli';
                    }
                    final normalized = value.replaceAll(',', '.');
                    return double.tryParse(normalized) == null
                        ? 'Geçerli bir sayı girin'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startDateController,
                        readOnly: true,
                        decoration:
                            widget.buildInputDecoration('Başlangıç Tarihi'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Başlangıç tarihi gerekli';
                          }
                          return null;
                        },
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedStartDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedStartDate = picked;
                              var ensuredEnd = _selectedEndDate;
                              if (!ensuredEnd.isAfter(_selectedStartDate)) {
                                ensuredEnd =
                                    _selectedStartDate.add(const Duration(days: 1));
                              }
                              final maxEnd =
                                  widget.calculateMaxEndDate(_selectedStartDate);
                              if (ensuredEnd.isAfter(maxEnd)) {
                                ensuredEnd = maxEnd;
                              }
                              _selectedEndDate = ensuredEnd;
                              _startDateController.text =
                                  widget.formatDateLabel(_selectedStartDate);
                              _endDateController.text =
                                  widget.formatDateLabel(_selectedEndDate);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _endDateController,
                        readOnly: true,
                        decoration:
                            widget.buildInputDecoration('Bitiş Tarihi'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitiş tarihi gerekli';
                          }
                          if (!_selectedEndDate.isAfter(_selectedStartDate)) {
                            return 'Bitiş tarihi başlangıçtan sonra olmalı';
                          }
                          final allowedMax =
                              widget.calculateMaxEndDate(_selectedStartDate);
                          if (_selectedEndDate.isAfter(allowedMax)) {
                            return 'Yarışma süresi en fazla ${widget.maxDurationDays} gün olabilir';
                          }
                          return null;
                        },
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedEndDate,
                            firstDate: _selectedStartDate,
                            lastDate:
                                widget.calculateMaxEndDate(_selectedStartDate),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedEndDate = picked;
                              _endDateController.text =
                                  widget.formatDateLabel(_selectedEndDate);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Yarışma süresi en fazla ${widget.maxDurationDays} gün olabilir.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _handleSubmit,
                    child: const Text(
                      'Yarışmayı Oluştur',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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

  void _handleSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final prizeValue = double.parse(
      _prizeController.text.replaceAll(',', '.').trim(),
    );

    Navigator.of(context).pop(
      _CompetitionFormResult(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        prizeKrepCoins: prizeValue,
        startDate: _selectedStartDate,
        endDate: _selectedEndDate,
        type: _selectedType,
      ),
    );
  }
}

class _CompetitionFormResult {
  const _CompetitionFormResult({
    required this.title,
    required this.description,
    required this.prizeKrepCoins,
    required this.startDate,
    required this.endDate,
    required this.type,
  });

  final String title;
  final String description;
  final double prizeKrepCoins;
  final DateTime startDate;
  final DateTime endDate;
  final CompetitionType type;

  Competition toCompetition() {
    final now = DateTime.now();
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final normalizedStart = startDate.isBefore(now) ? now : startDate;
    final status = now.isBefore(normalizedStart)
        ? CompetitionStatus.upcoming
        : now.isAfter(endDate)
            ? CompetitionStatus.ended
            : CompetitionStatus.active;

    return Competition(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      type: type,
      status: status,
      startDate: normalizedStart,
      endDate: endDate,
      votingEndDate: endDate.add(const Duration(days: 2)),
      prizeKrepCoins: prizeKrepCoins,
      createdByUserId: currentUser?.uid,
    );
  }
}