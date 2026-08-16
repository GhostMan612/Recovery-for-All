// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'dart:math';

/// A data model representing a calculated National Wellness Institute (NWI)
/// weekly progress report across the Six Dimensions of Wellness.
class NwiWeeklyReport {
  final DateTime startDate;
  final DateTime endDate;
  
  // Current week averages (Scale: 0.0 - 1.0)
  final Map<String, double> currentAverages;
  
  // Previous week averages (Scale: 0.0 - 1.0)
  final Map<String, double> previousAverages;
  
  // Percentage deltas from previous week to current week (e.g., +15.2% or -5.0%)
  final Map<String, double> percentageDeltas;
  
  // The dimension with the lowest average score this week
  final String primaryFocusDimension;

  const NwiWeeklyReport({
    required this.startDate,
    required this.endDate,
    required this.currentAverages,
    required this.previousAverages,
    required this.percentageDeltas,
    required this.primaryFocusDimension,
  });

  /// Serializes the report to a JSON structure for secure local storage or syncing.
  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'currentAverages': currentAverages,
      'previousAverages': previousAverages,
      'percentageDeltas': percentageDeltas,
      'primaryFocusDimension': primaryFocusDimension,
    };
  }
}

/// A mock check-in entity matching our SQLite data structures
class WellnessCheckInRaw {
  final String id;
  final int timestamp; // Milliseconds since epoch
  final double spiritual;
  final double intellectual;
  final double emotional;
  final double physical;
  final double social;
  final double occupational;

  const WellnessCheckInRaw({
    required this.id,
    required this.timestamp,
    required this.spiritual,
    required this.intellectual,
    required this.emotional,
    required this.physical,
    required this.social,
    required this.occupational,
  });

  /// Map check-in directly from our secure raw journal entry decryption pipelines
  factory WellnessCheckInRaw.fromJournalPayload(String journalId, int timestamp, String content) {
    // If the check-in is logged as raw JSON or a tokenized key-value list:
    // e.g. "Scores: {Spiritual: 0.8, Intellectual: 0.6, ...}"
    final cleanContent = content.replaceFirst('Scores: ', '').replaceAll('{', '{"').replaceAll('}', '}').replaceAll(': ', '": ').replaceAll(', ', ',"');
    try {
      final Map<String, dynamic> scores = jsonDecode(cleanContent);
      return WellnessCheckInRaw(
        id: journalId,
        timestamp: timestamp,
        spiritual: (scores['Spiritual'] as num? ?? 0.5).toDouble(),
        intellectual: (scores['Intellectual'] as num? ?? 0.5).toDouble(),
        emotional: (scores['Emotional'] as num? ?? 0.5).toDouble(),
        physical: (scores['Physical'] as num? ?? 0.5).toDouble(),
        social: (scores['Social'] as num? ?? 0.5).toDouble(),
        occupational: (scores['Occupational'] as num? ?? 0.5).toDouble(),
      );
    } catch (_) {
      // Fallback default scores on parsing failures to protect data flow
      return WellnessCheckInRaw(
        id: journalId,
        timestamp: timestamp,
        spiritual: 0.5,
        intellectual: 0.5,
        emotional: 0.5,
        physical: 0.5,
        social: 0.5,
        occupational: 0.5,
      );
    }
  }
}

class NwiProgressService {
  /// Aggregates check-ins from the database to calculate a complete weekly report.
  /// Computes current week averages (Days 0-7), prior week averages (Days 7-14),
  /// dimensional progress deltas, and highlights the primary focus zone.
  static NwiWeeklyReport calculateWeeklyReport(List<WellnessCheckInRaw> checkIns, {DateTime? evaluationTime}) {
    final DateTime now = evaluationTime ?? DateTime.now();
    final DateTime currentWeekStart = now.subtract(const Duration(days: 7));
    final DateTime previousWeekStart = now.subtract(const Duration(days: 14));

    final List<WellnessCheckInRaw> currentWeekCheckIns = [];
    final List<WellnessCheckInRaw> previousWeekCheckIns = [];

    for (final checkIn in checkIns) {
      final checkInDate = DateTime.fromMillisecondsSinceEpoch(checkIn.timestamp);
      if (checkInDate.isAfter(currentWeekStart) && !checkInDate.isAfter(now)) {
        currentWeekCheckIns.add(checkIn);
      } else if (checkInDate.isAfter(previousWeekStart) && !checkInDate.isAfter(currentWeekStart)) {
        previousWeekCheckIns.add(checkIn);
      }
    }

    final currentAverages = _calculateAverages(currentWeekCheckIns);
    final previousAverages = _calculateAverages(previousWeekCheckIns);
    final deltas = _calculateDeltas(currentAverages, previousAverages);
    final primaryFocus = _findLowestDimension(currentAverages);

    return NwiWeeklyReport(
      startDate: currentWeekStart,
      endDate: now,
      currentAverages: currentAverages,
      previousAverages: previousAverages,
      percentageDeltas: deltas,
      primaryFocusDimension: primaryFocus,
    );
  }

  static Map<String, double> _calculateAverages(List<WellnessCheckInRaw> list) {
    final Map<String, double> sums = {
      'Spiritual': 0.0,
      'Intellectual': 0.0,
      'Emotional': 0.0,
      'Physical': 0.0,
      'Social': 0.0,
      'Occupational': 0.0,
    };

    if (list.isEmpty) {
      // Default to neutral 50% baseline if no records exist for the window
      return sums.map((key, value) => MapEntry(key, 0.5));
    }

    for (final checkIn in list) {
      sums['Spiritual'] = sums['Spiritual']! + checkIn.spiritual;
      sums['Intellectual'] = sums['Intellectual']! + checkIn.intellectual;
      sums['Emotional'] = sums['Emotional']! + checkIn.emotional;
      sums['Physical'] = sums['Physical']! + checkIn.physical;
      sums['Social'] = sums['Social']! + checkIn.social;
      sums['Occupational'] = sums['Occupational']! + checkIn.occupational;
    }

    final int count = list.length;
    return sums.map((key, value) => MapEntry(key, value / count));
  }

  static Map<String, double> _calculateDeltas(Map<String, double> current, Map<String, double> previous) {
    final Map<String, double> deltas = {};
    
    current.forEach((dimension, currentVal) {
      final double prevVal = previous[dimension] ?? 0.5;
      if (prevVal == 0.0) {
        deltas[dimension] = currentVal > 0.0 ? 100.0 : 0.0;
      } else {
        // Delta percentage calculation: ((Current - Previous) / Previous) * 100
        deltas[dimension] = ((currentVal - prevVal) / prevVal) * 100;
      }
    });

    return deltas;
  }

  static String _findLowestDimension(Map<String, double> averages) {
    String lowestKey = 'Emotional';
    double lowestValue = double.maxFinite;

    averages.forEach((key, value) {
      if (value < lowestValue) {
        lowestValue = value;
        lowestKey = key;
      }
    });

    return lowestKey;
  }

  /// Evaluates clinical guidance prompts based on the lowest wellness dimension.
  static String getTherapeuticRecommendation(String focusDimension) {
    switch (focusDimension) {
      case 'Spiritual':
        return "Your spiritual compass has dipped this week. Consider reconnecting with your top core principles, walking the Red Road, or using a values-reflection prompt in your journal.";
      case 'Intellectual':
        return "Intellectual engagement is low. Dedicate 15 minutes today to mindful, stimulating reading—search the library for SMART worksheets or Buddhist recovery texts.";
      case 'Emotional':
        return "Emotional stress seems elevated. Try taking a 'cozy desk setup' micro-break or running a socratic check-in to identify competing internal parts.";
      case 'Physical':
        return "Physical vitality requires attention. Prioritize restorative sleep, healthy nutrition, or a simple 20-minute rhythmic walk under the open sky.";
      case 'Social':
        return "Social connections have dropped. We highly recommend mapping nearby BMLT meetings or launching your dialer to connect with your designated sponsor.";
      case 'Occupational':
        return "Daily routines feel less fulfilling. Try running a TGROW coaching flow to break down broad tasks into low-friction, satisfying micro-steps.";
      default:
        return "Take a deep breath and validate your effort. Change is built slowly, one mindful check-in at a time.";
    }
  }
}
