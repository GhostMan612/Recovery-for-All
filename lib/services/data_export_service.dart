// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/data_export_service.dart
//
// Exports all recovery data as CSV for sharing with therapists,
// counselors, or healthcare providers. Privacy-first: only anonymous
// data leaves the device (no identity fields, no location).

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/recovery_database.dart';

class DataExportService {
  final RecoveryDatabase database;

  DataExportService(this.database);

  /// Generates a full CSV export and returns the file path.
  Future<String> exportCsv() async {
    final buffer = StringBuffer();

    // Counters
    final counters = await database.select(database.counters).get();
    buffer.writeln('=== COUNTERS ===');
    buffer.writeln('Label,Start Date,Active,Daily Cost');
    for (final c in counters) {
      final date = DateTime.fromMillisecondsSinceEpoch(c.startDateTime);
      buffer.writeln(
          '"${c.label}",${date.toIso8601String().split("T").first},${c.isActive},${c.dailyCost.toStringAsFixed(2)}');
    }

    // Journal entries
    final journals = await (database.select(database.journalEntries)
          ..orderBy([(t) => OrderingTerm(
              expression: t.timestamp, mode: OrderingMode.desc)]))
        .get();
    buffer.writeln('');
    buffer.writeln('=== JOURNAL ENTRIES ===');
    buffer.writeln('Date,Mood (1-5),Content');
    for (final j in journals) {
      final date = DateTime.fromMillisecondsSinceEpoch(j.timestamp);
      // Strip ENC_ prefix for readability
      final content = j.contentEncrypted.startsWith('ENC_')
          ? j.contentEncrypted.substring(4)
          : j.contentEncrypted;
      // Base64 decode if possible
      String readable;
      try {
        readable = utf8.decode(base64Decode(content));
      } catch (_) {
        readable = content;
      }
      // Escape for CSV
      final escaped = readable.replaceAll('"', '""');
      buffer.writeln(
          '${date.toIso8601String()},${j.moodRating},"$escaped"');
    }

    // Wellness check-ins
    final wellness = await database.select(database.wellnessCheckIns).get();
    if (wellness.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('=== WELLNESS CHECK-INS ===');
      buffer.writeln('Date,Spiritual,Intellectual,Emotional,Physical,Social,Occupational');
      for (final w in wellness) {
        final date = DateTime.fromMillisecondsSinceEpoch(w.timestamp);
        buffer.writeln(
            '${date.toIso8601String().split("T").first},${w.spiritual},${w.intellectual},${w.emotional},${w.physical},${w.social},${w.occupational}');
      }
    }

    // Weekly goals
    final goals = await database.select(database.weeklyGoals).get();
    if (goals.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('=== WEEKLY GOALS ===');
      buffer.writeln('Title,Current,Target,Completed');
      for (final g in goals) {
        buffer.writeln('"${g.title}",${g.currentCount},${g.targetCount},${g.isCompleted}');
      }
    }

    // Constellation points
    final stars = await database.select(database.constellationPoints).get();
    if (stars.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('=== CONSTELLATION STARS ===');
      buffer.writeln('Title,Category,Date');
      for (final s in stars) {
        final date = DateTime.fromMillisecondsSinceEpoch(s.timestamp);
        buffer.writeln('"${s.title}",${s.category},${date.toIso8601String().split("T").first}');
      }
    }

    // Write to temp file
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/recovery_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }

  /// Generates a formatted text summary for healthcare providers.
  Future<String> generateSummary() async {
    final buffer = StringBuffer();
    buffer.writeln('Recovery Progress Summary');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String().split("T").first}');
    buffer.writeln('');

    // Counters
    final counters = await database.select(database.counters).get();
    if (counters.isNotEmpty) {
      buffer.writeln('== Active Counters ==');
      for (final c in counters.where((c) => c.isActive)) {
        final start = DateTime.fromMillisecondsSinceEpoch(c.startDateTime);
        final days = DateTime.now().difference(start).inDays;
        buffer.writeln('  ${c.label}: $days days');
      }
      buffer.writeln('');
    }

    // Journal stats
    final journalCount =
        await database.select(database.journalEntries).get();
    if (journalCount.isNotEmpty) {
      buffer.writeln('== Journal ==');
      buffer.writeln('  Total entries: ${journalCount.length}');
      final moods = journalCount.map((j) => j.moodRating).toList();
      final avgMood = moods.reduce((a, b) => a + b) / moods.length;
      buffer.writeln('  Average mood: ${avgMood.toStringAsFixed(1)} / 5');
      buffer.writeln('');
    }

    // Wellness stats
    final wellness = await database.select(database.wellnessCheckIns).get();
    if (wellness.isNotEmpty) {
      buffer.writeln('== Wellness ==');
      buffer.writeln('  Total check-ins: ${wellness.length}');
      if (wellness.length >= 2) {
        final avg = (wellness.fold<double>(0, (sum, w) =>
                sum + w.spiritual + w.intellectual + w.emotional +
                w.physical + w.social + w.occupational) /
            (wellness.length * 6));
        buffer.writeln('  Average dimension score: ${avg.toStringAsFixed(1)} / 10');
      }
      buffer.writeln('');
    }

    // Goals
    final goals = await database.select(database.weeklyGoals).get();
    if (goals.isNotEmpty) {
      buffer.writeln('== Weekly Goals ==');
      buffer.writeln('  Total: ${goals.length}');
      buffer.writeln('  Completed: ${goals.where((g) => g.isCompleted).length}');
      buffer.writeln('');
    }

    buffer.writeln('Exported from Recovery Companion (offline-first, alias-only).');
    return buffer.toString();
  }

  /// Shares the CSV file via the native share sheet.
  Future<void> shareCsv() async {
    final path = await exportCsv();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'Recovery data export (CSV)'),
    );
    // Clean up temp file after sharing
    try {
      await File(path).delete();
    } catch (_) {}
  }

  /// Shares the text summary via the native share sheet.
  Future<void> shareSummary() async {
    final summary = await generateSummary();
    await SharePlus.instance.share(
      ShareParams(text: summary),
    );
  }
}
