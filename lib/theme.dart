// Project Services — brand theme (same as the website).
// Deep teal #0C4A4A, warm sand #FAF7F0, amber #D9A03F.
import 'package:flutter/material.dart';

class AppColors {
  static const teal = Color(0xFF0C4A4A);
  static const tealDark = Color(0xFF083838);
  static const tealLight = Color(0xFFE6F0F0);
  static const sand = Color(0xFFFAF7F0);
  static const sandDark = Color(0xFFF0EAD9);
  static const amber = Color(0xFFD9A03F);
  static const amberDark = Color(0xFFB9832A);
  static const ink = Color(0xFF1F2A2A);
  static const inkSoft = Color(0xFF5C6B6B);
  static const line = Color(0xFFE3DDCF);
  static const white = Colors.white;
  static const green = Color(0xFF1E7B34);
  static const red = Color(0xFFB3261E);
}

ThemeData buildTheme() {
  const teal = AppColors.teal;
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.sand,
    colorScheme: ColorScheme.fromSeed(
      seedColor: teal,
      primary: teal,
      secondary: AppColors.amber,
      surface: AppColors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: teal,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: teal,
        side: const BorderSide(color: teal),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: teal, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
  );
}

String formatRs(num value) {
  final n = value.round();
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final fromEnd = s.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return 'Rs. $buf';
}
