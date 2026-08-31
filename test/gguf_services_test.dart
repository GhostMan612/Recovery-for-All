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
