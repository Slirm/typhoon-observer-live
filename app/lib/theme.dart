import 'package:flutter/material.dart';

abstract final class Palette {
  static const ink = Color(0xff20343e),
      muted = Color(0xff586e79),
      line = Color(0xffdce5e8),
      background = Color(0xfff5f7f8),
      blue = Color(0xff236d85),
      amber = Color(0xff935917),
      ocean = Color(0xffdfedf1),
      land = Color(0xfff2f5ef);
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'NotoSansSC',
  scaffoldBackgroundColor: Palette.background,
  colorScheme: ColorScheme.fromSeed(seedColor: Palette.blue).copyWith(
    primary: Palette.blue,
    secondary: Palette.amber,
    surface: Colors.white,
    onSurface: Palette.ink,
    outline: Palette.muted,
    outlineVariant: Palette.line,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: Palette.ink),
    bodySmall: TextStyle(fontSize: 12, height: 1.6, color: Palette.muted),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.5,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.5,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Palette.ink,
      minimumSize: const Size(44, 42),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      side: const BorderSide(color: Palette.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Palette.line),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: Palette.line,
    thickness: 1,
    space: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Palette.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Palette.line),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  ),
  tooltipTheme: const TooltipThemeData(
    waitDuration: Duration(milliseconds: 350),
  ),
);
