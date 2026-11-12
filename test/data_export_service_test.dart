// test/data_export_service_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/services/data_export_service.dart';
import 'package:recovery_for_all/services/journal_crypto_service.dart';

class _ExportPathProvider extends PathProviderPlatform {
  final String root;
  _ExportPathProvider(this.root);

  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecoveryDatabase db;
  late Directory dir;
  late DataExportService exporter;
  late PathProviderPlatform savedPathProvider;

  setUp(() async {
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform({});
    JournalCryptoService.lockSession();
    dir = await Directory.systemTemp.createTemp('rfa_csv_export_');
    savedPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _ExportPathProvider(dir.path);
    db = RecoveryDatabase.forTesting(NativeDatabase.memory());
    exporter = DataExportService(db);
  });

  tearDown(() async {
    JournalCryptoService.lockSession();
    PathProviderPlatform.instance = savedPathProvider;
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> addJournal(String id, String content) async {
    await db.addJournalEntry(JournalEntry(
      id: id,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      moodRating: 4,
      contentEncrypted: content,
      isSyncedToCloud: false,
    ));
  }

  test('locked journal cannot be exported and creates no plaintext file', () async {
    final key = await JournalCryptoService.loadMasterKey();
    await addJournal('locked', await JournalCryptoService.encrypt('private recovery writing', key));

    await expectLater(exporter.exportCsv(), throwsA(isA<StateError>()));
    expect(dir.listSync().where((f) => f.path.endsWith('.csv')), isEmpty);
  });

  test('unlocked export decrypts ENC2 and legacy ENC_ without exporting ciphertext', () async {
    final key = await JournalCryptoService.loadMasterKey();
    final ciphertext = await JournalCryptoService.encrypt(
      'PRIVATE RECOVERY TEXT, line two', key,
    );
    await addJournal('encrypted', ciphertext);
    await addJournal('legacy', 'ENC_${base64Encode(utf8.encode('legacy journal words'))}');
    JournalCryptoService.unlockSession();

    final path = await exporter.exportCsv();
    final exported = await File(path).readAsString();
    expect(exported, contains('PRIVATE RECOVERY TEXT, line two'));
    expect(exported, contains('legacy journal words'));
    expect(exported, isNot(contains('ENC2_')));
    expect(exported, isNot(contains(ciphertext)));
  });

  test('corrupt AES payload aborts export without creating a shareable file', () async {
    await JournalCryptoService.loadMasterKey();
    await addJournal('corrupt', 'ENC2_not-a-valid-payload');
    JournalCryptoService.unlockSession();

    await expectLater(exporter.exportCsv(), throwsA(isA<StateError>()));
    expect(dir.listSync().where((f) => f.path.endsWith('.csv')), isEmpty);
  });

  test('CSV quoting neutralizes formulas and escapes user-entered text', () {
    expect(DataExportService.csvCell('=SUM(1,2)'), '"\'=SUM(1,2)"');
    expect(DataExportService.csvCell('  @HYPERLINK("a","b")'),
        '"\'  @HYPERLINK(""a"",""b"")"');
    expect(DataExportService.csvCell('Meeting, "reflection"\nNext line'),
        '"Meeting, ""reflection""\nNext line"');
    expect(DataExportService.csvCell('ordinary'), '"ordinary"');
  });
}
