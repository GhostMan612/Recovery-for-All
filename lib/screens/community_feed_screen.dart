// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/screens/community_feed_screen.dart
//
// Recovery Circle feed. Guardrails from pet-store-rules.md §4 are structural:
// crisis strip always visible (C4), alias-only composer (C1), newest-first
// list with no ranking metric (C3), relapse posts carry a support footer,
// and a moderation queue appears only in moderator mode (C5).

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/community_feed_service.dart';
import '../widgets/themed_background.dart';

class CommunityFeedScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const CommunityFeedScreen({super.key, required this.database});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  late final CommunityFeedService _feed =
      CommunityFeedService(widget.database);
  String _alias = 'Anonymous';
  bool _isModerator = false;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    final profile = await widget.database.getProfile('active_user_profile');
    final moderator = await CommunityFeedService.isModerator();
    if (!mounted) return;
    setState(() {
      if (profile?.anonymousUsername?.isNotEmpty ?? false) {
        _alias = profile!.anonymousUsername!;
      }
      _isModerator = moderator;
    });
  }

  // ------------------------------------------------------------------
  // Compose
  // ------------------------------------------------------------------

  Future<void> _openComposer({String? presetBody, String? shapeJson}) async {
    final controller = TextEditingController(text: presetBody ?? '');
    FeedComposeResult? result;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sharing as $_alias',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                shapeJson != null
                    ? 'Your constellation shape rides along — day counts stay private.'
                    : 'Alias only · no location · no numbers required',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 5,
                maxLength: CommunityFeedService.maxPostLength,
                autofocus: presetBody == null,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                onChanged: (_) => setSheetState(() {}),
                decoration: InputDecoration(
                  hintText: 'How is your path going?',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: controller.text.trim().isEmpty
                      ? null
                      : () async {
                          result = await _feed.compose(
                            authorAlias: _alias,
                            body: controller.text,
                            kind: shapeJson != null ? 'shape' : 'story',
                            shapeJson: shapeJson,
                          );
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                  child: const Text('Share with the circle',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || result == null) return;
    switch (result!) {
      case FeedComposeResult.blockedCrisis:
        _showCrisisDoor();
      case FeedComposeResult.publishedWithSupport:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            content: const Text(
                'Shared. Support resources stay pinned to this post — '
                'you are not alone in this.'),
          ),
        );
      case FeedComposeResult.published:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            content: const Text('Shared with the circle.'),
          ),
        );
    }
  }

  /// Rule C4 — the crisis door is never buried: full-sheet, first action.
  void _showCrisisDoor() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('You matter more than any post.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 19,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                "What you wrote tells us tonight is heavy. The circle can't "
                'hold this one — humans can. Please reach out now.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13,
                    height: 1.45),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.phone_in_talk),
                label: const Text('Call or text 988',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.pop(sheetContext),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: const Icon(Icons.person_pin_circle),
                label: const Text('Open SOS & my contacts'),
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Tile helpers
  // ------------------------------------------------------------------

  String _relativeTime(int ms) {
    final diff = DateTime.now().millisecondsSinceEpoch - ms;
    if (diff < 60000) return 'just now';
    if (diff < 3600000) return '${diff ~/ 60000}m ago';
    if (diff < 86400000) return '${diff ~/ 3600000}h ago';
    return '${diff ~/ 86400000}d ago';
  }

  Widget _reactionButton(
      IconData icon, String label, int count, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: '$label, $count',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        // 48dp minimum: this is one of three reaction affordances per post
        // and was a ~21dp target.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text('$count',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(width: 2),
                Text(label,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: Text('Recovery Circle',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          if (_isModerator)
            IconButton(
              tooltip: 'Moderation queue',
              icon: const Icon(Icons.gavel_outlined, color: Colors.amberAccent),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _ModerationQueueDialog(service: _feed),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'feed_compose',
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.onPrimary),
        label: Text('Share', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        onPressed: () => _openComposer(),
      ),
      body: ThemedBackground(
        enableKenBurns: false,
        scrimOpacity: 0.9,
        child: SafeArea(
          child: Column(
            children: [
              // Rule C4: the crisis door lives at the top of the feed,
              // permanently — never buried in settings.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Material(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _showCrisisDoor,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.support, color: AppColors.dangerSoft),
                      title: Text(
                        'Need help now? 988 · your people · one tap away',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      trailing: Icon(Icons.chevron_right,
                          size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<FeedPost>>(
                  stream: _feed.watchMergedFeed(),
                  builder: (context, snapshot) {
                    final posts = snapshot.data ?? const <FeedPost>[];
                    if (posts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined,
                                size: 54, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(height: 16),
                            Text('The circle is quiet right now.',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface, fontSize: 17)),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Be the first to share how today went — '
                                'alias only, no numbers needed.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: posts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _postTile(posts[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postTile(FeedPost post) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: post.needsSupport
            ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35))
            : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                child: Text(post.authorAlias.isNotEmpty
                    ? post.authorAlias[0].toUpperCase()
                    : '?',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${post.authorAlias}${post.kind == 'shape' ? '  ·  constellation shape' : ''}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(_relativeTime(post.createdAt),
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 11)),
              IconButton(
                tooltip: 'Flag for moderators',
                icon: Icon(Icons.flag_outlined,
                    size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
                onPressed: () => _feed.flag(post.id),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(post.body,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, fontSize: 14, height: 1.45)),
          if (post.shapeJson != null) ...[
            const SizedBox(height: 8),
            _ShapeBadge(shapeJson: post.shapeJson!),
          ],
          if (post.needsSupport) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.favorite_outline,
                      size: 15, color: Theme.of(context).colorScheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This path has hard miles. Need support? '
                      '988 is always there — tap the banner above.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Divider(color: Theme.of(context).colorScheme.outlineVariant, height: 18),
          Row(
            children: [
              _reactionButton(Icons.volunteer_activism_outlined, 'strength',
                  post.strengthCount,
                  () => _feed.react(post.id, kind: 'strength')),
              _reactionButton(Icons.emoji_events_outlined, 'proud',
                  post.proudCount,
                  () => _feed.react(post.id, kind: 'proud')),
              _reactionButton(Icons.handshake_outlined, 'respect',
                  post.respectCount,
                  () => _feed.react(post.id, kind: 'respect')),
              const Spacer(),
              if (post.isMine)
                IconButton(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
                  onPressed: () => widget.database.deleteFeedPost(post.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Constellation share payload rendered as a tiny static star grid.
class _ShapeBadge extends StatelessWidget {
  final String shapeJson;
  const _ShapeBadge({required this.shapeJson});

  @override
  Widget build(BuildContext context) {
    // Payload format (from ConstellationScreen): lines of ✦/· rows.
    final rows =
        shapeJson.split('\n').where((l) => l.contains('✦')).take(5).toList();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            Text(row,
                style: const TextStyle(
                    fontSize: 10, height: 1.25, letterSpacing: 2)),
        ],
      ),
    );
  }
}

class _ModerationQueueDialog extends StatelessWidget {
  final CommunityFeedService service;
  const _ModerationQueueDialog({required this.service});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Moderation queue',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<FeedPost>>(
                stream: service.database.watchModerationQueue(),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <FeedPost>[];
                  if (items.isEmpty) {
                    return Center(
                      child: Text('Queue is clear.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final post = items[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${post.authorAlias} · ${post.status}'
                                ' · flags ${post.flagCount}',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.outline, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(post.body,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  child: Text('Hide',
                                      style: TextStyle(
                                          color: AppColors.dangerSoft)),
                                  onPressed: () =>
                                      service.hide(post.id),
                                ),
                                TextButton(
                                  child: Text('Keep visible',
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary)),
                                  onPressed: () =>
                                      service.approve(post.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
