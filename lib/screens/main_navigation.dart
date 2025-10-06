import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../theme/app_theme.dart';
import '../widgets/modern_bottom_navigation.dart';
import 'modern_home_screen.dart';
import 'modern_cringe_deposit_screen.dart';
import 'simple_profile_screen.dart';
import 'modern_competitions_screen.dart';
import 'modern_search_screen.dart';
import 'admin_test_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  int _previousIndex = 0;

  List<Widget> get _screens => [
    const ModernHomeScreen(), // 0: Ana akış
    ModernCringeDepositScreen(
      onCringeSubmitted: () {
        // Krep paylaşıldıktan sonra ana sayfaya geç
        setState(() {
          _previousIndex = 0;
          _selectedIndex = 0;
        });
      },
      onCloseRequested: () {
        setState(() {
          _selectedIndex = _previousIndex;
        });
      },
    ), // 1: Yeni krep ekle
    const ModernSearchScreen(), // 2: Arama
    const ModernCompetitionsScreen(), // 3: Yarışmalar
    const SimpleProfileScreen(), // 4: Profil
  ];

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _screens[_selectedIndex],
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      // 🛡️ Admin Test Panel (Development only)
      floatingActionButton: kDebugMode
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminTestPage(),
                  ),
                );
              },
              backgroundColor: Colors.deepPurple,
              tooltip: 'Admin Test Panel',
              child: const Icon(Icons.admin_panel_settings),
            )
          : null,
    );
  }
}
