import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFF070A12);
  static const card = Color(0xFF0D1220);
  static const card2 = Color(0xFF0B1020);
  static const stroke = Color(0xFF1B2338);
  static const textDim = Color(0xFF9BA8C7);
  static const accent = Color(0xFFFF7A1A);

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
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF070A12),
        selectedItemColor: accent,
        unselectedItemColor: Color(0xFF7D8AAE),
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }
}
