import 'package:flutter/material.dart';

/// Central color tokens for MediSync's "Medical teal + mint" light theme.
///
/// Every screen and widget pulls from here so the app reads as one system and
/// the palette can be re-skinned from a single file.
class AppColors {
  AppColors._();

  // Surfaces
  static const bg = Color(0xFFF0FDF4); // light mint-green app background
  static const surface = Color(0xFFFFFFFF); // cards
  static const surfaceAlt = Color(0xFFF1F5F9); // inputs, code blocks, fills

  // Brand
  static const primary = Color(0xFF0D9488); // teal
  static const primaryDark = Color(0xFF0F766E); // deeper teal (pressed/hover)
  static const accent = Color(0xFF34D399); // mint

  // Text
  static const text = Color(0xFF0F172A); // primary ink (slate)
  static const textMuted = Color(0xFF64748B); // secondary text
  static const textFaint = Color(0xFF94A3B8); // tertiary / axis labels

  // Lines & states
  static const border = Color(0xFFE2E8F0);
  static const onPrimary = Color(0xFFFFFFFF); // text/icons on teal
  static const danger = Color(0xFFEF4444);

  /// The signature gradient used for the logo, tiles, and hero accents.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent],
  );
}
