import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFF0F172A);
  static const card = Color(0xFF1E293B);
  static const stroke = Color(0xFF334155);
  static const textDim = Color(0xFF94A3B8);
  static const accent = Color(0xFF648F3C); // Your Green

  static const List<Color> sosGradient = [Color(0xFF6366F1), Color(0xFFA855F7)];

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surface: card,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: accent,
        unselectedItemColor: textDim,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}