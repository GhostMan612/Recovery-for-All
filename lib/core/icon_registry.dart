// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

class IconRegistry {
  IconRegistry._();

  static const Map<String, IconData> eventIcons = {
    'battle_win': Icons.shield_outlined,
    'battle_learned': Icons.school_outlined,
    'goal_complete': Icons.flag_outlined,
    'star': Icons.star_outline,
    'meeting': Icons.groups_outlined,
    'walk': Icons.directions_walk_outlined,
    'wellness': Icons.favorite_border,
    'check_in': Icons.favorite_outline,
    'journal': Icons.book_outlined,
    'gratitude': Icons.sentiment_satisfied_outlined,
    'grounding': Icons.air_outlined,
  };

  static const Map<String, IconData> toolIcons = {
    'Encrypted Journal': Icons.lock_outline,
    'Daily Reflections': Icons.menu_book_outlined,
    'Urge Surfing Timer': Icons.self_improvement,
    'Meditation Timer': Icons.timer_outlined,
    'Cost-Benefit Analysis': Icons.balance,
    'Meeting Finder': Icons.map_outlined,
    'Medicine Wheel': Icons.auto_awesome_outlined,
    'Wellness Check-In': Icons.donut_large_outlined,
  };

  static IconData eventIcon(String eventType) {
    if (eventType.startsWith('milestone_')) return Icons.emoji_events_outlined;
    if (eventType.startsWith('signoff_')) return Icons.verified_outlined;
    if (eventType.startsWith('worksheet_')) {
      return Icons.assignment_turned_in_outlined;
    }
    return eventIcons[eventType] ?? Icons.circle_outlined;
  }

  static IconData toolIcon(String tool) =>
      toolIcons[tool] ?? Icons.handyman_outlined;
}
