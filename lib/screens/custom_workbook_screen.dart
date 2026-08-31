// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';

/// On-device, user-imported workbooks (Option B).
/// Files stay on this device (app documents dir) and are never committed.
/// NA fellowship-approved literature (Step Working Guide, Basic Text) is
/// copyrighted — users must own the file or have permission. We store only
/// what the user picks.
class CustomWorkbookScreen extends StatefulWidget {
  const CustomWorkbookScreen({super.key});

  @override
  State<CustomWorkbookScreen> createState() => _CustomWorkbookScreenState();
}

class _CustomWorkbookScreenState extends State<CustomWorkbookScreen> {
  static const String _keyWorkbooks = 'custom_workbooks_v1';

  List<Map<String, dynamic>> _workbooks = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyWorkbooks);
    List<Map<String, dynamic>> list = [];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    // Prune missing files
    final pruned = <Map<String, dynamic>>[];
    for (final entry in list) {
      final path = entry['path'] as String?;
      if (path != null && await File(path).exists()) {
        pruned.add(entry);
      }
    }
    if (pruned.length != list.length) {
      await prefs.setString(_keyWorkbooks, jsonEncode(pruned));
    }
    if (mounted) setState(() { _workbooks = pruned; _loaded = true; });
  }

  Future<Directory> _workbookDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'custom_workbooks'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _import() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (files.isEmpty) return;
      final picked = files.first;
      final srcPath = picked.path;
      if (srcPath == null) return;
      final srcFile = File(srcPath);
      if (!await srcFile.exists()) return;

      final dir = await _workbookDir();
      final destName = p.basename(srcPath);
      final destPath = p.join(dir.path, destName);
      await srcFile.copy(destPath);

      final entry = {
        'name': destName,
        'path': destPath,
        'importedAt': DateTime.now().millisecondsSinceEpoch,
        'size': await File(destPath).length(),
      };
      final prefs = await SharedPreferences.getInstance();
      final updated = [..._workbooks, entry];
      await prefs.setString(_keyWorkbooks, jsonEncode(updated));
      if (mounted) setState(() => _workbooks = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $destName'), backgroundColor: AppColors.bgCard),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: AppColors.bgCard),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> entry) async {
    final path = entry['path'] as String?;
    if (path != null) {
      try { await File(path).delete(); } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final updated = _workbooks.where((e) => e['path'] != path).toList();
    await prefs.setString(_keyWorkbooks, jsonEncode(updated));
    if (mounted) setState(() => _workbooks = updated);
  }

  void _open(Map<String, dynamic> entry) {
    final path = entry['path'] as String?;
    final name = entry['name'] as String? ?? 'Workbook';
    if (path == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _PdfViewerScreen(path: path, title: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('My Workbooks', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(tooltip: 'Import PDF', icon: const Icon(Icons.file_upload_outlined, color: Colors.white70), onPressed: _import),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.bgCard.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Icon(Icons.privacy_tip_outlined, color: AppColors.accent, size: 18), SizedBox(width: 8), Text('On-device only', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]),
                    SizedBox(height: 8),
                    Text('Files you import stay on this device and are never uploaded. Only import files you own or have permission to use. Fellowship-approved NA literature (Basic Text, Step Working Guide) is copyrighted — please purchase via NAWS catalog or link to na.org.', style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5)),
                  ]),
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white), onPressed: _import, icon: const Icon(Icons.file_open_outlined), label: const Text('Import Workbook (PDF)', style: TextStyle(fontWeight: FontWeight.bold)))),
                const SizedBox(height: 20),
                if (_workbooks.isEmpty)
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.bgCard.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12)),
                    child: const Text('No workbooks yet — tap Import to pick a PDF from your device. Your counselor’s custom packet (like the 12-page guide) will appear here.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  )
                else
                  for (final entry in _workbooks)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.bgCard.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        const Icon(Icons.picture_as_pdf_outlined, color: AppColors.accent),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(entry['name']?.toString() ?? 'Workbook', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('${((entry['size'] as int? ?? 0) / 1024).round()} KB • ${DateTime.fromMillisecondsSinceEpoch(entry['importedAt'] as int? ?? 0).toLocal().toString().substring(0, 10)}', style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                        ])),
                        IconButton(tooltip: 'Open', icon: const Icon(Icons.open_in_new, color: Colors.white70), onPressed: () => _open(entry)),
                        IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, color: Colors.white38), onPressed: () => _delete(entry)),
                      ]),
                    ),
                if (_workbooks.isNotEmpty) const SizedBox(height: 12),
                // Dev helper: if media/na_swg_12.pdf exists on dev machine, offer one-tap test import (not bundled)
                FutureBuilder<bool>(
                  future: File('media/na_swg_12.pdf').exists(),
                  builder: (context, snapshot) {
                    if (snapshot.data != true) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(icon: const Icon(Icons.bug_report_outlined, size: 16), label: const Text('Dev: import media/na_swg_12.pdf'), onPressed: () async {
                        final src = File('media/na_swg_12.pdf');
                        if (!await src.exists()) return;
                        final dir = await _workbookDir();
                        final destPath = p.join(dir.path, 'na_swg_12.pdf');
                        await src.copy(destPath);
                        final entry = {'name': 'na_swg_12.pdf', 'path': destPath, 'importedAt': DateTime.now().millisecondsSinceEpoch, 'size': await File(destPath).length()};
                        final prefs = await SharedPreferences.getInstance();
                        final updated = [..._workbooks.where((e) => e['path'] != destPath), entry];
                        await prefs.setString(_keyWorkbooks, jsonEncode(updated));
                        if (mounted) setState(() => _workbooks = updated);
                      }),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _PdfViewerScreen extends StatefulWidget {
  final String path;
  final String title;
  const _PdfViewerScreen({required this.path, required this.title});
  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  int _pages = 0;
  int _currentPage = 0;
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Stack(children: [
        PDFView(
          filePath: widget.path,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: false,
          pageFling: false,
          pageSnap: true,
          onRender: (pages) => setState(() { _pages = pages ?? 0; _ready = true; }),
          onPageChanged: (page, total) => setState(() { _currentPage = page ?? 0; _pages = total ?? _pages; }),
          onError: (error) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF error: $error')));
          },
        ),
        if (!_ready) const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        if (_ready && _pages > 0)
          Positioned(bottom: 12, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)), child: Text('${_currentPage + 1} / $_pages', style: const TextStyle(color: Colors.white, fontSize: 12))))),
      ]),
    );
  }
}
