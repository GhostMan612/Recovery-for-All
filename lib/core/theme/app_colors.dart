// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

/// Shared design tokens for Recovery Companion.
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

  /// Default scrim over photographic backgrounds so body text stays readable.
  static Color scrim([double opacity = 0.72]) => bgDeep.withValues(alpha: opacity);
}
