// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/widgets/themed_background.dart

import 'package:flutter/material.dart';

import '../services/hardware_tier_service.dart';

/// Canonical reduce-motion predicate for this app (Phase 12).
///
/// Every auto-playing animation must consult this. Previously only
/// ThemedBackground did, so the 6 AnimationControllers and the Lottie aura on
/// a craving surface (pet_trials screen shake, grounding breath, constellation
/// twinkle, splash zoom) all played regardless of the system setting.
bool appReduceMotion(BuildContext context) {
  return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

class ThemedBackground extends StatefulWidget {
  final Widget child;
  final String assetPath;
  final double scrimOpacity;
  final bool enableKenBurns;
  final bool safeArea;

  const ThemedBackground({
    super.key,
    required this.child,
    this.assetPath = 'assets/images/screen_background.png',
    this.scrimOpacity = 0.72,
    this.enableKenBurns = true,
    this.safeArea = true,
  });

  @override
  State<ThemedBackground> createState() => _ThemedBackgroundState();
}

class _ThemedBackgroundState extends State<ThemedBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = appReduceMotion(context) || HardwareTierService.isLowEnd;
    final ctrl = _controller;
    if (ctrl == null) return;
    if (widget.enableKenBurns && !reduce) {
      if (!ctrl.isAnimating) {
        ctrl.repeat(reverse: true);
      }
    } else {
      ctrl.stop();
      ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = appReduceMotion(context) || HardwareTierService.isLowEnd;
    final animate = widget.enableKenBurns && !reduce && _controller != null;

    final scheme = Theme.of(context).colorScheme;
    Widget background = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface,
            scheme.surfaceContainer,
            scheme.surface,
          ],
        ),
      ),
    );

    if (animate) {
      background = AnimatedBuilder(
        animation: _controller!,
        builder: (context, child) {
          final t = _controller!.value;
          final scale = 1.0 + (0.06 * t);
          final dx = -0.02 + (0.04 * t);
          final dy = -0.015 + (0.03 * t);
          return Transform.scale(
            scale: scale,
            alignment: Alignment(dx, dy),
            child: child,
          );
        },
        child: background,
      );
    }

    final content = widget.safeArea ? SafeArea(child: widget.child) : widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        Container(color: scheme.surface.withValues(alpha: widget.scrimOpacity)),
        content,
      ],
    );
  }
}