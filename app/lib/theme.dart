import 'package:flutter/material.dart';

/// A light, clinical palette: calm teal for information, red and amber kept
/// for red flags only, so they stand out.
abstract final class C {
  static const background = Color(0xFFF4F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE2E6EA);
  static const text = Color(0xFF101828);
  static const muted = Color(0xFF5B6675);
  static const primary = Color(0xFF0F766E);
  static const alarm = Color(0xFFB42318);
  static const urgent = Color(0xFFB54708);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: C.primary, surface: C.surface);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: C.background,
    appBarTheme: const AppBarTheme(backgroundColor: C.background, foregroundColor: C.text, elevation: 0, scrolledUnderElevation: 0),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    ),
  );
}
