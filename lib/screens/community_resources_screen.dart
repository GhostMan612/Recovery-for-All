// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../data/recovery_resources.dart';
import '../services/recovery_pet_service.dart';
import '../services/resource_link_health.dart';
import 'native_resources_screen.dart';

/// Curated community support directory: Recovery Community Organizations,
/// all-pathway meetings, and daily reflection feeds from trusted sources.
///
/// Content lives in [RecoveryResources] (data registry). Sections tagged
/// with pathways show only when relevant — unless the user flips
/// "Show everything" (prefs `resources_show_all_v1`).
class CommunityResourcesScreen extends StatefulWidget {
  const CommunityResourcesScreen({super.key});

  @override
  State<CommunityResourcesScreen> createState() =>
      _CommunityResourcesScreenState();
}

class _CommunityResourcesScreenState extends State<CommunityResourcesScreen> {
  static const String _keyShowAll = 'resources_show_all_v1';

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
    final service = ResourceLinkHealth.instance;
    unawaited(service
        .ensureFresh(RecoveryResources.allUrls)
        .then((_) => _refreshHealth()));
  }

  Future<void> _refreshHealth() async {
    final service = ResourceLinkHealth.instance;
    final health = <String, LinkHealth>{};
    for (final section in RecoveryResources.sections) {
      for (final link in section.links) {
        health[link.url] = await service.statusFor(link.url);
      }
    }
    if (!mounted) return;
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

  List<ResourceSection> get _visibleSections => RecoveryResources.sections
      .where((s) =>
          _showAll ||
          s.pathways.isEmpty ||
          s.pathways.intersection(_paths).isNotEmpty)
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

  void _openNative(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NativeResourcesScreen()),
    );
  }

  Widget _section(ResourceSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(section.icon, color: AppColors.accent, size: 18),
          const SizedBox(width: 8),
          Text(section.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        for (final link in section.links)
          Builder(builder: (context) {
            final dead = _health[link.url]?.ok == false;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  leading: Icon(link.icon,
                      color:
                          dead ? Colors.white24 : AppColors.accent),
                  title: Text(link.title,
                      style: TextStyle(
                          color: dead ? Colors.white38 : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(link.subtitle,
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                  trailing: dead
                      ? const Icon(Icons.link_off,
                          size: 18, color: Colors.white24)
                      : const Icon(Icons.open_in_new,
                          size: 18, color: Colors.white38),
                  onTap: () {
                    _open(link.url);
                    if (dead) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('This site may be down right '
                                'now — the description above tells you '
                                'what to search for.')),
                      );
                    }
                  },
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _visibleSections;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Community Support',
            style: TextStyle(color: Colors.white)),
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
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.25)),
                  ),
                  child: const Text(
                    'Trusted organizations outside this app. Links open in '
                    'your browser so content is always current.',
                    style: TextStyle(color: AppColors.textPrimary,
                        fontSize: 13, height: 1.45),
                  ),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < sections.length; i++) ...[
                  _section(sections[i]),
                  if (i == 0) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          leading: const Icon(Icons.spa_outlined,
                              color: AppColors.accent),
                          title: const Text('Native Recovery Centers (in-app)',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              'Culturally specific programs across Minnesota',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right,
                              size: 18, color: Colors.white38),
                          onTap: () => _openNative(context),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                if (_lastVerifiedAt != null)
                  Center(
                    child: Text(
                      'Links verified ${_formatDay(_lastVerifiedAt!)}',
                      style:
                          const TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
