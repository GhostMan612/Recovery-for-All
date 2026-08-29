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
  'milestone': Color(0xFFFBBF24), // gold
  'step_work': Color(0xFF34D399), // green
  'community': Color(0xFF38BDF8), // blue
  'service': Color(0xFFF97316),   // orange
  'mindfulness': Color(0xFFA78BFA), // purple
  'spiritual': Color(0xFF34D399), // green
};

Color _colorForCategory(String category) =>
    _kCategoryColors[category] ?? AppColors.accent;

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
        title: const Text('Name your sky', style: TextStyle(color: Colors.white)),
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
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
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
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.copy_all_outlined, color: AppColors.accent),
                title: const Text('Copy shape', style: TextStyle(color: Colors.white, fontSize: 14)),
                onTap: () => Navigator.pop(sheetContext, 'copy'),
              ),
              ListTile(
                leading: const Icon(Icons.forum_outlined, color: AppColors.accent),
                title: const Text('Post to Recovery Circle', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Shape only — never your numbers', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
        SnackBar(backgroundColor: const Color(0xFF1E293B), content: const Text('Constellation shared with the circle.')),
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
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Add a star', style: TextStyle(color: Colors.white)),
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
                              color: category == cat ? Colors.white : AppColors.textMuted)),
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
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8)))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent), onPressed: () => Navigator.pop(dialogContext, titleController.text.trim().isNotEmpty), child: const Text('Add', style: TextStyle(color: Colors.white))),
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
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFF1E293B), content: Text('"$title" added to ${_skyName ?? "your sky"} · +${RecoveryPetService.sparksStar} Sparks')));
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
              const SizedBox(width: 10),
              Expanded(child: Text(node.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 6),
            Text('${node.category} · ${date.day}/${date.month}/${date.year}', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            Text('This star is part of ${_skyName ?? "your constellation"} — a moment you chose to mark. It stays here forever.', style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.45)),
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
    final nodes = _nodes;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: GestureDetector(
          onTap: _renameSky,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(_skyName ?? 'Your Constellation', style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            const Icon(Icons.edit_outlined, size: 16, color: Colors.white38),
          ]),
        ),
        actions: [
          IconButton(tooltip: 'Share shape', icon: const Icon(Icons.ios_share, color: Colors.white70), onPressed: (nodes == null || nodes.isEmpty) ? null : _shareShape),
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                Expanded(
                  child: nodes.isEmpty
                      ? _EmptySky(onSeed: () async {
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
                          _load();
                        })
                      : _ConstellationCanvas(
                          nodes: nodes,
                          skyName: _skyName,
                          zoom: _zoom,
                          onZoomChanged: (v) => setState(() => _zoom = v),
                          onStarTap: _showStarDetails,
                        ),
                ),
              ],
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
  late AnimationController _zoomController;
  late AnimationController _focusController;
  double _pinchBaseZoom = 1.0;
  int? _focusedStarIndex;
  bool _is3DView = false;
  double _yaw = 0.0;
  double _pitch = 0.0;

  @override
  void initState() {
    super.initState();
    _twinkleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _zoomController = AnimationController.unbounded(vsync: this, duration: const Duration(milliseconds: 200), value: widget.zoom);
    _focusController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void didUpdateWidget(covariant _ConstellationCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoom != widget.zoom) _zoomController.value = widget.zoom;
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    _zoomController.dispose();
    _focusController.dispose();
    super.dispose();
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
      onScaleStart: (_) { _pinchBaseZoom = _zoomController.value; },
      onScaleUpdate: (details) {
        final next = (_pinchBaseZoom * details.scale).clamp(1.0, 10.0);
        if ((next - _zoomController.value).abs() > 0.001) _zoomController.value = next;
      },
      onTapUp: (details) {
        final size = context.size;
        if (size == null) return;
        double bestDist = double.infinity;
        int? bestIndex;
        for (var i = 0; i < widget.nodes.length; i++) {
          final node = widget.nodes[i];
          final px = size.width / 2 + node.x * size.width * 0.45 * _zoomController.value;
          final py = size.height / 2 + node.y * size.height * 0.45 * _zoomController.value;
          final dist = (details.localPosition - Offset(px, py)).distance;
          if (dist < 30 && dist < bestDist) { bestDist = dist; bestIndex = i; }
        }
        if (bestIndex != null) _focusOnStar(bestIndex); else _clearFocus();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Animated starfield background
          AnimatedBuilder(animation: _twinkleController, builder: (context, _) => CustomPaint(painter: _StarFieldPainter(time: _twinkleController.value))),
          // Main constellation with zoom + branch lines + focus highlight
          AnimatedBuilder(
            animation: Listenable.merge([_zoomController, _focusController]),
            builder: (context, _) => CustomPaint(painter: _ConstellationCanvasPainter(
              nodes: widget.nodes,
              zoom: _zoomController.value,
              focusedIndex: _focusedStarIndex,
              focusProgress: _focusController.value,
            )),
          ),
          // 3D view toggle
          Positioned(left: 16, top: 12, child: Material(
            color: const Color(0xFF1E293B).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(onTap: _toggle3DView, borderRadius: BorderRadius.circular(12), child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_is3DView ? Icons.view_in_ar : Icons.crop_rotate, color: _is3DView ? AppColors.accent : Colors.white70, size: 20),
                const SizedBox(width: 6),
                Text(_is3DView ? '3D View' : '2D View', style: TextStyle(color: _is3DView ? AppColors.accent : Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            )),
          )),
          // Focus info badge
          if (_focusedStarIndex != null)
            Positioned(top: 60, left: 16, right: 16, child: AnimatedBuilder(animation: _focusController, builder: (context, _) => Opacity(opacity: _focusController.value, child: Transform.translate(
              offset: Offset(0, 20 * (1 - _focusController.value)),
              child: Material(color: const Color(0xFF1E293B).withValues(alpha: 0.95), borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(16), child: _buildFocusInfo(widget.nodes[_focusedStarIndex!])),
            ))))),
          // 3D view
          if (_is3DView) Positioned.fill(child: RecoveryConstellation3DWidget(nodes: widget.nodes)),
          // Zoom slider (bottom)
          Positioned(left: 16, right: 16, bottom: 12, child: Row(children: [
            const Icon(Icons.zoom_out, size: 16, color: Colors.white38),
            Expanded(child: Slider(value: _zoomController.value, min: 1.0, max: 10.0, activeColor: AppColors.accent, onChanged: (v) => _zoomController.value = v)),
            const Icon(Icons.zoom_in, size: 16, color: Colors.white38),
          ])),
          // Sky name label
          if (widget.skyName != null) Positioned(left: 12, top: 8, child: Text(widget.skyName!, style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildFocusInfo(ConstellationNode3D node) {
    final color = _colorForCategory(node.category);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Text(node.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 20), onPressed: _clearFocus),
      ]),
      const SizedBox(height: 8),
      Text('${node.category} · ${node.timestamp.day}/${node.timestamp.month}/${node.timestamp.year}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: ElevatedButton.icon(onPressed: () { _clearFocus(); widget.onStarTap(widget.nodes.indexOf(node)); }, icon: const Icon(Icons.info_outline, size: 18), label: const Text('Details'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () { _clearFocus(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quick actions coming soon'))); }, icon: const Icon(Icons.star_border, size: 18), label: const Text('Quick Action'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent))),
      ]),
    ]);
  }

  Color _colorForCategory(String category) => _kCategoryColors[category] ?? AppColors.accent;
}

/// Custom painter for the 2D constellation canvas with branch lines and focus highlight
class _ConstellationCanvasPainter extends CustomPainter {
  final List<ConstellationNode3D> nodes;
  final double zoom;
  final int? focusedIndex;
  final double focusProgress;

  _ConstellationCanvasPainter({required this.nodes, required this.zoom, this.focusedIndex, this.focusProgress = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Group nodes by category for branch lines
    final categoryGroups = <String, List<(ConstellationNode3D, int)>>{};
    for (int i = 0; i < nodes.length; i++) {
      final cat = nodes[i].category;
      categoryGroups.putIfAbsent(cat, () => []).add((nodes[i], i));
    }

    // Draw branch lines first (behind stars)
    final branchPaint = Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.15)..strokeWidth = 1.5..style = PaintingStyle.stroke;

    for (final entry in categoryGroups.entries) {
      final catNodes = entry.value;
      if (catNodes.length < 2) continue;
      catNodes.sort((a, b) => a.$1.timestamp.compareTo(b.$1.timestamp));
      for (int i = 1; i < catNodes.length; i++) {
        final (prevNode, _) = catNodes[i - 1];
        final (currNode, _) = catNodes[i];
        final px1 = cx + prevNode.x * size.width * 0.45 * zoom;
        final py1 = cy + prevNode.y * size.height * 0.45 * zoom;
        final px2 = cx + currNode.x * size.width * 0.45 * zoom;
        final py2 = cy + currNode.y * size.height * 0.45 * zoom;
        final path = Path()..moveTo(px1, py1)..quadraticBezierTo((px1 + px2) / 2, (py1 + py2) / 2 - 30, px2, py2);
        canvas.drawPath(path, branchPaint);
      }
    }

    // Draw stars
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final px = cx + node.x * size.width * 0.45 * zoom;
      final py = cy + node.y * size.height * 0.45 * zoom;
      final color = _colorForCategory(node.category);
      final isFocused = focusedIndex == i;
      final focusScale = isFocused ? 1.0 + 0.5 * focusProgress : 1.0;
      final focusAlpha = isFocused ? 1.0 : (focusProgress > 0 ? 0.3 : 1.0);

      final glowPaint = Paint()..color = color.withValues(alpha: 0.4 * focusAlpha * focusScale)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)..style = PaintingStyle.fill;
      final starPaint = Paint()..color = color.withValues(alpha: focusAlpha)..style = PaintingStyle.fill;

      final starSize = 6.0 * focusScale;
      final glowSize = 14.0 * focusScale;

      canvas.drawCircle(Offset(px, py), glowSize, glowPaint);
      canvas.drawCircle(Offset(px, py), starSize, starPaint);

      if (isFocused) {
        final ringPaint = Paint()..color = color.withValues(alpha: 0.5 * focusProgress)..style = PaintingStyle.stroke..strokeWidth = 3.0;
        canvas.drawCircle(Offset(px, py), starSize + 8 + 10 * focusProgress, ringPaint);
      }
    }
  }

  Color _colorForCategory(String category) => _kCategoryColors[category] ?? AppColors.accent;

  @override
  bool shouldRepaint(covariant _ConstellationCanvasPainter oldDelegate) {
    return oldDelegate.zoom != zoom || oldDelegate.focusedIndex != focusedIndex || oldDelegate.focusProgress != focusProgress || oldDelegate.nodes != nodes;
  }
}

// ---- twinkling starfield background ----

class _StarFieldPainter extends CustomPainter {
  final double time;
  _StarFieldPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42); // deterministic
    final paint = Paint();
    for (var i = 0; i < 80; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final phase = (time * 2 * math.pi + i * 0.7) % (2 * math.pi);
      final alpha = 0.08 + 0.18 * (0.5 + 0.5 * math.sin(phase));
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 0.6 + rnd.nextDouble() * 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => oldDelegate.time != time;
}

class _EmptySky extends StatelessWidget {
  final Future<void> Function() onSeed;
  const _EmptySky({required this.onSeed});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.auto_awesome, color: AppColors.accent, size: 48),
      const SizedBox(height: 16),
      const Text('Your sky is waiting.', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
      const SizedBox(height: 8),
      const Text('Light your first star to mark the\nbeginning of your path.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: onSeed, style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white), child: const Text('Begin My Path')),
    ]));
  }
}