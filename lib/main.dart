import 'package:flutter/material.dart';
import 'services/advanced_ai_service.dart';
import 'services/cringe_notification_service.dart';
import 'services/competition_service.dart';
import 'services/cringe_search_service.dart';
import 'services/user_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';

void main() async {
  // Flutter binding'i initialize et
  WidgetsFlutterBinding.ensureInitialized();
  
  // Servisleri initialize et
  AdvancedAIService.initialize();
  await CringeNotificationService.initialize();
  await CompetitionService.initialize();
  await CringeSearchService.initialize();
  
  runApp(const CringeBankasiApp());
}

class CringeBankasiApp extends StatelessWidget {
  const CringeBankasiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '😬 CRINGE BANKASI',
      theme: ThemeData(
        // Instagram tarzı sadece 2 renk: Beyaz zemin + Siyah metin
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF000000), // Siyah - Ana renk
          secondary: Color(0xFF262626), // Koyu gri - İkincil
          surface: Color(0xFFFFFFFF), // Beyaz - Zemin
          onPrimary: Color(0xFFFFFFFF), // Beyaz yazı siyah üzerinde
          onSecondary: Color(0xFFFFFFFF), // Beyaz yazı gri üzerinde
          onSurface: Color(0xFF000000), // Siyah yazı beyaz üzerinde
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // AppBar teması
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF000000),
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        // Card teması
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
          ),
        ),
        // Scaffold teması
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        // BottomNavigationBar teması
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          selectedItemColor: Color(0xFF000000),
          unselectedItemColor: Color(0xFF8E8E8E),
          elevation: 1,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: UserService.instance.isLoggedIn ? MainNavigation() : LoginScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/main': (context) => MainNavigation(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
