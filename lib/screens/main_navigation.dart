import 'package:flutter/material.dart';
import 'home_screen_twitter.dart';
import 'cringe_deposit_screen.dart';
import 'profile_screen.dart';
import 'competitions_screen.dart';
import 'search_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),      // Twitter tarzı ana akış
    SearchScreen(),    // Arama/Keşfet
    CringeDepositScreen(), // Yeni krep ekle 
    CompetitionsScreen(), // Yarışmalar (Aktivite)
    ProfileScreen(),   // Profil
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE1E8ED), width: 0.5)),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: const Color(0xFF8E8E8E),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          elevation: 0,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            // Instagram tarzı Ana Sayfa
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 26),
              activeIcon: Icon(Icons.home, size: 26),
              label: 'Ana Sayfa',
            ),
            // Instagram tarzı Arama
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined, size: 26),
              activeIcon: Icon(Icons.search, size: 26),
              label: 'Arama',
            ),
            // Instagram tarzı Yeni Post (Krep Ekle)
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined, size: 26),
              activeIcon: Icon(Icons.add_box, size: 26),
              label: 'Ekle',
            ),
            // Instagram tarzı Yarışmalar (Kalp)
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border, size: 26),
              activeIcon: Icon(Icons.favorite, size: 26),
              label: 'Yarışmalar',
            ),
            // Instagram tarzı Profil
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 26),
              activeIcon: Icon(Icons.person, size: 26),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
