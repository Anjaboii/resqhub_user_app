import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'home/home_screen.dart';
import 'vehicles/vehicles_screen.dart';
import 'history/history_screen.dart';
import 'profile/profile_screen.dart';
import 'Emergency_garages.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final pages = const [
    HomeScreen(),
    VehiclesScreen(),
    HistoryScreen(),
    EmergencyGarages(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF070A12) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1B2338) : const Color(0xFFE2E8F0),
              width: 0.5,
            ),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) => setState(() => index = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.orangeAccent,
          unselectedItemColor: isDark ? Colors.white54 : Colors.grey,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: loc.tr('home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.directions_car_outlined),
              activeIcon: const Icon(Icons.directions_car),
              label: loc.tr('vehicles'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history_outlined),
              activeIcon: const Icon(Icons.history),
              label: loc.tr('history'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.warning_amber_outlined),
              activeIcon: const Icon(Icons.warning_amber_rounded),
              label: loc.tr('emergency'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: loc.tr('profile'),
            ),
          ],
        ),
      ),
    );
  }
}