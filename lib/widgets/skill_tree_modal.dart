// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';

import '../database/recovery_database.dart';
import '../services/recovery_pet_service.dart';

class _Perk {
  final int level;
  final String title;
  final String subtitle;
  final IconData icon;
  const _Perk(this.level, this.title, this.subtitle, this.icon);
}

class SkillTreeModal extends StatefulWidget {
  final RecoveryDatabase database;
  const SkillTreeModal({super.key, required this.database});

  @override
  State<SkillTreeModal> createState() => _SkillTreeModalState();
}

class _SkillTreeModalState extends State<SkillTreeModal> {
  List<String> _paths = [];
  RecoveryPet? _pet;
  bool _loading = true;

  static const Map<String, Map<int, _Perk>> _perkMap = {
    '12-Step (AA/NA)': {
      2: _Perk(2, 'Fellowship Aura', 'AA • Warm resonance at meetings', Icons.groups_rounded),
      5: _Perk(5, 'Service Shield', 'AA • Deflects urge spikes when helping', Icons.shield_outlined),
      8: _Perk(8, 'Twelvefold Crown', 'AA • Wisdom of the steps', Icons.emoji_events_outlined),
    },
    'SMART Recovery': {
      2: _Perk(2, 'CBT Spark', 'SMART • Reframe trigger', Icons.lightbulb_outline),
      5: _Perk(5, 'CBT Deflector', 'SMART • Tool-based guard', Icons.security_outlined),
      8: _Perk(8, 'Rational Mastery', 'SMART • Master of balance', Icons.psychology_outlined),
    },
    'Recovery Dharma': {
      2: _Perk(2, 'Mindful Glow', 'DHARMA • Breath-anchored calm', Icons.self_improvement_outlined),
      5: _Perk(5, 'Equanimity Veil', 'DHARMA • Observe urges', Icons.spa_outlined),
      8: _Perk(8, 'Bodhi Light', 'DHARMA • Compassionate clarity', Icons.brightness_7_outlined),
    },
    'Wellbriety': {
      2: _Perk(2, 'Medicine Wheel Bloom', 'Wellbriety • Four-direction balance', Icons.circle_outlined),
      5: _Perk(5, 'Ancestor Guard', 'Wellbriety • Grounded resilience', Icons.shield_moon_outlined),
      8: _Perk(8, 'White Bison Heart', 'Wellbriety • Sacred strength', Icons.favorite_outline),
    },
    'Secular/Agnostic': {
      2: _Perk(2, 'Evidence Lens', 'Secular • Clarity focus', Icons.science_outlined),
      5: _Perk(5, 'Logic Bulwark', 'Secular • Rational deflector', Icons.analytics_outlined),
      8: _Perk(8, 'Humanist Beacon', 'Secular • Self-directed path', Icons.explore_outlined),
    },
    'Therapy & CBT': {
      2: _Perk(2, 'Grounding Sigil', 'Therapy • Halt check', Icons.health_and_safety_outlined),
      5: _Perk(5, 'Resilience Frame', 'CBT • Re-story the urge', Icons.view_module_outlined),
      8: _Perk(8, 'Integration Crown', 'Therapy • Whole-self', Icons.hub_outlined),
    },
  };

  static const Map<int, _Perk> _genericPerks = {
    1: _Perk(1, 'First Light', 'Awakening • Path begins', Icons.auto_awesome),
    3: _Perk(3, 'Steady Step', 'Momentum • Daily check-ins', Icons.trending_up),
    4: _Perk(4, 'Kin Bond', 'Companion • Trust grows', Icons.pets_outlined),
    6: _Perk(6, 'Fellowship Buff', 'QR Handshake • +50 XP', Icons.qr_code_scanner),
    7: _Perk(7, 'Constellation Spark', 'Star • Memory etched', Icons.star_outline),
    9: _Perk(9, 'Sovereign Trail', 'Veteran • Path mastery', Icons.military_tech_outlined),
    10: _Perk(10, 'Luminary', 'Luminary • Light for others', Icons.wb_sunny_outlined),
  };

  List<_Perk> _buildPerks() {
    final perks = <int, _Perk>{};
    for (var i = 1; i <= 10; i++) {
      if (_genericPerks.containsKey(i)) perks[i] = _genericPerks[i]!;
    }
    for (final path in _paths) {
      final map = _perkMap[path];
      if (map == null) continue;
      for (final e in map.entries) {
        perks[e.key] = e.value;
      }
    }
    final sorted = perks.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => e.value).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await widget.database.getProfile('active_user_profile');
    final pet = await RecoveryPetService.ensureHatched();
    List<String> paths = [];
    try {
      if (profile?.activePaths != null && profile!.activePaths.isNotEmpty) {
        final decoded = jsonDecode(profile.activePaths) as List;
        paths = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _paths = paths;
      _pet = RecoveryPetService.evaluateLevel(pet);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final perks = _buildPerks();
    final pet = _pet;
    final level = pet?.pathLevel ?? 1;
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF0F172A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF38BDF8).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.account_tree_outlined, color: Color(0xFF38BDF8)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Skill Tree', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(_paths.isEmpty ? 'Your path' : _paths.join(' • '), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFF472B6).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text('Lv $level', style: const TextStyle(color: Color(0xFFF472B6), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: perks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final perk = perks[index];
                      final achieved = level >= perk.level;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: achieved ? const Color(0xFF38BDF8).withValues(alpha: 0.18) : const Color(0xFF1E293B),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: achieved ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
                                ),
                                child: Icon(perk.icon, size: 18, color: achieved ? const Color(0xFF38BDF8) : const Color(0xFF64748B)),
                              ),
                              if (index != perks.length - 1)
                                Container(width: 2, height: 28, color: achieved ? const Color(0xFF38BDF8).withValues(alpha: 0.35) : const Color(0xFF1E293B)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: achieved ? const Color(0xFF1E293B) : const Color(0xFF0B1220),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: achieved ? const Color(0xFF38BDF8).withValues(alpha: 0.35) : const Color(0xFF1E293B)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Lv ${perk.level} • ${perk.title}', style: TextStyle(color: achieved ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(perk.subtitle, style: TextStyle(color: achieved ? const Color(0xFF94A3B8) : const Color(0xFF475569), fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Icon(achieved ? Icons.check_circle : Icons.lock_outline, color: achieved ? const Color(0xFFF472B6) : const Color(0xFF334155), size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Text('${pet?.pathXp ?? 0} XP total • ${100 - ((pet?.pathXp ?? 0) % 100)} XP to next level', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
