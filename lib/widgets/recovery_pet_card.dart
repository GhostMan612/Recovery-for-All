// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/recovery_pet_service.dart';

/// Compact dashboard card for the Path Companion.
class RecoveryPetCard extends StatelessWidget {
  final RecoveryPet pet;
  final VoidCallback? onCheckIn;
  final VoidCallback? onWalk;
  final VoidCallback? onOpen;

  const RecoveryPetCard({
    super.key,
    required this.pet,
    this.onCheckIn,
    this.onWalk,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(mood: pet.mood, resting: pet.isResting),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pet.isResting
                              ? 'Resting · I’m here when you are'
                              : '${pet.mood.emoji} ${pet.mood.label}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '✦ ${pet.sparks}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatBar(label: 'Energy', value: pet.energy, color: AppColors.success),
              const SizedBox(height: 8),
              _StatBar(label: 'Bond', value: pet.bond, color: AppColors.accent),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCheckIn,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Check in'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onWalk,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('I walked'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final PetMood mood;
  final bool resting;

  const _Avatar({required this.mood, required this.resting});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            resting
                ? AppColors.textDim
                : AppColors.accent.withValues(alpha: 0.9),
            AppColors.bgDeep,
          ],
        ),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        resting ? '😴' : mood.emoji,
        style: const TextStyle(fontSize: 26),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.bgDeep,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple mood picker sheet for check-in → Sparks.
Future<PetMood?> showPetCheckInSheet(BuildContext context) {
  return showModalBottomSheet<PetMood>(
    context: context,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final options = [
        PetMood.happy,
        PetMood.hopeful,
        PetMood.calm,
        PetMood.struggling,
      ];
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How are you feeling?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your companion grows with honesty — not perfection.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...options.map(
              (m) => ListTile(
                leading: Text(m.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(
                  m == PetMood.struggling ? 'Struggling' : m.label,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(context, m),
              ),
            ),
          ],
        ),
      );
    },
  );
}
