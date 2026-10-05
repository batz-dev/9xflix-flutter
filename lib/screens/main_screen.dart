import 'package:flutter/material.dart';
import '../services/download_manager.dart';
import '../constants/app_theme.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'downloads_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final DownloadManager _dm = DownloadManager();

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    DownloadsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 0.8)),
        ),
        child: AnimatedBuilder(
          animation: _dm,
          builder: (context, _) {
            final activeCount = _dm.activeDownloads.length;

            return BottomNavigationBar(
              currentIndex: _currentIndex,
              backgroundColor: AppTheme.surface,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: AppTheme.textMuted,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              type: BottomNavigationBarType.fixed,
              onTap: (index) => setState(() => _currentIndex = index),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_filled),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.download_rounded),
                      if (activeCount > 0)
                        Positioned(
                          top: -3,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                            child: Text(
                              '$activeCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Downloads',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
