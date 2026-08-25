// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/gguf_inference_service.dart
//
// GGUF on-device inference using llama_cpp_dart. Loads a downloaded
// .gguf model and generates text. Safety: output passes through
// SafetyGuardrailService before display. Falls back to scripted coach
// if model is missing, fails to load, or times out.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'gguf_model_service.dart';

class GgufInferenceService {
  static Llama? _llama;
  static bool _isLoaded = false;
  static String? _loadedModelId;
  static bool _busy = false;

  static bool get isLoaded => _isLoaded;
  static String? get loadedModelId => _loadedModelId;

  /// Loads a GGUF model for inference. Returns true on success.
  static Future<bool> loadModel(String modelId) async {
    if (_isLoaded && _loadedModelId == modelId) return true;
    await unload();
    try {
      final modelFile = await GgufModelService().getModelPath(modelId);
      if (modelFile == null) return false;

      _llama = Llama(
        modelFile.path,
        contextParams: ContextParams()
          ..nCtx = 2048
          ..nBatch = 256,
        samplerParams: SamplerParams()
          ..temp = 0.7
          ..topP = 0.9,
        verbose: false,
      );
      _isLoaded = true;
      _loadedModelId = modelId;
      debugPrint('[gguf] model loaded: $modelId');
      return true;
    } catch (e) {
      debugPrint('[gguf] model load failed: $e');
      _isLoaded = false;
      return false;
    }
  }

  /// Generates a response for the given prompt.
  /// Returns null if the model isn't loaded or generation fails.
  static Future<String?> generate(
    String prompt, {
    int maxTokens = 256,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_isLoaded || _llama == null || _busy) return null;
    _busy = true;
    try {
      _llama!.setPrompt(prompt);
      final buffer = StringBuffer();
      var tokenCount = 0;

      await for (final token in _llama!.generateText()) {
        buffer.write(token);
        tokenCount++;
        if (tokenCount >= maxTokens) break;
      }

      final result = buffer.toString().trim();
      debugPrint('[gguf] generated $tokenCount tokens, ${result.length} chars');
      return result.isEmpty ? null : result;
    } catch (e) {
      debugPrint('[gguf] generation failed: $e');
      return null;
    } finally {
      _busy = false;
    }
  }

  /// Clears the conversation context (start fresh).
  static void clearContext() {
    try {
      _llama?.clear();
    } catch (_) {}
  }

  /// Unloads the model to free RAM.
  static Future<void> unload() async {
    try {
      _llama?.dispose();
    } catch (_) {}
    _llama = null;
    _isLoaded = false;
    _loadedModelId = null;
  }
}
