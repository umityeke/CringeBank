import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../widgets/animated_bubble_background.dart';

class ModernCompetitionsScreen extends StatefulWidget {
  const ModernCompetitionsScreen({super.key});

  @override
  State<ModernCompetitionsScreen> createState() => _ModernCompetitionsScreenState();
}

class _ModernCompetitionsScreenState extends State<ModernCompetitionsScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _tabController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  int _selectedTab = 0;
  final PageController _pageController = PageController();

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

    _controller.forward();
  }

  @override
  void dispose() {
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
                      gradient: AppTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor.withOpacity(0.3),
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
                    child: const Text(
                      '🔥 3 Aktif',
                      style: TextStyle(
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
        ? AppTheme.accentColor.withOpacity(0.8)
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
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) {
              return _buildCompetitionCard(index);
            },
          ),
        );
      },
    );
  }

  Widget _buildCompetitionCard(int index) {
    final competitions = [
      {
        'title': 'Haftalık Krep Yarışması',
        'description': 'Bu haftanın en utanç verici anı kazanır!',
        'prize': '1000 🪙',
        'participants': 127,
        'timeLeft': '2 gün 14 saat',
        'color': Colors.orange,
        'icon': Icons.emoji_events,
      },
      {
        'title': 'Aylık Mega Krep',
        'description': 'Aylık büyük ödül! Premium özellikler kazanın',
        'prize': '5000 🪙 + Premium',
        'participants': 543,
        'timeLeft': '18 gün 6 saat',
        'color': Colors.purple,
        'icon': Icons.military_tech,
      },
      {
        'title': 'Yeni Başlayanlar Kupası',
        'description': 'İlk haftanızda mı? Bu sizin için!',
        'prize': '500 🪙',
        'participants': 89,
        'timeLeft': '5 gün 3 saat',
        'color': Colors.green,
        'icon': Icons.star,
      },
    ];

    final competition = competitions[index];
    
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
                        color: (competition['color'] as Color).withOpacity(0.2),
                      ),
                      child: Icon(
                        competition['icon'] as IconData,
                        color: competition['color'] as Color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            competition['title'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            competition['description'] as String,
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
                              competition['prize'] as String,
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
                              '${competition['participants']} kişi',
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
                              competition['timeLeft'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: competition['color'] as Color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: competition['color'] as Color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Yarışmaya Katıl',
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
                      : AppTheme.accentColor.withOpacity(0.3),
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                const Text(
                  'Henüz yarışmaya katılmadınız',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'İlk yarışmanıza katılın ve ödül kazanın!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
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
                    backgroundColor: AppTheme.accentColor,
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
            ),
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
            onPressed: () {},
            backgroundColor: AppTheme.accentColor,
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
}