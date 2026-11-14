// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/widgets/game_sprite_stage.dart
//
// Reusable 2D sprite atlas renderer for Recovery for All.
// Supports power-of-two 4x4 sprite sheets, cell selection, animation playback,
// hit flash tinting, reduced-motion pinning (Frame 0), and graceful fallback.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;

import '../core/motion/app_motion.dart';

/// Predefined animation parameters for Ember Kit companion sprite atlas.
class EmberKitSpriteConfig {
  static const String asset = 'assets/game/sprites/ember_kit_v1.png';
  static const int columns = 4;
  static const int rows = 4;
  static const double frameSize = 256.0;
  static const int totalFrames = 16;

  // Idle: 8 frames, 125ms per frame (1000ms loop)
  static const int idleStart = 0;
  static const int idleCount = 8;
  static const Duration idleDuration = Duration(milliseconds: 125);

  // Joy: 4 frames, 100ms per frame (400ms one-shot on reward/celebration)
  static const int joyStart = 8;
  static const int joyCount = 4;
  static const Duration joyDuration = Duration(milliseconds: 100);

  // Rest: 4 frames, 250ms per frame (1000ms gentle loop)
  static const int restStart = 12;
  static const int restCount = 4;
  static const Duration restDuration = Duration(milliseconds: 250);

  // Static pose for reduced motion
  static const int staticFrame = 0;
}

/// Predefined animation parameters for Craving Wraith Trial monster sprite atlas.
class CravingWraithSpriteConfig {
  static const String asset = 'assets/game/sprites/craving_wraith_v1.png';
  static const int columns = 4;
  static const int rows = 4;
  static const double frameSize = 256.0;
  static const int totalFrames = 16;

  // Idle: 8 frames, 150ms per frame (1200ms loop)
  static const int idleStart = 0;
  static const int idleCount = 8;
  static const Duration idleDuration = Duration(milliseconds: 150);

  // Hit: 4 frames, 80ms per frame (320ms one-shot recoil)
  static const int hitStart = 8;
  static const int hitCount = 4;
  static const Duration hitDuration = Duration(milliseconds: 80);

  // Fade: 4 frames, 150ms per frame (600ms one-shot dissolution)
  static const int fadeStart = 12;
  static const int fadeCount = 4;
  static const Duration fadeDuration = Duration(milliseconds: 150);

  // Static pose for reduced motion
  static const int staticFrame = 0;
}

/// CustomPainter that renders a single sub-cell from a 4x4 (or custom rows/cols)
/// sprite atlas with optional flash color overlay.
class SpriteAtlasPainter extends CustomPainter {
  final ui.Image image;
  final int frameIndex;
  final int columns;
  final int rows;
  final Color? flashColor;
  final double flashAmount;
  final BoxFit fit;

  SpriteAtlasPainter({
    required this.image,
    required this.frameIndex,
    this.columns = 4,
    this.rows = 4,
    this.flashColor,
    this.flashAmount = 0.0,
    this.fit = BoxFit.contain,
  });

  /// Compute source rectangle for a specific frame index in a grid atlas.
  static Rect calculateFrameRect({
    required int frameIndex,
    int columns = 4,
    int rows = 4,
    double frameSize = 256.0,
  }) {
    final int clampedIndex = frameIndex.clamp(0, (columns * rows) - 1);
    final int col = clampedIndex % columns;
    final int row = clampedIndex ~/ columns;
    return Rect.fromLTWH(
      col * frameSize,
      row * frameSize,
      frameSize,
      frameSize,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || image.width <= 0 || image.height <= 0) return;

    final double cellWidth = image.width / columns;
    final double cellHeight = image.height / rows;
    final int clampedIndex = frameIndex.clamp(0, (columns * rows) - 1);
    final int col = clampedIndex % columns;
    final int row = clampedIndex ~/ columns;

    final Rect src = Rect.fromLTWH(
      col * cellWidth,
      row * cellHeight,
      cellWidth,
      cellHeight,
    );

    final FittedSizes fittedSizes = applyBoxFit(fit, src.size, size);
    final Rect dest = Alignment.center.inscribe(
      fittedSizes.destination,
      Offset.zero & size,
    );

    final Paint paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium;

    if (flashAmount > 0.0 && flashColor != null) {
      paint.colorFilter = ColorFilter.mode(
        flashColor!.withValues(alpha: flashAmount.clamp(0.0, 1.0)),
        BlendMode.srcATop,
      );
    }

    canvas.drawImageRect(image, src, dest, paint);
  }

  @override
  bool shouldRepaint(covariant SpriteAtlasPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.frameIndex != frameIndex ||
        oldDelegate.flashAmount != flashAmount ||
        oldDelegate.flashColor != flashColor ||
        oldDelegate.columns != columns ||
        oldDelegate.rows != rows ||
        oldDelegate.fit != fit;
  }
}

/// Animated 2D sprite atlas widget.
///
/// Decodes and caches the transparent PNG atlas, ticks through active frames,
/// respects [AppMotion.reduceMotionOf], and falls back to [fallback] when
/// loading or if the asset cannot be loaded.
class GameSpriteStage extends StatefulWidget {
  final String assetPath;
  final int startFrame;
  final int frameCount;
  final Duration frameDuration;
  final bool loop;
  final int staticFrame;
  final double? width;
  final double? height;
  final Color? flashColor;
  final double flashAmount;
  final Widget? fallback;
  final VoidCallback? onComplete;

  const GameSpriteStage({
    super.key,
    required this.assetPath,
    this.startFrame = 0,
    this.frameCount = 1,
    this.frameDuration = const Duration(milliseconds: 125),
    this.loop = true,
    this.staticFrame = 0,
    this.width,
    this.height,
    this.flashColor,
    this.flashAmount = 0.0,
    this.fallback,
    this.onComplete,
  });

  static final Map<String, ui.Image> _atlasCache = {};

  /// Pre-populate cache or inject synthetic image for testing.
  static void cacheAtlasForTesting(String path, ui.Image image) {
    _atlasCache[path] = image;
  }

  /// Clear the atlas image cache.
  static void clearCache() {
    _atlasCache.clear();
  }

  @override
  State<GameSpriteStage> createState() => _GameSpriteStageState();
}

class _GameSpriteStageState extends State<GameSpriteStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ui.Image? _image;
  bool _hasError = false;

  Duration get _totalDuration => widget.frameDuration * widget.frameCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration > Duration.zero
          ? _totalDuration
          : const Duration(milliseconds: 100),
    );
    _controller.addStatusListener(_onAnimationStatus);
    _loadAtlas();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !widget.loop) {
      widget.onComplete?.call();
    }
  }

  Future<void> _loadAtlas() async {
    final path = widget.assetPath;
    if (GameSpriteStage._atlasCache.containsKey(path)) {
      if (mounted) {
        setState(() {
          _image = GameSpriteStage._atlasCache[path];
          _hasError = false;
        });
      }
      return;
    }

    try {
      final ByteData data = await rootBundle.load(path);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      GameSpriteStage._atlasCache[path] = frameInfo.image;
      if (mounted) {
        setState(() {
          _image = frameInfo.image;
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant GameSpriteStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _loadAtlas();
    }
    if (oldWidget.startFrame != widget.startFrame ||
        oldWidget.frameCount != widget.frameCount ||
        oldWidget.frameDuration != widget.frameDuration ||
        oldWidget.loop != widget.loop) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final reduce = AppMotion.reduceMotionOf(context);
    if (reduce || widget.frameCount <= 1) {
      _controller.stop();
      return;
    }

    final newDuration = _totalDuration;
    if (_controller.duration != newDuration) {
      _controller.duration = newDuration;
    }

    if (widget.loop) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null || _hasError) {
      return widget.fallback ??
          SizedBox(width: widget.width, height: widget.height);
    }

    final reduce = AppMotion.reduceMotionOf(context);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final int currentFrame;
          if (reduce || widget.frameCount <= 1) {
            currentFrame = widget.staticFrame;
          } else {
            final double progress = _controller.value.clamp(0.0, 1.0);
            final int step =
                (progress * widget.frameCount).floor() % widget.frameCount;
            currentFrame = widget.startFrame + step;
          }

          return CustomPaint(
            size: Size(widget.width ?? 160, widget.height ?? 160),
            painter: SpriteAtlasPainter(
              image: image,
              frameIndex: currentFrame,
              flashColor: widget.flashColor,
              flashAmount: widget.flashAmount,
            ),
          );
        },
      ),
    );
  }
}
