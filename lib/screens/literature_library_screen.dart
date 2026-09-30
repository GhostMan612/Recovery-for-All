// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/recovery_literature.dart';
import '../services/recovery_pet_service.dart';
import '../services/resource_link_health.dart';
import 'custom_workbook_screen.dart';

/// Free recovery literature, organized by pathway. Content lives in
/// [RecoveryLiterature] (data registry). Pathway-tagged categories appear
/// only when relevant — "Show everything" reveals the full library.
class LiteratureLibraryScreen extends StatefulWidget {
  const LiteratureLibraryScreen({super.key});

  @override
  State<LiteratureLibraryScreen> createState() =>
      _LiteratureLibraryScreenState();
}

class _LiteratureLibraryScreenState extends State<LiteratureLibraryScreen> {
  static const String _keyShowAll = 'literature_show_all_v1';

  bool _showAll = false;
  Set<String> _paths = {};
  bool _loaded = false;
  final Map<String, LinkHealth> _health = {};
  int? _lastVerifiedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var paths = const <String>{};
    try {
      final profile =
          await RecoveryPetService.database?.getProfile('active_user_profile');
      if (profile != null && profile.activePaths.isNotEmpty) {
        paths = (jsonDecode(profile.activePaths) as List)
            .map((e) => e.toString())
            .toSet();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _showAll = prefs.getBool(_keyShowAll) ?? false;
      _paths = paths;
      _loaded = true;
    });
    // Silent staggered refresh of expired entries; never blocks reading.
    final service = ResourceLinkHealth.instance;
    unawaited(service
        .ensureFresh(RecoveryLiterature.allUrls)
        .then((_) => _refreshHealth()));
  }

  Future<void> _refreshHealth() async {
    final service = ResourceLinkHealth.instance;
    final health = <String, LinkHealth>{};
    for (final (_, links) in RecoveryLiterature.sections) {
      for (final link in links) {
        health[link.url] = await service.statusFor(link.url);
      }
    }    if (!mounted) return;
    setState(() => _health.addAll(health));
    final newest = await service.lastVerifiedAt();
    if (mounted && newest != _lastVerifiedAt) {
      setState(() => _lastVerifiedAt = newest);
    }
  }

  Future<void> _toggleShowAll(bool value) async {
    setState(() => _showAll = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowAll, value);
  }

  List<(LitCategory, List<LitLink>)> get _visibleSections =>
      RecoveryLiterature.sections
          .where((s) =>
              _showAll ||
              s.$1.pathways.isEmpty ||
              s.$1.pathways.intersection(_paths).isNotEmpty)
          .toList();

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String _formatDay(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final sections = _visibleSections;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Literature Library'),
        actions: [
          IconButton(
            tooltip: 'My Workbooks (on-device PDFs)',
            icon: Icon(Icons.menu_book_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomWorkbookScreen())),
          ),
          IconButton(
            tooltip: _showAll ? 'Showing everything' : 'Tailored to your paths',
            icon: Icon(
              _showAll ? Icons.visibility : Icons.tune,
              color: _showAll ? Theme.of(context).colorScheme.primary : Colors.white38,
            ),
            onPressed: () => _toggleShowAll(!_showAll),
          ),
        ],
      ),
      body: !_loaded
          ? Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final (category, links) in sections) ...[
                  Row(children: [
                    Icon(category.icon, color: Theme.of(context).colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(category.name,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 10),
                  for (final link in links)
                    Builder(builder: (context) {
                      final dead = _health[link.url]?.ok == false;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            title: Text(link.title,
                                style: TextStyle(
                                    color: dead
                                        ? Colors.white38
                                        : Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(link.subtitle,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 12)),
                            trailing: dead
                                ? Icon(Icons.link_off,
                                    size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24))
                                : Icon(Icons.open_in_new,
                                    size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                            onTap: () {
                              _open(link.url);
                              if (dead) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'This site may be down right now '
                                          '— the description above tells '
                                          'you what to search for.')),
                                );
                              }
                            },
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 14),
                ],
                if (_lastVerifiedAt != null)
                  Center(
                    child: Text(
                      'Links verified ${_formatDay(_lastVerifiedAt!)}',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), fontSize: 11),
                    ),
                  ),
              ],
            ),
    );
  }
}
