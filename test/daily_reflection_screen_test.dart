// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/screens/daily_reflection_screen.dart';
import 'package:recovery_for_all/services/journal_crypto_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecoveryDatabase db;
  late Uint8List masterKey;

  setUp(() async {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    JournalCryptoService.lockSession();
    masterKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 10));
    const storage = FlutterSecureStorage();
    await storage.write(key: 'journal_master_key_v1', value: base64Encode(masterKey));

    db = RecoveryDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    JournalCryptoService.lockSession();
    await db.close();
  });

  Widget buildScreen() {
    return MaterialApp(
      home: DailyReflectionScreen(database: db),
    );
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (condition()) return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('DailyReflectionScreen Encryption & Preservation Path', () {
    testWidgets('saving a reflection writes ENC2_ encrypted content to database', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen());
      await pumpUntil(tester, () => find.byType(CircularProgressIndicator).evaluate().isEmpty);

      final textField = find.byType(TextField).first;
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'Peace is not the absence of conflict, but the presence of stillness.');
      await tester.pump(const Duration(milliseconds: 50));

      final saveButton = find.widgetWithText(ElevatedButton, 'Save Reflection');
      expect(saveButton, findsOneWidget);

      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);

      // Await save completion indicated by SnackBar confirmation
      await pumpUntil(
        tester,
        () => find.text('Reflection saved to your journal').evaluate().isNotEmpty,
      );
      expect(find.text('Reflection saved to your journal'), findsOneWidget);

      // Check database contents
      final entries = await db.select(db.journalEntries).get();
      expect(entries, hasLength(1));
      final savedEntry = entries.first;

      // Must be encrypted with modern ENC2_ prefix
      expect(savedEntry.contentEncrypted.startsWith('ENC2_'), isTrue);

      // Must successfully decrypt to original input
      final plain = await JournalCryptoService.decrypt(savedEntry.contentEncrypted, masterKey);
      expect(plain, equals('Peace is not the absence of conflict, but the presence of stillness.'));
    });

    testWidgets('displays decrypted content for historical plaintext and ENC_ entries when PIN is unconfigured', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed pre-existing historical unencrypted and legacy ENC_ entries
      await db.addJournalEntry(JournalEntry(
        id: 'hist_plain',
        timestamp: DateTime.now().millisecondsSinceEpoch - 10000,
        moodRating: 4,
        contentEncrypted: 'Historical raw plaintext reflection',
        isSyncedToCloud: false,
      ));

      final legacyPayload = 'ENC_${base64Encode(utf8.encode('Legacy base64 reflection'))}';
      await db.addJournalEntry(JournalEntry(
        id: 'hist_legacy',
        timestamp: DateTime.now().millisecondsSinceEpoch - 5000,
        moodRating: 5,
        contentEncrypted: legacyPayload,
        isSyncedToCloud: false,
      ));

      await tester.pumpWidget(buildScreen());

      // Await historical decryption and display
      await pumpUntil(
        tester,
        () => find.text('Historical raw plaintext reflection').evaluate().isNotEmpty,
      );

      // Both historical entries must be rendered as readable plaintext, never raw ciphertext or error
      expect(find.text('Historical raw plaintext reflection'), findsOneWidget);
      expect(find.text('Legacy base64 reflection'), findsOneWidget);

      // After loading, historical entries are upgraded to ENC2_
      final updatedEntries = await db.select(db.journalEntries).get();
      for (final e in updatedEntries) {
        expect(e.contentEncrypted.startsWith('ENC2_'), isTrue);
      }
    });

    testWidgets('shows warning and prevents corrupted save if master key is inaccessible with existing history', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Add existing entry
      await db.addJournalEntry(JournalEntry(
        id: 'existing_entry',
        timestamp: DateTime.now().millisecondsSinceEpoch - 10000,
        moodRating: 4,
        contentEncrypted: 'ENC2_dummy',
        isSyncedToCloud: false,
      ));

      // Remove master key from storage to simulate lockout/storage error
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'journal_master_key_v1');

      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(milliseconds: 200));

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'New reflection during key lockout');
      await tester.pump(const Duration(milliseconds: 50));

      final saveButton = find.widgetWithText(ElevatedButton, 'Save Reflection');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);

      // Await warning SnackBar
      await pumpUntil(
        tester,
        () => find.textContaining('Encryption key inaccessible').evaluate().isNotEmpty,
      );

      // SnackBar shows key inaccessible message
      expect(find.textContaining('Encryption key inaccessible'), findsOneWidget);

      // Database should NOT have added the new entry, and existing entry is preserved
      final entries = await db.select(db.journalEntries).get();
      expect(entries, hasLength(1));
      expect(entries.first.id, equals('existing_entry'));
    });
  });

  group('DailyReflectionScreen Journal PIN Privacy Protection & Fail-Closed Gate', () {
    const validPin = '123456';

    setUp(() async {
      await JournalCryptoService.setPin(validPin);
      JournalCryptoService.lockSession();
    });

    testWidgets('gates past reflections when PIN is set and session is locked', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed a private reflection in the database
      final encPrivate = await JournalCryptoService.encrypt('Top secret recovery thought', masterKey);
      await db.addJournalEntry(JournalEntry(
        id: 'secret_ref_1',
        timestamp: DateTime.now().millisecondsSinceEpoch - 10000,
        moodRating: 4,
        contentEncrypted: encPrivate,
        isSyncedToCloud: false,
      ));

      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(milliseconds: 200));

      // The secret reflection must NOT be visible or decrypted
      expect(find.text('Top secret recovery thought'), findsNothing);

      // The privacy gate UI must be rendered
      expect(find.text('Past Reflections Locked'), findsOneWidget);
      expect(find.textContaining('Enter your 6-digit Journal PIN'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Unlock Past Reflections'), findsOneWidget);

      // Attempting unlock with incorrect PIN
      final pinField = find.byType(TextField).last;
      await tester.enterText(pinField, '999999');
      await tester.pump(const Duration(milliseconds: 50));

      final unlockButton = find.widgetWithText(ElevatedButton, 'Unlock Past Reflections');
      await tester.ensureVisible(unlockButton);
      await tester.tap(unlockButton);
      await tester.pump(const Duration(milliseconds: 200));

      // Incorrect PIN error shown, reflection still NOT visible
      expect(find.text('Incorrect PIN. Please try again.'), findsOneWidget);
      expect(find.text('Top secret recovery thought'), findsNothing);

      // Now enter the correct PIN
      await tester.enterText(pinField, validPin);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(unlockButton);

      await pumpUntil(
        tester,
        () => find.text('Top secret recovery thought').evaluate().isNotEmpty,
      );

      // Secret reflection is now safely unlocked and visible
      expect(find.text('Top secret recovery thought'), findsOneWidget);
      expect(find.text('Past Reflections Locked'), findsNothing);
    });

    testWidgets('renders past reflections immediately if journal session was already unlocked', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Unlock session prior to screen open (e.g. unlocked in JournalScreen)
      JournalCryptoService.unlockSession();

      final enc = await JournalCryptoService.encrypt('Already authenticated reflection', masterKey);
      await db.addJournalEntry(JournalEntry(
        id: 'auth_ref_1',
        timestamp: DateTime.now().millisecondsSinceEpoch - 10000,
        moodRating: 5,
        contentEncrypted: enc,
        isSyncedToCloud: false,
      ));

      await tester.pumpWidget(buildScreen());
      await pumpUntil(
        tester,
        () => find.text('Already authenticated reflection').evaluate().isNotEmpty,
      );

      expect(find.text('Already authenticated reflection'), findsOneWidget);
      expect(find.text('Past Reflections Locked'), findsNothing);
    });

    testWidgets('fails closed with Vault Storage Inaccessible when PIN metadata is corrupted or partial', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed private reflection
      final encPrivate = await JournalCryptoService.encrypt('Protected private thought', masterKey);
      await db.addJournalEntry(JournalEntry(
        id: 'secret_ref_corrupt',
        timestamp: DateTime.now().millisecondsSinceEpoch - 10000,
        moodRating: 4,
        contentEncrypted: encPrivate,
        isSyncedToCloud: false,
      ));

      // Corrupt the secure storage PIN metadata: valid salt but malformed hash length
      const storage = FlutterSecureStorage();
      await storage.write(key: 'journal_pin_hash_v1', value: base64Encode(List<int>.filled(10, 99)));
      JournalCryptoService.lockSession();

      await tester.pumpWidget(buildScreen());
      await pumpUntil(
        tester,
        () => find.text('Vault Storage Inaccessible').evaluate().isNotEmpty,
      );

      // Must display Vault Storage Inaccessible and retry button
      expect(find.text('Vault Storage Inaccessible'), findsOneWidget);
      expect(find.textContaining('Secure storage could not verify your PIN metadata'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry Vault Check'), findsOneWidget);

      // Must NOT allow PIN entry or offer PIN setup
      expect(find.text('Choose Your Journal PIN'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Unlock Past Reflections'), findsNothing);

      // Reflections MUST remain concealed
      expect(find.text('Protected private thought'), findsNothing);
    });

    testWidgets('automatically conceals reflections when app enters background (paused)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Unlock session
      JournalCryptoService.unlockSession();

      final enc = await JournalCryptoService.encrypt('Visible reflection before pause', masterKey);
      await db.addJournalEntry(JournalEntry(
        id: 'visible_ref_1',
        timestamp: DateTime.now().millisecondsSinceEpoch - 10000,
        moodRating: 5,
        contentEncrypted: enc,
        isSyncedToCloud: false,
      ));

      await tester.pumpWidget(buildScreen());
      await pumpUntil(
        tester,
        () => find.text('Visible reflection before pause').evaluate().isNotEmpty,
      );

      expect(find.text('Visible reflection before pause'), findsOneWidget);
      expect(JournalCryptoService.isSessionUnlocked, isTrue);

      // Simulate app backgrounding
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Session must be locked
      expect(JournalCryptoService.isSessionUnlocked, isFalse);

      // Decrypted reflection must be completely cleared from UI
      expect(find.text('Visible reflection before pause'), findsNothing);

      // Privacy gate must be rendered
      expect(find.text('Past Reflections Locked'), findsOneWidget);
    });
  });
}
