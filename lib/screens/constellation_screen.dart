// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/recovery_database.dart';
import '../services/community_feed_service.dart';
import '../services/recovery_pet_service.dart';
import 'constellation_canvas_3d.dart';
import '../core/theme/app_colors.dart';

/// Renders the user's milestone constellation from the local Drift store.
///
/// Star-map rules (blueprint: the lines are THEIR path):
///   * every saved milestone becomes one star;
///   * path lines connect stars in the order milestones actually happened,
///     never a preset shape — two people's 30 days draw different figures;
///   * the whole sky can be named ("The Return") for ownership;
///   * sharing exports the SHAPE (relative positions + span), never day
///     counts or dates, so feeds can't turn into sobriety leaderboards.
class ConstellationScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const ConstellationScreen({super.key, required this.database});

  @override
  State<ConstellationScreen> createState() => _ConstellationScreenState();
}

class _ConstellationScreenState extends State<ConstellationScreen> {
  static const String _skyNameKey = 'constellation_sky_name_v1';

  List<ConstellationNode3D>? _nodes;
  String? _skyName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final points = await widget.database.getConstellationPoints();
    // Path = chronological order the milestones were lived, not insertion
    // order — this is what makes each person's figure unique.
    final sorted = [...points]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final nodes = sorted.map((p) {
      // Points are seeded on a 0..1 plane; project onto the sky sphere band
      // the 3D painter expects (roughly -0.45..0.45 with a gentle z spread).
      final titleHash = p.title.hashCode;
      return ConstellationNode3D(
        id: p.id,
        title: p.title,
        category: p.category,
        timestamp: DateTime.fromMillisecondsSinceEpoch(p.timestamp),
        x: (p.positionX - 0.5) * 0.8,
        y: (p.positionY - 0.5) * 0.6,
        z: ((titleHash % 100) / 100 - 0.5) * 0.2,
      );
    }).toList();
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nodes = nodes;
        _skyName = prefs.getString(_skyNameKey);
      });
    }
  }

  Future<void> _renameSky() async {
    final controller = TextEditingController(text: _skyName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Name your sky',
            style: TextStyle(color: Colors.white)),
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
            onPressed: () => Navigator.pop(
                dialogContext,
                controller.text.trim().isEmpty
                    ? null
                    : controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      return;
    } else if (name.isEmpty) {
      await prefs.remove(_skyNameKey);
    } else {
      await prefs.setString(_skyNameKey, name);
    }
    if (mounted) setState(() => _skyName = name);
  }

  /// Shape-share: emoji star chart + name + span. Deliberately NO day counts.
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                leading:
                    const Icon(Icons.copy_all_outlined, color: AppColors.accent),
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
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12)),
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

  String _renderShapeGrid(List<ConstellationNode3D> nodes) {
    const cols = 9;
    const rows = 5;
    final grid = List.generate(rows, (_) => List.filled(cols, '·'));
    for (final n in nodes) {
      // x,y are centered on 0 — normalize back to the grid box.
      final cx = (((n.x / 0.8) + 0.5).clamp(0.0, 0.999) * cols).floor();
      final cy = (((n.y / 0.6) + 0.5).clamp(0.0, 0.999) * rows).floor();
      grid[cy][cx] = '✦';
    }
    return [for (final row in grid) row.join()].join('\n');
  }

  int _spanNights(List<ConstellationNode3D> nodes) =>
      ((nodes.last.timestamp.millisecondsSinceEpoch -
              nodes.first.timestamp.millisecondsSinceEpoch) /
          86400000)
      .floor();

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
                child: Text(
                  _skyName ?? 'Your Constellation',
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
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
            onPressed: (nodes == null || nodes.isEmpty) ? null : _shareShape,
          ),
        ],
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
                              timestamp: DateTime.now().millisecondsSinceEpoch,
                              positionX: 0.5,
                              positionY: 0.5,
                            ),
                          );
                          _load();
                        })
                      : RecoveryConstellation3DWidget(nodes: nodes),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Every milestone you mark becomes a star. Drag to orbit your sky.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
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
          const Text(
            'Your sky is waiting.',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
          ),
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
              foregroundColor: Colors.white,
            ),
            child: const Text('Begin My Path'),
          ),
        ],
      ),
    );
  }
}
