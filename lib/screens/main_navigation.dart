import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/app/application/navigation_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_bottom_navigation.dart';
import 'modern_home_screen.dart';
import 'modern_cringe_deposit_screen.dart';
import 'simple_profile_screen.dart';
import 'modern_competitions_screen.dart';
import 'modern_search_screen.dart';

class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationControllerProvider);
    final navigationController = ref.read(
      navigationControllerProvider.notifier,
    );

    final screens = <Widget>[
      const ModernHomeScreen(), // 0: Ana akış
      ModernCringeDepositScreen(
        onCringeSubmitted: navigationController.resetToHome,
        onCloseRequested: navigationController.restorePrevious,
      ), // 1: Yeni krep ekle
      const ModernSearchScreen(), // 2: Arama
      const ModernCompetitionsScreen(), // 3: Yarışmalar
      const SimpleProfileScreen(), // 4: Profil
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: screens[navigationState.selectedIndex],
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: navigationState.selectedIndex,
        onTap: navigationController.select,
      ),
    );
  }
}
