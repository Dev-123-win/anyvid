import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'providers/downloads_provider.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => DownloadsProvider())],
      child: const AnyVidApp(),
    ),
  );
}

class AnyVidApp extends StatelessWidget {
  const AnyVidApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(brightness: Brightness.light);

    return MaterialApp(
      title: 'AnyVid',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0061FF),
          surface: const Color(0xFFFAFAFA),
          primary: const Color(0xFF0061FF),
        ),
        textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
          displaySmall: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
          titleLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        MobileAds.instance.initialize();
      });
    });
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentIndex = index),
            indicatorColor: const Color(0xFF0061FF).withValues(alpha: 0.1),
            destinations: [
              NavigationDestination(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedHome01,
                  color: Colors.grey,
                  size: 24,
                ),
                selectedIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedHome01,
                  color: Color(0xFF0061FF),
                  size: 24,
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedPlayList,
                  color: Colors.grey,
                  size: 24,
                ),
                selectedIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedPlayList,
                  color: Color(0xFF0061FF),
                  size: 24,
                ),
                label: 'Library',
              ),
              NavigationDestination(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedSettings03,
                  color: Colors.grey,
                  size: 24,
                ),
                selectedIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedSettings03,
                  color: Color(0xFF0061FF),
                  size: 24,
                ),
                label: 'Settings',
              ),
            ],
          ),
          AdService.getBannerWidget(),
        ],
      ),
    );
  }
}
