// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/gguf_model_service.dart
//
// Deeper chat model manager. Handles:
//   * Device RAM detection → tier gate (hidden below 3 GB)
//   * Model catalog tiered by device capability
//   * Download with progress + cancel + delete
//   * Storage management (private app dir, not Downloads)
//
// SAFETY: This feature is OPTIONAL. Off by default. The scripted coach
// remains the default and the safety pipeline (guardrail → crisis →
// model → keywords) is never reordered.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---- device tier ----

enum DeviceTier {
  low, // < 3 GB — deeper chat hidden
  medium, // 3–6 GB — small models only
  high, // 6–8 GB — standard models
  premium, // 8+ GB — larger models
}

// ---- model catalog entry ----

class GgufModelInfo {
  final String id;
  final String name;
  final String description;
  final String downloadUrl;
  final int fileSizeBytes;
  final DeviceTier minTier;
  final int contextWindow;
  final String quantization;
  /// SHA-256 hex for integrity check after download (Gap B).
  /// When null, verification is skipped (legacy catalog entries).
  final String? sha256Hex;

  const GgufModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.downloadUrl,
    required this.fileSizeBytes,
    required this.minTier,
    required this.contextWindow,
    required this.quantization,
    this.sha256Hex,
  });

  String get fileSizeMb => '${(fileSizeBytes / (1024 * 1024)).round()} MB';
}

// ---- download state ----

enum DownloadState { idle, downloading, completed, failed, notDownloaded }

class DownloadProgress {
  final DownloadState state;
  final int downloadedBytes;
  final int totalBytes;

  const DownloadProgress({
    required this.state,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
  });

  double get progress =>
      totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
}

// ---- service ----

class GgufModelService {
  static const String _keyEnabled = 'gguf_enabled_v1';
  static const String _keySelectedModel = 'gguf_selected_model_v1';
  static const String _keyDownloadedModels = 'gguf_downloaded_v1';

  static final GgufModelService _instance = GgufModelService._();
  factory GgufModelService() => _instance;
  GgufModelService._();

  DeviceTier _deviceTier = DeviceTier.low;
  bool _tierDetected = false;

  // ---- model catalog (2026 research, ASK-1 + Gap B) ----
  // Adaptive defaulting (Gemini ASK-1 Option 3): Gemma 3 270M QAT fits ~350 MB RSS
  // on 4 GB Moto G 2025. We KEEP opt-in (privacy/metered-data) but surface a
  // one-time suggestion for medium tier instead of silent auto-download.
  // SHA-256 TODO: fill from `sha256sum` of verified HF download; when present
  // downloadModel will verify and retry once (see downloadModel below).

  static const List<GgufModelInfo> catalog = [
    GgufModelInfo(
      id: 'gemma3_270m',
      name: 'Gemma 3 270M',
      description:
          'Google\'s smallest instruct model. Fast, lightweight, good for short replies.',
      // NOTE: HF resolve URLs are case-sensitive — quant suffix must be
      // uppercase exactly as published (Q4_K_M, not q4_k_m).
      downloadUrl:
          'https://huggingface.co/lmstudio-community/gemma-3-270m-it-GGUF/resolve/main/gemma-3-270m-it-Q4_K_M.gguf',
      fileSizeBytes: 253 * 1024 * 1024, // ~253 MB per HF files table
      minTier: DeviceTier.medium,
      contextWindow: 4096,
      quantization: 'Q4_K_M',
      sha256Hex: null, // TODO: populate after verified download
    ),
    GgufModelInfo(
      id: 'qwen35_08b',
      name: 'Qwen3.5 0.8B',
      description:
          'Alibaba\'s 2026 compact model. Best balance of quality and size for 4–6 GB devices.',
      downloadUrl:
          'https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf',
      fileSizeBytes: 530 * 1024 * 1024, // ~530 MB
      minTier: DeviceTier.medium,
      contextWindow: 8192,
      quantization: 'Q4_K_M',
      sha256Hex: null,
    ),
    GgufModelInfo(
      id: 'smollm2_17b',
      name: 'SmolLM2 1.7B',
      description:
          'Hugging Face\'s 1.7B model. Best quality for 8 GB devices. Apache 2.0.',
      downloadUrl:
          'https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf',
      fileSizeBytes: 1100 * 1024 * 1024, // ~1.1 GB
      minTier: DeviceTier.high,
      contextWindow: 8192,
      quantization: 'Q4_K_M',
      sha256Hex: null,
    ),
    GgufModelInfo(
      id: 'phi4mini',
      name: 'Phi-4 Mini',
      description:
          'Microsoft\'s 3.8B reasoning model. Best quality sub-4B. MIT license.',
      downloadUrl:
          'https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf',
      fileSizeBytes: 2700 * 1024 * 1024, // ~2.7 GB
      minTier: DeviceTier.premium,
      contextWindow: 16384,
      quantization: 'Q4_K_M',
      sha256Hex: null,
    ),
  ];

  /// Models available for this device (filtered by tier).
  List<GgufModelInfo> get availableModels => catalog
      .where((m) => m.minTier.index <= _deviceTier.index)
      .toList();

  // ---- device tier detection ----

  Future<DeviceTier> detectDeviceTier() async {
    if (_tierDetected) return _deviceTier;
    try {
      if (Platform.isAndroid) {
        final memInfo = await File('/proc/meminfo').readAsString();
        final match =
            RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(memInfo);
        if (match != null) {
          final totalGb =
              int.parse(match.group(1)!) / (1024 * 1024);
          _deviceTier = totalGb < 3
              ? DeviceTier.low
              : totalGb < 6
                  ? DeviceTier.medium
                  : totalGb < 8
                      ? DeviceTier.high
                      : DeviceTier.premium;
        }
      } else {
        // Non-Android (dev/testing) — assume high tier
        _deviceTier = DeviceTier.high;
      }
    } catch (_) {
      _deviceTier = DeviceTier.medium; // conservative fallback
    }
    _tierDetected = true;
    debugPrint('[gguf] device tier: $_deviceTier');
    return _deviceTier;
  }

  DeviceTier get deviceTier => _deviceTier;

  /// True when the device can support deeper chat at all.
  bool get isSupported => _deviceTier != DeviceTier.low;

  /// R24 Adaptive Router: suggested model for this tier (no auto-download).
  /// Medium+ gets Gemma 3 270M QAT; low gets null (locked to TFLite).
  GgufModelInfo? get suggestedModelForTier {
    if (_deviceTier == DeviceTier.low) return null;
    // Smallest available for tier — Gemma 270M for medium, larger for high/premium if needed
    final avail = availableModels;
    if (avail.isEmpty) return null;
    // Prefer Gemma 270M on medium (smallest, ~350 MB RSS), else smallest
    return avail.firstWhere((m) => m.id == 'gemma3_270m', orElse: () => avail.first);
  }

  /// Ensure a default model is selected for qualifying tiers (no download).
  /// Call after detectDeviceTier(). Leaves existing selection untouched.
  Future<void> ensureDefaultModelForTier() async {
    await detectDeviceTier();
    if (_deviceTier == DeviceTier.low) return;
    final existing = await getSelectedModelId();
    if (existing != null && existing.isNotEmpty) {
      // Populate the synchronous cache so selectedModel agrees with storage.
      _cacheSelected(existing);
      return;
    }
    final suggested = suggestedModelForTier;
    if (suggested != null) {
      await setSelectedModelId(suggested.id);
      debugPrint('[gguf] auto-assigned default model ${suggested.id} for tier $_deviceTier');
    }
  }

  /// True if tier qualifies but suggested model file is missing (show download card).
  Future<bool> needsDownloadForSuggested() async {
    final suggested = suggestedModelForTier;
    if (suggested == null) return false;
    return !(await isModelDownloaded(suggested.id));
  }

  // ---- enabled toggle ----

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }

  // ---- model selection ----

  Future<String?> getSelectedModelId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedModel);
  }

  Future<void> setSelectedModelId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedModel, id);
    _cacheSelected(id);
  }

  /// The model the user actually chose.
  ///
  /// This getter's comment claimed "the last selected, or the smallest
  /// available" but the body only ever returned `models.first` — it never read
  /// `_keySelectedModel`. Every surface showing "current model" therefore
  /// displayed Gemma 270M regardless of the picker's selection, and
  /// disagreed with the id that `chatbot_screen` passes to inference.
  ///
  /// Synchronous by design: `getSelectedModelId()` is async, and this is called
  /// from build(). The cached field is refreshed by [setSelectedModelId] and by
  /// [ensureDefaultModelForTier], and falls back to the smallest available when
  /// nothing has been chosen yet.
  GgufModelInfo? _selectedModelCache;
  bool _selectedCacheLoaded = false;

  GgufModelInfo? get selectedModel {
    final models = availableModels;
    if (models.isEmpty) return null;
    if (_selectedCacheLoaded && _selectedModelCache != null) {
      // Guard against a cached id that the current tier does not offer.
      return models.firstWhere(
        (m) => m.id == _selectedModelCache!.id,
        orElse: () => models.first,
      );
    }
    return models.first;
  }

  /// Called by [setSelectedModelId] and [ensureDefaultModelForTier] so
  /// [selectedModel] stops disagreeing with the persisted choice.
  void _cacheSelected(String? id) {
    if (id == null) {
      _selectedModelCache = null;
      _selectedCacheLoaded = false;
      return;
    }
    GgufModelInfo? found;
    for (final m in catalog) {
      if (m.id == id) {
        found = m;
        break;
      }
    }
    _selectedModelCache = found;
    _selectedCacheLoaded = found != null;
  }

  // ---- download management ----

  /// Human-readable reason the last [downloadModel] failed, for UI
  /// surfacing — "try again later" alone hides real causes (404s,
  /// missing INTERNET permission, timeouts).
  static String? lastDownloadError;

  Future<Set<String>> getDownloadedModels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyDownloadedModels);
    if (raw == null) return {};
    // `.toString()`, not `as String`: one non-String element used to throw with
    // no catch, which took down isModelDownloaded → needsDownloadForSuggested
    // → the GGUF chat path, from a single bad prefs value.
    final List<dynamic> list;
    try {
      list = jsonDecode(raw) as List;
    } catch (_) {
      return {};
    }
    return list.where((e) => e != null).map((e) => e.toString()).toSet();
  }

  Future<bool> isModelDownloaded(String modelId) async {
    return (await getDownloadedModels()).contains(modelId);
  }

  Future<File?> getModelPath(String modelId) async {
    final dir = await _modelDir();
    final file = File('${dir.path}/$modelId.gguf');
    return file.existsSync() ? file : null;
  }

  Future<Directory> _modelDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/gguf_models');
    await dir.create(recursive: true);
    return dir;
  }

  /// Ceiling on the total bytes this feature may occupy.
  ///
  /// The catalog holds four models totalling ~4.6 GB. A user who downloads all
  /// four fills a phone that also holds their journal, their images and the OS
  /// itself, and the failure lands mid-transfer as an opaque ENOSPC. A budget
  /// turns that into a decision made before the transfer starts.
  ///
  /// 3 GB is chosen against the target hardware rather than a round number: the
  /// largest single model is 2.7 GB, so every catalog entry fits, and the two
  /// most likely to be wanted together (Gemma 270M + Phi-4 Mini ≈ 2.6 GB) fit
  /// with room to spare.
  static const int storageBudgetBytes = 3 * 1024 * 1024 * 1024;

  /// Slack reserved for the `.tmp` file coexisting with its final name during
  /// the atomic rename, and for filesystem metadata.
  static const int _writeSlackBytes = 64 * 1024 * 1024;

  /// Total bytes of `.gguf` files currently in the model directory.
  ///
  /// Derived from the filesystem, not from the `gguf_downloaded_models_v1`
  /// prefs set. Prefs can disagree with disk — a user clearing app storage
  /// leaves the names behind, an interrupted download leaves a file without a
  /// prefs entry — and budgeting against a stale set is how you blow the budget.
  Future<int> _bytesUsedOnDisk() async {
    final dir = await _modelDir();
    var total = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      // A `.tmp` in flight counts too: it occupies space and no prefs entry
      // names it, so excluding it is how two concurrent downloads each pass a
      // check the pair cannot satisfy.
      final isModel = lower.endsWith('.gguf') || lower.endsWith('.gguf.tmp');
      if (!isModel) continue;
      total += await entity.length();
    }
    return total;
  }

  /// Checks the download fits the budget, evicting other models if it does not.
  ///
  /// Returns an error message, or null when the download may proceed.
  ///
  /// NOTE ON WHY THIS IS A BUDGET AND NOT A FREE-SPACE PROBE: Dart's
  /// `FileStat.stat(directory).size` reports the size of the *directory entry*
  /// — 4096 bytes on ext4/f2fs — not the free space on the volume. An earlier
  /// version of this file compared that 4096 against the model's size and threw
  /// "Not enough free space: 241 needed, 0 MB available" on every device, which
  /// blocked 100% of downloads while reading as a working safety check. Dart
  /// exposes no cross-platform free-space API (`dart:io` has no
  /// `statvfs`), and shelling out is not an option on Android, so a
  /// self-imposed budget plus eviction is the honest mechanism: it is
  /// enforceable, testable, and cannot silently mis-report.
  ///
  /// A genuinely full volume still surfaces as an error mid-transfer, so the
  /// stream is also watched for ENOSPC — see [_isOutOfSpace].
  Future<String?> _ensureBudget(
    Directory dir,
    GgufModelInfo model,
    String targetPath,
  ) async {
    final needed = model.fileSizeBytes + _writeSlackBytes;

    // The model already on disk does not count against the budget: replacing it
    // needs no extra room beyond the slack.
    var used = await _bytesUsedOnDisk();
    final existing = File(targetPath);
    if (await existing.exists()) used -= await existing.length();

    if (used + needed <= storageBudgetBytes) return null;

    // Evict other models, largest first, until it fits or nothing is left.
    // Largest-first because one eviction should free the most room possible,
    // minimising how many models the user loses to keep the one they asked for.
    final others = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.gguf')) continue;
      if (entity.path == targetPath) continue;
      others.add(entity);
    }
    others.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));

    final prefs = await SharedPreferences.getInstance();
    final downloaded = await getDownloadedModels();
    var freed = 0;
    for (final victim in others) {
      if (used - freed + needed <= storageBudgetBytes) break;
      final size = victim.lengthSync();
      try {
        await victim.delete();
      } on FileSystemException {
        // Could not remove it (still open, or the FS refused) — keep going and
        // see whether a smaller victim frees enough.
        continue;
      }
      freed += size;
      // Keep the prefs mirror honest, or the model list shows a model whose
      // file no longer exists — a state `isModelReady` already guards against,
      // but only after a wasted round trip.
      final id = victim.uri.pathSegments.last.replaceAll(RegExp(r'\.gguf$'), '');
      downloaded.remove(id);
      debugPrint('[gguf] evicted $id (${(size / (1024 * 1024)).round()} MB) '
          'to make room for ${model.id}');
    }

    used -= freed;
    if (used + needed <= storageBudgetBytes) {
      await prefs.setString(
          _keyDownloadedModels, jsonEncode(downloaded.toList()));
      return null;
    }

    return 'Not enough storage: ${model.fileSizeMb} MB needed, and the '
        '${(storageBudgetBytes / (1024 * 1024)).round()} MB budget has only '
        '${((storageBudgetBytes - used) / (1024 * 1024)).round()} MB free. '
        'Delete a downloaded model to free space.';
  }

  /// Whether [e] is an out-of-space failure from the write side.
  ///
  /// POSIX ENOSPC is errno 28 and EDQUOT is 122. `dart:io` surfaces the errno
  /// through `FileSystemException.osError.errorCode`, which is why this cannot
  /// be a substring match on `message`: the same condition reads as "No space
  /// left on device", "Disk quota exceeded", or a bare "Cannot write" depending
  /// on the platform and the FS driver.
  bool _isOutOfSpace(Object e) {
    if (e is! FileSystemException) return false;
    final code = e.osError?.errorCode;
    if (code == 28 || code == 122) return true;
    final m = e.message.toLowerCase();
    return m.contains('no space') || m.contains('quota exceeded');
  }

  /// Test seam for [_ensureBudget].
  ///
  /// Visible for testing because the alternative is a 2 GB download against a
  /// live HTTP host in the test suite — which is why the previous version of
  /// this check shipped broken with no test coverage: the only realistic test
  /// was too expensive to write, so the check was reasoned about instead of
  /// exercised. It returns the error message, or null when the download may
  /// proceed; it does not itself perform a download.
  @visibleForTesting
  Future<String?> ensureBudgetForTest(
    GgufModelInfo model,
    String targetPath,
  ) async {
    final dir = await _modelDir();
    return _ensureBudget(dir, model, targetPath);
  }

/// Downloads a model with streaming progress. Returns true on success.
  /// [onProgress] reports (downloaded, total). Cancel by setting
  /// [isCancelled] to true.
  ///
  /// Storage is governed by [_ensureBudget]: a self-imposed ceiling on total
  /// bytes in the model directory, with largest-first eviction of other models
  /// to make room. The header advertised "Storage management (private app dir,
  /// not Downloads)" while there was none of it — no quota, no eviction — and
  /// the four catalog entries total ~4.6 GB.
  ///
  /// A genuinely full *volume* cannot be predicted from Dart, so the write
  /// stream is also watched for ENOSPC and reported as such rather than as
  /// "try again later".
  Future<bool> downloadModel(
    GgufModelInfo model, {
    void Function(int downloaded, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    lastDownloadError = null;
    try {
      final dir = await _modelDir();
      final file = File('${dir.path}/${model.id}.gguf');
      if (file.existsSync()) return true; // already downloaded

      final tmpFile = File('${dir.path}/${model.id}.gguf.tmp');
      if (tmpFile.existsSync()) await tmpFile.delete(); // clean stale temp

      final budgetError = await _ensureBudget(dir, model, file.path);
      if (budgetError != null) throw Exception(budgetError);

      final client = http.Client();
      try {
        final request =
            http.Request('GET', Uri.parse(model.downloadUrl));
        final response =
            await client.send(request).timeout(const Duration(minutes: 30));

        if (response.statusCode != 200) {
          throw HttpException('Download failed: ${response.statusCode}');
        }

        final totalBytes = response.contentLength ?? model.fileSizeBytes;
        final sink = tmpFile.openWrite();
        var downloaded = 0;

        try {
          await for (final chunk in response.stream) {
            if (isCancelled?.call() ?? false) {
              await sink.flush();
              await sink.close();
              if (tmpFile.existsSync()) await tmpFile.delete();
              throw Exception('Download cancelled by user');
            }
            sink.add(chunk);
            downloaded += chunk.length;
            onProgress?.call(downloaded, totalBytes);
          }
          await sink.flush();
          await sink.close();
        } catch (e) {
          await sink.close();
          if (tmpFile.existsSync()) await tmpFile.delete();
          // A full volume mid-transfer is the one storage failure the budget
          // cannot predict. Report it as such — "No space left on device"
          // instead of a bare ENOSPC string the user cannot act on.
          if (_isOutOfSpace(e)) {
            throw Exception(
                'Ran out of storage part-way through the download '
                '(${model.fileSizeMb} MB model). Free up device space and try '
                'again; the partial file has been deleted.');
          }
          rethrow;
        }
      } finally {
        // Every failure path above — bad status, a mid-stream drop, a user
        // cancel, ENOSPC — used to leave this client open, leaking the socket
        // on a transfer that may already have moved hundreds of MB. Cancelled
        // downloads were the common case: the user backs out of a 2.7 GB
        // model and the connection stays established.
        client.close();
      }

      // SHA-256 verification (Gap B).
      //
      // Streamed, not `readAsBytes()`. These files are up to 2.7 GB and the
      // target devices are the 4-6 GB ones this feature exists for, so loading
      // the whole thing into RAM to hash it is an OOM on exactly the hardware
      // that needs it most.
      if (model.sha256Hex != null) {
        final digest = await sha256.bind(tmpFile.openRead()).first;
        if (digest.toString() != model.sha256Hex) {
          await tmpFile.delete();
          throw Exception(
              'SHA-256 verification failed: expected ${model.sha256Hex}, got $digest');
        }
        debugPrint('[gguf] SHA-256 verified for ${model.id}');
      }

      // Atomic rename: .tmp -> .gguf
      await tmpFile.rename(file.path);

      // Mark as downloaded
      final prefs = await SharedPreferences.getInstance();
      final downloadedSet = await getDownloadedModels();
      downloadedSet.add(model.id);
      await prefs.setString(
          _keyDownloadedModels, jsonEncode(downloadedSet.toList()));

      return true;
    } catch (e) {
      debugPrint('[gguf] download failed: $e');
      lastDownloadError = e.toString();
      return false;
    }
  }

  /// Checks if model file exists AND is reasonably sized (>1MB).
  /// Prevents false positives from partial/corrupt downloads.
  Future<bool> isModelReady(String modelId) async {
    final dir = await _modelDir();
    final file = File('${dir.path}/$modelId.gguf');
    if (!file.existsSync()) return false;
    final size = await file.length();
    return size > 1000000; // 1MB minimum
  }

  Future<void> deleteModel(String modelId) async {
    final dir = await _modelDir();
    final file = File('${dir.path}/$modelId.gguf');
    if (file.existsSync()) await file.delete();
    final downloaded = await getDownloadedModels();
    downloaded.remove(modelId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyDownloadedModels, jsonEncode(downloaded.toList()));
  }

  Future<int> getModelSizeOnDisk(String modelId) async {
    final dir = await _modelDir();
    final file = File('${dir.path}/$modelId.gguf');
    return file.existsSync() ? file.length() : 0;
  }
}
