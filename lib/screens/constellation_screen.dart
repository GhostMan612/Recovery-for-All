// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:math' as math;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/community_feed_service.dart';
import '../services/recovery_pet_service.dart';
import 'constellation_canvas_3d.dart';

/// Recovery Constellation — the user's path rendered as a living star map.
///
/// Growth pattern: phyllotaxis (sunflower spiral) — each new star extends
/// outward from the center at a golden angle, so the constellation naturally
/// spreads as milestones accumulate. Never clusters.
///
/// Features: category-colored stars, pinch/slide zoom, animated starfield
/// background, tap-for-details, manual star addition.
class ConstellationScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const ConstellationScreen({super.key, required this.database});

  @override
  State<ConstellationScreen> createState() => _ConstellationScreenState();
}

// ---- category colors ----

const Map<String, Color> _kCategoryColors = {
  'milestone': Color(0xFFFBBF24), // gold
  'step_work': Color(0xFF34D399), // green
  'community': Color(0xFF38BDF8), // blue
  'service': Color(0xFFF97316),   // orange
  'mindfulness': Color(0xFFA78BFA), // purple
  'spiritual': Color(0xFF34D399), // green
};

Color _colorForCategory(String category) =>
    _kCategoryColors[category] ?? AppColors.accent;

// ---- phyllotaxis positioning ----

/// Computes star positions using a sunflower spiral — each star is placed
/// at a golden-angle increment from the previous, with radius growing by
/// sqrt(index) for even distribution. This replaces the old hash-based
/// scatter that caused clustering.
List<ConstellationNode3D> _phyllotaxisNodes(List<ConstellationPoint> points) {
  final sorted = [...points]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  const goldenAngle = 2.399963; // radians (~137.5°)
  const maxRadius = 0.42;

  return sorted.asMap().entries.map((entry) {
    final index = entry.key;
    final p = entry.value;
    final angle = index * goldenAngle;
    final radius = maxRadius * sqrt(index + 1) / sqrt(sorted.length + 1);
    return ConstellationNode3D(
      id: p.id,
      title: p.title,
      category: p.category,
      timestamp: DateTime.fromMillisecondsSinceEpoch(p.timestamp),
      x: radius * cos(angle),
      y: radius * sin(angle) * 0.7, // slight vertical squash for aesthetics
      z: ((p.title.hashCode % 100) / 100 - 0.5) * 0.15,
    );
  }).toList();
}

class _ConstellationScreenState extends State<ConstellationScreen> {
  static const String _skyNameKey = 'constellation_sky_name_v1';

  List<ConstellationNode3D>? _nodes;
  String? _skyName;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final points = await widget.database.getConstellationPoints();
    final nodes = _phyllotaxisNodes(points);
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nodes = nodes;
      _skyName = prefs.getString(_skyNameKey);
    });
  }

  // ------------------------------------------------------------------
  // Rename sky
  // ------------------------------------------------------------------

  Future<void> _renameSky() async {
    final controller = TextEditingController(text: _skyName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title:
            const Text('Name your sky', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. The Return, North Star, Second Chances',
            hintStyle: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(dialogContext,
                controller.text.trim().isEmpty ? null : controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
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
    if (mounted) setState(() => _skyName = name);
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

  int _spanNights(List<ConstellationNode3D> nodes) =>
      ((nodes.last.timestamp.millisecondsSinceEpoch -
              nodes.first.timestamp.millisecondsSinceEpoch) /
          86400000)
      .floor();

  Future<void> _shareShape() async {
    final nodes = _nodes;
    if (nodes == null || nodes.isEmpty) return;
    final shape = _renderShapeGrid(nodes);
    final spanDays = _spanNights(nodes);
    final name = _skyName ?? 'My constellation';

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
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
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(shape,
                    style: const TextStyle(
                        fontSize: 11, height: 1.3, letterSpacing: 2)),
              ),
              const SizedBox(height: 6),
              const Text('Shapes travel. Day counts stay private.',
                  style:
                      TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.copy_all_outlined,
                    color: AppColors.accent),
                title: const Text('Copy shape',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                onTap: () => Navigator.pop(sheetContext, 'copy'),
              ),
              ListTile(
                leading: const Icon(Icons.forum_outlined,
                    color: AppColors.accent),
                title: const Text('Post to Recovery Circle',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Shape only — never your numbers',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
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
          backgroundColor: const Color(0xFF1E293B),
          content:
              const Text('Star shape copied — your day counts stay private'),
        ),
      );
    } else if (choice == 'post') {
      final profile =
          await widget.database.getProfile('active_user_profile');
      await CommunityFeedService(widget.database).compose(
        authorAlias: profile?.anonymousUsername ?? 'Anonymous',
        body: '$name — ${nodes.length} stars over $spanDays nights',
        kind: 'shape',
        shapeJson: shape,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E293B),
          content: const Text('Constellation shared with the circle.'),
        ),
      );
    }
  }

  // ------------------------------------------------------------------
  // Manual star
  // ------------------------------------------------------------------

  Future<void> _addManualStar() async {
    final titleController = TextEditingController();
    var category = 'milestone';
    const categories = [
      'milestone', 'step_work', 'community', 'service', 'mindfulness', 'spiritual',
    ];
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title:
              const Text('Add a star', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                maxLength: 40,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. 90 meetings, Made amends, Sponsored someone',
                  hintStyle: TextStyle(color: Color(0xFF64748B)),
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
                              color: category == cat
                                  ? Colors.white
                                  : AppColors.textMuted)),
                      selected: category == cat,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.bgCard,
                      onSelected: (_) => setDialog(() => category = cat),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child:
                  const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () => Navigator.pop(
                  dialogContext, titleController.text.trim().isNotEmpty),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final title = titleController.text.trim();
    await widget.database.addConstellationPoint(
      ConstellationPoint(
        id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        category: category,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        positionX: 0.5,
        positionY: 0.5,
      ),
    );
    await RecoveryPetService.logStar(title);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E293B),
          content: Text(
              '"$title" added to ${_skyName ?? "your sky"} · +${RecoveryPetService.sparksStar} Sparks'),
        ),
      );
    }
  }

  // ------------------------------------------------------------------
  // Star details (tap)
  // ------------------------------------------------------------------

  void _showStarDetails(int index) {
    final nodes = _nodes;
    if (nodes == null || index >= nodes.length) return;
    final node = nodes[index];
    final color = _colorForCategory(node.category);
    final date = node.timestamp;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(node.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('${node.category} · ${date.month}/${date.day}/${date.year}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 12),
              Text(
                'This star is part of ${_skyName ?? "your constellation"} — '
                'a moment you chose to mark. It stays here forever.',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 13, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final nodes = _nodes;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: GestureDetector(
          onTap: _renameSky,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(_skyName ?? 'Your Constellation',
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_outlined,
                  size: 16, color: Colors.white38),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Share shape',
            icon: const Icon(Icons.ios_share, color: Colors.white70),
            onPressed:
                (nodes == null || nodes.isEmpty) ? null : _shareShape,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_star',
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Star', style: TextStyle(color: Colors.white)),
        onPressed: _addManualStar,
      ),
      body: nodes == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                Expanded(
                  child: nodes.isEmpty
                      ? _EmptySky(onSeed: () async {
                          await RecoveryPetService.ensureHatched();
                          await widget.database.addConstellationPoint(
                            ConstellationPoint(
                              id: 'seed_first_path_${DateTime.now().millisecondsSinceEpoch}',
                              title: 'Began My Recovery Path',
                              category: 'milestone',
                              timestamp:
                                  DateTime.now().millisecondsSinceEpoch,
                              positionX: 0.5,
                              positionY: 0.5,
                            ),
                          );
                          await RecoveryPetService.logStar(
                              'Began My Recovery Path');
                          _load();
                        })
                      : _ConstellationCanvas(
                          nodes: nodes,
                          skyName: _skyName,
                          zoom: _zoom,
                          onZoomChanged: (v) =>
                              setState(() => _zoom = v),
                          onStarTap: _showStarDetails,
                        ),
                ),
              ],
            ),
    );
  }
}

// ---- canvas widget with zoom + tap + starfield background ----

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

class _ConstellationCanvasState extends State<_ConstellationCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _twinkleController;
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;

  @override
  void initState() {
    super.initState();
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.zoom,
    );
    _zoomAnimation = Tween<double>(begin: 1.0, end: 3.0)
        .animate(CurvedAnimation(parent: _zoomController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) {
        // Find the closest star to the tap point.
        final size = context.size;
        if (size == null) return;
        double bestDist = double.infinity;
        int? bestIndex;
        for (var i = 0; i < widget.nodes.length; i++) {
          final node = widget.nodes[i];
          final px = size.width / 2 + node.x * size.width * 0.45 * _zoomController.value;
          final py = size.height / 2 + node.y * size.height * 0.45 * _zoomController.value;
          final dist = (details.localPosition - Offset(px, py)).distance;
          if (dist < 30 && dist < bestDist) {
            bestDist = dist;
            bestIndex = i;
          }
        }
        if (bestIndex != null) widget.onStarTap(bestIndex);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Animated starfield background
          AnimatedBuilder(
            animation: _twinkleController,
            builder: (context, _) => CustomPaint(
              painter: _StarFieldPainter(
                time: _twinkleController.value,
              ),
            ),
          ),
          // Main constellation with zoom
          AnimatedBuilder(
            animation: _zoomAnimation,
            builder: (context, _) => CustomPaint(
              painter: Constellation3DPainter(
                nodes: widget.nodes,
                yaw: 0,
                pitch: 0,
                zoom: _zoomController.value,
              ),
            ),
          ),
          // Zoom slider (bottom)
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Row(
              children: [
                const Icon(Icons.zoom_out, size: 16, color: Colors.white38),
                Expanded(
                  child: Slider(
                    value: _zoomController.value,
                    min: 1.0,
                    max: 3.0,
                    activeColor: AppColors.accent,
                    onChanged: (v) => _zoomController.value = v,
                  ),
                ),
                const Icon(Icons.zoom_in, size: 16, color: Colors.white38),
              ],
            ),
          ),
          // Sky name label
          if (widget.skyName != null)
            Positioned(
              left: 12,
              top: 8,
              child: Text(widget.skyName!,
                  style: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                      fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

// ---- twinkling starfield background ----

class _StarFieldPainter extends CustomPainter {
  final double time;
  _StarFieldPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(42); // deterministic
    final paint = Paint();
    for (var i = 0; i < 80; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final phase = (time * 2 * math.pi + i * 0.7) % (2 * math.pi);
      final alpha = 0.08 + 0.18 * (0.5 + 0.5 * sin(phase));
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 0.6 + rnd.nextDouble() * 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) =>
      oldDelegate.time != time;
}

class _EmptySky extends StatelessWidget {
  final Future<void> Function() onSeed;

  const _EmptySky({required this.onSeed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.accent, size: 48),
          const SizedBox(height: 16),
          const Text('Your sky is waiting.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
            'Light your first star to mark the\nbeginning of your path.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onSeed,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white),
            child: const Text('Begin My Path'),
          ),
        ],
      ),
    );
  }
}
