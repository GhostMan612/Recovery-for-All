// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  TextColumn get sponsorPhone => text().nullable()();
  TextColumn get customHelpPhone => text().nullable()();
  TextColumn get personalityJson => text().nullable()();

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

@DataClassName('RecoveryPetRow')
class RecoveryPets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get speciesOrStyle => text().withDefault(const Constant('kin'))();
  RealColumn get energy => real().withDefault(const Constant(0.7))();
  RealColumn get bond => real().withDefault(const Constant(0.2))();
  TextColumn get mood => text().withDefault(const Constant('hopeful'))();
  IntColumn get sparks => integer().withDefault(const Constant(10))();
  TextColumn get unlockedItems => text().withDefault(const Constant('["starter_glow"]'))();
  TextColumn get equippedOutfit => text().withDefault(const Constant('starter_glow'))();
  IntColumn get lastFedAt => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PetEventRow')
class PetEvents extends Table {
  TextColumn get id => text()();
  TextColumn get petId => text()();
  TextColumn get eventType => text()();
  IntColumn get sparksDelta => integer().withDefault(const Constant(0))();
  IntColumn get timestamp => integer()();
  TextColumn get metaJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Profiles,
  Counters,
  JournalEntries,
  ConstellationPoints,
  WeeklyGoals,
  WellnessCheckIns,
  RecoveryPets,
  PetEvents,
])
class RecoveryDatabase extends _$RecoveryDatabase {
  RecoveryDatabase() : super(_openEncryptedConnection());

  RecoveryDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          await customStatement('PRAGMA foreign_keys = OFF');
          await transaction(() async {
            if (from < 2) {
              await m.addColumn(profiles, profiles.selectedValues);
              await m.createTable(weeklyGoals);
            }
            if (from < 3) {
              await m.createTable(wellnessCheckIns);
            }
            if (from < 4) {
              await m.addColumn(profiles, profiles.sponsorPhone);
              await m.addColumn(profiles, profiles.customHelpPhone);
            }
            if (from < 5) {
              await m.createTable(recoveryPets);
              await m.createTable(petEvents);
            }
            if (from < 6) {
              await m.addColumn(profiles, profiles.personalityJson);
            }
          });
          await customStatement('PRAGMA foreign_keys = ON');
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<int> saveProfile(Profile profile) =>
      into(profiles).insertOnConflictUpdate(profile);

  Future<Profile?> getProfile(String id) =>
      (select(profiles)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Stream<List<Counter>> watchAllCounters() => select(counters).watch();

  Future<int> addCounter(Counter counter) =>
      into(counters).insertOnConflictUpdate(counter);

  Future<void> updateCounterAnniversary(String id, DateTime newDateTime) {
    return (update(counters)..where((tbl) => tbl.id.equals(id))).write(
      CountersCompanion(
        startDateTime: Value(newDateTime.millisecondsSinceEpoch),
      ),
    );
  }

  Future<int> deleteCounter(String id) =>
      (delete(counters)..where((tbl) => tbl.id.equals(id))).go();

  Future<int> addJournalEntry(JournalEntry entry) =>
      into(journalEntries).insert(entry);

  Stream<List<JournalEntry>> watchRecentJournals() {
    return (select(journalEntries)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.timestamp,
                  mode: OrderingMode.desc,
                )
          ]))
        .watch();
  }

  Future<int> addConstellationPoint(ConstellationPoint point) =>
      into(constellationPoints).insert(point);

  Future<List<ConstellationPoint>> getConstellationPoints() =>
      select(constellationPoints).get();

  Stream<List<ConstellationPoint>> watchConstellationPoints() =>
      select(constellationPoints).watch();

  Future<int> addWeeklyGoal(WeeklyGoal goal) =>
      into(weeklyGoals).insertOnConflictUpdate(goal);

  Stream<List<WeeklyGoal>> watchAllWeeklyGoals() => select(weeklyGoals).watch();

  Future<int> incrementWeeklyGoal(String id, {int by = 1}) async {
    final rows =
        await (select(weeklyGoals)..where((tbl) => tbl.id.equals(id))).get();
    if (rows.isEmpty) return 0;
    final goal = rows.first;
    final newCount = goal.currentCount + by;
    return (update(weeklyGoals)..where((tbl) => tbl.id.equals(id))).write(
      WeeklyGoalsCompanion(
        currentCount: Value(newCount),
        isCompleted: Value(newCount >= goal.targetCount),
      ),
    );
  }

  Future<int> resetAllWeeklyGoals() =>
      (update(weeklyGoals)).write(
        WeeklyGoalsCompanion(currentCount: const Value(0), isCompleted: const Value(false)),
      );

  Future<int> deleteWeeklyGoal(String id) =>
      (delete(weeklyGoals)..where((tbl) => tbl.id.equals(id))).go();

  Future<int> addWellnessCheckIn(WellnessCheckIn checkIn) =>
      into(wellnessCheckIns).insertOnConflictUpdate(checkIn);

  Future<List<WellnessCheckIn>> getCheckInsForRange(int startMs, int endMs) {
    return (select(wellnessCheckIns)
          ..where((tbl) => tbl.timestamp.isBetweenValues(startMs, endMs))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.timestamp,
                  mode: OrderingMode.desc,
                )
          ]))
        .get();
  }

  Future<RecoveryPetRow?> getPet(String id) =>
      (select(recoveryPets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> upsertPet(RecoveryPetRow pet) =>
      into(recoveryPets).insertOnConflictUpdate(pet);

  Stream<RecoveryPetRow?> watchPet(String id) {
    return (select(recoveryPets)..where((t) => t.id.equals(id)))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<int> addPetEvent(PetEventRow event) => into(petEvents).insert(event);

  Stream<List<PetEventRow>> watchPetEvents(String petId) {
    return (select(petEvents)
          ..where((t) => t.petId.equals(petId))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.timestamp,
                  mode: OrderingMode.desc,
                )
          ]))
        .watch();
  }
}

const _kDbKeyStorageKey = 'recovery_db_sqlcipher_key_v1';

String _generateKeyHex() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

LazyDatabase _openEncryptedConnection() {
  return LazyDatabase(() async {
    const storage = FlutterSecureStorage();
    var key = await storage.read(key: _kDbKeyStorageKey);
    if (key == null || key.isEmpty) {
      key = _generateKeyHex();
      await storage.write(key: _kDbKeyStorageKey, value: key);
    }

    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'recovery_companion_secure.db'));

    return NativeDatabase(
      file,
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = \"x'$key'\"");
        rawDb.execute('PRAGMA cipher_page_size = 4096');
        rawDb.execute('PRAGMA kdf_iter = 256000');
      },
    );
  });
}