// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

/// The shared reader chrome: a verified host indicator plus one labelled,
/// explicitly user-triggered browser escape.
///
/// The host text is the honesty control for the whole feature. Third-party HTML
/// is never presented under app branding, so the visible origin has to come
/// from the URL actually loaded, not from the title the caller passed in.
class ResourceViewerToolbar extends StatelessWidget
    implements PreferredSizeWidget {
  static const double height = 52;

  final String host;
  final Future<void> Function()? onOpenExternal;

  const ResourceViewerToolbar({
    super.key,
    required this.host,
    this.onOpenExternal,
  });

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.public, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                label: 'Current website: $host',
                excludeSemantics: true,
                child: Text(
                  host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            // A disabled control keeps the row stable as the URL resolves, and
            // makes "nothing to escape to" visible rather than absent.
            IconButton(
              tooltip: 'Open in browser',
              onPressed: onOpenExternal,
              icon: const Icon(Icons.open_in_new),
            ),
          ],
        ),
      ),
    );
  }
}