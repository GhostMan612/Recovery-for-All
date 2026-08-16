// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'recovery_database.g.dart';

@DataClassName('Profile')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get anonymousUsername => text().nullable()();
  IntColumn get createdAt => integer()();
  BoolColumn get biometricLockEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get selectedGoals => text()(); 
  TextColumn get activePaths => text()();   
  TextColumn get selectedValues => text().nullable()(); 

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Counter')
class Counters extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()(); 
  IntColumn get startDateTime => integer()(); 
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('JournalEntry')
class JournalEntries extends Table {
  TextColumn get id => text()();
  IntColumn get timestamp => integer()();
  IntColumn get moodRating => integer()(); 
  TextColumn get contentEncrypted => text()(); 
  BoolColumn get isSyncedToCloud => boolean().withDefault(const Constant(false))(); 

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ConstellationPoint')
class ConstellationPoints extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()(); 
  TextColumn get category => text()(); 
  IntColumn get timestamp => integer()();
  RealColumn get positionX => real()(); 
  RealColumn get positionY => real()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('WeeklyGoal')
class WeeklyGoals extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get targetCount => integer()();
  IntColumn get currentCount => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('WellnessCheckIn')
class WellnessCheckIns extends Table {
  TextColumn get id => text()();
  IntColumn get timestamp => integer()();
  RealColumn get spiritual => real()();
  RealColumn get intellectual => real()();
  RealColumn get emotional => real()();
  RealColumn get physical => real()();
  RealColumn get social => real()();
  RealColumn get occupational => real()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Profiles, Counters, JournalEntries, ConstellationPoints, WeeklyGoals, WellnessCheckIns])
class RecoveryDatabase extends _$RecoveryDatabase {
  RecoveryDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(profiles, profiles.selectedValues);
            await m.createTable(weeklyGoals);
          }
          if (from < 3) {
            await m.createTable(wellnessCheckIns);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
  
  Future<int> saveProfile(Profile profile) => into(profiles).insertOnConflictUpdate(profile);
  Future<Profile?> getProfile(String id) => (select(profiles)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Stream<List<Counter>> watchAllCounters() => select(counters).watch();
  Future<int> addCounter(Counter counter) => into(counters).insertOnConflictUpdate(counter);
  Future<void> updateCounterAnniversary(String id, DateTime newDateTime) {
    return (update(counters)..where((tbl) => tbl.id.equals(id)))
        .write(CountersCompanion(startDateTime: Value(newDateTime.millisecondsSinceEpoch)));
  }
  Future<int> deleteCounter(String id) => (delete(counters)..where((tbl) => tbl.id.equals(id))).go();

  Future<int> addJournalEntry(JournalEntry entry) => into(journalEntries).insert(entry);
  Stream<List<JournalEntry>> watchRecentJournals() {
    return (select(journalEntries)
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<int> addConstellationPoint(ConstellationPoint point) => into(constellationPoints).insert(point);
  Future<List<ConstellationPoint>> getConstellationPoints() => select(constellationPoints).get();
  Stream<List<ConstellationPoint>> watchConstellationPoints() => select(constellationPoints).watch();

  Future<int> addWeeklyGoal(WeeklyGoal goal) => into(weeklyGoals).insertOnConflictUpdate(goal);
  Stream<List<WeeklyGoal>> watchAllWeeklyGoals() => select(weeklyGoals).watch();

  Future<int> addWellnessCheckIn(WellnessCheckIn checkIn) => into(wellnessCheckIns).insertOnConflictUpdate(checkIn);
  Future<List<WellnessCheckIn>> getCheckInsForRange(int startMs, int endMs) {
    return (select(wellnessCheckIns)
          ..where((tbl) => tbl.timestamp.isBetweenValues(startMs, endMs))
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]))
        .get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'recovery_companion_secure.db'));
    return NativeDatabase(file);
  });
}
