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
import 'package:recovery_for_all/screens/chatbot_screen.dart';
import 'package:recovery_for_all/screens/coping_tool_screen.dart';
import 'package:recovery_for_all/screens/daily_reflection_screen.dart';
import 'package:recovery_for_all/screens/gratitude_entry_screen.dart';
import 'package:recovery_for_all/services/journal_crypto_service.dart';
import 'package:recovery_for_all/services/recovery_pet_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecoveryDatabase db;
  late Uint8List masterKey;

  setUp(() async {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    JournalCryptoService.lockSession();
    JournalCryptoService.initLifecycleObserver();

    masterKey = Uint8List.fromList(List<int>.generate(32, (i) => i * 2 + 1));
    const storage = FlutterSecureStorage();
    await storage.write(key: 'journal_master_key_v1', value: base64Encode(masterKey));

    db = RecoveryDatabase.forTesting(NativeDatabase.memory());
    RecoveryPetService.bindDatabase(db);
  });

  tearDown(() async {
    JournalCryptoService.lockSession();
    JournalCryptoService.disposeLifecycleObserver();
    await db.close();
  });

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

  group('Journal Write Paths: Strict Encryption Without Insecure Fallbacks', () {
    testWidgets('GratitudeEntryScreen never writes unencrypted/Base64 entry when encryption fails', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed an existing entry so loadMasterKey requires verification
      await db.addJournalEntry(JournalEntry(
        id: 'existing_seed',
        timestamp: DateTime.now().millisecondsSinceEpoch - 10000,
        moodRating: 4,
        contentEncrypted: 'ENC2_seed',
        isSyncedToCloud: false,
      ));

      // Remove master key to cause encryption failure
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'journal_master_key_v1');

      await tester.pumpWidget(MaterialApp(home: GratitudeEntryScreen(database: db)));
      await tester.pump(const Duration(milliseconds: 100));

      // Fill in gratitude fields
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));
      await tester.enterText(fields.at(0), 'Morning coffee');
      await tester.enterText(fields.at(1), 'Supportive friend');
      await tester.enterText(fields.at(2), 'Resilience');
      await tester.pump(const Duration(milliseconds: 50));

      final saveButton = find.widgetWithText(ElevatedButton, 'Save to Private Vault');
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);

      await pumpUntil(tester, () => find.textContaining('Error saving entry').evaluate().isNotEmpty);
      expect(find.textContaining('Error saving entry'), findsOneWidget);

      // Verify database did NOT insert an insecure fallback entry
      final entries = await db.select(db.journalEntries).get();
      expect(entries, hasLength(1));
      expect(entries.first.id, equals('existing_seed'));
    });

    testWidgets('CopingToolScreen never writes plaintext entry when encryption fails', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed an existing entry
      await db.addJournalEntry(JournalEntry(
        id: 'existing_seed_coping',
        timestamp: DateTime.now().millisecondsSinceEpoch - 10000,
        moodRating: 4,
        contentEncrypted: 'ENC2_seed',
        isSyncedToCloud: false,
      ));

      // Remove master key to cause encryption failure
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'journal_master_key_v1');

      await tester.pumpWidget(MaterialApp(home: CopingToolScreen(database: db)));
      await tester.pump(const Duration(milliseconds: 100));

      // Select first tool to reveal the session log button
      await tester.tap(find.text('5-4-3-2-1 Grounding'));
      await tester.pump(const Duration(milliseconds: 100));

      final logButton = find.widgetWithText(ElevatedButton, 'Log This Session');
      expect(logButton, findsOneWidget);
      await tester.ensureVisible(logButton);
      await tester.tap(logButton);

      await pumpUntil(tester, () => find.textContaining('Unable to encrypt and log session').evaluate().isNotEmpty);
      expect(find.textContaining('Unable to encrypt and log session'), findsOneWidget);

      // Database entries must NOT contain plaintext coping tool log
      final entries = await db.select(db.journalEntries).get();
      expect(entries, hasLength(1));
      expect(entries.first.id, equals('existing_seed_coping'));
    });

    testWidgets('ChatbotScreen crisis path never persists plaintext when encryption fails, and STILL shows SOS sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed existing entry
      await db.addJournalEntry(JournalEntry(
        id: 'existing_seed_chat',
        timestamp: DateTime.now().millisecondsSinceEpoch - 10000,
        moodRating: 4,
        contentEncrypted: 'ENC2_seed',
        isSyncedToCloud: false,
      ));

      // Remove master key to cause encryption failure
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'journal_master_key_v1');

      await tester.pumpWidget(MaterialApp(home: ChatbotScreen(database: db)));
      await tester.pump(const Duration(milliseconds: 100));

      final inputField = find.byType(TextField);
      expect(inputField, findsOneWidget);

      // Trigger crisis guardrail
      await tester.enterText(inputField, 'I want to hurt myself');
      await tester.pump(const Duration(milliseconds: 50));

      final sendButton = find.byIcon(Icons.send);
      await tester.tap(sendButton);

      // SOS interface must still be presented immediately!
      await pumpUntil(tester, () => find.text('SOS Crisis Safety Gate').evaluate().isNotEmpty);
      expect(find.text('SOS Crisis Safety Gate'), findsOneWidget);

      // Verify no plaintext entry was written to database
      final entries = await db.select(db.journalEntries).get();
      expect(entries, hasLength(1));
      expect(entries.first.id, equals('existing_seed_chat'));
    });
  });

  group('Historical PIN-less Data & Safe Enrollment', () {
    testWidgets('requires explicit PIN setup when history exists, preserving all records', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed historical entries without PIN
      final encHistorical = await JournalCryptoService.encrypt('Pre-update historical journal entry', masterKey);
      await db.addJournalEntry(JournalEntry(
        id: 'hist_j_1',
        timestamp: DateTime.now().millisecondsSinceEpoch - 20000,
        moodRating: 4,
        contentEncrypted: encHistorical,
        isSyncedToCloud: false,
      ));

      await tester.pumpWidget(MaterialApp(home: DailyReflectionScreen(database: db)));
      await pumpUntil(tester, () => find.text('PIN Enrollment Required').evaluate().isNotEmpty);

      // Entries MUST be concealed behind the setup gate
      expect(find.text('Pre-update historical journal entry'), findsNothing);
      expect(find.text('PIN Enrollment Required'), findsOneWidget);

      // Enter 6-digit PIN and enroll
      final pinField = find.byType(TextField).last;
      await tester.enterText(pinField, '123456');
      await tester.pump(const Duration(milliseconds: 50));

      final enrollButton = find.widgetWithText(ElevatedButton, 'Set PIN & Access Reflections');
      await tester.ensureVisible(enrollButton);
      await tester.tap(enrollButton);

      await pumpUntil(tester, () => find.text('Pre-update historical journal entry').evaluate().isNotEmpty);

      // Historical entry is revealed and intact!
      expect(find.text('Pre-update historical journal entry'), findsOneWidget);

      final entries = await db.select(db.journalEntries).get();
      expect(entries, hasLength(1));
      expect(entries.first.id, equals('hist_j_1'));
    });
  });

  group('Centralized Application Lifecycle Auto-Lock', () {
    test('journal session is locked when app is backgrounded even after navigating away from journal', () async {
      await JournalCryptoService.setPin('123456');
      JournalCryptoService.unlockSession();
      expect(JournalCryptoService.isSessionUnlocked, isTrue);

      // Background app (paused) - session must auto-lock via app-wide coordinator
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(JournalCryptoService.isSessionUnlocked, isFalse);

      // Resume and unlock again
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      JournalCryptoService.unlockSession();
      expect(JournalCryptoService.isSessionUnlocked, isTrue);

      // Inactive (e.g. app switcher or system modal) must also lock
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(JournalCryptoService.isSessionUnlocked, isFalse);

      // Restore resumed state
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });
}
