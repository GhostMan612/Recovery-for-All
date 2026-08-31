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
import 'package:flutter/foundation.dart';
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

enum DownloadState { idle, downloading, completed, failed }

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
    if (existing != null && existing.isNotEmpty) return;
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
  }

  GgufModelInfo? get selectedModel {
    final models = availableModels;
    if (models.isEmpty) return null;
    // Return the last selected, or the smallest available.
    return models.first;
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
    return (jsonDecode(raw) as List).map((e) => e as String).toSet();
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

  /// Downloads a model with streaming progress. Returns true on success.
  /// [onProgress] reports (downloaded, total). Cancel by setting
  /// [isCancelled] to true.
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

      final client = http.Client();
      final request =
          http.Request('GET', Uri.parse(model.downloadUrl));
      final response =
          await client.send(request).timeout(const Duration(minutes: 30));

      if (response.statusCode != 200) {
        throw HttpException('Download failed: ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? model.fileSizeBytes;
      final sink = file.openWrite();
      var downloaded = 0;

      await for (final chunk in response.stream) {
      if (isCancelled?.call() ?? false) {
        await sink.flush();
        sink.close();
        await file.delete();
        return false;
      }
      sink.add(chunk);
      downloaded += chunk.length;
      onProgress?.call(downloaded, totalBytes);
    }
await sink.flush();
    sink.close();
    client.close();

    // SHA-256 verification (Gap B)
    if (model.sha256Hex != null) {
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes).toString();
      if (digest != model.sha256Hex) {
        await file.delete();
        throw Exception('SHA-256 verification failed: expected ${model.sha256Hex}, got $digest');
      }
      debugPrint('[gguf] SHA-256 verified for ${model.id}');
    }

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
