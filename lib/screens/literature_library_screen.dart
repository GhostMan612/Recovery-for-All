// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../data/recovery_literature.dart';
import '../services/recovery_pet_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final sections = _visibleSections;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title:
            const Text('Literature Library', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: _showAll ? 'Showing everything' : 'Tailored to your paths',
            icon: Icon(
              _showAll ? Icons.visibility : Icons.tune,
              color: _showAll ? AppColors.accent : Colors.white38,
            ),
            onPressed: () => _toggleShowAll(!_showAll),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final (category, links) in sections) ...[
                  Row(children: [
                    Icon(category.icon, color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(category.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 10),
                  for (final link in links)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          title: Text(link.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(link.subtitle,
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                          trailing: const Icon(Icons.open_in_new,
                              size: 18, color: Colors.white38),
                          onTap: () => _open(link.url),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
    );
  }
}
