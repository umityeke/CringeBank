import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_bottom_navigation.dart';
import 'modern_home_screen.dart';
import 'modern_cringe_deposit_screen.dart';
import 'modern_profile_screen.dart';
import 'modern_competitions_screen.dart';
import 'modern_search_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ModernHomeScreen(), // Twitter tarzı ana akış  
    const ModernSearchScreen(), // Arama/Keşfet
    const ModernCringeDepositScreen(), // Yeni krep ekle
    const ModernCompetitionsScreen(), // Yarışmalar (Aktivite)
    const ModernProfileScreen(), // Profil
  ];

  void _onItemTapped(int index) {
    setState(() {
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
    );
  }
}
