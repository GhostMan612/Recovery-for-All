// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/screens/constellation_screen.dart
//
// Recovery Constellation — the user's path rendered as a living star map.
// Growth pattern: category-based phyllotaxis branches — each category forms
/// its own spiral arm, preventing clustering and creating natural milestone
/// branches. Stars of the same category form connected spiral arms.
library;


import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constellation_geometry.dart';
import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/community_feed_service.dart';
import '../services/recovery_pet_service.dart';
import '../widgets/app_primitives.dart';
import '../widgets/themed_background.dart' show appReduceMotion;
import 'constellation_canvas_3d.dart';

/// Recovery Constellation — the user's path rendered as a living star map.
///
/// Growth pattern: category-based phyllotaxis (sunflower spiral) — each 
/// category forms its own spiral arm, preventing clustering and creating
/// natural milestone branches. Stars of the same category form connected
/// spiral arms.
///
/// Features: category-colored stars, pinch/slide zoom (1x-10x), animated 
/// starfield background, tap-for-details, manual star addition, 3D view toggle,
/// star focus with detail panel, category branch lines.
class ConstellationScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const ConstellationScreen({super.key, required this.database});

  @override
  State<ConstellationScreen> createState() => _ConstellationScreenState();
}

// ---- category colors ----

const Map<String, Color> _kCategoryColors = {
  'milestone': AppColors.starMilestone, // gold
  'step_work': AppColors.starStepWork, // green
  'community': AppColors.starCommunity, // blue
  'service': AppColors.starService,   // orange
  'mindfulness': AppColors.starMindfulness, // purple
  'spiritual': AppColors.starSpiritual, // green
};

Color _colorForCategory(String category, Color fallback) =>
    _kCategoryColors[category] ?? fallback;

// ---- category-based phyllotaxis positioning ----

/// Computes star positions using category-based phyllotaxis branches — 
/// each category forms its own spiral arm, preventing clustering and 
/// creating natural milestone branches. Stars of the same category 
/// (e.g., 'milestone', 'step_work') form connected spiral arms.
List<ConstellationNode3D> _phyllotaxisNodes(List<ConstellationPoint> points) {
  if (points.isEmpty) return [];
  
  final sorted = [...points]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  
  // Group points by category for branch formation
  final categoryGroups = <String, List<ConstellationPoint>>{};
  for (final p in sorted) {
    categoryGroups.putIfAbsent(p.category, () => []).add(p);
  }
  
  // Assign each category a base angle for its spiral arm
  final categoryAngles = <String, double>{};
  final categoryOrder = ['milestone', 'step_work', 'community', 'service', 'mindfulness', 'spiritual'];
  for (int i = 0; i < categoryOrder.length; i++) {
    categoryAngles[categoryOrder[i]] = i * (2 * math.pi / categoryOrder.length);
  }
  
  const goldenAngle = 2.399963; // radians (~137.5°)
  const maxRadius = 0.42;
  
  final nodes = <ConstellationNode3D>[];
  
  // Process each category as its own spiral arm (branch)
  for (final category in categoryOrder) {
    final catPoints = categoryGroups[category] ?? [];
    if (catPoints.isEmpty) continue;
    
    final baseAngle = categoryAngles[category] ?? 0.0;
    
    for (int i = 0; i < catPoints.length; i++) {
      final p = catPoints[i];
      // Angle = base category angle + golden angle increment within category
      final angle = baseAngle + i * goldenAngle;
      // Radius grows with sqrt for even distribution within the branch
      final radius = maxRadius * math.sqrt(i + 1) / math.sqrt(catPoints.length + 1);
      
      nodes.add(ConstellationNode3D(
        id: p.id,
        title: p.title,
        category: p.category,
        timestamp: DateTime.fromMillisecondsSinceEpoch(p.timestamp),
        x: radius * math.cos(angle),
        y: radius * math.sin(angle) * 0.7,
        z: ((p.title.hashCode % 100) / 100 - 0.5) * 0.15,
      ));
    }
  }
  
  return nodes;
}

class _ConstellationScreenState extends State<ConstellationScreen> {
  static const String _skyNameKey = 'constellation_sky_name_v1';

  List<ConstellationNode3D>? _nodes;
  String? _skyName;
  double _zoom = 1.0;
  late final Stream<List<ConstellationPoint>> _pointsStream;

  @override
  void initState() {
    super.initState();
    _pointsStream = widget.database.watchConstellationPoints();
    _loadSkyName();
  }

  Future<void> _loadSkyName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _skyName = prefs.getString(_skyNameKey);
    });
  }

  /// Structural equality on the fields the canvas and the 3D widget read.
  /// List identity is useless here because `_phyllotaxisNodes` allocates a new
  /// list on every call.
  static bool _sameNodes(List<ConstellationNode3D>? a, List<ConstellationNode3D> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i], y = b[i];
      if (x.id != y.id || x.title != y.title || x.category != y.category) return false;
      if (x.timestamp != y.timestamp) return false;
    }
    return true;
  }

  // ------------------------------------------------------------------
  // Rename sky
  // ------------------------------------------------------------------

  Future<void> _renameSky() async {
    final controller = TextEditingController(text: _skyName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Text('Name your sky', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'e.g. The Return, North Star, Second Chances',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () => Navigator.pop(dialogContext,
                controller.text.trim().isEmpty ? null : controller.text.trim()),
            child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    if (name == null) return;
    if (name.isEmpty) {
      await prefs.remove(_skyNameKey);
    } else {
      await prefs.setString(_skyNameKey, name);
    }
    if (mounted) setState(() => _skyName = name.isEmpty ? null : name);
  }

  // ------------------------------------------------------------------
  // Shape-share
  // ------------------------------------------------------------------

  String _renderShapeGrid(List<ConstellationNode3D> nodes) {
    const cols = 9;
    const rows = 5;
    final grid = List.generate(rows, (_) => List.filled(cols, '·'));
    for (final n in nodes) {
      final cx = (((n.x / 0.8) + 0.5).clamp(0.0, 0.999) * cols).floor();
      final cy = (((n.y / 0.6) + 0.5).clamp(0.0, 0.999) * rows).floor();
      if (cy >= 0 && cy < rows && cx >= 0 && cx < cols) grid[cy][cx] = '✦';
    }
    return [for (final row in grid) row.join()].join('\n');
  }

  /// `_phyllotaxisNodes` groups by category, it does not sort by time, so
  /// `nodes.first`/`.last` were the oldest milestone and the newest spiritual
  /// star — not the extremes. That under-reported the span and could go
  /// negative when the newest milestone predated the oldest step_work. The
  /// result is shared to the public Recovery Circle feed, so a wrong number
  /// leaves the device. Sort, then take the extremes.
  int _spanNights(List<ConstellationNode3D> nodes) {
    if (nodes.length < 2) return 0;
    final ts = nodes.map((n) => n.timestamp.millisecondsSinceEpoch).toList()..sort();
    return ((ts.last - ts.first) / 86400000).floor().clamp(0, 1 << 30);
  }

  Future<void> _shareShape() async {
    final nodes = _nodes;
    if (nodes == null || nodes.isEmpty) return;
    final shape = _renderShapeGrid(nodes);
    final spanDays = _spanNights(nodes);
    final name = _skyName ?? 'My constellation';

    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(shape,
                    style: const TextStyle(
                        fontSize: 11, height: 1.3, letterSpacing: 2)),
              ),
              const SizedBox(height: 6),
              Text('Shapes travel. Day counts stay private.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.copy_all_outlined, color: Theme.of(context).colorScheme.primary),
                title: Text('Copy shape', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                onTap: () => Navigator.pop(sheetContext, 'copy'),
              ),
              ListTile(
                leading: Icon(Icons.forum_outlined, color: Theme.of(context).colorScheme.primary),
                title: Text('Post to Recovery Circle', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                subtitle: Text('Shape only — never your numbers', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                onTap: () => Navigator.pop(sheetContext, 'post'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: '''
$name

$shape

${nodes.length} stars over $spanDays nights
— Recovery Companion'''));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          content: const Text('Star shape copied — your day counts stay private'),
        ),
      );
    } else if (choice == 'post') {
      final profile = await widget.database.getProfile('active_user_profile');
      await CommunityFeedService(widget.database).compose(
        authorAlias: profile?.anonymousUsername ?? 'Anonymous',
        body: '$name — ${nodes.length} stars over $spanDays nights',
        kind: 'shape',
        shapeJson: shape,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Theme.of(context).colorScheme.surfaceContainer, content: Text('Constellation shared with the circle.')),
      );
    }
  }

  // ------------------------------------------------------------------
  // Manual star
  // ------------------------------------------------------------------

  Future<void> _addManualStar() async {
    final titleController = TextEditingController();
    var category = 'milestone';
    const categories = ['milestone', 'step_work', 'community', 'service', 'mindfulness', 'spiritual'];
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          title: Text('Add a star', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                maxLength: 40,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'e.g. 90 meetings, Made amends, Sponsored someone',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final cat in categories)
                    ChoiceChip(
                      label: Text(cat,
                          style: TextStyle(
                              fontSize: 11,
                              color: category == cat ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant)),
                      selected: category == cat,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                      onSelected: (_) => setDialog(() => category = cat),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary), onPressed: () => Navigator.pop(dialogContext, titleController.text.trim().isNotEmpty), child: Text('Add', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final title = titleController.text.trim();
    await widget.database.addConstellationPoint(ConstellationPoint(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      category: category,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      positionX: 0.5,
      positionY: 0.5,
    ));
    await RecoveryPetService.logStar(title);
    // stream handles load
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Theme.of(context).colorScheme.surfaceContainer, content: Text('"$title" added to ${_skyName ?? "your sky"} · +${RecoveryPetService.sparksStar} Sparks')));
    }
  }

  // ------------------------------------------------------------------
  // Star details (tap)
  // ------------------------------------------------------------------

  void _showStarDetails(int index) {
    final nodes = _nodes;
    if (nodes == null || index >= nodes.length) return;
    final node = nodes[index];
    final color = _colorForCategory(node.category, Theme.of(context).colorScheme.primary);
    final date = node.timestamp;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
              const SizedBox(width: 10),
              Expanded(child: Text(node.title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 6),
            Text('${node.category} · ${date.day}/${date.month}/${date.year}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 12),
            Text('This star is part of ${_skyName ?? "your constellation"} — a moment you chose to mark. It stays here forever.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, height: 1.45)),
          ]),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: GestureDetector(
          onTap: _renameSky,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(_skyName ?? 'Your Constellation', style: TextStyle(color: Theme.of(context).colorScheme.onSurface), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            Icon(Icons.edit_outlined, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
          ]),
        ),
        actions: [
          IconButton(tooltip: 'Share shape', icon: Icon(Icons.ios_share, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)), onPressed: (_nodes == null || _nodes!.isEmpty) ? null : _shareShape),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_star',
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onSurface),
        label: Text('Add Star', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        onPressed: _addManualStar,
      ),
      body: StreamBuilder<List<ConstellationPoint>>(
        stream: _pointsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _nodes == null) {
            return const AppLoadingState();
          }
// Derive synchronously rather than scheduling a post-frame setState: the
          // previous version called setState from a callback scheduled on
          // EVERY build, and _phyllotaxisNodes returns a fresh list each call,
          // so the comparison never matched and the screen rebuilt at 60 fps
          // forever. Sync derivation means this only rebuilds when the points
          // themselves changed.
          if (snapshot.hasData) {
            final derived = _phyllotaxisNodes(snapshot.data!);
            if (!_sameNodes(_nodes, derived)) {
              _nodes = derived;
            }
          }
          final nodes = _nodes ?? [];
          if (nodes.isEmpty) {
            return _EmptySky(onSeed: () async {
              await RecoveryPetService.ensureHatched();
              await widget.database.addConstellationPoint(ConstellationPoint(
                id: 'seed_first_path_${DateTime.now().millisecondsSinceEpoch}',
                title: 'Began My Recovery Path',
                category: 'milestone',
                timestamp: DateTime.now().millisecondsSinceEpoch,
                positionX: 0.5,
                positionY: 0.5,
              ));
              await RecoveryPetService.logStar('Began My Recovery Path');
              _loadSkyName();
            });
          }
          return Column(
            children: [
              // P3: Category legend
              const _CategoryLegend(),
              Expanded(
                child: _ConstellationCanvas(
                  nodes: nodes,
                  skyName: _skyName,
                  zoom: _zoom,
                  onZoomChanged: (v) => setState(() => _zoom = v),
                  onStarTap: _showStarDetails,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---- canvas widget with zoom + tap + starfield background + 3D view + branch lines + star focus ----

class _ConstellationCanvas extends StatefulWidget {
  final List<ConstellationNode3D> nodes;
  final String? skyName;
  final double zoom;
  final void Function(double) onZoomChanged;
  final void Function(int) onStarTap;

  const _ConstellationCanvas({
    required this.nodes,
    required this.skyName,
    required this.zoom,
    required this.onZoomChanged,
    required this.onStarTap,
  });

  @override
  State<_ConstellationCanvas> createState() => _ConstellationCanvasState();
}

class _ConstellationCanvasState extends State<_ConstellationCanvas> with TickerProviderStateMixin {
  late AnimationController _twinkleController;
  late AnimationController _focusController;

  /// Single source of truth for zoom. This used to be an AnimationController
  /// used purely as a value holder, which broke in two ways: (1) the slider
  /// lived outside the AnimatedBuilder that repainted the canvas, so dragging
  /// the thumb moved the stars in one coordinate space and the thumb in
  /// another — it read as the sky sliding sideways rather than zooming; and
  /// (2) nothing ever called onZoomChanged, so the parent's _zoom stayed at
  /// 1.0 forever. A plain field in state makes every consumer agree.
  double _zoom = 1.0;
  double _pinchBaseZoom = 1.0;

  /// Pan offset in canvas logical pixels, applied after the zoom scaling.
  ///
  /// Zoom alone cannot keep stars reachable: positions scale about the canvas
  /// centre, so a node even slightly off-centre leaves the screen by ~2.5x.
  /// Pan is what makes the sky draggable, and [clampSkyPan] is what guarantees
  /// that no combination of zoom and pan can strand a star off-screen.
  Offset _pan = Offset.zero;
  Offset _panAtGestureStart = Offset.zero;
  Offset _focalAtGestureStart = Offset.zero;

  int? _focusedStarIndex;
  bool _is3DView = false;

  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  /// Nodes mapped to the normalised (-0.45..0.45) space the geometry module
  /// expects, so the painter, the hit-test and the tests all speak the same
  /// language.
  List<Offset> _normalisedNodes() =>
      [for (final n in widget.nodes) Offset(n.x, n.y)];

  @override
  void initState() {
    super.initState();
    _twinkleController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _zoom = widget.zoom;
    _focusController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 80 stars twinkling on a 4s infinite loop. Static stars are still a
    // complete constellation, so reduce-motion just freezes them.
    if (appReduceMotion(context)) {
      _twinkleController.stop();
      _twinkleController.value = 0;
    } else if (!_twinkleController.isAnimating) {
      _twinkleController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ConstellationCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoom != widget.zoom && (widget.zoom - _zoom).abs() > 0.001) {
      _zoom = widget.zoom.clamp(_minZoom, _maxZoom);
    }
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  /// Single entry point for zoom changes that are NOT gestures — i.e. the
  /// slider. Repaints the canvas AND the slider from the same value, so they can
  /// never drift apart again.
  ///
  /// The pinch path deliberately does not come through here: it has a focal
  /// point and sets `_zoom` and `_pan` together in one `setState`, because a
  /// focal-anchored zoom is not expressible as "scale the old zoom".
  void _setZoom(double value, {bool notifyParent = false}) {
    final next = value.clamp(_minZoom, _maxZoom);
    if ((next - _zoom).abs() <= 0.001) return;
    setState(() {
      final previous = _zoom;
      _zoom = next;
      if (_zoom <= _minZoom) {
        // Minimum zoom is the "go home" state, so the pan resets there.
        _pan = Offset.zero;
      } else {
        // Scale the pan by the same factor, which keeps the view scaling about
        // the canvas centre: a point at `C + d` moves to `C + d*r`. Without
        // this, dragging the slider would also slide the sky sideways.
        _pan = _pan * (next / previous);
      }
    });
    // Only tell the parent on gesture end. Pushing on every drag frame would
    // setState the whole screen ~60x/sec for no benefit.
    if (notifyParent) widget.onZoomChanged(next);
  }

  void _focusOnStar(int index) {
    setState(() {
      _focusedStarIndex = index;
      _focusController.forward(from: 0);
    });
    widget.onStarTap(index);
  }

  void _clearFocus() {
    setState(() {
      _focusedStarIndex = null;
      _focusController.reverse();
    });
  }

  void _toggle3DView() {
    setState(() {
      _is3DView = !_is3DView;
      _clearFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (d) {
        _pinchBaseZoom = _zoom;
        _panAtGestureStart = _pan;
        _focalAtGestureStart = d.localFocalPoint;
      },
      onScaleUpdate: (d) {
        final size = context.size;
        if (size == null) return;
        // One handler for both gestures, because a one-finger drag arrives
        // here too with scale == 1.0. Zooming and panning in separate
        // callbacks is what made them fight each other.
        final next = (_pinchBaseZoom * d.scale).clamp(_minZoom, _maxZoom);
        final pan = gesturePan(
          basePan: _panAtGestureStart,
          baseZoom: _pinchBaseZoom,
          newZoom: next,
          focalDelta: d.localFocalPoint - _focalAtGestureStart,
          startFocal: _focalAtGestureStart,
          size: size,
        );
        setState(() {
          _zoom = next;
          _pan = pan;
        });
      },
      onScaleEnd: (_) {
        // Snap back inside the reachable range so a fling cannot leave the sky
        // stranded somewhere the user cannot drag out of.
        final size = context.size;
        if (size != null) {
          setState(() {
            _pan = clampSkyPan(
              normalised: _normalisedNodes(),
              size: size,
              zoom: _zoom,
              desired: _pan,
            );
          });
        }
        widget.onZoomChanged(_zoom);
      },
      onTapUp: (details) {
        final size = context.size;
        if (size == null) return;
        final pan = clampSkyPan(
          normalised: _normalisedNodes(),
          size: size,
          zoom: _zoom,
          desired: _pan,
        );
        final positions = skyPositions(
          normalised: _normalisedNodes(),
          size: size,
          zoom: _zoom,
          pan: pan,
        );
        double bestDist = double.infinity;
        int? bestIndex;
        for (var i = 0; i < positions.length; i++) {
          final dist = (details.localPosition - positions[i]).distance;
          // The hit radius tracks the drawn star, so a zoomed-in star is still
          // easy to tap and a zoomed-out one is not fiddly to miss.
          final radius = 30.0 * skyStarScale(_zoom);
          if (dist < radius && dist < bestDist) {
            bestDist = dist;
            bestIndex = i;
          }
        }
        if (bestIndex != null) {
          _focusOnStar(bestIndex);
        } else {
          _clearFocus();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Animated starfield background
          AnimatedBuilder(animation: _twinkleController, builder: (context, _) => CustomPaint(painter: _StarFieldPainter(time: _twinkleController.value, starColor: Theme.of(context).colorScheme.onSurface))),
          // Main constellation with zoom + branch lines + focus highlight.
          // Reads _zoom directly now that zoom lives in state, so this
          // repaints on every _setZoom — same as the slider below.
          AnimatedBuilder(
            animation: _focusController,
            builder: (context, _) => CustomPaint(painter: _ConstellationCanvasPainter(
              nodes: widget.nodes,
              zoom: _zoom,
              pan: _pan,
              focusedIndex: _focusedStarIndex,
              focusProgress: _focusController.value,
              fallbackColor: Theme.of(context).colorScheme.primary,
              branchColor: Theme.of(context).colorScheme.primary,
            )),
          ),
          // 3D view toggle
          Positioned(left: 16, top: 12, child: Material(
            color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            child: Semantics(
              button: true,
              label: _is3DView ? 'Switch to 2D view' : 'Switch to 3D view',
              // Without excludeSemantics the label above is concatenated with
              // the visible '3D View'/'2D View' Text, so TalkBack announced
              // "Switch to 3D view, 3D View". Safe here — the only interactive
              // descendant is the InkWell, whose onTap is repeated below.
              excludeSemantics: true,
              onTap: _toggle3DView,
              child: InkWell(onTap: _toggle3DView, borderRadius: BorderRadius.circular(12), child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ExcludeSemantics(child: Icon(_is3DView ? Icons.view_in_ar : Icons.crop_rotate, color: _is3DView ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 20)),
                  const SizedBox(width: 6),
                  Text(_is3DView ? '3D View' : '2D View', style: TextStyle(color: _is3DView ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              )),
            ),
          )),
          // Focus info badge
          if (_focusedStarIndex != null)
            Positioned(top: 60, left: 16, right: 16, child: AnimatedBuilder(animation: _focusController, builder: (context, _) => Opacity(opacity: _focusController.value, child: Transform.translate(
              offset: Offset(0, 20 * (1 - _focusController.value)),
              child: Material(color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(16), child: Padding(padding: EdgeInsets.all(16), child: _buildFocusInfo(widget.nodes[_focusedStarIndex!])),
            ))))),
          // 3D view
          if (_is3DView) Positioned.fill(child: RecoveryConstellation3DWidget(nodes: widget.nodes)),
          // Zoom slider (bottom).
          //
          // `bottom: 12` put this row underneath the extended "Add Star" FAB:
          // the FAB spans roughly 16..72dp from the bottom on the right half of
          // the screen, so the right ~30% of the slider track was covered and
          // could not be tapped or dragged at all. Discovered on hardware, not
          // by reading — a tap intended for the slider opened the Add Star
          // dialog instead. Sitting the row above the FAB clears it entirely,
          // and it clears it for any FAB width rather than for today's label.
          Positioned(left: 16, right: 16, bottom: 84, child: Row(children: [
            Icon(Icons.zoom_out, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
            Expanded(child: Slider(
              value: _zoom,
              min: _minZoom,
              max: _maxZoom,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) => _setZoom(v),
              onChangeEnd: (v) => widget.onZoomChanged(v),
            )),
            Icon(Icons.zoom_in, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
          ])),
          // Sky name label
          if (widget.skyName != null) Positioned(left: 12, top: 8, child: Text(widget.skyName!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildFocusInfo(ConstellationNode3D node) {
    final color = _colorForCategory(node.category, Theme.of(context).colorScheme.primary);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 10),
        // maxLines is required for ellipsis to do anything; without it the title wraps
        // to as many lines as it needs and the badge grows down over the 3D
        // toggle and the zoom slider.
        Expanded(child: Text(node.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold))),
        IconButton(icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 20), onPressed: _clearFocus),
      ]),
      const SizedBox(height: 8),
      Text('${node.category} · ${node.timestamp.day}/${node.timestamp.month}/${node.timestamp.year}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: ElevatedButton.icon(onPressed: () { _clearFocus(); widget.onStarTap(widget.nodes.indexOf(node)); }, icon: const Icon(Icons.info_outline, size: 18), label: const Text('Details'), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () { _clearFocus(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quick actions coming soon'))); }, icon: const Icon(Icons.star_border, size: 18), label: const Text('Quick Action'), style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary))),
      ]),
    ]);
  }

  Color _colorForCategory(String category, Color fallback) => _kCategoryColors[category] ?? fallback;
}

/// Custom painter for the 2D constellation canvas with branch lines and focus highlight
class _ConstellationCanvasPainter extends CustomPainter {
  final List<ConstellationNode3D> nodes;
  final double zoom;

  /// Requested pan. The *effective* pan is derived from it in [paint] via
  /// [clampSkyPan], so a caller can never strand the sky off-screen.
  final Offset pan;
  final int? focusedIndex;
  final double focusProgress;
  final Color fallbackColor;
  final Color branchColor;

  _ConstellationCanvasPainter({
    required this.nodes,
    required this.zoom,
    required this.pan,
    required this.fallbackColor,
    required this.branchColor,
    this.focusedIndex,
    this.focusProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final normalised = [for (final n in nodes) Offset(n.x, n.y)];
    final effectivePan = clampSkyPan(
      normalised: normalised,
      size: size,
      zoom: zoom,
      desired: pan,
    );
    final points = skyPositions(
      normalised: normalised,
      size: size,
      zoom: zoom,
      pan: effectivePan,
    );
    // Star radius grows with zoom so zooming reads as getting closer, not just
    // as the sky sliding apart.
    final starScale = skyStarScale(zoom);

    // Group nodes by category for branch lines
    final categoryGroups = <String, List<(ConstellationNode3D, int)>>{};
    for (int i = 0; i < nodes.length; i++) {
      final cat = nodes[i].category;
      categoryGroups.putIfAbsent(cat, () => []).add((nodes[i], i));
    }

    // Draw branch lines first (behind stars)
    final branchPaint = Paint()..color = branchColor.withValues(alpha: 0.15)..strokeWidth = 1.5..style = PaintingStyle.stroke;

    for (final entry in categoryGroups.entries) {
      final catNodes = entry.value;
      if (catNodes.length < 2) continue;
      catNodes.sort((a, b) => a.$1.timestamp.compareTo(b.$1.timestamp));
      for (int i = 1; i < catNodes.length; i++) {
        final (prevNode, prevIndex) = catNodes[i - 1];
        final (currNode, currIndex) = catNodes[i];
        final p1 = points[prevIndex];
        final p2 = points[currIndex];
        final path = Path()..moveTo(p1.dx, p1.dy)..quadraticBezierTo((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2 - 30, p2.dx, p2.dy);
        canvas.drawPath(path, branchPaint);
      }
    }

    // Draw stars
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final at = points[i];
      final color = _colorForCategory(node.category);
      final isFocused = focusedIndex == i;
      final focusScale = isFocused ? 1.0 + 0.5 * focusProgress : 1.0;
      final focusAlpha = isFocused ? 1.0 : (focusProgress > 0 ? 0.3 : 1.0);

      final glowPaint = Paint()..color = color.withValues(alpha: 0.4 * focusAlpha * focusScale)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)..style = PaintingStyle.fill;
      final starPaint = Paint()..color = color.withValues(alpha: focusAlpha)..style = PaintingStyle.fill;

      // starScale is what makes zoom legible: without it a star stayed 6px at
      // every zoom level and zooming only moved it around.
      final starSize = 6.0 * focusScale * starScale;
      final glowSize = 14.0 * focusScale * starScale;

      canvas.drawCircle(at, glowSize, glowPaint);
      canvas.drawCircle(at, starSize, starPaint);

      if (isFocused) {
        final ringPaint = Paint()..color = color.withValues(alpha: 0.5 * focusProgress)..style = PaintingStyle.stroke..strokeWidth = 3.0;
        canvas.drawCircle(at, starSize + 8 + 10 * focusProgress, ringPaint);
      }
    }
  }

  Color _colorForCategory(String category) => _kCategoryColors[category] ?? fallbackColor;

  @override
  bool shouldRepaint(covariant _ConstellationCanvasPainter oldDelegate) {
    // pan is load-bearing here: without it in this list, panning repaints
    // nothing and the sky appears frozen under the user's finger.
    return oldDelegate.zoom != zoom || oldDelegate.pan != pan || oldDelegate.focusedIndex != focusedIndex || oldDelegate.focusProgress != focusProgress || oldDelegate.nodes != nodes || oldDelegate.fallbackColor != fallbackColor || oldDelegate.branchColor != branchColor;
  }
}

// ---- twinkling starfield background ----

class _StarFieldPainter extends CustomPainter {
  final double time;
  final Color starColor;
  _StarFieldPainter({required this.time, required this.starColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42); // deterministic
    final paint = Paint();
    for (var i = 0; i < 80; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final phase = (time * 2 * math.pi + i * 0.7) % (2 * math.pi);
      final alpha = 0.08 + 0.18 * (0.5 + 0.5 * math.sin(phase));
      paint.color = starColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 0.6 + rnd.nextDouble() * 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => oldDelegate.time != time || oldDelegate.starColor != starColor;
}

class _EmptySky extends StatelessWidget {
  final Future<void> Function() onSeed;
  const _EmptySky({required this.onSeed});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.auto_awesome,
      title: 'Your sky is waiting.',
      message: 'Light your first star to mark the\nbeginning of your path.',
      action: FilledButton(
        onPressed: onSeed,
        child: const Text('Begin My Path'),
      ),
    );
  }
}


// ---- P3: Category legend ----

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend();

  static const _labels = {
    'milestone': 'Milestones',
    'step_work': 'Step Work',
    'community': 'Community',
    'service': 'Goals',
    'mindfulness': 'Mindfulness',
    'spiritual': 'Spiritual',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in _kCategoryColors.entries)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: entry.value,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _labels[entry.key] ?? entry.key,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
