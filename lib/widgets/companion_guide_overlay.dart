// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// lib/widgets/companion_guide_overlay.dart
//
// Pet-avatar guide overlay — draggable, collapsible, reduce-motion aware.
// Shows the next eligible tutorial from CompanionGuideService.
// Self-healing: never crashes if a tutorial's route is missing.
// Uses AvatarVisualLayer + Lottie aura (reuses pet_home_screen avatar).

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

import '../services/companion_guide_service.dart';
import '../services/recovery_pet_service.dart';
import '../widgets/avatar_visual_layer.dart';

class CompanionGuideOverlay extends StatefulWidget {
  final RecoveryPetService petService;
  final CompanionGuideService guideService;
  final VoidCallback? onClose;

  const CompanionGuideOverlay({
    super.key,
    required this.petService,
    required this.guideService,
    this.onClose,
  });

  @override
  State<CompanionGuideOverlay> createState() => _CompanionGuideOverlayState();
}

class _CompanionGuideOverlayState extends State<CompanionGuideOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _expandController;
  late final AnimationController _auraController;
  late final AnimationController _bobController;

  StreamSubscription? _eligibleSub;
  RecoveryPet? _pet;
  CompanionTutorial? _currentTutorial;
  int _currentStepIndex = 0;
  bool _isExpanded = false;
  bool _isDragging = false;
  Offset _overlayPosition = const Offset(16, 100);
  final GlobalKey _avatarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _eligibleSub = widget.guideService.eligibleTutorials.listen((tutorials) {
      if (mounted) {
        setState(() {
          _currentTutorial = tutorials.firstOrNull;
          _currentStepIndex = 0;
        });
      }
    });

    _loadPrefs();
    _loadPetAndTutorial();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isExpanded = !(prefs.getBool('companion_guide_collapsed') ?? false);
      final posX = prefs.getDouble('companion_guide_pos_x') ?? 16.0;
      final posY = prefs.getDouble('companion_guide_pos_y') ?? 100.0;
      _overlayPosition = Offset(posX, posY);
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('companion_guide_collapsed', !_isExpanded);
    await prefs.setDouble('companion_guide_pos_x', _overlayPosition.dx);
    await prefs.setDouble('companion_guide_pos_y', _overlayPosition.dy);
  }

  Future<void> _loadPetAndTutorial() async {
    final pet = await RecoveryPetService.ensureHatched();
    final pathways = await _getUserPathways();
    final tutorial = await widget.guideService.getNextEligibleTutorial(pathways.toSet());
    if (mounted) {
      setState(() {
        _pet = pet;
        _currentTutorial = tutorial;
      });
    }
  }

  Future<List<String>> _getUserPathways() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('active_user_profile');
    if (raw == null) return [];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final paths = map['activePaths'] as List?;
      return paths?.map((e) => e.toString()).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    _eligibleSub?.cancel();
    _expandController.dispose();
    _auraController.dispose();
    _bobController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentTutorial == null) return;
    if (_currentStepIndex < _currentTutorial!.steps.length - 1) {
      setState(() => _currentStepIndex++);
    } else {
      _completeTutorial();
    }
  }

  Future<void> _completeTutorial() async {
    if (_currentTutorial == null) return;
    await widget.guideService.markCompleted(_currentTutorial!.id);
  }

  Future<void> _dismissTutorial() async {
    if (_currentTutorial == null) return;
    await widget.guideService.dismissTutorial(_currentTutorial!.id);
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
    _savePrefs();
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _overlayPosition += details.delta;
      final size = MediaQuery.of(context).size;
      _overlayPosition = Offset(
        _overlayPosition.dx.clamp(0, size.width - 100),
        _overlayPosition.dy.clamp(0, size.height - 200),
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    _savePrefs();
  }

  @override
  Widget build(BuildContext context) {
    if (_pet == null || _currentTutorial == null) {
      return const SizedBox.shrink();
    }

    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Stack(
      children: [
        // Draggable avatar bubble (always visible when not expanded)
        Positioned(
          left: _overlayPosition.dx,
          top: _overlayPosition.dy,
          child: GestureDetector(
            onPanStart: _handleDragStart,
            onPanUpdate: _handleDragUpdate,
            onPanEnd: _handleDragEnd,
            onTap: _toggleExpanded,
            child: AnimatedBuilder(
              animation: Listenable.merge([_bobController, _auraController]),
              builder: (context, child) {
                final bobOffset = reducedMotion
                    ? 0.0
                    : sin(_bobController.value * 2 * pi) * 4.0;
                final auraScale = reducedMotion
                    ? 1.0
                    : 1.0 + 0.05 * sin(_auraController.value * 2 * pi);
                return Transform.translate(
                  offset: Offset(0, bobOffset),
                  child: Transform.scale(
                    scale: auraScale,
                    child: _buildAvatarBubble(reducedMotion),
                  ),
                );
              },
            ),
          ),
        ),
        // Expanded tutorial panel
        if (_isExpanded)
          Positioned.fill(
            child: _buildTutorialPanel(reducedMotion),
          ),
      ],
    );
  }

  Widget _buildAvatarBubble(bool reducedMotion) {
    return Container(
      key: _avatarKey,
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
]
                ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Lottie aura (reuses avatar aura system)
          if (!reducedMotion)
            Lottie.asset(
              'assets/lottie/aura_warm.json',
              width: 96,
              height: 96,
              repeat: true,
              animate: true,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          // Pet avatar
          AvatarVisualLayer(
            pet: _pet!,
            size: 72,
            showAura: false,
            compact: true,
          ),
          // Notification dot
          if (_currentStepIndex < (_currentTutorial?.steps.length ?? 1) - 1)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
              ),
),
                  ],
                ),
    );
  }

  Widget _buildTutorialPanel(bool reducedMotion) {
    final tutorial = _currentTutorial!;
    final step = tutorial.steps[_currentStepIndex];
    final isLastStep = _currentStepIndex == tutorial.steps.length - 1;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.3),
      body: GestureDetector(
        onTap: () => setState(() => _isExpanded = false),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _expandController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 100 * (1 - _expandController.value)),
                child: Opacity(
                  opacity: _expandController.value,
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tutorial.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Step ${_currentStepIndex + 1} of ${tutorial.steps.length}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        onPressed: () => setState(() => _isExpanded = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Avatar in panel (smaller)
                  Center(
                    child: AvatarVisualLayer(
                      pet: _pet!,
                      size: 80,
                      showAura: !reducedMotion,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Step text
                  Text(
                    step.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Progress indicator
                  Row(
                    children: List.generate(tutorial.steps.length, (index) {
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: index < tutorial.steps.length - 1 ? 6 : 0),
                          decoration: BoxDecoration(
                            color: index <= _currentStepIndex
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  // Actions
                  Row(
                    children: _buildActionButtons(isLastStep),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(bool isLastStep) {
    final buttons = <Widget>[];
    if (!isLastStep) {
      buttons.add(
        Expanded(
          child: OutlinedButton(
            onPressed: _dismissTutorial,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF94A3B8),
              side: const BorderSide(color: Color(0xFF334155)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Not now'),
          ),
        ),
      );
    } else {
      buttons.add(
        Expanded(
          child: OutlinedButton(
            onPressed: _dismissTutorial,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF94A3B8),
              side: const BorderSide(color: Color(0xFF334155)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Dismiss'),
          ),
        ),
      );
    }
    buttons.add(const SizedBox(width: 12));
    buttons.add(
      Expanded(
        child: ElevatedButton(
          onPressed: isLastStep ? _completeTutorial : _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF38BDF8),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            isLastStep ? 'Complete' : 'Next',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
    return buttons;
  }
}

extension on List<CompanionTutorial> {
  CompanionTutorial? get firstOrNull => isEmpty ? null : first;
}