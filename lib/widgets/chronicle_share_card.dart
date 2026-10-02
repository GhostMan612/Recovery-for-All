// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/recovery_pet_service.dart';
import 'avatar_visual_layer.dart';

/// R26 Phase 2 — C2-compliant share card for Kin's Chronicle.
/// Captures via RepaintBoundary → PNG → share_plus.
/// No sober-time numbers, no location — only reflection text + pet avatar.
class ChronicleShareCard extends StatefulWidget {
  final String chronicleText;
  final RecoveryPet pet;

  const ChronicleShareCard({
    super.key,
    required this.chronicleText,
    required this.pet,
  });

  @override
  State<ChronicleShareCard> createState() => _ChronicleShareCardState();
}

class _ChronicleShareCardState extends State<ChronicleShareCard> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareChronicle() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/kins_chronicle_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(pngBytes);

      final params = ShareParams(
        text: 'My recovery reflection for the week.',
        files: [XFile(file.path)],
      );
      await SharePlus.instance.share(params);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: _captureKey,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AvatarVisualLayer(pet: widget.pet, size: 60, compact: true),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Kin's Chronicle",
                        // Theme-driven on purpose. This widget is both the
                        // on-screen preview AND the RepaintBoundary captured to
                        // the shared PNG, so the preview must match the
                        // artefact exactly — a fixed palette here would render a
                        // preview the user never actually shares.
                        //
                        // `onSurface`, not Colors.white: the panel is
                        // `surfaceContainer`, near-white in light mode. It was
                        // `const`, so it could not read the theme at all.
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  widget.chronicleText,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isSharing ? null : _shareChronicle,
          icon: _isSharing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              // onPrimary, not Colors.white: the button fill is `primary`, a
              // LIGHT tone in light mode.
              : Icon(Icons.ios_share, color: Theme.of(context).colorScheme.onPrimary),
          label: Text(
            _isSharing ? 'Capturing...' : 'Share Chronicle',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
        ),
      ],
    );
  }
}
