// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

import '../database/recovery_database.dart';
import '../services/recovery_pet_service.dart';
import 'constellation_canvas_3d.dart';
import '../core/theme/app_colors.dart';

/// Renders the user's milestone constellation from the local Drift store.
class ConstellationScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const ConstellationScreen({super.key, required this.database});

  @override
  State<ConstellationScreen> createState() => _ConstellationScreenState();
}

class _ConstellationScreenState extends State<ConstellationScreen> {
  List<ConstellationNode3D>? _nodes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final points = await widget.database.getConstellationPoints();
    final nodes = points.map((p) {
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
    if (mounted) setState(() => _nodes = nodes);
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _nodes;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Your Constellation',
            style: TextStyle(color: Colors.white)),
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
