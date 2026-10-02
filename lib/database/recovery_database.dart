// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

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
  RealColumn get dailyCost => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

// v12: every watched query on these tables filters and/or orders by the indexed
// columns. Without them each emission was a full scan plus a sort.
@TableIndex(name: 'idx_journal_ts', columns: {#timestamp})
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

@TableIndex(name: 'idx_points_ts', columns: {#timestamp})
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

@TableIndex(name: 'idx_checkin_ts', columns: {#timestamp})
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

/// Community "Recovery Circle" feed (Volume III /community_feeds).
/// Privacy posture: alias-only, no location fields, no sober-time numbers.
@TableIndex(name: 'idx_feed_status_created', columns: {#status, #createdAt})
@TableIndex(name: 'idx_feed_flag', columns: {#flagCount})
@DataClassName('FeedPost')
class FeedPosts extends Table {
  TextColumn get id => text()();
  TextColumn get authorAlias => text()();

  /// story | chip | shape
  TextColumn get kind => text()();
  TextColumn get body => text().withLength(min: 1, max: 480)();

  /// Optional constellation share payload (relative star positions).
  TextColumn get shapeJson => text().nullable()();

  /// true when relapse-language was detected — post publishes but renders a
  /// persistent support-resources footer (rule C4).
  BoolColumn get needsSupport => boolean().withDefault(const Constant(false))();

  /// visible | pending | hidden
  TextColumn get status => text().withDefault(const Constant('visible'))();
  IntColumn get flagCount => integer().withDefault(const Constant(0))();

  /// Masked support reaction counts (Volume III support_reactions).
  IntColumn get strengthCount => integer().withDefault(const Constant(0))();
  IntColumn get proudCount => integer().withDefault(const Constant(0))();
  IntColumn get respectCount => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  BoolColumn get isMine => boolean().withDefault(const Constant(true))();

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
  // R28: migrated pet state — equippedSlots JSON, path progression
  TextColumn get equippedSlotsJson => text().withDefault(const Constant('{}'))();
  IntColumn get pathLevel => integer().withDefault(const Constant(1))();
  IntColumn get pathXp => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_pet_events_pet_ts', columns: {#petId, #timestamp})
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

@TableIndex(name: 'idx_sync_peer_ts', columns: {#peerAlias, #timestamp})
@DataClassName('FellowshipSync')
class FellowshipSyncs extends Table {
  TextColumn get id => text()();
  TextColumn get peerAlias => text()();
  IntColumn get timestamp => integer()();
  IntColumn get xpAwarded => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ActiveRaid')
class ActiveRaids extends Table {
  TextColumn get id => text()();
  TextColumn get bossName => text()();
  IntColumn get maxHp => integer()();
  IntColumn get currentHp => integer()();
  IntColumn get endTime => integer()();
  IntColumn get userContribution => integer()();

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
  FeedPosts,
  FellowshipSyncs,
  ActiveRaids,
])
class RecoveryDatabase extends _$RecoveryDatabase {
  RecoveryDatabase() : super(_openEncryptedConnection());

  RecoveryDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 12;

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
            if (from < 7) {
              await m.createTable(feedPosts);
            }
            if (from < 8) {
              await m.addColumn(counters, counters.dailyCost);
            }
            if (from < 9) {
              await m.addColumn(recoveryPets, recoveryPets.equippedSlotsJson);
              await m.addColumn(recoveryPets, recoveryPets.pathLevel);
              await m.addColumn(recoveryPets, recoveryPets.pathXp);
            }
            if (from < 10) {
              await m.createTable(fellowshipSyncs);
            }
            if (from < 11) {
              await m.createTable(activeRaids);
            }
            // v12: indexes. The schema shipped with none, so every watched
            // query that filtered or ordered on a column did a full scan plus
            // a sort on tables that only grow. createIndex is idempotent in
            // Drift, so this is safe to re-run.
            if (from < 12) {
              await m.createIndex(idxJournalTs);
              await m.createIndex(idxCheckinTs);
              await m.createIndex(idxFeedStatusCreated);
              await m.createIndex(idxFeedFlag);
              await m.createIndex(idxPetEventsPetTs);
              await m.createIndex(idxSyncPeerTs);
              await m.createIndex(idxPointsTs);
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

  Stream<List<JournalEntry>> watchRecentJournals({int limit = 100}) {
    // "Recent" was in the name but there was no LIMIT — the fastest-growing
    // table in the app was fully decoded on every write.
    return (select(journalEntries)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.timestamp,
                  mode: OrderingMode.desc,
                )
          ])
          ..limit(limit))
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
    // Atomic increment in SQL. Two increments in the same frame both read
    // currentCount = 2 and both wrote 3 — one was lost, and isCompleted was
    // derived from the stale targetCount.
    await customUpdate(
      'UPDATE weekly_goals SET '
      '  current_count = MIN(current_count + ?, 1073741824), '
      '  is_completed = (current_count + ?) >= target_count '
      'WHERE id = ?',
      variables: [
        Variable.withInt(by),
        Variable.withInt(by),
        Variable.withString(id),
      ],
      updates: {weeklyGoals},
    );
    final rows =
        await (select(weeklyGoals)..where((tbl) => tbl.id.equals(id))).get();
    return rows.isEmpty ? 0 : rows.first.currentCount;
  }

  Future<int> resetAllWeeklyGoals() =>
      (update(weeklyGoals)).write(
        WeeklyGoalsCompanion(currentCount: const Value(0), isCompleted: const Value(false)),
      );

  /// Testing helper: delete all pet data (used by integration tests).
  Future<void> deleteAllPetData() async {
    await transaction(() async {
      await delete(petEvents).go();
      await delete(recoveryPets).go();
    });
  }

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

  // ---- Recovery Circle feed ----

  Future<int> addFeedPost(FeedPost post) => into(feedPosts).insert(post);

  /// Single post read, for moderation paths and tests.
  Future<FeedPost?> getFeedPost(String id) =>
      (select(feedPosts)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Rule C3: newest first. There is deliberately no sober-time field to
  /// sort by — the feed cannot become a leaderboard.
  Stream<List<FeedPost>> watchVisibleFeed() {
    return (select(feedPosts)
          ..where((t) => t.status.equals('visible'))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                )
          ]))
        .watch();
  }

  /// Rule C5: moderation queue = pending + community-flagged posts.
  Stream<List<FeedPost>> watchModerationQueue() {
    return (select(feedPosts)
          ..where((t) =>
              t.status.equals('pending') | t.flagCount.isBiggerThanValue(0))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                )
          ]))
        .watch();
  }

  Future<void> reactToPost(String postId,
      {required String kind, int by = 1}) async {
    // Throw on an unknown kind instead of silently doing nothing. The two
    // halves used to disagree: the `switch` read respectCount for anything
    // unmatched, but the Companion used strict equality and so wrote three
    // `Value.absent()` columns — an UPDATE that changed nothing, with the
    // reaction evaporating and no error. A bad `kind` also reached Firestore as
    // `'${kind}Count'`, desyncing local and cloud.
    final column = switch (kind) {
      'strength' => feedPosts.strengthCount,
      'proud' => feedPosts.proudCount,
      'respect' => feedPosts.respectCount,
      _ => throw ArgumentError.value(
          kind, 'kind', 'must be one of strength, proud, respect'),
    };
    // One SQL statement: `SET <col> = <col> + ?`. A Dart read-modify-write
    // lost concurrent reactions.
    await customUpdate(
      'UPDATE feed_posts SET ${column.name} = MIN(${column.name} + ?, 1073741824) WHERE id = ?',
      variables: [Variable.withInt(by), Variable.withString(postId)],
      updates: {feedPosts},
    );
  }

  Future<int> flagPost(String id) {
    // Increment, not assign. `flagCount: Value(1)` reset a post that 7 users
    // had reported back down to 1, destroying the moderation signal that rule
    // C5 depends on.
    return customUpdate(
      "UPDATE feed_posts SET flag_count = MIN(flag_count + 1, 1073741824), status = 'pending' WHERE id = ?",
      variables: [Variable.withString(id)],
      updates: {feedPosts},
    );
  }

  Future<int> setPostStatus(String id, String status) {
    return (update(feedPosts)..where((tbl) => tbl.id.equals(id)))
        .write(FeedPostsCompanion(status: Value(status)));
  }

  Future<int> deleteFeedPost(String id) =>
      (delete(feedPosts)..where((tbl) => tbl.id.equals(id))).go();

  /// Targeted UPDATE for a single profile column. `saveProfile` replaces every
  /// column from a snapshot the caller read earlier, so the settings screen
  /// toggling one boolean could revert a concurrent write (onboarding finishing
  /// `selectedGoals`, or the SOS service persisting `sponsorPhone`).
  Future<int> setProfileBiometricLock(String id, bool enabled) =>
      (update(profiles)..where((tbl) => tbl.id.equals(id))).write(
        ProfilesCompanion(biometricLockEnabled: Value(enabled)),
      );

  Stream<List<PetEventRow>> watchPetEvents(String petId, {int limit = 50}) {
    // LIMIT in SQL, not `.take(50)` in Dart. Callers were decoding the entire
    // ledger on every single write and throwing most of it away — and the table
    // is never pruned, so that cost grew without bound.
    return (select(petEvents)
          ..where((t) => t.petId.equals(petId))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.timestamp,
                  mode: OrderingMode.desc,
                )
          ])
          ..limit(limit))
        .watch();
  }

  Future<int> addFellowshipSync(FellowshipSync sync) =>
      into(fellowshipSyncs).insertOnConflictUpdate(sync);

  Future<List<FellowshipSync>> getAllFellowshipSyncs() =>
      select(fellowshipSyncs).get();

  Future<List<FellowshipSync>> getRecentFellowshipSyncsForPeer(String peerAlias, int sinceMs) {
    return (select(fellowshipSyncs)
          ..where((t) => t.peerAlias.equals(peerAlias) & t.timestamp.isBiggerThanValue(sinceMs)))
        .get();
  }

  Future<int> addActiveRaid(ActiveRaid raid) => into(activeRaids).insertOnConflictUpdate(raid);
  Future<List<ActiveRaid>> getAllActiveRaids() => select(activeRaids).get();
  Future<ActiveRaid?> getActiveRaidById(String id) => (select(activeRaids)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<bool> updateActiveRaid(ActiveRaid raid) => update(activeRaids).replace(raid);
  Future<int> deleteActiveRaid(String id) => (delete(activeRaids)..where((t) => t.id.equals(id))).go();
  Stream<List<ActiveRaid>> watchActiveRaids() => select(activeRaids).watch();
}

const _kDbKeyStorageKey = 'recovery_db_sqlcipher_key_v1';

String _generateKeyHex() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

LazyDatabase _openEncryptedConnection() {
  return LazyDatabase(() async {
    if (Platform.isAndroid) {
      try {
        await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions().timeout(const Duration(seconds: 4));
      } catch (_) {}
      try {
        open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
      } catch (_) {}
    }

    const storage = FlutterSecureStorage();
    String? key;
    try {
      key = await storage.read(key: _kDbKeyStorageKey).timeout(const Duration(seconds: 4));
    } catch (_) {
      key = null;
    }
    if (key == null || key.isEmpty) {
      key = _generateKeyHex();
      try {
        await storage.write(key: _kDbKeyStorageKey, value: key).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    final dbFolder = await getApplicationDocumentsDirectory().timeout(const Duration(seconds: 4));
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