// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../database/recovery_database.dart';
import 'ollama_service.dart';

/// R26 — Narrative Identity engine (Dan P. McAdams).
/// Synthesizes 7-day telemetry (wellness, petEvents, constellation)
/// into a 3-paragraph "Kin's Chronicle" (Agency / Communion / Redemption).
/// Routes to Sovereign Mantle (Ollama) or local GGUF, falls back to
/// deterministic scripted narrative for offline/low-RAM/airplane.
class NarrativeExportService {
  /// Generates a weekly chronicle from trailing 7 days.
  /// Pure telemetry → prompt → inference → fallback.
  static Future<String> generateWeeklyChronicle(RecoveryDatabase db) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;

    // 1. Gather 7-day telemetry (>= sevenDaysAgo, 1ms tolerance)
    final checkIns = await (db.select(db.wellnessCheckIns)
          ..where((t) => t.timestamp.isBiggerThanValue(sevenDaysAgo - 1)))
        .get();

    final petEvents = await (db.select(db.petEvents)
          ..where((t) => t.timestamp.isBiggerThanValue(sevenDaysAgo - 1)))
        .get();

    final stars = await (db.select(db.constellationPoints)
          ..where((t) => t.timestamp.isBiggerThanValue(sevenDaysAgo - 1)))
        .get();

    // 2. Compute McAdams metrics — use actual eventType values from
    // RecoveryPetService: 'battle_win', 'walk', etc.
    final battlesWon = petEvents.where((e) => e.eventType == 'battle_win').length;
    final walks = petEvents.where((e) => e.eventType == 'walk').length;
    final totalSparks = petEvents.fold<int>(0, (sum, e) => sum + e.sparksDelta);

    double avgSpiritual = 0, avgEmotional = 0;
    if (checkIns.isNotEmpty) {
      avgSpiritual = checkIns.map((c) => c.spiritual).reduce((a, b) => a + b) / checkIns.length;
      avgEmotional = checkIns.map((c) => c.emotional).reduce((a, b) => a + b) / checkIns.length;
    }

    // 3. McAdams Framework Prompt (Agency / Communion / Redemption)
    final prompt = """
REALITY FILTER: ON.
You are a therapeutic recovery companion. Write a 3-paragraph weekly reflection ("Kin's Chronicle") for the user based on Dan P. McAdams' Narrative Identity theory.
Data this week:
- Earned Sparks: $totalSparks
- Battles Won (Urges Overcome): $battlesWon
- Mindful Walks: $walks
- Constellation Stars (Milestones): ${stars.length}
- Emotional Avg (0-10): ${avgEmotional.toStringAsFixed(1)}
- Spiritual Avg (0-10): ${avgSpiritual.toStringAsFixed(1)}

Paragraph 1 (Agency): Focus on self-mastery, control, and achievements based on the battles won and sparks earned.
Paragraph 2 (Communion): Focus on connection, inner peace, and emotional/spiritual wellness based on walks and mood.
Paragraph 3 (Redemption Sequence): Frame any struggles as turning points leading to growth (a bad-to-good arc). End with a forward-looking, grounded statement.
Keep it concise, empathetic, and free of medical advice or sycophancy.
""";

    try {
      // 4. Route to Sovereign Mantle / Local Inference (Ollama primary 192.168.4.144:8000)
      final ollama = OllamaService();
      final response = await ollama.generateResponse(prompt).timeout(const Duration(seconds: 25));
      if (response.trim().isNotEmpty) return response.trim();
    } catch (e) {
      debugPrint('[narrative] inference failed, using fallback: $e');
    }

    // 5. Deterministic Fallback (Airplane / Low RAM / timeout)
    return _generateScriptedFallback(battlesWon, walks, totalSparks, stars.length, avgEmotional);
  }

  @visibleForTesting
  static String generateScriptedFallback(
    int battles,
    int walks,
    int sparks,
    int stars,
    double emotional,
  ) =>
      _generateScriptedFallback(battles, walks, sparks, stars, emotional);

  static String _generateScriptedFallback(
    int battles,
    int walks,
    int sparks,
    int stars,
    double emotional,
  ) {
    final p1 =
        "This week, you demonstrated remarkable agency on your path. Overcoming $battles difficult moments and gathering $sparks Sparks shows a commitment to your own growth and mastery over your environment.";
    final emotionalLine = emotional == 0
        ? "Your emotional center has held steady"
        : "Your emotional center (avg ${emotional.toStringAsFixed(1)}/10) has held steady";
    final p2 =
        "Through $walks mindful walks and consistent reflection, you've maintained a focus on your inner wellness. $emotionalLine, reflecting a deepening connection to your daily practices.";
    final p3 =
        "Every path has its friction, but the challenges faced this week are the foundation for the resilience you are building. The ${stars > 0 ? '$stars new stars' : 'steady constellations'} in your sky represent a living, evolving story of moving forward, one intentional day at a time.";
    return "$p1\n\n$p2\n\n$p3";
  }

  /// Persists chronicle as a journal entry (encrypted at rest via SQLCipher DB).
  /// Content is stored as the journal's contentEncrypted field; the DB layer
  /// is already encrypted, and journal crypto is applied at the UI layer on read.
  static Future<void> saveToJournal(RecoveryDatabase db, String chronicle) async {
    final entry = JournalEntry(
      id: 'chronicle_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      moodRating: 4,
      contentEncrypted: chronicle,
      isSyncedToCloud: false,
    );
    await db.addJournalEntry(entry);
  }
}
