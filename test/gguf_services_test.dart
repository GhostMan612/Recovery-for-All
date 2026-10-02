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
          await GgufModelService().isModelDownloaded('smollm2_17b'), isTrue);
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
      expect(path, isNotNull);
      expect(path!.path, endsWith('gemma3_270m.gguf'));
    });

    test('downloadModel short-circuits true when file already on disk',
        () async {
      final dir = Directory('${tempDir.path}/gguf_models');
      await dir.create(recursive: true);
      await File('${dir.path}/smollm2_17b.gguf').writeAsBytes(const [9]);
      final model =
          GgufModelService.catalog.firstWhere((m) => m.id == 'smollm2_17b');
      final ok = await GgufModelService().downloadModel(model);
      expect(ok, isTrue,
          reason: 'pre-seeded file must satisfy download without network');
    });

    test('deleteModel removes both the file and the registry entry',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'gguf_downloaded_v1', '["gemma3_270m","phi4mini"]');

      await GgufModelService().deleteModel('phi4mini');

      expect(await GgufModelService().getModelSizeOnDisk('phi4mini'), 0);
      expect(await GgufModelService().isModelDownloaded('phi4mini'), isFalse);
      // Untouched sibling survives.
      expect(
          await GgufModelService().isModelDownloaded('gemma3_270m'), isTrue);
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
    // Budget is 3 GB with 64 MB of write slack. A 2.7 GB model therefore needs
    // 2764 MB, and 3072 - 2764 = 308 MB of headroom — which is what makes the
    // eviction arithmetic in the third case non-obvious and worth pinning.

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

    test('over-budget download evicts other models, largest first', () async {
      final dir = await emptyModelDir();
      await _sparseFile('${dir.path}/small.gguf', 300 * 1024 * 1024);
      await _sparseFile('${dir.path}/large.gguf', 1500 * 1024 * 1024);

      // 1800 MB used, needs 2764 MB, budget 3072 MB.
      //   Evicting the 1500 MB file first: 300 + 2764 = 3064 <= 3072. Done.
      //   Evicting only the 300 MB file: 1500 + 2764 = 4264 > 3072, so a
      //     SECOND eviction would be needed — and there is none left.
      // So this case pins the ORDER, not just the outcome: one eviction must be
      // enough, and it must be the large one.
      final err = await GgufModelService().ensureBudgetForTest(
        phi4,
        '${dir.path}/${phi4.id}.gguf',
      );
      expect(err, isNull);
      expect(File('${dir.path}/large.gguf').existsSync(), isFalse,
          reason: 'largest-first: a single eviction was sufficient');
      expect(File('${dir.path}/small.gguf').existsSync(), isTrue,
          reason: 'the smaller model must survive when one eviction suffices');
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

    test('replacing an already-downloaded model does not need 2x the space',
        () async {
      final dir = await emptyModelDir();
      final target = await _sparseFile(
          '${dir.path}/${phi4.id}.gguf', 2700 * 1024 * 1024);

      // 2700 MB on disk, budget 3072 MB. The download needs 2764 MB, which
      // would be 5464 MB if the existing file counted against us. It is the
      // SAME bytes being replaced, so it must be discounted — otherwise a
      // legitimate re-download can never pass its own check, and the only way
      // to "fix" that would be to raise the budget past every model.
      final err =
          await GgufModelService().ensureBudgetForTest(phi4, target.path);
      expect(err, isNull);
      expect(target.existsSync(), isTrue,
          reason: 'the budget check must not evict the file it is replacing');
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
