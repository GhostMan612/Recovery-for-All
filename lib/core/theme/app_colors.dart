// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  static const Color bgDeep = Color(0xFF0F172A);
  static const Color bgCard = Color(0xFF1E293B);
  static const Color border = Color(0xFF334155);
  static const Color accent = Color(0xFF38BDF8);
  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFDC2626);
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDim = Color(0xFF64748B);
  static const Color textHint = Color(0xFF475569);

  static Color scrim([double opacity = 0.72]) => bgDeep.withValues(alpha: opacity);
}
