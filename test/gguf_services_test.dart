// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// Host tests for the GGUF deeper-chat stack: catalog integrity,
// tier gating, prefs-backed state, storage layer, and the
// inference service's fail-safe contract (missing model → null →
// caller falls back to the scripted coach).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:recovery_for_all/services/gguf_inference_service.dart';
import 'package:recovery_for_all/services/gguf_model_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  final String basePath;
  _FakePathProviderPlatform(this.basePath);

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;
}

/// Creates a file of [bytes] apparent size WITHOUT allocating [bytes] of RAM.
///
/// A sparse file. `List<int>.filled(3 * 1024 * 1024 * 1024, 0)` — the obvious
/// way to fake a large model — is ~24 GB of boxed integers and starves the
/// whole suite; that is what made four budget tests fail, and it also pushed
/// unrelated crypto tests past their timeouts. `setLength` on a fresh handle
/// creates a sparse file on NTFS/ext4/f2fs: `length()` reports the full size,
/// disk usage stays near zero.
Future<File> _sparseFile(String path, int bytes) async {
  final f = File(path);
  final handle = await f.open(mode: FileMode.write);
  try {
    // `RandomAccessFile` has no `setLength`, so seek to the last byte and write
    // one. The OS extends the file to that offset and, on NTFS/ext4/f2fs,
    // leaves the intervening range unallocated: `length()` reports the full
    // size while disk usage stays near zero.
    await handle.setPosition(bytes - 1);
    await handle.writeFrom(const [0]);
  } finally {
    await handle.close();
  }
  return f;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late Directory tempDir;
  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('gguf_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });
  tearDownAll(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('model catalog', () {
    test('ids are unique and non-empty', () {
      final ids = GgufModelService.catalog.map((m) => m.id).toList();
      expect(ids, everyElement(isNotEmpty));
      expect(ids.toSet().length, ids.length);
    });

    test('every entry is a real download target with sane metadata', () {
      for (final m in GgufModelService.catalog) {
        expect(m.downloadUrl, startsWith('https://'));
        expect(m.fileSizeBytes, greaterThan(0));
        expect(m.contextWindow, greaterThan(0));
        expect(m.quantization, 'Q4_K_M');
        expect(m.minTier, isNot(DeviceTier.low),
            reason: 'no model may be offered to low-tier devices');
      }
    });

    test('all shipped model downloads have a pinned SHA-256 digest', () {
      expect(GgufModelService.catalog, hasLength(4));
      for (final model in GgufModelService.catalog) {
        expect(model.sha256Hex, isNotNull,
            reason: '${model.id} must not skip download integrity verification');
        expect(model.sha256Hex, matches(RegExp(r'^[0-9a-f]{64}$')),
            reason: '${model.id} must have a complete SHA-256 checksum');
      }
    });

    test('tier ordering matches device fleet mapping', () {
      final byId = {for (final m in GgufModelService.catalog) m.id: m};
      expect(byId['gemma3_270m']!.minTier, DeviceTier.medium);
      expect(byId['qwen35_08b']!.minTier, DeviceTier.medium);
      expect(byId['smollm2_17b']!.minTier, DeviceTier.high);
      expect(byId['phi4mini']!.minTier, DeviceTier.premium);
    });

    test('fileSizeMb formats as rounded MB', () {
      const m = GgufModelInfo(
        id: 'x',
        name: 'X',
        description: '',
        downloadUrl: 'https://example.com/x.gguf',
        fileSizeBytes: 300 * 1024 * 1024,
        minTier: DeviceTier.medium,
        contextWindow: 4096,
        quantization: 'Q4_K_M',
      );
      expect(m.fileSizeMb, '300 MB');
    });
  });

  group('DownloadProgress', () {
    test('progress is the downloaded fraction', () {
      const p = DownloadProgress(
        state: DownloadState.downloading,
        downloadedBytes: 250,
        totalBytes: 1000,
      );
      expect(p.progress, closeTo(0.25, 1e-9));
    });

    test('zero total never divides by zero', () {
      const p = DownloadProgress(state: DownloadState.idle);
      expect(p.progress, 0.0);
    });
  });

  group('device tier gate (host = non-Android path)', () {
    test('host devices detect as high tier and are supported', () async {
      final service = GgufModelService();
      final tier = await service.detectDeviceTier();
      expect(tier, DeviceTier.high);
      expect(service.isSupported, isTrue);
    });

    test('high tier sees medium+high models but not premium-only', () {
      final ids =
          GgufModelService().availableModels.map((m) => m.id).toSet();
      expect(ids, containsAll(<String>['gemma3_270m', 'qwen35_08b']));
      expect(ids.contains('smollm2_17b'), isTrue);
      expect(ids.contains('phi4mini'), isFalse);
    });

    test('selectedModel falls back to first available model', () {
      final fallback = GgufModelService().selectedModel;
      expect(fallback, isNotNull);
      expect(
        GgufModelService()
            .availableModels
            .map((m) => m.id)
            .contains(fallback!.id),
        isTrue,
      );
    });
  });

  group('prefs-backed state', () {
    test('deeper chat is OFF by default — safety posture', () async {
      final service = GgufModelService();
      expect(await service.isEnabled(), isFalse);
    });

    test('enabled toggle round-trips', () async {
      final service = GgufModelService();
      await service.setEnabled(true);
      expect(await service.isEnabled(), isTrue);
      await service.setEnabled(false);
      expect(await service.isEnabled(), isFalse);
    });

    test('selected model id defaults to null and round-trips', () async {
      final service = GgufModelService();
      expect(await service.getSelectedModelId(), isNull);
      await service.setSelectedModelId('qwen35_08b');
      expect(await service.getSelectedModelId(), 'qwen35_08b');
    });

    test('downloaded registry starts empty', () async {
      expect(await GgufModelService().getDownloadedModels(), isEmpty);
      expect(await GgufModelService().isModelDownloaded('gemma3_270m'),
          isFalse);
    });

    test('registry json round-trips through prefs directly', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'gguf_downloaded_v1', '["gemma3_270m","smollm2_17b"]');
      final set = await GgufModelService().getDownloadedModels();
      expect(set, {'gemma3_270m', 'smollm2_17b'});
      expect(
          await GgufModelService().isModelDownloaded('smollm2_17b'), isFalse,
          reason: 'a registry marker alone cannot prove disk integrity');
    });
  });

  group('storage layer (faked app documents dir)', () {
    test('getModelPath returns null before anything is stored', () async {
      expect(await GgufModelService().getModelPath('gemma3_270m'), isNull);
    });

    test('size on disk reflects a stored model file', () async {
      final dir = Directory('${tempDir.path}/gguf_models');
      await dir.create(recursive: true);
      final f = File('${dir.path}/gemma3_270m.gguf');
      await f.writeAsBytes(const [1, 2, 3, 4]);
      expect(await GgufModelService().getModelSizeOnDisk('gemma3_270m'), 4);
      final path = await GgufModelService().getModelPath('gemma3_270m');
      expect(path, isNull,
          reason: 'a four-byte file is not a verified model');
    });

    test('cached corrupt models are never marked ready or loadable', () async {
      final dir = Directory('${tempDir.path}/gguf_models');
      await dir.create(recursive: true);
      await File('${dir.path}/smollm2_17b.gguf').writeAsBytes(const [9]);
      final svc = GgufModelService();
      expect(await svc.isModelReady('smollm2_17b'), isFalse);
      expect(await svc.getModelPath('smollm2_17b'), isNull);
    });

    test('cached file hashing uses streamed real SHA-256 validation', () async {
      final f = File('${tempDir.path}/SAMPLE_hash_check.bin');
      await f.writeAsBytes(const [97, 98, 99]); // abc
      const knownDigest =
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
      final svc = GgufModelService();
      expect(await svc.verifyFileDigestForTest(f, knownDigest), isTrue);
      await f.writeAsBytes(const [97, 98, 100]); // abd
      expect(await svc.verifyFileDigestForTest(f, knownDigest), isFalse);
    });

    test('model IDs cannot traverse outside the cache directory', () async {
      expect(await GgufModelService().getModelPath('../journal'), isNull);
      expect(await GgufModelService().isModelReady('../../secret'), isFalse);
      final outside = File('${tempDir.path}/SAMPLE_private.gguf');
      await outside.writeAsBytes(const [1, 2, 3]);
      await GgufModelService().deleteModel('../SAMPLE_private');
      expect(await outside.exists(), isTrue,
          reason: 'path traversal must never delete files outside gguf_models');
      expect(await GgufModelService().getModelSizeOnDisk('../SAMPLE_private'), 0);
    });

    test('deleteModel removes both the file and the registry entry',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'gguf_downloaded_v1', '["gemma3_270m","phi4mini"]');

      await GgufModelService().deleteModel('phi4mini');

      expect(await GgufModelService().getModelSizeOnDisk('phi4mini'), 0);
      expect(await GgufModelService().isModelDownloaded('phi4mini'), isFalse);
      // Untouched registry marker survives. Readiness is independently false
      // until an actual matching model file has been verified on disk.
      expect(await GgufModelService().getDownloadedModels(),
          contains('gemma3_270m'));
      expect(
          await GgufModelService().isModelDownloaded('gemma3_270m'), isFalse);
    });

    test('deleting a model that was never stored does not throw', () async {
      await GgufModelService().deleteModel('never_downloaded');
      expect(
          await GgufModelService().isModelDownloaded('never_downloaded'),
          isFalse);
    });
  });

  group('storage budget (the check that used to block every download)', () {
    // The removed implementation called `FileStat.stat(dir.path).size`, which
    // reports the DIRECTORY ENTRY size (4096 on ext4/f2fs), not free space, and
    // compared it against the model size. `4096 < 241 MB` is always true, so
    // every download threw "Not enough free space: 241 needed, 0 MB available"
    // on every device. The suite could not catch it because every download
    // test short-circuits on a pre-existing file — the one path that skips the
    // check entirely. These tests exercise the budget directly so that a
    // regression in it cannot hide behind that short-circuit again.
    //
    // Budget is 3 GB with 64 MB of write slack. Preflight must preserve
    // existing models and account for temporary download peak usage.

    Future<Directory> emptyModelDir() async {
      final dir = Directory('${tempDir.path}/gguf_models');
      await dir.create(recursive: true);
      for (final f in dir.listSync()) {
        if (f is File) await f.delete();
      }
      return dir;
    }

    final gemma =
        GgufModelService.catalog.firstWhere((m) => m.id == 'gemma3_270m');
    final phi4 =
        GgufModelService.catalog.firstWhere((m) => m.id == 'phi4mini');

    test('a download that fits the budget is allowed', () async {
      final dir = await emptyModelDir();
      final err = await GgufModelService().ensureBudgetForTest(
        gemma,
        '${dir.path}/${gemma.id}.gguf',
      );
      expect(err, isNull,
          reason: 'a 241 MB model must not be blocked on an empty directory — '
              'this is exactly what the old free-space probe did');
    });

    test('an in-flight .tmp file counts against the budget', () async {
      final dir = await emptyModelDir();
      // A partial download occupies real space even though no prefs entry names
      // it. Ignoring it is how two concurrent downloads each pass a check the
      // pair cannot satisfy. The census also deliberately will NOT evict a
      // `.tmp` — it belongs to a transfer in progress — so a 3 GB partial
      // leaves no room for anything.
      await _sparseFile('${dir.path}/phi4mini.gguf.tmp', 3 * 1024 * 1024 * 1024);

      final err = await GgufModelService().ensureBudgetForTest(
        gemma,
        '${dir.path}/${gemma.id}.gguf',
      );
      expect(err, isNotNull,
          reason: '3 GB of .tmp plus a 241 MB model must exceed the 3 GB budget');
    });

    test('over-budget preflight preserves every existing model and preference',
        () async {
      final dir = await emptyModelDir();
      final small = await _sparseFile(
          '${dir.path}/small.gguf', 300 * 1024 * 1024);
      final large = await _sparseFile(
          '${dir.path}/large.gguf', 1500 * 1024 * 1024);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gguf_downloaded_v1', '["gemma3_270m"]');

      final err = await GgufModelService().ensureBudgetForTest(
        phi4,
        '${dir.path}/${phi4.id}.gguf',
      );
      expect(err, isNotNull);
      expect(err, contains('No models were deleted'));
      expect(await small.exists(), isTrue);
      expect(await large.exists(), isTrue);
      expect(await small.length(), 300 * 1024 * 1024);
      expect(await large.length(), 1500 * 1024 * 1024);
      expect(prefs.getString('gguf_downloaded_v1'),
          '["gemma3_270m"]',
          reason: 'refused downloads may not rewrite existing model registry');
    });

    test('a model larger than the whole budget reports a usable message',
        () async {
      final dir = await emptyModelDir();
      // No eviction can rescue this: the model is larger than the entire
      // budget, so the only correct outcome is a refusal that says what to do.
      // A synthetic 4 GB entry — nothing in the catalog is that large.
      final huge = GgufModelInfo(
        id: 'huge',
        name: 'Huge',
        description: '',
        downloadUrl: 'https://example.com/huge.gguf',
        fileSizeBytes: 4 * 1024 * 1024 * 1024,
        minTier: DeviceTier.premium,
        contextWindow: 4096,
        quantization: 'Q4_K_M',
      );
      final err = await GgufModelService().ensureBudgetForTest(
        huge,
        '${dir.path}/huge.gguf',
      );
      expect(err, isNotNull);
      expect(err, contains('Not enough storage'));
      expect(err, contains('Delete a downloaded model'),
          reason: 'the message must tell the user what to do, not just that '
              'it failed');
    });

    test('replacement peak budget counts existing file and preserves it',
        () async {
      final dir = await emptyModelDir();
      final target = await _sparseFile(
          '${dir.path}/${phi4.id}.gguf', 2700 * 1024 * 1024);

      // Promotion is not in-place: the .tmp must be fully downloaded and
      // validated BEFORE rename. Preflight must conservatively count both.
      final err =
          await GgufModelService().ensureBudgetForTest(phi4, target.path);
      expect(err, isNotNull);
      expect(err, contains('existing model is preserved'));
      expect(await target.exists(), isTrue);
      expect(await target.length(), 2700 * 1024 * 1024);
    });

  });

  group('GgufInferenceService fail-safe contract', () {
    test('generate returns null when no model is loaded', () async {
      await GgufInferenceService.unload();
      final out = await GgufInferenceService.generate('User: hi\nAssistant:');
      expect(out, isNull);
    });

    test('loadModel with a missing model file fails cleanly', () async {
      final ok = await GgufInferenceService.loadModel('definitely_missing');
      expect(ok, isFalse);
      expect(GgufInferenceService.isLoaded, isFalse);
      expect(GgufInferenceService.loadedModelId, isNull);
      // And generation after the failed load still returns null (fallback).
      expect(
        await GgufInferenceService.generate('User: hi\nAssistant:'),
        isNull,
      );
    });

    test('unload and clearContext are safe with no model', () async {
      await GgufInferenceService.unload();
      GgufInferenceService.clearContext();
      expect(GgufInferenceService.isLoaded, isFalse);
      expect(GgufInferenceService.loadedModelId, isNull);
    });
  });
}
