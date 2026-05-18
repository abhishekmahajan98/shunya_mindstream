import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Dark theme ─────────────────────────────────────────────
  static const bgDark = Color(0xFF09090A);
  static const surfaceDark = Color(0xFF121214);
  static const surfaceDark2 = Color(0xFF1A1A1E);
  static const borderDark = Color(0x14FFFFFF); // 8% white

  static const textDark = Color(0xFFE0D8CF);
  static const textDark2 = Color(0xFF9A9390);
  static const textDark3 = Color(0xFF5A5755);

  // ── Light theme ─────────────────────────────────────────────
  static const bgLight = Color(0xFFF8F6F2);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceLight2 = Color(0xFFF0EDE8);
  static const borderLight = Color(0x14000000); // 8% black

  static const textLight = Color(0xFF3C3836);
  static const textLight2 = Color(0xFF7A7470);
  static const textLight3 = Color(0xFFB0ABA5);

  // ── Accent ──────────────────────────────────────────────────
  static const teal = Color(0xFF6AADA0);       // Primary — dark mode
  static const tealDark = Color(0xFF4C8C7F);   // Primary — light mode
  static const tealGlow = Color(0x266AADA0);   // 15% teal

  static const violet = Color(0xFF9B8EC4);
  static const violetGlow = Color(0x269B8EC4);

  static const sand = Color(0xFFD4C5A9);
  static const sandDark = Color(0xFFB8A88A);

  // ── Semantic ────────────────────────────────────────────────
  static const success = Color(0xFF5BAD8A);
  static const error = Color(0xFFCF6679);
  static const warning = Color(0xFFD4A85A);
}
