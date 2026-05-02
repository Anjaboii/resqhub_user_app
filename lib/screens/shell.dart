import 'package:flutter/material.dart';
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

  // Updated to 5 pages
  final pages = const [
    HomeScreen(),
    VehiclesScreen(),
    HistoryScreen(),
    EmergencyGarages(), // New Tab
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF070A12),
          border: Border(
            top: BorderSide(color: Color(0xFF1B2338), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) => setState(() => index = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.orangeAccent, // Changed to orange to match theme
          unselectedItemColor: Colors.white54,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car_outlined),
              activeIcon: Icon(Icons.directions_car),
              label: "Vehicles",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: "History",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warning_amber_outlined), // Emergency Icon
              activeIcon: Icon(Icons.warning_amber_rounded),
              label: "Emergency",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}