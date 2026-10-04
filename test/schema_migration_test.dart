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
}