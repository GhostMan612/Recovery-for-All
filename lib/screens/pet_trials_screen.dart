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
import '../widgets/trial_monster_painter.dart';

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

class _Pop {
  final String text;
  final Color color;
  double y;
  double opacity;
  _Pop(this.text, this.color, this.y, this.opacity);
}

class PetTrialsScreen extends StatefulWidget {
  const PetTrialsScreen({super.key});

  @override
  State<PetTrialsScreen> createState() => _PetTrialsScreenState();
}

class _PetTrialsScreenState extends State<PetTrialsScreen>
    with TickerProviderStateMixin {
  RecoveryPet? _pet;
  _BattleState? _battle;
  bool _busy = false;
  late AnimationController _breath;
  late AnimationController _shake;
  late AnimationController _flash;
  double _hitFlash = 0;
  double _shakeX = 0;
  double _lunge = 0;
  final List<_Pop> _pops = [];

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

  TrialMonsterKind _kindFor(_Monster m) {
    if (m == _reaper) return TrialMonsterKind.reaper;
    if (m.name.contains('Hound')) return TrialMonsterKind.hound;
    if (m.name.contains('Fog')) return TrialMonsterKind.fog;
    return TrialMonsterKind.wraith;
  }

  Color _colorFor(_Monster m) {
    if (m == _reaper) return const Color(0xFFDC2626);
    if (m.name.contains('Hound')) return const Color(0xFFEA580C);
    if (m.name.contains('Fog')) return const Color(0xFF38BDF8);
    return const Color(0xFF64748B);
  }

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _flash = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _shake.addListener(() {
      final t = _shake.value;
      final decay = 1 - t;
      setState(() => _shakeX = math.sin(t * math.pi * 6) * 10 * decay);
    });
    _flash.addListener(() => setState(() => _hitFlash = 1 - _flash.value));
    _load();
    _maybeShowTutorial();
  }

  Future<void> _maybeShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('seen_trials_tutorial') ?? false) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await prefs.setBool('seen_trials_tutorial', true);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_stories, color: AppColors.accent, size: 36),
          const SizedBox(height: 12),
          const Text('How Trials work',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
            'Focus is your inner steadiness. You start each battle with 2 Focus '
            'and gain +1 every turn (max 5). Every coping skill costs Focus — '
            'plan your moves.\n\n'
            'Grounding Shield blocks the next hit.\n'
            'Meeting Rally and Step Strike deal damage.\n'
            'Gratitude Heal restores Resolve.\n\n'
            'Win or lose, your companion learns. Nothing here can hurt your '
            'real progress.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text('Begin'),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _breath.dispose();
    _shake.dispose();
    _flash.dispose();
    super.dispose();
  }

  void _spawnPop(String text, Color color) {
    final pop = _Pop(text, color, 0, 1);
    setState(() => _pops.add(pop));
    Future<void>.delayed(const Duration(milliseconds: 40), () {
      if (!mounted) return;
      setState(() => pop.y = -42);
    });
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        pop.opacity = 0;
        _pops.remove(pop);
      });
    });
  }

  void _doShake() {
    _shake.forward(from: 0);
  }

  void _doFlash() {
    _flash.forward(from: 0);
  }

  void _doLunge() async {
    setState(() => _lunge = 14);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _lunge = 0);
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
      _spawnPop('+15', AppColors.success);
      await FeedbackService.battleHeal();
    } else if (ability.shields) {
      battle.shieldActive = true;
      battle.addLog('Grounding Shield raised.');
      _spawnPop('Shield', AppColors.success);
      await FeedbackService.battleShield();
    } else {
      final dmg = ability.minDamage +
          rng.nextInt(ability.maxDamage - ability.minDamage + 1);
      battle.enemyHp = math.max(0, battle.enemyHp - dmg);
      battle.addLog('${ability.name} deals $dmg damage!');
      _doLunge();
      _doFlash();
      _spawnPop('-$dmg', AppColors.accent);
      await FeedbackService.battleHit();
    }
    battle.focus = math.max(0, battle.focus - ability.focusCost);
    setState(() {});

    if (battle.enemyHp <= 0) {
      battle.phase = _BattlePhase.victory;
      battle.addLog('The ${battle.monster.name} fades. You stood your ground.');
      _spawnPop('Victory!', Colors.white);
      await RecoveryPetService.logBattleWin();
      await FeedbackService.milestone();
      _busy = false;
      setState(() {});
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    battle.phase = _BattlePhase.enemyTurn;
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (battle.monster.heals && rng.nextBool()) {
      final heal = 5 + rng.nextInt(4);
      battle.enemyHp = math.min(battle.monster.maxHp, battle.enemyHp + heal);
      battle.addLog('${battle.monster.name} absorbs $heal HP.');
      _spawnPop('+$heal', _colorFor(battle.monster));
    } else {
      var dmg = battle.monster.minDamage +
          rng.nextInt(battle.monster.maxDamage - battle.monster.minDamage + 1);
      if (battle.shieldActive) {
        dmg = (dmg * 0.3).round();
        battle.shieldActive = false;
        battle.addLog('Grounding Shield absorbed most of the hit!');
        _spawnPop('-$dmg blocked', AppColors.success);
      } else {
        battle.addLog('${battle.monster.name} deals $dmg damage.');
        _spawnPop('-$dmg', const Color(0xFFEF4444));
        _doShake();
        _doFlash();
      }
      battle.resolve = math.max(0, battle.resolve - dmg);
    }
    battle.focus = math.min(5, battle.focus + 1);
    battle.phase = _BattlePhase.playerTurn;
    _busy = false;

    if (battle.resolve <= 0) {
      battle.phase = _BattlePhase.defeat;
      battle.addLog(
          'The ${battle.monster.name} retreats. Your companion learned something.');
      await RecoveryPetService.logBattleLearned();
      await FeedbackService.battleDefeat();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            onPressed: _maybeShowTutorial,
          ),
        ],
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
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _maybeShowTutorial,
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('How to play'),
                ),
                const SizedBox(height: 12),
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
    final monsterColor = _colorFor(battle.monster);
    return Transform.translate(
      offset: Offset(_shakeX, 0),
      child: Padding(
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
            // Monster stage — the heart of the juice
            _buildMonsterStage(battle, monsterColor),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Focus',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                      for (var i = 0; i < 5; i++)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < battle.focus
                                ? AppColors.accent
                                : Colors.transparent,
                            border: Border.all(
                                color: i < battle.focus
                                    ? AppColors.accent
                                    : AppColors.border),
                            boxShadow: i < battle.focus
                                ? [
                                    BoxShadow(
                                        color: AppColors.accent
                                            .withValues(alpha: 0.5),
                                        blurRadius: 4)
                                  ]
                                : null,
                          ),
                        ),
                      const Spacer(),
                      Text('+1 / turn',
                          style: TextStyle(
                              color: AppColors.textMuted
                                  .withValues(alpha: 0.7),
                              fontSize: 10)),
                      if (battle.shieldActive) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield,
                                  size: 12, color: AppColors.success),
                              SizedBox(width: 4),
                              Text('Shield',
                                  style: TextStyle(
                                      color: AppColors.success, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
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
      ),
    );
  }

  Widget _buildMonsterStage(_BattleState battle, Color monsterColor) {
    return SizedBox(
      height: 200,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            // Ambience backdrop
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: TrialAmbiencePainter(
                    t: _breath.value, tint: monsterColor),
              ),
            ),
            // Monster
            Center(
              child: Transform.translate(
                offset: Offset(_lunge, 0),
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(
                    painter: TrialMonsterPainter(
                      kind: _kindFor(battle.monster),
                      baseColor: Color.lerp(
                              monsterColor, Colors.white, _hitFlash * 0.55) ??
                          monsterColor,
                      t: _breath.value,
                      hitFlash: _hitFlash,
                    ),
                  ),
                ),
              ),
            ),
            // Damage pops
            for (final pop in _pops)
              Positioned(
                left: 0,
                right: 0,
                top: 24 + pop.y,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 140),
                    opacity: pop.opacity,
                    child: Center(
                      child: Text(pop.text,
                          style: TextStyle(
                              color: pop.color,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              shadows: const [
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 6,
                                    offset: Offset(0, 1))
                              ])),
                    ),
                  ),
                ),
              ),
            // Shield ring overlay
            if (battle.shieldActive)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.5),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppColors.success.withValues(alpha: 0.18),
                              blurRadius: 18,
                              spreadRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ability.name,
                    style: TextStyle(
                        color: enabled ? Colors.white : AppColors.textDim,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: enabled
                        ? AppColors.accent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: enabled
                            ? AppColors.accent.withValues(alpha: 0.5)
                            : AppColors.border),
                  ),
                  child: Text('${ability.focusCost}●',
                      style: TextStyle(
                          color:
                              enabled ? AppColors.accent : AppColors.textDim,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
                ability.shields
                    ? 'Block next hit'
                    : ability.heals
                        ? 'Restore 15 Resolve'
                        : '${ability.minDamage}–${ability.maxDamage} dmg',
                style: TextStyle(
                    color: enabled ? AppColors.textMuted : AppColors.textDim,
                    fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
