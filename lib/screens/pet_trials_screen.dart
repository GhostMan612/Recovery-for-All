// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/dashboard_providers.dart';
import '../core/providers.dart' show databaseProvider;
import '../core/theme/app_colors.dart';
import '../features/game/application/battle_session_service.dart';
import '../features/game/data/battle_catalog.dart';
import '../features/game/domain/battle_action.dart';
import '../features/game/domain/battle_state.dart';
import '../services/feedback_service.dart';
// Imported for the `RecoveryPet` TYPE only. This screen must not read pet
// state from the service — see the class doc below — but the type is declared
// there, and `dashboardDataProvider` hands back that same type.
import '../services/recovery_pet_service.dart';
import '../widgets/themed_background.dart' show appReduceMotion;
import '../widgets/trial_monster_painter.dart';

class _Pop {
  final String text;
  final Color color;
  double y;
  double opacity;
  _Pop(this.text, this.color, this.y, this.opacity);
}

/// A `ConsumerStatefulWidget` on purpose. This screen used to be a plain
/// `StatefulWidget` holding its own `RecoveryPet? _pet`, populated by calling
/// `RecoveryPetService.ensureHatched()` in `initState`.
///
/// That was a second live copy of the same row, and it is a copy of a value
/// that changes: `_buildLobby` gates an ability on `(_pet?.sparks ?? 0) ~/ 100
/// >= 5`. A one-shot read in `initState` meant the 500-Sparks ability stayed
/// locked for anyone who earned the 500th Spark anywhere else in the app, with
/// no way to re-read it — the navigation shell keeps destinations alive in an
/// `IndexedStack`, so this screen is not torn down and rebuilt either.
///
/// Reading `dashboardDataProvider` makes the duplicate impossible: one owner,
/// and it updates itself.
class PetTrialsScreen extends ConsumerStatefulWidget {
  const PetTrialsScreen({super.key});

  @override
  ConsumerState<PetTrialsScreen> createState() => _PetTrialsScreenState();
}

class _PetTrialsScreenState extends ConsumerState<PetTrialsScreen>
    with TickerProviderStateMixin {
  RecoveryPet? get _pet => ref.watch(dashboardDataProvider).pet;
  BattleState? _battle;
  bool _busy = false;
  BattleDifficulty _selectedDifficulty = BattleDifficulty.standard;
  bool _quietMode = false;
  late AnimationController _breath;
  late AnimationController _shake;
  late AnimationController _flash;
  double _hitFlash = 0;
  double _shakeX = 0;
  double _lunge = 0;
  final List<_Pop> _pops = [];

  TrialMonsterKind _kindFor(BattleMonster m) => m.kind;

  Color _colorFor(BattleMonster m) {
    if (m.kind == TrialMonsterKind.reaper) return Theme.of(context).colorScheme.error;
    if (m.kind == TrialMonsterKind.hound) return AppColors.monsterHound;
    if (m.kind == TrialMonsterKind.fog) return Theme.of(context).colorScheme.primary;
    return Theme.of(context).colorScheme.outline;
  }

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
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
    _maybeShowTutorial();
    _restoreActiveSession();
  }

  Future<void> _restoreActiveSession() async {
    final active = await BattleSessionService.loadActiveSession();
    if (mounted && active != null) {
      setState(() => _battle = active);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!appReduceMotion(context) && !_breath.isAnimating) {
      _breath.repeat();
    } else if (appReduceMotion(context) && _breath.isAnimating) {
      _breath.stop();
      _breath.value = 0;
    }
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
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_stories, color: Theme.of(context).colorScheme.primary, size: 36),
          const SizedBox(height: 12),
          Text('How Trials work',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            'Focus is your inner steadiness. You start each battle with 2-3 Focus '
            'and gain +1 every turn (max 5). Every coping skill costs Focus — '
            'plan your moves.\n\n'
            'Take a Breath restores +2 Focus (free, always available).\n'
            'Grounding Shield blocks the next hit.\n'
            'Meeting Rally and Step Strike deal damage.\n'
            'Gratitude Heal restores Resolve.\n\n'
            'Win or lose, your companion learns. Nothing here can hurt your '
            'real progress.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary),
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
    if (appReduceMotion(context)) return;
    _shake.forward(from: 0);
  }

  void _doFlash() {
    if (appReduceMotion(context)) return;
    _flash.forward(from: 0);
  }

  void _doLunge() async {
    setState(() => _lunge = 14);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _lunge = 0);
  }

  Future<void> _startBattle() async {
    final pet = _pet;
    if (pet == null || _busy) return;
    _busy = true;

    final db = ref.read(databaseProvider);
    final state = await BattleSessionService.startSession(
      db: db,
      petEnergy: pet.energy,
      petBond: pet.bond,
      petSparks: pet.sparks,
      difficulty: _selectedDifficulty,
      isQuietMode: _quietMode,
    );

    setState(() {
      _battle = state;
      _busy = false;
    });
  }

  Future<void> _useAbility(BattleAction ability) async {
    final battle = _battle;
    if (battle == null || _busy || battle.phase != BattlePhase.playerTurn) return;
    if (battle.focus < ability.focusCost) return;
    _busy = true;

    // Trigger visual/haptic feedback for player action
    if (ability.type == BattleActionType.takeBreath) {
      _spawnPop('+2 Focus', Theme.of(context).colorScheme.primary);
      await FeedbackService.battleShield();
    } else if (ability.heals) {
      _spawnPop('+15', Theme.of(context).colorScheme.tertiary);
      await FeedbackService.battleHeal();
    } else if (ability.shields) {
      _spawnPop('Shield', Theme.of(context).colorScheme.tertiary);
      await FeedbackService.battleShield();
    } else if (ability.isEscape) {
      _spawnPop('Safe Exit', Theme.of(context).colorScheme.outline);
    } else if (ability.isReflection) {
      _spawnPop('Mindful', Theme.of(context).colorScheme.primary);
    } else {
      _doLunge();
      _doFlash();
      _spawnPop('Hit!', Theme.of(context).colorScheme.primary);
      await FeedbackService.battleHit();
    }

    // Pure reducer evaluates turn and monster reaction
    final nextState = BattleSessionService.dispatch(battle, ability);
    setState(() => _battle = nextState);

    if (nextState.isTerminal) {
      final db = ref.read(databaseProvider);
      await BattleSessionService.completeSession(db, nextState);

      if (nextState.phase == BattlePhase.victory ||
          nextState.phase == BattlePhase.quietComplete) {
        _spawnPop('Victory!', Colors.white);
        await FeedbackService.milestone();
      } else if (nextState.phase == BattlePhase.learnedDefeat) {
        await FeedbackService.battleDefeat();
      }
      _busy = false;
      setState(() {});
      return;
    }

    // Delay for enemy attack juice if battle continues
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (!nextState.isQuietMode) {
      if (nextState.shieldActive) {
        _spawnPop('Blocked', Theme.of(context).colorScheme.tertiary);
      } else {
        _doShake();
        _doFlash();
      }
    }
    _busy = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    final battle = _battle;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: Text('Trials of the Path',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          IconButton(
            tooltip: 'How Trials work',
            icon: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            onPressed: _maybeShowTutorial,
          ),
        ],
      ),
      body: pet == null
          ? Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : battle == null
              ? _buildLobby(pet)
              : _buildBattle(battle),
    );
  }

  Widget _buildLobby(RecoveryPet pet) {
    return FutureBuilder<int>(
      future: BattleSessionService.getBattlesToday(),
      builder: (context, snapshot) {
        final battles = snapshot.data ?? 0;
        final remaining = BattleSessionService.maxBattlesPerDay - battles;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined,
                    size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('Trials of the Path',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  remaining > 0
                      ? '$remaining trials remaining today.\n'
                          'Face a coping hurdle or practice quiet reflection.'
                      : 'You have faced enough for today.\n'
                          'Quiet reflection is always open.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.5),
                ),
                const SizedBox(height: 16),
                // Gear score & path level display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _GearStat(
                            label: 'Gear Score',
                            value: pet.gearScore.toString(),
                            icon: Icons.diamond_outlined,
                          ),
                          _GearStat(
                            label: 'Path Level',
                            value: pet.pathLevelComputed.toString(),
                            icon: Icons.star_outline,
                          ),
                          _GearStat(
                            label: 'Ability Slots',
                            value: pet.abilitySlots.toString(),
                            icon: Icons.inventory_2_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: (pet.pathXp % 100) / 100.0,
                        minHeight: 6,
                        backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'XP to next level: ${100 - (pet.pathXp % 100)}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Difficulty selection & quiet mode
                SegmentedButton<BattleDifficulty>(
                  segments: const [
                    ButtonSegment(value: BattleDifficulty.guided, label: Text('Guided')),
                    ButtonSegment(value: BattleDifficulty.standard, label: Text('Standard')),
                    ButtonSegment(value: BattleDifficulty.challenge, label: Text('Challenge')),
                  ],
                  selected: {_selectedDifficulty},
                  onSelectionChanged: (val) {
                    setState(() => _selectedDifficulty = val.first);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Quiet / Reflection Mode',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Non-combat mindful coping with equal growth',
                      style: TextStyle(fontSize: 12)),
                  value: _quietMode,
                  onChanged: (val) => setState(() => _quietMode = val),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                if (remaining > 0 || _quietMode)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      icon: Icon(_quietMode ? Icons.self_improvement : Icons.shield_outlined),
                      label: Text(_quietMode ? 'Begin Reflection' : 'Begin Trial',
                          style: const TextStyle(
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

  Widget _buildBattle(BattleState battle) {
    final monsterColor = _colorFor(battle.monster);
    final availableActions =
        BattleCatalog.actionsForSession(isQuietMode: battle.isQuietMode);

    return Transform.translate(
      offset: Offset(_shakeX, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
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
                      value: battle.monster.maxHp > 0
                          ? battle.monster.currentHp / battle.monster.maxHp
                          : 0.0,
                      minHeight: 8,
                      backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                      color: monsterColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${battle.monster.currentHp} / ${battle.monster.maxHp} HP',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildMonsterStage(battle, monsterColor),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: ListView.builder(
                  itemCount: battle.battleLog.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      battle.battleLog[index],
                      style: TextStyle(
                          color: index == 0
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Semantics(
                    label: 'Resolve ${battle.resolve} of ${battle.maxResolve}',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Resolve',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                        Text('${battle.resolve} / ${battle.maxResolve}',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.tertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: ExcludeSemantics(
                      child: LinearProgressIndicator(
                        value: battle.maxResolve > 0
                            ? battle.resolve / battle.maxResolve
                            : 0.0,
                        minHeight: 8,
                        backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    label: 'Focus ${battle.focus} of 5',
                    child: Row(
                      children: [
                        Text('Focus',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                        const SizedBox(width: 8),
                        for (var i = 0; i < 5; i++)
                          ExcludeSemantics(
                            child: Container(
                              margin: const EdgeInsets.only(right: 4),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < battle.focus
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                border: Border.all(
                                    color: i < battle.focus
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outlineVariant),
                                boxShadow: i < battle.focus
                                    ? [
                                        BoxShadow(
                                            color: Theme.of(context).colorScheme.primary
                                                .withValues(alpha: 0.5),
                                            blurRadius: 4)
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text('+1 / turn',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12)),
                        if (battle.shieldActive) ...[
                          const SizedBox(width: 10),
                          Semantics(
                            label: 'Shield active, blocks the next hit',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ExcludeSemantics(
                                    child: Icon(Icons.shield,
                                        size: 12, color: Theme.of(context).colorScheme.tertiary),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('Shield',
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.tertiary, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (battle.phase == BattlePhase.playerTurn)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ability in availableActions)
                    _AbilityButton(
                      ability: ability,
                      enabled: battle.focus >= ability.focusCost && !_busy,
                      onTap: () => _useAbility(ability),
                    ),
                ],
              )
            else if (battle.isTerminal)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (battle.phase == BattlePhase.victory ||
                            battle.phase == BattlePhase.quietComplete)
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.surfaceContainer,
                    foregroundColor: (battle.phase == BattlePhase.victory ||
                            battle.phase == BattlePhase.quietComplete)
                        ? Theme.of(context).colorScheme.onTertiary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => setState(() => _battle = null),
                  child: Text(
                      (battle.phase == BattlePhase.victory ||
                              battle.phase == BattlePhase.quietComplete)
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

  Widget _buildMonsterStage(BattleState battle, Color monsterColor) {
    return SizedBox(
      height: 200,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: TrialAmbiencePainter(
                    t: _breath.value, tint: monsterColor),
              ),
            ),
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
                              shadows: [
                                Shadow(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1))
                              ])),
                    ),
                  ),
                ),
              ),
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
                            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.5),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.18),
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
  final BattleAction ability;
  final bool enabled;
  final VoidCallback onTap;

  const _AbilityButton(
      {required this.ability, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${ability.name}, ${ability.focusCost} Focus',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? Theme.of(context).colorScheme.surfaceContainer
              : Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ability.name,
                    style: TextStyle(
                        color: enabled
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.outline,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: enabled
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: enabled
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                            : Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Text('${ability.focusCost}●',
                      style: TextStyle(
                          color:
                              enabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                          fontSize: 12,
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
                        : ability.isEscape
                            ? 'Safe Exit'
                            : ability.isReflection
                                ? 'Mindful Step'
                                : '${ability.minDamage}–${ability.maxDamage} dmg',
                style: TextStyle(
                    color: enabled ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.outline,
                    fontSize: 12)),
          ],
        ),
        ),
      ),
    );
  }
}

/// Gear stat display widget for the Trials lobby.
class _GearStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _GearStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
