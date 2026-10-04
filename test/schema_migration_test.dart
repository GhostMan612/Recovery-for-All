// ============================================================
// As Above, So Below. As Within, So Without.
// ============================================================

// Schema migration coverage for a POPULATED database.
//
// Every other test in this repo opens a fresh in-memory database, which means
// `onCreate` runs and `onUpgrade` NEVER runs. So the entire upgrade path — the
// code every existing user executes on first launch after an update — had zero
// coverage. This file closes that.
//
// The bug class is not hypothetical here: v3 -> v6 left the journal PIN
// hash/salt keys present-but-empty, which made `hasPin()` return true and locked
// real users out of their own journals. That shipped to real devices through a
// migration nobody had executed in a test.
//
// DESIGN: no hand-written v12 DDL.
//
// The obvious way to test a migration is to paste the old CREATE TABLE
// statements. That version of the test rots immediately: the hand-written schema
// is a second source of truth that stops matching the real one, and then the
// test is exercising a schema the app never had. Instead this file lets DRIFT
// build the authoritative current schema, then subtracts precisely what the
// `if (from < 13)` block adds. The subtraction is the exact inverse of the
// migration, so the two cannot silently disagree: if someone adds a column to
// the v13 block, these DROPs stop matching and the test fails loudly rather
// than passing against a fiction.
//
// This also means v12 is the correct thing to test. v13 is the version that just
// shipped, so v12 is what essentially every real install is sitting on right now.

import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/database/recovery_database.dart';

/// Builds a database that is byte-for-byte v12 with realistic rows in it, and
/// hands back the file. The caller reopens it with [RecoveryDatabase], which is
/// what triggers the real `onUpgrade(12 -> 13)`.
Future<File> _seedPopulatedV12() async {
  final dir = await Directory.systemTemp.createTemp('rf_migration_');
  final file = File('${dir.path}${Platform.pathSeparator}recovery.db');

  final seed = RecoveryDatabase.forTesting(
      NativeDatabase(file) as QueryExecutor);
  // drift 2.31.0's GeneratedDatabase has no `isClosed`, so track it ourselves
  // rather than guessing at close() idempotency.
  var seedClosed = false;
  addTearDown(() async {
    if (!seedClosed) {
      try {
        await seed.close();
      } on Object {
        // Already failing; a close error must not mask the real one.
      }
    }
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows can hold a handle briefly; a leaked temp dir is not a test
        // failure and must never turn a green test red.
      }
    }
  });

  // Force the connection open so `onCreate` runs and the authoritative v13
  // schema exists.
  await seed.customStatement('SELECT 1');

  // --- Roll back to exactly v12 -------------------------------------------------
  // Inverse of `if (from < 13)` in recovery_database.dart, in reverse order
  // because `peer_key_b64` is indexed.
  await seed.customStatement('DROP INDEX IF EXISTS idx_sync_key_ts');
  await seed.customStatement('ALTER TABLE fellowship_syncs DROP COLUMN role');
  await seed
      .customStatement('ALTER TABLE fellowship_syncs DROP COLUMN attested');
  await seed.customStatement(
      'ALTER TABLE fellowship_syncs DROP COLUMN peer_key_b64');

  // --- Populate it the way a real install would ---------------------------------
  // Two pre-attestation handshakes. These are the rows that make XP farmable if
  // the migration breaks them.
  await seed.customStatement(
    "INSERT INTO fellowship_syncs (id, peer_alias, timestamp, xp_awarded) "
    "VALUES ('old-1', 'BrightOak', 1700000000000, 50)",
  );
  await seed.customStatement(
    "INSERT INTO fellowship_syncs (id, peer_alias, timestamp, xp_awarded) "
    "VALUES ('old-2', 'MapleAsh', 1700000500000, 50)",
  );

  // Unrelated user data. The migration runs `PRAGMA foreign_keys = OFF` inside a
  // transaction; if anything in that path is destructive, THIS is what a user
  // loses. Losing a journal is unrecoverable.
  await seed.customStatement(
    "INSERT INTO profiles (id, created_at, selected_goals, active_paths) "
    "VALUES ('me', 1690000000000, '[\"quit\"]', '[\"aa\"]')",
  );
  await seed.customStatement(
    "INSERT INTO journal_entries (id, timestamp, mood_rating, content_encrypted) "
    "VALUES ('j-1', 1690000001000, 3, 'CIPHER-TEXT-THAT-MUST-NOT-BE-TOUCHED')",
  );
  await seed.customStatement(
    "INSERT INTO counters (id, label, start_date_time) "
    "VALUES ('c-1', 'Clean Time', 1690000002000)",
  );

  // The one line that turns a v13 database into a v12 database. Drift reads the
  // version from `PRAGMA user_version`, exactly as it will on a real upgrade.
  await seed.customStatement('PRAGMA user_version = 12');
  seedClosed = true;
  await seed.close();

  return file;
}

/// Builds a database that is byte-for-byte **v1** with realistic rows in it.
///
/// This is the exact inverse of all twelve `if (from < N)` blocks, applied in
/// reverse dependency order:
///
///   DROP INDEX  every one of the eight (v12 adds seven, v13 adds one)
///   DROP TABLE  the seven the migration creates
///               (v2 weekly_goals, v3 wellness_check_ins, v5 recovery_pets +
///                pet_events, v7 feed_posts, v10 fellowship_syncs,
///                v11 active_raids)
///   DROP COLUMN profiles.selected_values   (v2)
///                 profiles.sponsor_phone   (v4)
///                 profiles.custom_help_phone(v4)
///                 profiles.personality_json(v6)
///                 counters.daily_cost       (v8)
///
/// What is left is the v1 schema: profiles, counters, journal_entries and
/// constellation_points. If a thirteenth block is added without updating this
/// function, the test stops exercising v1 and the DROPs stop being an inverse —
/// which is the same "second source of truth" trap the v12 seeder avoids, one
/// level up.
Future<File> _seedPopulatedV1() async {
  final dir = await Directory.systemTemp.createTemp('rf_migration_v1_');
  final file = File('${dir.path}${Platform.pathSeparator}recovery.db');

  final seed = RecoveryDatabase.forTesting(
      NativeDatabase(file) as QueryExecutor);
  var seedClosed = false;
  addTearDown(() async {
    if (!seedClosed) {
      try {
        await seed.close();
      } on Object {
        // Already failing; a close error must not mask the real one.
      }
    }
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows can hold a handle briefly; a leaked temp dir is not a test
        // failure and must never turn a green test red.
      }
    }
  });

  await seed.customStatement('SELECT 1');

  // Indexes first: they belong to tables that are about to be dropped.
  for (final i in const [
    'idx_sync_key_ts',
    'idx_sync_peer_ts',
    'idx_points_ts',
    'idx_journal_ts',
    'idx_checkin_ts',
    'idx_feed_status_created',
    'idx_feed_flag',
    'idx_pet_events_pet_ts',
  ]) {
    await seed.customStatement('DROP INDEX IF EXISTS $i');
  }

  // Tables the migration is responsible for creating.
  for (final t in const [
    'active_raids',
    'fellowship_syncs',
    'feed_posts',
    'pet_events',
    'recovery_pets',
    'wellness_check_ins',
    'weekly_goals',
  ]) {
    await seed.customStatement('DROP TABLE IF EXISTS $t');
  }

  // Columns added to tables that DID exist at v1. Dropping the whole table
  // instead would throw away the rows, and the rows are the entire point.
  await seed
      .customStatement('ALTER TABLE profiles DROP COLUMN personality_json');
  await seed
      .customStatement('ALTER TABLE profiles DROP COLUMN custom_help_phone');
  await seed
      .customStatement('ALTER TABLE profiles DROP COLUMN sponsor_phone');
  await seed
      .customStatement('ALTER TABLE profiles DROP COLUMN selected_values');
  await seed.customStatement('ALTER TABLE counters DROP COLUMN daily_cost');

  // --- Populate it the way a first-release install would -----------------------
  // One row in each of the four tables that existed at v1.
  await seed.customStatement(
    "INSERT INTO profiles (id, created_at, selected_goals, active_paths) "
    "VALUES ('me', 1690000000000, '[\"quit\"]', '[\"aa\"]')",
  );
  await seed.customStatement(
    "INSERT INTO journal_entries (id, timestamp, mood_rating, content_encrypted) "
    "VALUES ('j-1', 1690000001000, 3, 'CIPHER-TEXT-THAT-MUST-NOT-BE-TOUCHED')",
  );
  await seed.customStatement(
    "INSERT INTO counters (id, label, start_date_time) "
    "VALUES ('c-1', 'Clean Time', 1690000002000)",
  );
  await seed.customStatement(
    "INSERT INTO constellation_points "
    "(id, title, category, timestamp, position_x, position_y) "
    "VALUES ('cp-1', 'First Step', 'milestone', 1690000003000, 0.5, 0.5)",
  );

  await seed.customStatement('PRAGMA user_version = 1');
  seedClosed = true;
  await seed.close();

  return file;
}

Future<Set<String>> _indexesOn(RecoveryDatabase db, String table) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=?",
        variables: [Variable<String>(table)],
      )
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v12 -> v13 migration on a populated database', () {
    late File file;
    late RecoveryDatabase db;
    var dbClosed = false;

    setUp(() async {
      file = await _seedPopulatedV12();
      // This open is what runs onUpgrade. If the migration is wrong, it throws
      // here and every test in the group fails, which is the point.
      db = RecoveryDatabase.forTesting(NativeDatabase(file) as QueryExecutor);
      dbClosed = false;
    });

    tearDown(() async {
      if (!dbClosed) await db.close();
      final dir = file.parent;
      if (dir.existsSync()) {
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // See note in _seedPopulatedV12.
        }
      }
    });

    /// Raw scalar SELECT. Several of these tables have no read helper at all
    /// (`getAllCounters` is a Stream, and there is no `getJournalEntry`), and
    /// going through SQL here also means the test does not depend on a
    /// convenience method it is meant to be validating.
    Future<int> countRows(String table) async {
      final r = await db
          .customSelect('SELECT COUNT(*) AS n FROM $table')
          .getSingle();
      return r.read<int>('n');
    }

    test('lands on schema version 13', () async {
      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.data['user_version'], 13);
      expect(db.schemaVersion, 13);
    });

    test('keeps every pre-existing row — no data loss', () async {
      final syncs = await db.getAllFellowshipSyncs();
      expect(syncs, hasLength(2),
          reason: 'a migration that dropped fellowship_syncs rows would let a '
              'user bank the 24h reward repeatedly');

      expect(await countRows('profiles'), 1,
          reason: 'profiles is unrelated to v13 and must be untouched');
      expect(await countRows('journal_entries'), 1,
          reason: 'journal entries are the irreplaceable data in this app');
      expect(await countRows('counters'), 1);
      expect(await countRows('constellation_points'), 0);
    });

    test('journal ciphertext is byte-identical after migrating', () async {
      // A migration that "helpfully" rewrote, re-encoded or truncated the
      // encrypted payload would make the entry undecryptable while still
      // looking present. Assert the exact stored value.
      final row = await db
          .customSelect(
            'SELECT content_encrypted FROM journal_entries WHERE id = ?',
            variables: [Variable<String>('j-1')],
          )
          .getSingle();
      expect(row.read<String>('content_encrypted'),
          'CIPHER-TEXT-THAT-MUST-NOT-BE-TOUCHED');
    });

    test('pre-attestation rows read back as unattested, not as garbage',
        () async {
      final syncs = await db.getAllFellowshipSyncs();
      for (final s in syncs) {
        expect(s.peerKeyB64, isNull,
            reason: 'a pre-protocol row has no key; SQLite must backfill NULL, '
                'not the empty string, or the key cooldown will match on ""');
        expect(s.attested, 0,
            reason: 'attested is declared with a default of 0 precisely so '
                'these rows stay readable instead of failing NOT NULL');
        expect(s.role, isNull);
      }
      // And the original values are still intact alongside the new ones.
      expect(syncs.first.peerAlias, 'BrightOak');
      expect(syncs.first.xpAwarded, 50);
    });

    test('adds the v13 columns', () async {
      final cols = await db
          .customSelect("SELECT name FROM pragma_table_info('fellowship_syncs')")
          .get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(names, containsAll(<String>{
        'peer_key_b64',
        'attested',
        'role',
      }));
    });

    test('adds the (peer_key_b64, timestamp) index', () async {
      expect(await _indexesOn(db, 'fellowship_syncs'),
          contains('idx_sync_key_ts'));
    });

    test('does NOT drop the v12 (peer_alias, timestamp) index', () async {
      // The alias lookup is deliberately RETAINED alongside the key lookup so a
      // user who synced under the old protocol still cannot bank a second
      // grant. If this index were dropped the query would still work but scan
      // the table — and a migration that removes a v12 index is a regression
      // hiding behind a passing test.
      expect(await _indexesOn(db, 'fellowship_syncs'),
          contains('idx_sync_peer_ts'));
    });

    test('a migrated row can carry a peer key, and the key cooldown finds it',
        () async {
      // The new column existing is not enough — it has to be USABLE, or the
      // cooldown silently stops applying to everyone.
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.addFellowshipSync(FellowshipSync(
        id: 'new-1',
        peerAlias: 'BrightOak',
        timestamp: now,
        xpAwarded: 50,
        peerKeyB64: 'PEER-PUBLIC-KEY-B64',
        attested: 1,
        role: 'inviter',
      ));

      final byKey = await db.getRecentFellowshipSyncsForPeerKey(
          'PEER-PUBLIC-KEY-B64', now - 60000);
      expect(byKey.map((r) => r.id), contains('new-1'));
      expect(byKey.single.attested, 1);
      expect(byKey.single.role, 'inviter');
    });

    test('the key cooldown does NOT match keyless legacy rows', () async {
      // By design: legacy rows have no key, so they are invisible here. That is
      // exactly WHY the alias lookup is still called alongside it — asserted in
      // the next test. If this ever starts matching, someone has "fixed" it by
      // treating NULL as a key.
      final byKey = await db.getRecentFellowshipSyncsForPeerKey(
          'PEER-PUBLIC-KEY-B64', 0);
      expect(byKey, isEmpty);
    });

    test('the retained ALIAS cooldown still blocks a pre-protocol peer',
        () async {
      // This is the anti-double-banking property. If migrating a v12 database
      // broke the legacy alias lookup, a user who synced yesterday could bank a
      // second +50 XP today and the cooldown would be gone.
      final byAlias = await db.getRecentFellowshipSyncsForPeer('BrightOak', 0);
      expect(byAlias.map((r) => r.id), contains('old-1'));
    });

    test('re-opening an already-migrated database is a no-op', () async {
      await db.close();
      dbClosed = true;
      // Drift must not re-run onUpgrade: `createIndex`/`addColumn` would throw
      // or duplicate on a second pass. Real installs reopen the database on
      // every single cold start, so an unstable migration would be fatal.
      final reopened = RecoveryDatabase.forTesting(
          NativeDatabase(file) as QueryExecutor);
      addTearDown(() async {
        try {
          await reopened.close();
        } on Object {
          // Best effort; the assertion below is what matters.
        }
      });
      expect(await reopened.getAllFellowshipSyncs(), hasLength(2));
      final v = await reopened.customSelect('PRAGMA user_version').getSingle();
      expect(v.data['user_version'], 13);
    });
  });

  // ---------------------------------------------------------------------------
  // The v12 group above is the path almost every current install takes. This
  // group is the OTHER end of it: a v1 database, which is a first-release
  // install, upgraded all the way to v13 in one launch.
  //
  // Why this matters even though v12 is more common: `onUpgrade` is ONE function
  // containing TWELVE `if (from < N)` blocks. The v12 test proves the last one.
  // A defect in any of the other eleven — a wrong column name, a table that is
  // created in the wrong order relative to something that reads it, a
  // non-nullable column added without a default onto a table that already has
  // rows — is invisible to every other test in this repo, because every other
  // test creates a fresh database and only ever runs `onCreate`.
  //
  // The users on v1 are also exactly the users most likely to hit it: they have
  // upgraded the most times, so they traverse the most blocks.
  // ---------------------------------------------------------------------------
  group('v1 -> v13 migration on a populated database (all twelve blocks)',
      () {
    late File file;
    late RecoveryDatabase db;
    var dbClosed = false;

    setUp(() async {
      file = await _seedPopulatedV1();
      db = RecoveryDatabase.forTesting(NativeDatabase(file) as QueryExecutor);
      dbClosed = false;
    });

    tearDown(() async {
      if (!dbClosed) await db.close();
      final dir = file.parent;
      if (dir.existsSync()) {
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // See note in _seedPopulatedV1.
        }
      }
    });

    Future<int> countRows(String table) async {
      final r = await db
          .customSelect('SELECT COUNT(*) AS n FROM $table')
          .getSingle();
      return r.read<int>('n');
    }

    Future<List<Map<String, Object?>>> rowsOf(String table) async {
      final rs = await db.customSelect('SELECT * FROM $table').get();
      return rs.map((r) => r.data).toList();
    }

    test('runs every block and lands on schema version 13', () async {
      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.data['user_version'], 13,
          reason: 'a v1 install must traverse all twelve `if (from < N)` blocks');
    });

    test('the four tables that existed at v1 survive with their rows', () async {
      expect(await countRows('profiles'), 1);
      expect(await countRows('journal_entries'), 1);
      expect(await countRows('counters'), 1);
      expect(await countRows('constellation_points'), 1);
    });

    test('the v1 NOT NULL text columns are still readable afterwards', () async {
      // These have no default, so an `addColumn` on them would either fail the
      // migration outright or invent a value. A user with a saved goal list must
      // still have it.
      final profile = (await rowsOf('profiles')).single;
      expect(profile['selected_goals'], '["quit"]');
      expect(profile['active_paths'], '["aa"]');
    });

    test('journal ciphertext is byte-identical after eleven migrations',
        () async {
      final entry = (await rowsOf('journal_entries')).single;
      expect(entry['content_encrypted'], 'CIPHER-TEXT-THAT-MUST-NOT-BE-TOUCHED');
      expect(entry['mood_rating'], 3);
      expect(entry['timestamp'], 1690000001000);
    });

    test('every table the migration creates exists afterwards', () async {
      // created by v2, v3, v5 (x2), v7, v10, v11
      for (final t in const [
        'weekly_goals',
        'wellness_check_ins',
        'recovery_pets',
        'pet_events',
        'feed_posts',
        'fellowship_syncs',
        'active_raids',
      ]) {
        expect(await countRows(t), 0,
            reason: '$t did not exist at v1; the migration must create it');
      }
    });

    test('every index is created — v12\'s seven AND v13\'s one', () async {
      // The v12 block is the one that adds indexes; reaching it from v1 means
      // also creating fellowship_syncs first (v10). If a block were reordered or
      // an index referenced a table that did not exist yet, this is where it
      // would fail.
      for (final i in const [
        'idx_journal_ts',
        'idx_checkin_ts',
        'idx_feed_status_created',
        'idx_feed_flag',
        'idx_pet_events_pet_ts',
        'idx_sync_peer_ts',
        'idx_points_ts',
        'idx_sync_key_ts',
      ]) {
        final rows = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' AND name=?",
              variables: [Variable<String>(i)],
            )
            .get();
        expect(rows, hasLength(1), reason: 'missing index $i');
      }
    });

    test('columns added without a default come back null, not as garbage',
        () async {
      // The exact v3 -> v6 shape: a nullable column added onto a table that
      // already has rows. It must read null. If it read as an empty string or a
      // zero, some caller would treat "has a value" as true and act on it.
      final profile = (await rowsOf('profiles')).single;
      expect(profile.containsKey('selected_values'), isTrue);
      expect(profile['selected_values'], isNull);
      expect(profile['sponsor_phone'], isNull);
      expect(profile['custom_help_phone'], isNull);
      expect(profile['personality_json'], isNull);
    });

    test('the one column added WITH a default is backfilled, not null', () async {
      // SQLite backfills the declared default on ADD COLUMN, which is what makes
      // this safe on a device holding real rows: without it, adding
      // `daily_cost` to a table that already has rows would either fail or leave
      // NULL, and every clean-time calculation would then read null.
      //
      // Only `counters.daily_cost` is genuinely ADDED by a migration block.
      // `journal_entries.is_synced_to_cloud` and
      // `profiles.biometric_lock_enabled` also default, but no `if (from < N)`
      // block adds them — they existed at v1, so their values were written by
      // the INSERT above, not by the migration. They are pinned below only so a
      // future schema edit that changes a default is noticed.
      final counter = (await rowsOf('counters')).single;
      expect(counter['daily_cost'], 0.0,
          reason: 'counters.daily_cost is added at v8 with default 0.0');

      final entry = (await rowsOf('journal_entries')).single;
      expect(entry['is_synced_to_cloud'], 0);

      final profile = (await rowsOf('profiles')).single;
      expect(profile['biometric_lock_enabled'], 0);
    });

    test('the migrated pet table is WRITABLE, not merely present', () async {
      // The end-to-end point of the whole exercise: after eleven migrations the
      // tables are not just present, they accept what the real code writes.
      // recovery_pets did not exist at v1 (v5 creates it) and gained three
      // columns at v9, so it is the table most exposed to a create-then-alter
      // ordering mistake — and `equipped_slots_json`/`path_level`/`path_xp` are
      // NOT NULL, so an alter that failed to backfill turns every later write
      // into a constraint violation rather than a visible error at migration
      // time.
      final now = 1690000009000;
      await db.upsertPet(RecoveryPetRow(
        id: 'active_pet',
        name: 'Ash',
        speciesOrStyle: 'wolf',
        energy: 100,
        bond: 12,
        mood: 'content',
        sparks: 40,
        unlockedItems: '[]',
        equippedOutfit: '[]',
        lastFedAt: now,
        createdAt: now,
        equippedSlotsJson: '[]',
        pathLevel: 1,
        pathXp: 0,
      ));
      final row = await db.getPet('active_pet');
      expect(row, isNotNull);
      expect(row!.sparks, 40);
      expect(row.pathLevel, 1);
      expect(await countRows('recovery_pets'), 1);
    });

    test('re-opening after the eleven-block migration is a no-op', () async {
      await db.close();
      dbClosed = true;
      final reopened = RecoveryDatabase.forTesting(
          NativeDatabase(file) as QueryExecutor);
      addTearDown(() async {
        try {
          await reopened.close();
        } on Object {
          // Best effort; the assertion below is what matters.
        }
      });
      final v = await reopened.customSelect('PRAGMA user_version').getSingle();
      expect(v.data['user_version'], 13);
      expect(await countRowsOf(reopened, 'profiles'), 1);
    });
  });
}

/// `countRows` needs a database handle, and the reopen test holds a second one.
Future<int> countRowsOf(RecoveryDatabase db, String table) async {
  final r =
      await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle();
  return r.read<int>('n');
}