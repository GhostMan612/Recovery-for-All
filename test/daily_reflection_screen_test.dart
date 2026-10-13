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
    masterKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 10));
    const storage = FlutterSecureStorage();
    await storage.write(key: 'journal_master_key_v1', value: base64Encode(masterKey));

    db = RecoveryDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
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

      final textField = find.byType(TextField);
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

    testWidgets('displays decrypted content for historical plaintext and ENC_ entries', (tester) async {
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

      final textField = find.byType(TextField);
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
}
