import 'package:flutter/material.dart';

const Color primaryDark = Color(0xFF1B233A);
const Color bgLight = Color(0xFFF3F4ED);
const Color accentGreen = Color(0xFF26C281);
const Color accentOrange = Color(0xFFFFA726);
const Color textDark = Color(0xFF202636);
const Color textGrey = Color(0xFF7C8291);

ThemeData smartCupTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bgLight,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accentGreen,
      primary: primaryDark,
    ),
    fontFamily: 'Arial',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: textDark,
    ),
  );
}