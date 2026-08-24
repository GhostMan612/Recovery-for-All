// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../services/feedback_service.dart';
import '../services/recovery_pet_service.dart';

enum _BattlePhase { playerTurn, enemyTurn, victory, defeat }

class _Ability {
  final String name;
  final int focusCost;
  final int minDamage;
  final int maxDamage;
  final bool heals;
  final bool shields;
  const _Ability(this.name,
      {required this.focusCost, this.minDamage = 0, this.maxDamage = 0,
       this.heals = false, this.shields = false});
}

class _Monster {
  final String name;
  final int maxHp;
  final int minDamage;
  final int maxDamage;
  final bool heals;
  const _Monster(this.name,
      {required this.maxHp, required this.minDamage, required this.maxDamage,
       this.heals = false});
}

class _BattleState {
  _BattlePhase phase = _BattlePhase.playerTurn;
  int resolve = 0;
  int maxResolve = 0;
  int focus = 2;
  int enemyHp = 0;
  bool shieldActive = false;
  _Monster monster =
      const _Monster('Craving Wraith', maxHp: 40, minDamage: 4, maxDamage: 9);
  final List<String> log = [];
  void addLog(String msg) {
    log.insert(0, msg);
    if (log.length > 20) log.removeLast();
  }
}

class PetTrialsScreen extends StatefulWidget {
  const PetTrialsScreen({super.key});

  @override
  State<PetTrialsScreen> createState() => _PetTrialsScreenState();
}

class _PetTrialsScreenState extends State<PetTrialsScreen>
    with SingleTickerProviderStateMixin {
  RecoveryPet? _pet;
  _BattleState? _battle;
  bool _busy = false;
  late AnimationController _shakeController;

  static const int _maxBattlesPerDay = 3;
  static const String _keyBattles = 'pet_trials_battles_v1';

  static const List<_Ability> _abilities = [
    _Ability('Grounding Shield', focusCost: 1, shields: true),
    _Ability('Meeting Rally', focusCost: 2, minDamage: 12, maxDamage: 20),
    _Ability('Gratitude Heal', focusCost: 2, heals: true),
    _Ability('Step Strike', focusCost: 3, minDamage: 25, maxDamage: 40),
  ];

  static const List<_Monster> _monsterPool = [
    _Monster('Craving Wraith', maxHp: 40, minDamage: 4, maxDamage: 9),
    _Monster('Trigger Hound', maxHp: 30, minDamage: 6, maxDamage: 11),
    _Monster('Isolation Fog',
        maxHp: 55, minDamage: 3, maxDamage: 8, heals: true),
  ];

  static const _Monster _reaper = _Monster('Relapse Reaper',
      maxHp: 90, minDamage: 8, maxDamage: 14);

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _load();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final pet = await RecoveryPetService.ensureHatched();
    if (!mounted) return;
    setState(() => _pet = pet);
  }

  Future<int> _battlesToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString('${_keyBattles}_date') != today) return 0;
    return prefs.getInt('${_keyBattles}_count') ?? 0;
  }

  Future<void> _incrementBattles() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('${_keyBattles}_date', today);
    await prefs.setInt('${_keyBattles}_count', await _battlesToday() + 1);
  }

  void _startBattle() {
    final pet = _pet;
    if (pet == null || _busy) return;
    final monster =
        pet.bond >= 50 && math.Random().nextBool() ? _reaper : _pickMonster();
    final maxResolve = 30 + (pet.energy * 0.7).round();
    setState(() {
      _battle = _BattleState()
        ..resolve = maxResolve
        ..maxResolve = maxResolve
        ..enemyHp = monster.maxHp
        ..monster = monster
        ..phase = _BattlePhase.playerTurn;
      _battle!.addLog('A ${monster.name} emerges from the shadows.');
    });
    _incrementBattles();
  }

  _Monster _pickMonster() {
    if ((_pet?.sparks ?? 0) ~/ 100 >= 5) {
      return _monsterPool[math.Random().nextInt(_monsterPool.length)];
    }
    return _monsterPool[math.Random().nextInt(2)];
  }

  Future<void> _useAbility(_Ability ability) async {
    final battle = _battle;
    if (battle == null || _busy || battle.phase != _BattlePhase.playerTurn) return;
    if (battle.focus < ability.focusCost) return;
    _busy = true;
    final rng = math.Random();

    if (ability.heals) {
      battle.resolve = math.min(battle.maxResolve, battle.resolve + 15);
      battle.addLog('15 Resolve restored by ${ability.name}.');
      await FeedbackService.reward();
    } else if (ability.shields) {
      battle.shieldActive = true;
      battle.addLog('Grounding Shield raised.');
      await FeedbackService.selection();
    } else {
      final dmg = ability.minDamage +
          rng.nextInt(ability.maxDamage - ability.minDamage + 1);
      battle.enemyHp = math.max(0, battle.enemyHp - dmg);
      battle.addLog('${ability.name} deals $dmg damage!');
      await FeedbackService.reward();
    }
    battle.focus = math.max(0, battle.focus - ability.focusCost);
    setState(() {});

    if (battle.enemyHp <= 0) {
      battle.phase = _BattlePhase.victory;
      battle.addLog('The ${battle.monster.name} fades. You stood your ground.');
      await RecoveryPetService.logBattleWin();
      await FeedbackService.milestone();
      _busy = false;
      setState(() {});
      return;
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    battle.phase = _BattlePhase.enemyTurn;
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (battle.monster.heals && rng.nextBool()) {
      final heal = 5 + rng.nextInt(4);
      battle.enemyHp = math.min(battle.monster.maxHp, battle.enemyHp + heal);
      battle.addLog('${battle.monster.name} absorbs $heal HP.');
    } else {
      var dmg = battle.monster.minDamage +
          rng.nextInt(battle.monster.maxDamage - battle.monster.minDamage + 1);
      if (battle.shieldActive) {
        dmg = (dmg * 0.3).round();
        battle.shieldActive = false;
        battle.addLog('Grounding Shield absorbed most of the hit!');
      }
      battle.resolve = math.max(0, battle.resolve - dmg);
      battle.addLog('${battle.monster.name} deals $dmg damage.');
    }
    battle.focus = math.min(5, battle.focus + 1);
    battle.phase = _BattlePhase.playerTurn;
    _busy = false;

    if (battle.resolve <= 0) {
      battle.phase = _BattlePhase.defeat;
      battle.addLog(
          'The ${battle.monster.name} retreats. Your companion learned something.');
      await RecoveryPetService.logBattleLearned();
      await FeedbackService.selection();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    final battle = _battle;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Trials of the Path',
            style: TextStyle(color: Colors.white)),
      ),
      body: pet == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : battle == null
              ? _buildLobby(pet)
              : _buildBattle(battle),
    );
  }

  Widget _buildLobby(RecoveryPet pet) {
    return FutureBuilder<int>(
      future: _battlesToday(),
      builder: (context, snapshot) {
        final battles = snapshot.data ?? 0;
        final remaining = _maxBattlesPerDay - battles;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 56, color: AppColors.accent),
                const SizedBox(height: 20),
                const Text('Trials of the Path',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  remaining > 0
                      ? '$remaining trials remaining today.\n'
                          'Face an urge monster using your coping skills.'
                      : 'You have faced enough for today.\n'
                          'Rest — your companion is proud.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.5),
                ),
                const SizedBox(height: 28),
                if (remaining > 0)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text('Begin Trial',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      onPressed: _startBattle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBattle(_BattleState battle) {
    final monsterColor = battle.monster == _reaper
        ? const Color(0xFFDC2626)
        : const Color(0xFF64748B);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: monsterColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text(battle.monster.name,
                    style: TextStyle(
                        color: monsterColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: battle.enemyHp / battle.monster.maxHp,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    color: monsterColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${battle.enemyHp} / ${battle.monster.maxHp} HP',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.builder(
                itemCount: battle.log.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    battle.log[index],
                    style: TextStyle(
                        color: index == 0
                            ? Colors.white
                            : AppColors.textMuted,
                        fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Resolve',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                    Text('${battle.resolve} / ${battle.maxResolve}',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: battle.resolve / battle.maxResolve,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        'Focus: ${"●" * battle.focus}${"○" * (5 - battle.focus)}',
                        style: const TextStyle(
                            color: AppColors.accent, fontSize: 12)),
                    if (battle.shieldActive)
                      const Icon(Icons.shield,
                          size: 16, color: AppColors.success),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (battle.phase == _BattlePhase.playerTurn)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ability in _abilities)
                  _AbilityButton(
                    ability: ability,
                    enabled: battle.focus >= ability.focusCost && !_busy,
                    onTap: () => _useAbility(ability),
                  ),
              ],
            )
          else if (battle.phase == _BattlePhase.victory ||
              battle.phase == _BattlePhase.defeat)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: battle.phase == _BattlePhase.victory
                      ? AppColors.success
                      : AppColors.bgCard,
                  foregroundColor: battle.phase == _BattlePhase.victory
                      ? Colors.white
                      : AppColors.textMuted,
                ),
                onPressed: () => setState(() => _battle = null),
                child: Text(
                    battle.phase == _BattlePhase.victory
                        ? 'Victory — return'
                        : 'Learned something — return',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}

class _AbilityButton extends StatelessWidget {
  final _Ability ability;
  final bool enabled;
  final VoidCallback onTap;

  const _AbilityButton(
      {required this.ability, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.bgCard
              : AppColors.bgCard.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Text(ability.name,
                style: TextStyle(
                    color: enabled ? Colors.white : AppColors.textDim,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${'●' * ability.focusCost} Focus',
                style: TextStyle(
                    color: enabled ? AppColors.accent : AppColors.textDim,
                    fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
