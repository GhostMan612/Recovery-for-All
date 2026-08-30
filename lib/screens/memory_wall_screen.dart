// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/recovery_pet_service.dart';

/// Dedicated view for the "Kin Remembers..." memory wall.
/// Shows the user's recovery event history (pet_events) chronologically,
/// newest first, paginated with a "Load more" pattern.
class MemoryWallScreen extends StatefulWidget {
  final RecoveryDatabase database;
  final String? petId;

  const MemoryWallScreen({
    super.key,
    required this.database,
    this.petId,
  });

  @override
  State<MemoryWallScreen> createState() => _MemoryWallScreenState();
}

class _MemoryWallScreenState extends State<MemoryWallScreen> {
  static const int _pageSize = 50;

  late final String _petId;
  late final Stream<List<PetEventRow>> _eventStream;

  @override
  void initState() {
    super.initState();
    _petId = widget.petId ?? RecoveryPetService.defaultPetId;
    _eventStream = widget.database.watchPetEvents(_petId);
  }

  String _formatTimestamp(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return diff.inMinutes <= 1
            ? 'Just now'
            : '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _memoryLine(PetEventRow e) {
    final t = e.eventType;
    if (t.startsWith('milestone_')) {
      return 'Kin remembers your ${t.substring(10)} chip.';
    }
    if (t.startsWith('signoff_step')) {
      return 'Kin remembers step ${t.substring(12)} signed off.';
    }
    if (t.startsWith('worksheet_step')) {
      return 'Kin remembers step ${t.substring(14)} worked through.';
    }
    if (t.startsWith('worksheet_')) {
      return 'Kin remembers a worksheet faced honestly.';
    }
    switch (t) {
      case 'battle_win':
        return 'Kin remembers a Trial won.';
      case 'battle_learned':
        return 'Kin remembers learning something the hard way.';
      case 'goal_complete':
        return 'Kin remembers a weekly goal finished.';
      case 'star':
        return 'Kin remembers a star added to your sky.';
      case 'meeting':
        return 'Kin remembers a room you walked into.';
      case 'walk':
        return 'Kin remembers moving together.';
      case 'wellness':
        return 'Kin remembers the wellness wheel checked.';
      case 'check_in':
        return 'Kin remembers a daily check-in.';
      case 'journal':
        return 'Kin remembers words put to page.';
      case 'gratitude':
        return 'Kin remembers a moment of gratitude.';
      case 'grounding':
        return 'Kin remembers grounding breaths taken.';
      case 'species_ember_kit':
      case 'species_tide_kin':
      case 'species_moss_sprite':
      case 'species_star_whelp':
      case 'species_sovereign_linx':
      case 'species_riverglass_otter':
      case 'species_prairie_ember_hare':
      case 'species_north_star_loon':
        return 'Kin remembers a new form adopted.';
    }
    return 'Kin remembers a moment of care.';
  }

  IconData _iconForEvent(String eventType) {
    if (eventType.startsWith('milestone_')) return Icons.emoji_events_outlined;
    if (eventType.startsWith('signoff_')) return Icons.verified_outlined;
    if (eventType.startsWith('worksheet_')) return Icons.assignment_turned_in_outlined;
    switch (eventType) {
      case 'battle_win':
        return Icons.shield_outlined;
      case 'battle_learned':
        return Icons.school_outlined;
      case 'goal_complete':
        return Icons.flag_outlined;
      case 'star':
        return Icons.star_outline;
      case 'meeting':
        return Icons.groups_outlined;
      case 'walk':
        return Icons.directions_walk_outlined;
      case 'wellness':
        return Icons.favorite_border;
      case 'check_in':
        return Icons.favorite_outline;
      case 'journal':
        return Icons.book_outlined;
      case 'gratitude':
        return Icons.sentiment_satisfied_outlined;
      case 'grounding':
        return Icons.air_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _colorForEvent(String eventType) {
    if (eventType.startsWith('milestone_')) return AppColors.accent;
    if (eventType.startsWith('signoff_')) return Colors.amber;
    if (eventType.startsWith('worksheet_')) return Colors.blueAccent;
    switch (eventType) {
      case 'battle_win':
        return AppColors.success;
      case 'battle_learned':
        return Colors.orangeAccent;
      case 'goal_complete':
        return AppColors.accent;
      case 'star':
        return Colors.yellowAccent;
      case 'meeting':
        return Colors.purpleAccent;
      case 'walk':
        return Colors.tealAccent;
      case 'wellness':
        return Colors.pinkAccent;
      case 'check_in':
        return Colors.redAccent;
      case 'journal':
        return Colors.lightBlueAccent;
      case 'gratitude':
        return Colors.amberAccent;
      case 'grounding':
        return Colors.greenAccent;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Kin Remembers',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<PetEventRow>>(
        stream: _eventStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          final allEvents = snapshot.data ?? const <PetEventRow>[];
          final events = allEvents.take(_pageSize).toList();

          if (events.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length + (events.length < allEvents.length ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == events.length) {
                return _buildLoadMoreIndicator(allEvents.length);
              }
              final event = events[index];
              return _buildEventCard(event);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 64,
              color: AppColors.accent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Your recovery constellation of memories will appear here as you log events.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check in, journal, ground, take a walk \u2014 each moment becomes a star.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textDim,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator(int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Text(
        'Showing $_pageSize of $totalCount memories',
        style: TextStyle(color: AppColors.textDim, fontSize: 12),
      ),
    );
  }

  Widget _buildEventCard(PetEventRow event) {
    final color = _colorForEvent(event.eventType);
    final icon = _iconForEvent(event.eventType);
    final timeAgo = _formatTimestamp(event.timestamp);
    final hasSparks = event.sparksDelta > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _memoryLine(event),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      timeAgo,
                      style: TextStyle(
                        color: AppColors.textDim,
                        fontSize: 11,
                      ),
                    ),
                    if (hasSparks) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.auto_awesome, size: 12, color: AppColors.accent),
                      const SizedBox(width: 2),
                      Text(
                        '+${event.sparksDelta} \u2726',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}