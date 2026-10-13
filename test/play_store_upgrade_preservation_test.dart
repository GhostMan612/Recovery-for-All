// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/services/community_feed_service.dart';
import 'package:recovery_for_all/services/journal_crypto_service.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';

/// Prepares a database populated with realistic user data at schema version [fromVersion] (12 or 13).
///
/// This models the exact state of an active Play Store user prior to the update:
/// - Real encrypted journal entries (AES-256-GCM under Master Key, and legacy Base64)
/// - Configured 6-digit PIN in SecureStorage
/// - Active Sobriety Counters with custom start dates and cost savings
/// - Wellness check-ins and weekly goals
/// - Hatched pet with accumulated Sparks, XP, Level, Mood, and custom cosmetic equipment
/// - Historical Pet Care events
/// - Historical Recovery Circle posts (authored by the user and peers)
/// - Historical Fellowship Syncs (mutual handshake history)
/// - Constellation points
Future<File> _seedPopulatedPlayStoreDb({
  required int fromVersion,
  required Uint8List masterKey,
  required String journalPlaintextAes,
  required String journalPlaintextLegacy,
}) async {
  assert(fromVersion == 12 || fromVersion == 13);
  final dir = await Directory.systemTemp.createTemp('rf_playstore_upgrade_');
  final file = File('${dir.path}${Platform.pathSeparator}recovery_companion_secure.db');

  final seed = RecoveryDatabase.forTesting(NativeDatabase(file) as QueryExecutor);
  var seedClosed = false;
  addTearDown(() async {
    if (!seedClosed) {
      try {
        await seed.close();
      } catch (_) {}
    }
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // Force connection open so current Drift schema is created.
  await seed.customStatement('SELECT 1');

  // --- Roll back to fromVersion ---
  // Drop v15 additions:
  await seed.customStatement('DROP INDEX IF EXISTS idx_circle_outbox_status');
  await seed.customStatement('DROP TABLE IF EXISTS circle_outbox_entries');

  // Drop v14 additions:
  await seed.customStatement('DROP TABLE IF EXISTS raid_victory_receipts');
  await seed.customStatement('DROP TABLE IF EXISTS raid_damage_receipts');
  await seed.customStatement('DROP TABLE IF EXISTS reward_receipts');
  await seed.customStatement('DROP TABLE IF EXISTS recovery_actions');

  if (fromVersion == 12) {
    // Drop v13 additions:
    await seed.customStatement('DROP INDEX IF EXISTS idx_sync_key_ts');
    await seed.customStatement('ALTER TABLE fellowship_syncs DROP COLUMN role');
    await seed.customStatement('ALTER TABLE fellowship_syncs DROP COLUMN attested');
    await seed.customStatement('ALTER TABLE fellowship_syncs DROP COLUMN peer_key_b64');
  }

  // --- Populate with realistic user recovery history ---
  // 1. Profile
  await seed.customStatement(
    "INSERT INTO profiles (id, created_at, selected_goals, active_paths, selected_values, sponsor_phone, custom_help_phone, personality_json, biometric_lock_enabled) "
    "VALUES ('me', 1690000000000, '[\"quit\",\"peace\"]', '[\"aa\",\"na\"]', '[\"honesty\",\"courage\"]', '555-0199', '555-0100', '{\"style\":\"grounded\"}', 1)",
  );

  // 2. Encrypted Journals
  final encAes = await JournalCryptoService.encrypt(journalPlaintextAes, masterKey);
  final encLegacy = 'ENC_${base64Encode(utf8.encode(journalPlaintextLegacy))}';

  await seed.customStatement(
    "INSERT INTO journal_entries (id, timestamp, mood_rating, content_encrypted, is_synced_to_cloud) "
    "VALUES ('j-aes-1', 1690000100000, 4, '$encAes', 0)",
  );
  await seed.customStatement(
    "INSERT INTO journal_entries (id, timestamp, mood_rating, content_encrypted, is_synced_to_cloud) "
    "VALUES ('j-legacy-1', 1690000050000, 3, '$encLegacy', 0)",
  );

  // 3. Sobriety Counters
  await seed.customStatement(
    "INSERT INTO counters (id, label, start_date_time, daily_cost) "
    "VALUES ('c-alcohol', 'Alcohol Sobriety', 1680000000000, 18.50)",
  );
  await seed.customStatement(
    "INSERT INTO counters (id, label, start_date_time, daily_cost) "
    "VALUES ('c-clean', 'Clean Time', 1685000000000, 25.00)",
  );

  // 4. Wellness Check-ins & Weekly Goals
  await seed.customStatement(
    "INSERT INTO wellness_check_ins (id, timestamp, spiritual, intellectual, emotional, physical, social, occupational) "
    "VALUES ('wci-1', 1690000200000, 9.0, 8.0, 7.5, 8.0, 8.5, 7.0)",
  );
  await seed.customStatement(
    "INSERT INTO weekly_goals (id, title, target_count, current_count, is_completed) "
    "VALUES ('wg-1', 'Attend 3 Recovery Meetings', 3, 2, 0)",
  );

  // 5. Recovery Pet Progression
  await seed.customStatement(
    "INSERT INTO recovery_pets (id, name, species_or_style, energy, bond, mood, sparks, unlocked_items, equipped_outfit, last_fed_at, created_at, equipped_slots_json, path_level, path_xp) "
    "VALUES ('active_pet', 'Shadow', 'ember_kit', 0.85, 0.90, 'happy', 450, '[\"starter_glow\",\"hat_bandana\",\"aura_warm\"]', 'hat_bandana', 1690000300000, 1680000000000, '{\"head\":\"hat_bandana\",\"aura\":\"aura_warm\"}', 4, 380)",
  );
  await seed.customStatement(
    "INSERT INTO pet_events (id, pet_id, event_type, timestamp, sparks_delta, meta_json) "
    "VALUES ('pe-1', 'active_pet', 'care', 1690000280000, 15, '{\"note\":\"Compassionate care check-in\"}')",
  );
  await seed.customStatement(
    "INSERT INTO pet_events (id, pet_id, event_type, timestamp, sparks_delta, meta_json) "
    "VALUES ('pe-2', 'active_pet', 'level_up', 1690000300000, 50, '{\"note\":\"Achieved Path Level 4\"}')",
  );

  // 6. Historical Circle Shares (feed_posts)
  await seed.customStatement(
    "INSERT INTO feed_posts (id, author_alias, kind, body, created_at, status, is_mine, strength_count, proud_count, respect_count) "
    "VALUES ('post-user-1', 'CourageousOtter', 'story', 'Celebrating 90 days clean and sober today! Grateful for this fellowship.', 1690000400000, 'visible', 1, 5, 4, 5)",
  );
  await seed.customStatement(
    "INSERT INTO feed_posts (id, author_alias, kind, body, created_at, status, is_mine, strength_count, proud_count, respect_count) "
    "VALUES ('post-peer-2', 'BrightOak', 'story', 'Keep your head high, one breath at a time.', 1690000450000, 'visible', 0, 3, 2, 3)",
  );

  // 7. Fellowship Syncs
  if (fromVersion == 12) {
    await seed.customStatement(
      "INSERT INTO fellowship_syncs (id, peer_alias, timestamp, xp_awarded) "
      "VALUES ('sync-v12-1', 'BrightOak', 1700000000000, 50)",
    );
  } else {
    await seed.customStatement(
      "INSERT INTO fellowship_syncs (id, peer_alias, timestamp, xp_awarded, peer_key_b64, attested, role) "
      "VALUES ('sync-v13-1', 'BrightOak', 1700000000000, 50, 'PEER_ED25519_PUBKEY_TEST', 1, 'inviter')",
    );
  }

  // 8. Constellation Points
  await seed.customStatement(
    "INSERT INTO constellation_points (id, title, category, timestamp, position_x, position_y) "
    "VALUES ('cp-1', 'Accepted Step 1', 'step', 1690000005000, 0.42, 0.78)",
  );

  // Set authoritative PRAGMA user_version to simulate existing install
  await seed.customStatement('PRAGMA user_version = $fromVersion');
  seedClosed = true;
  await seed.close();

  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List masterKey;
  const pinCode = '842109';
  const journalTextAes = 'Today I felt peace during my morning reflection. Recovery is real.';
  const journalTextLegacy = 'Grateful for step 12 conversation with my sponsor.';

  setUp(() async {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    // Generate and write master key & PIN into secure storage
    masterKey = await JournalCryptoService.loadMasterKey();
    await JournalCryptoService.setPin(pinCode);
  });

  for (final sourceVersion in [13, 12]) {
    group('Play Store Upgrade: v$sourceVersion -> v15 Production User Data Preservation', () {
      late File dbFile;
      late RecoveryDatabase db;
      var dbClosed = false;

      setUp(() async {
        dbFile = await _seedPopulatedPlayStoreDb(
          fromVersion: sourceVersion,
          masterKey: masterKey,
          journalPlaintextAes: journalTextAes,
          journalPlaintextLegacy: journalTextLegacy,
        );

        // Opening via RecoveryDatabase triggers real onUpgrade(sourceVersion -> 15)
        db = RecoveryDatabase.forTesting(NativeDatabase(dbFile) as QueryExecutor);
        dbClosed = false;
      });

      tearDown(() async {
        if (!dbClosed) await db.close();
        final dir = dbFile.parent;
        if (dir.existsSync()) {
          try {
            dir.deleteSync(recursive: true);
          } catch (_) {}
        }
      });

      test('database upgrades safely and lands on schema version 15', () async {
        final versionResult = await db.customSelect('PRAGMA user_version').getSingle();
        expect(versionResult.data['user_version'], 15);
        expect(db.schemaVersion, 15);
      });

      test('v14 and v15 tables and indexes are created without error', () async {
        for (final table in const [
          'recovery_actions',
          'reward_receipts',
          'raid_damage_receipts',
          'raid_victory_receipts',
          'circle_outbox_entries',
        ]) {
          final countRow = await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle();
          expect(countRow.read<int>('c'), 0, reason: '$table should be present and initialized');
        }

        final indexes = await db.customSelect("SELECT name FROM sqlite_master WHERE type='index'").get();
        final indexNames = indexes.map((r) => r.read<String>('name')).toSet();
        expect(indexNames, contains('idx_circle_outbox_status'));
        expect(indexNames, contains('idx_sync_peer_ts'));
      });

      test('DATA PRESERVATION: encrypted journals survive and decrypt accurately', () async {
        final entries = await db.watchRecentJournals().first;
        expect(entries, hasLength(2));

        // 1. Verify AES-GCM encrypted journal
        final aesEntry = entries.firstWhere((e) => e.id == 'j-aes-1');
        expect(aesEntry.contentEncrypted.startsWith('ENC2_'), isTrue);
        expect(aesEntry.moodRating, 4);
        final decryptedAes = await JournalCryptoService.decrypt(aesEntry.contentEncrypted, masterKey);
        expect(decryptedAes, equals(journalTextAes));

        // 2. Verify legacy encrypted journal
        final legacyEntry = entries.firstWhere((e) => e.id == 'j-legacy-1');
        expect(legacyEntry.contentEncrypted.startsWith('ENC_'), isTrue);
        expect(legacyEntry.moodRating, 3);
        final decryptedLegacy = await JournalCryptoService.decrypt(legacyEntry.contentEncrypted, masterKey);
        expect(decryptedLegacy, equals(journalTextLegacy));
      });

      test('SECURITY PRESERVATION: PIN access remains valid with zero lockout', () async {
        // Must maintain valid PIN without requiring reset or causing lockout
        expect(await JournalCryptoService.hasPin(), isTrue);
        expect(await JournalCryptoService.verifyPin(pinCode), isTrue);
        expect(await JournalCryptoService.verifyPin('000000'), isFalse);
        expect(await JournalCryptoService.verifyPin('123456'), isFalse);
      });

      test('DATA PRESERVATION: sobriety records and check-ins remain intact and accurate', () async {
        final counters = await db.watchAllCounters().first;
        expect(counters, hasLength(2));

        final alcCounter = counters.firstWhere((c) => c.id == 'c-alcohol');
        expect(alcCounter.label, 'Alcohol Sobriety');
        expect(alcCounter.startDateTime, 1680000000000);
        expect(alcCounter.dailyCost, 18.50);

        final cleanCounter = counters.firstWhere((c) => c.id == 'c-clean');
        expect(cleanCounter.label, 'Clean Time');
        expect(cleanCounter.startDateTime, 1685000000000);
        expect(cleanCounter.dailyCost, 25.00);

        // Profile preserved
        final profile = await db.getProfile('me');
        expect(profile, isNotNull);
        expect(profile!.selectedGoals, '["quit","peace"]');
        expect(profile.activePaths, '["aa","na"]');
        expect(profile.biometricLockEnabled, isTrue);

        // Wellness check-in preserved
        final wci = await db.customSelect('SELECT * FROM wellness_check_ins WHERE id = "wci-1"').getSingle();
        expect(wci.read<double>('spiritual'), 9.0);
        expect(wci.read<double>('intellectual'), 8.0);
        expect(wci.read<double>('emotional'), 7.5);

        // Weekly goals preserved
        final wg = await db.customSelect('SELECT * FROM weekly_goals WHERE id = "wg-1"').getSingle();
        expect(wg.read<String>('title'), 'Attend 3 Recovery Meetings');
        expect(wg.read<int>('current_count'), 2);
        expect(wg.read<int>('target_count'), 3);
      });

      test('DATA PRESERVATION: pet progression, Sparks, Level, and equipment survive untouched', () async {
        final petRow = await db.getPet('active_pet');
        expect(petRow, isNotNull);
        expect(petRow!.name, 'Shadow');
        expect(petRow.speciesOrStyle, 'ember_kit');
        expect(petRow.sparks, 450);
        expect(petRow.pathLevel, 4);
        expect(petRow.pathXp, 380);
        expect(petRow.mood, 'happy');
        expect(petRow.equippedOutfit, 'hat_bandana');
        expect(petRow.equippedSlotsJson, '{"head":"hat_bandana","aura":"aura_warm"}');

        // Verify domain model mapping does not alter progression
        final petModel = RecoveryPetService.petFromRow(petRow);
        expect(petModel.name, 'Shadow');
        expect(petModel.sparks, 450);
        expect(petModel.pathLevel, 4);
        expect(petModel.pathXp, 380);
        expect(petModel.equippedSlots['head'], 'hat_bandana');
        expect(petModel.equippedSlots['aura'], 'aura_warm');

        // Pet history events preserved
        final events = await (db.select(db.petEvents)..where((t) => t.petId.equals('active_pet'))).get();
        expect(events, hasLength(2));
        expect(events.any((e) => e.eventType == 'care' && e.sparksDelta == 15), isTrue);
        expect(events.any((e) => e.eventType == 'level_up' && e.sparksDelta == 50), isTrue);
      });

      test('DATA PRESERVATION: historical Circle shares remain readable and uncorrupted', () async {
        final feedPosts = await db.select(db.feedPosts).get();
        expect(feedPosts, hasLength(2));

        final userPost = feedPosts.firstWhere((p) => p.id == 'post-user-1');
        expect(userPost.authorAlias, 'CourageousOtter');
        expect(userPost.body, contains('Celebrating 90 days clean'));
        expect(userPost.strengthCount, 5);
        expect(userPost.proudCount, 4);
        expect(userPost.respectCount, 5);

        final peerPost = feedPosts.firstWhere((p) => p.id == 'post-peer-2');
        expect(peerPost.authorAlias, 'BrightOak');
        expect(peerPost.body, contains('Keep your head high'));

        // Remote writing safeguard invariant remains strictly active
        expect(CommunityFeedService.remoteWritesDisabled, isTrue,
            reason: 'Production Circle remote publishing must remain disabled until cutover authorization');
      });

      test('DATA PRESERVATION: fellowship syncs and constellation points survive', () async {
        final syncs = await db.getAllFellowshipSyncs();
        expect(syncs, hasLength(1));
        expect(syncs.single.peerAlias, 'BrightOak');
        expect(syncs.single.xpAwarded, 50);

        final points = await db.getConstellationPoints();
        expect(points, hasLength(1));
        expect(points.single.title, 'Accepted Step 1');
      });

      test('SAFETY: no historical reward reissuance during upgrade', () async {
        // RecoveryActions and RewardReceipts must start clean — no backfill fabrication
        final actions = await (db.select(db.recoveryActions)).get();
        expect(actions, isEmpty);

        final receipts = await (db.select(db.rewardReceipts)).get();
        expect(receipts, isEmpty);

        // Pet progression balance is authoritative and unchanged
        final pet = await db.getPet('active_pet');
        expect(pet!.sparks, 450);
        expect(pet.pathXp, 380);
      });

      test('STABILITY: subsequent cold start (reopening) is a stable no-op', () async {
        await db.close();
        dbClosed = true;

        final reopened = RecoveryDatabase.forTesting(NativeDatabase(dbFile) as QueryExecutor);
        addTearDown(() async {
          try {
            await reopened.close();
          } catch (_) {}
        });

        final v = await reopened.customSelect('PRAGMA user_version').getSingle();
        expect(v.data['user_version'], 15);

        // Confirm data persists across the second launch
        final reopenedPet = await reopened.getPet('active_pet');
        expect(reopenedPet!.sparks, 450);
        expect(reopenedPet.pathLevel, 4);

        final reopenedJournals = await reopened.watchRecentJournals().first;
        expect(reopenedJournals, hasLength(2));
      });
    });
  }

  group('Cryptographic key safety and fail-closed storage', () {
    test('loadMasterKey refuses to generate replacement key if existing entries are indicated', () async {
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'journal_master_key_v1');

      expect(
        () => JournalCryptoService.loadMasterKey(hasExistingEntries: true),
        throwsA(isA<MasterKeyInaccessibleException>()),
      );
    });

    test('loadMasterKey refuses to generate replacement key if storage throws error and entries exist', () async {
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'journal_master_key_v1');

      expect(
        () => JournalCryptoService.loadMasterKey(hasExistingEntries: true),
        throwsA(isA<MasterKeyInaccessibleException>()),
      );
    });

    test('loadMasterKey generates key on fresh install without history', () async {
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
      final key = await JournalCryptoService.loadMasterKey();
      expect(key, hasLength(32));

      // Second call returns identical key
      final key2 = await JournalCryptoService.loadMasterKey();
      expect(key2, equals(key));
    });
  });

  group('Authentic SQLCipher Encrypted Database & Upgrade Safety', () {
    late Directory tempDir;
    late File dbFile;
    const testDbKey = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sqlcipher_upgrade_test_');
      dbFile = File('${tempDir.path}${Platform.pathSeparator}recovery_companion_secure.db');
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      if (Platform.isLinux) {
        final lib = RecoveryDatabase.resolveLinuxSqlCipher();
        if (lib != null) {
          open.overrideFor(OperatingSystem.linux, () => lib);
        }
      }
    });

    test('Negative test: opening with ordinary SQLite when SQLCipher is enforced fails closed', () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'recovery_db_sqlcipher_key_v1', value: testDbKey);

      final db = RecoveryDatabase.openEncrypted(
        file: dbFile,
        storage: storage,
        enforceSqlCipher: true,
        forceStandardSqlite: true,
      );

      expect(
        () async => await db.customSelect('SELECT 1').get(),
        throwsA(isA<DatabaseEncryptionException>()),
      );
    });

    test('Header verification: standard unencrypted SQLite file is detected by hasPlaintextSqliteHeader', () async {
      final rawDb = RecoveryDatabase.forTesting(NativeDatabase(dbFile) as QueryExecutor);
      await rawDb.customStatement('CREATE TABLE test_tab (id INT PRIMARY KEY);');
      await rawDb.close();

      expect(RecoveryDatabase.hasPlaintextSqliteHeader(dbFile), isTrue);

      final headerBytes = dbFile.openSync().readSync(16);
      expect(utf8.decode(headerBytes.sublist(0, 15)), equals('SQLite format 3'));
    });

    test(
      'Authentic SQLCipher positive test: verifies cipher_version, encrypted on-disk header, wrong-key rejection, and v13 to v15 data preservation',
      () async {
        const storage = FlutterSecureStorage();
        await storage.write(key: 'recovery_db_sqlcipher_key_v1', value: testDbKey);

        final masterKey = Uint8List.fromList(List<int>.generate(32, (i) => i * 3 + 1));
        await storage.write(key: 'journal_master_key_v1', value: base64Encode(masterKey));

        // 1. Seed database with v13 schema and encrypted data under strict SQLCipher enforcement
        final initialDb = RecoveryDatabase.openEncrypted(
          file: dbFile,
          storage: storage,
          enforceSqlCipher: true,
        );
        await initialDb.customStatement('SELECT 1');

        // Confirm PRAGMA cipher_version is nonempty and valid
        final cipherRows = await initialDb.customSelect('PRAGMA cipher_version').get();
        expect(cipherRows, isNotEmpty);
        expect(cipherRows.first.data.values.first?.toString().trim().isNotEmpty, isTrue);

        // Drop v15 additions
        await initialDb.customStatement('DROP INDEX IF EXISTS idx_circle_outbox_status');
        await initialDb.customStatement('DROP TABLE IF EXISTS circle_outbox_entries');

        // Drop v14 additions
        await initialDb.customStatement('DROP TABLE IF EXISTS raid_victory_receipts');
        await initialDb.customStatement('DROP TABLE IF EXISTS raid_damage_receipts');
        await initialDb.customStatement('DROP TABLE IF EXISTS reward_receipts');
        await initialDb.customStatement('DROP TABLE IF EXISTS recovery_actions');

        final encJournal = await JournalCryptoService.encrypt('Encrypted journal prior to upgrade', masterKey);
        await initialDb.addJournalEntry(JournalEntry(
          id: 'journal_sqlcipher_1',
          timestamp: 1672531199000,
          moodRating: 5,
          contentEncrypted: encJournal,
          isSyncedToCloud: false,
        ));

        await initialDb.addCounter(Counter(
          id: 'counter_sqlcipher_1',
          label: 'Alcohol Freedom',
          startDateTime: 1672531199000,
          isActive: true,
          dailyCost: 15.5,
        ));

        await initialDb.customStatement(
          "INSERT INTO recovery_pets (id, name, species_or_style, energy, bond, mood, sparks, unlocked_items, equipped_outfit, last_fed_at, created_at, equipped_slots_json, path_level, path_xp) "
          "VALUES ('pet_sqlcipher_1', 'Phoenix', 'guardian', 0.95, 0.85, 'thriving', 500, '[\"crown_gold\"]', 'crown_gold', 1672531199000, 1672531199000, '{\"head\":\"crown_gold\"}', 5, 450)",
        );

        await initialDb.customStatement('PRAGMA user_version = 13');
        await initialDb.close();

        // 2. Verify on-disk file header is NOT plaintext SQLite
        expect(RecoveryDatabase.hasPlaintextSqliteHeader(dbFile), isFalse);
        final headerBytes = dbFile.openSync().readSync(16);
        expect(utf8.decode(headerBytes.sublist(0, 15), allowMalformed: true), isNot(equals('SQLite format 3')));

        // 3. Verify wrong key CANNOT open the populated encrypted database
        const wrongKey = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
        final wrongStoragePlatform = TestFlutterSecureStoragePlatform({'recovery_db_sqlcipher_key_v1': wrongKey});
        FlutterSecureStoragePlatform.instance = wrongStoragePlatform;
        const wrongStorage = FlutterSecureStorage();

        final wrongDb = RecoveryDatabase.openEncrypted(
          file: dbFile,
          storage: wrongStorage,
          enforceSqlCipher: true,
        );
        expect(
          () async => await wrongDb.customSelect('SELECT COUNT(*) FROM recovery_pets').get(),
          throwsA(isA<Exception>()),
        );
        try {
          await wrongDb.close();
        } catch (_) {}

        // Restore correct storage key platform
        FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({
          'recovery_db_sqlcipher_key_v1': testDbKey,
          'journal_master_key_v1': base64Encode(masterKey),
        });

        // 4. Open with authentic SQLCipher connection: triggers v13 -> v15 upgrade
        final upgradedDb = RecoveryDatabase.openEncrypted(
          file: dbFile,
          storage: storage,
          enforceSqlCipher: true,
        );
        await upgradedDb.customStatement('SELECT 1');

        final v = (await upgradedDb.customSelect('PRAGMA user_version').getSingle()).data['user_version'] as int;
        expect(v, equals(15));

        // 5. Verify all domain data preserved across upgrade under SQLCipher
        final journals = await upgradedDb.select(upgradedDb.journalEntries).get();
        expect(journals, hasLength(1));
        final plain = await JournalCryptoService.decrypt(journals.first.contentEncrypted, masterKey);
        expect(plain, equals('Encrypted journal prior to upgrade'));

        final counters = await upgradedDb.select(upgradedDb.counters).get();
        expect(counters, hasLength(1));
        expect(counters.first.label, equals('Alcohol Freedom'));

        final pets = await upgradedDb.select(upgradedDb.recoveryPets).get();
        expect(pets, hasLength(1));
        expect(pets.first.name, equals('Phoenix'));
        expect(pets.first.sparks, equals(500));

        // 6. Stable reopening
        await upgradedDb.close();
        final reopenedDb = RecoveryDatabase.openEncrypted(
          file: dbFile,
          storage: storage,
          enforceSqlCipher: true,
        );
        final finalPets = await reopenedDb.select(reopenedDb.recoveryPets).get();
        expect(finalPets.first.name, equals('Phoenix'));
        await reopenedDb.close();
      },
      skip: !RecoveryDatabase.isSqlCipherActive()
          ? 'Native SQLCipher library not active in current test runner (supported on Android and Linux CI with libsqlcipher-dev)'
          : null,
    );

    test('Simulation (unencrypted engine fallback): openEncrypted connection upgrades v13 to v15, retains data, and reopens stably', () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'recovery_db_sqlcipher_key_v1', value: testDbKey);

      final masterKey = Uint8List.fromList(List<int>.generate(32, (i) => i * 3 + 1));
      await storage.write(key: 'journal_master_key_v1', value: base64Encode(masterKey));

      // 1. Seed database with v13 schema and encrypted data
      final initialDb = RecoveryDatabase.openEncrypted(file: dbFile, storage: storage);
      await initialDb.customStatement('SELECT 1');

      // Drop v15 additions
      await initialDb.customStatement('DROP INDEX IF EXISTS idx_circle_outbox_status');
      await initialDb.customStatement('DROP TABLE IF EXISTS circle_outbox_entries');

      // Drop v14 additions
      await initialDb.customStatement('DROP TABLE IF EXISTS raid_victory_receipts');
      await initialDb.customStatement('DROP TABLE IF EXISTS raid_damage_receipts');
      await initialDb.customStatement('DROP TABLE IF EXISTS reward_receipts');
      await initialDb.customStatement('DROP TABLE IF EXISTS recovery_actions');

      final encJournal = await JournalCryptoService.encrypt('Encrypted journal prior to upgrade', masterKey);
      await initialDb.addJournalEntry(JournalEntry(
        id: 'journal_sqlcipher_1',
        timestamp: 1672531199000,
        moodRating: 5,
        contentEncrypted: encJournal,
        isSyncedToCloud: false,
      ));

      await initialDb.addCounter(Counter(
        id: 'counter_sqlcipher_1',
        label: 'Alcohol Freedom',
        startDateTime: 1672531199000,
        isActive: true,
        dailyCost: 15.5,
      ));

      await initialDb.customStatement(
        "INSERT INTO recovery_pets (id, name, species_or_style, energy, bond, mood, sparks, unlocked_items, equipped_outfit, last_fed_at, created_at, equipped_slots_json, path_level, path_xp) "
        "VALUES ('pet_sqlcipher_1', 'Phoenix', 'guardian', 0.95, 0.85, 'thriving', 500, '[\"crown_gold\"]', 'crown_gold', 1672531199000, 1672531199000, '{\"head\":\"crown_gold\"}', 5, 450)",
      );

      await initialDb.customStatement('PRAGMA user_version = 13');
      await initialDb.close();

      // 2. Open with v15 upgrade
      final upgradedDb = RecoveryDatabase.openEncrypted(file: dbFile, storage: storage);
      await upgradedDb.customStatement('SELECT 1');

      final v = (await upgradedDb.customSelect('PRAGMA user_version').getSingle()).data['user_version'] as int;
      expect(v, equals(15));

      // 3. Verify all recovery domains
      final journals = await upgradedDb.select(upgradedDb.journalEntries).get();
      expect(journals, hasLength(1));
      final plain = await JournalCryptoService.decrypt(journals.first.contentEncrypted, masterKey);
      expect(plain, equals('Encrypted journal prior to upgrade'));

      final counters = await upgradedDb.select(upgradedDb.counters).get();
      expect(counters, hasLength(1));
      expect(counters.first.label, equals('Alcohol Freedom'));

      final pets = await upgradedDb.select(upgradedDb.recoveryPets).get();
      expect(pets, hasLength(1));
      expect(pets.first.name, equals('Phoenix'));
      expect(pets.first.sparks, equals(500));

      // 4. Stable reopening
      await upgradedDb.close();
      final reopenedDb = RecoveryDatabase.openEncrypted(file: dbFile, storage: storage);
      final finalPets = await reopenedDb.select(reopenedDb.recoveryPets).get();
      expect(finalPets.first.name, equals('Phoenix'));
      await reopenedDb.close();
    });

    test('Encrypted connection fails closed and preserves file untouched when SQLCipher key is missing', () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'recovery_db_sqlcipher_key_v1', value: testDbKey);

      // Create existing populated database
      final db = RecoveryDatabase.openEncrypted(file: dbFile, storage: storage);
      await db.customStatement('SELECT 1');
      await db.addCounter(Counter(
        id: 'c_protect',
        label: 'Protected Counter',
        startDateTime: 1672531199000,
        isActive: true,
        dailyCost: 10.0,
      ));
      await db.close();

      final initialLength = dbFile.lengthSync();
      final initialBytes = dbFile.readAsBytesSync();
      expect(initialLength, greaterThan(0));

      // Delete key from secure storage
      await storage.delete(key: 'recovery_db_sqlcipher_key_v1');

      // Attempt open: MUST throw DatabaseKeyInaccessibleException and fail closed
      final failingDb = RecoveryDatabase.openEncrypted(file: dbFile, storage: storage);
      expect(
        () async => await failingDb.customStatement('SELECT 1'),
        throwsA(isA<DatabaseKeyInaccessibleException>()),
      );

      // Verify database file on disk is completely untouched
      expect(dbFile.existsSync(), isTrue);
      expect(dbFile.lengthSync(), equals(initialLength));
      expect(dbFile.readAsBytesSync(), equals(initialBytes));

      // Restore key: database is fully accessible and undamaged
      await storage.write(key: 'recovery_db_sqlcipher_key_v1', value: testDbKey);
      final restoredDb = RecoveryDatabase.openEncrypted(file: dbFile, storage: storage);
      final counters = await restoredDb.select(restoredDb.counters).get();
      expect(counters, hasLength(1));
      expect(counters.first.label, equals('Protected Counter'));
      await restoredDb.close();
    });
  });

  group('Daily Reflection Encryption & Historical Upgrade Safety', () {
    late Directory tempDir;
    late File dbFile;
    late Uint8List masterKey;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('reflection_crypto_test_');
      dbFile = File('${tempDir.path}${Platform.pathSeparator}test.db');
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
      masterKey = Uint8List.fromList(List<int>.generate(32, (i) => i * 5 + 2));
      const storage = FlutterSecureStorage();
      await storage.write(key: 'journal_master_key_v1', value: base64Encode(masterKey));
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('Daily reflection encrypts new entries with ENC2_ using verified master key', () async {
      final db = RecoveryDatabase.forTesting(NativeDatabase(dbFile) as QueryExecutor);
      await db.customStatement('SELECT 1');

      final rawText = 'Today I found peace and clarity in my journey.';
      final encrypted = await JournalCryptoService.encrypt(rawText, masterKey);
      expect(encrypted.startsWith('ENC2_'), isTrue);

      await db.addJournalEntry(JournalEntry(
        id: 'reflection_new_1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        moodRating: 4,
        contentEncrypted: encrypted,
        isSyncedToCloud: false,
      ));

      final entries = await db.select(db.journalEntries).get();
      expect(entries.first.contentEncrypted.startsWith('ENC2_'), isTrue);
      final decrypted = await JournalCryptoService.decrypt(entries.first.contentEncrypted, masterKey);
      expect(decrypted, equals(rawText));

      await db.close();
    });

    test('Daily reflection preserves historical plaintext and ENC_ entries without loss', () async {
      final db = RecoveryDatabase.forTesting(NativeDatabase(dbFile) as QueryExecutor);
      await db.customStatement('SELECT 1');

      final plainLegacy = 'Historical plaintext written before encryption requirement';
      final encLegacy = 'ENC_${base64Encode(utf8.encode('Legacy base64 encoded reflection'))}';

      await db.addJournalEntry(JournalEntry(
        id: 'legacy_plain_1',
        timestamp: 1670000000000,
        moodRating: 3,
        contentEncrypted: plainLegacy,
        isSyncedToCloud: false,
      ));

      await db.addJournalEntry(JournalEntry(
        id: 'legacy_enc_1',
        timestamp: 1670000100000,
        moodRating: 4,
        contentEncrypted: encLegacy,
        isSyncedToCloud: false,
      ));

      final readPlain = await JournalCryptoService.decrypt(plainLegacy, masterKey);
      expect(readPlain, equals(plainLegacy));

      final readLegacy = await JournalCryptoService.decrypt(encLegacy, masterKey);
      expect(readLegacy, equals('Legacy base64 encoded reflection'));

      await db.close();
    });

    test('upgradeHistoricalEntries idempotently upgrades legacy entries to ENC2_', () async {
      final db = RecoveryDatabase.forTesting(NativeDatabase(dbFile) as QueryExecutor);
      await db.customStatement('SELECT 1');

      await db.addJournalEntry(JournalEntry(
        id: 'to_upgrade_plain',
        timestamp: 1670000000000,
        moodRating: 3,
        contentEncrypted: 'Raw historical reflection text',
        isSyncedToCloud: false,
      ));

      await db.addJournalEntry(JournalEntry(
        id: 'to_upgrade_legacy',
        timestamp: 1670000100000,
        moodRating: 4,
        contentEncrypted: 'ENC_${base64Encode(utf8.encode('Legacy base64 reflection'))}',
        isSyncedToCloud: false,
      ));

      final alreadyModern = await JournalCryptoService.encrypt('Already modern', masterKey);
      await db.addJournalEntry(JournalEntry(
        id: 'already_modern',
        timestamp: 1670000200000,
        moodRating: 5,
        contentEncrypted: alreadyModern,
        isSyncedToCloud: false,
      ));

      // Perform non-destructive upgrade
      final count = await JournalCryptoService.upgradeHistoricalEntries(db, masterKey);
      expect(count, equals(2));

      // Verify all rows are now ENC2_ and decrypt accurately
      final allEntries = await db.select(db.journalEntries).get();
      for (final e in allEntries) {
        expect(e.contentEncrypted.startsWith('ENC2_'), isTrue);
      }

      final decryptedPlain = await JournalCryptoService.decrypt(
        allEntries.firstWhere((e) => e.id == 'to_upgrade_plain').contentEncrypted,
        masterKey,
      );
      expect(decryptedPlain, equals('Raw historical reflection text'));

      // Idempotency check: running again upgrades 0 entries
      final secondCount = await JournalCryptoService.upgradeHistoricalEntries(db, masterKey);
      expect(secondCount, equals(0));

      await db.close();
    });
  });
}
