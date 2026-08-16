// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/core/native_service.dart

import '../services/llama_ffi_service.dart';

class NativeService {
  static final LlamaFfiService _ffi = LlamaFfiService();

  static bool loadModel(String modelPath) {
    return _ffi.loadModel(modelPath);
  }

  static String generate(String prompt, {int maxTokens = 128}) {
    return _ffi.generate(prompt, maxTokens);
  }

  static void unloadModel() {
    _ffi.unloadModel();
  }
}
