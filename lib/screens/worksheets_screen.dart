// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../data/worksheets_registry.dart';
import '../services/feedback_service.dart';
import '../services/recovery_pet_service.dart';

/// R2 — guided worksheets for every tool. [id] == null renders the list;
/// otherwise the worksheet editor for that entry.
class WorksheetsScreen extends StatefulWidget {
  final String? id;

  const WorksheetsScreen({super.key, this.id});

  @override
  State<WorksheetsScreen> createState() => _WorksheetsScreenState();
}

class _WorksheetsScreenState extends State<WorksheetsScreen> {
  static const String _storeKey = 'tool_worksheets_v1';

  Map<String, List<String>> _saved = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (!mounted) return;
    setState(() {
      _saved = raw == null
          ? {}
          : (jsonDecode(raw) as Map<String, dynamic>).map((k, v) =>
              MapEntry(k, (v as List).map((e) => e.toString()).toList()));
      _loaded = true;
    });
  }

  Future<void> _save(String id, List<String> answers) async {
    _saved[id] = answers;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeKey, jsonEncode(_saved));
    await RecoveryPetService.logToolWorksheet(id);
    await FeedbackService.reward();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text(
            'Worksheet saved · +${RecoveryPetService.sparksWorksheet} Sparks'),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entry =
        widget.id == null ? null : WorksheetsRegistry.byId(widget.id!);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(entry?.title ?? 'Worksheets',
            style: const TextStyle(color: Colors.white)),
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : entry == null
              ? _buildList()
              : _buildEditor(entry),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Guided worksheets — written while calm, read when it matters. '
          'Saved on-device only.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13,
              height: 1.45),
        ),
        const SizedBox(height: 16),
        for (final entry in WorksheetsRegistry.all)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                leading: Icon(
                  _saved.containsKey(entry.id)
                      ? Icons.task_alt
                      : Icons.edit_note_outlined,
                  color: _saved.containsKey(entry.id)
                      ? AppColors.success
                      : AppColors.accent,
                ),
                title: Text(entry.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${entry.tool} · ${entry.description}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right,
                    size: 18, color: Colors.white38),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          WorksheetsScreen(id: entry.id)),
                ).then((_) => _load()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEditor(WorksheetEntry entry) {
    final answers = _saved[entry.id] ??
        List<String>.filled(entry.prompts.length, '');
    final controllers = [
      for (var i = 0; i < entry.prompts.length; i++)
        TextEditingController(text: answers.length > i ? answers[i] : ''),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(entry.description,
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 13, height: 1.45)),
        const SizedBox(height: 16),
        for (var i = 0; i < entry.prompts.length; i++) ...[
          Text(entry.prompts[i],
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: controllers[i],
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bgCard,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              _save(entry.id, controllers.map((c) => c.text.trim()).toList());
              Navigator.pop(context);
            },
            child: const Text('Save worksheet',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
