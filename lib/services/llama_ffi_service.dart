// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef InitModelNative = Pointer<Void> Function(Pointer<Utf8> modelPath);
typedef InitModelDart = Pointer<Void> Function(Pointer<Utf8> modelPath);

typedef GenerateTextNative = Pointer<Utf8> Function(
    Pointer<Void> ctx, Pointer<Utf8> prompt, Int32 maxTokens);
typedef GenerateTextDart = Pointer<Utf8> Function(
    Pointer<Void> ctx, Pointer<Utf8> prompt, int maxTokens);

typedef FreeModelNative = Void Function(Pointer<Void> ctx);
typedef FreeModelDart = void Function(Pointer<Void> ctx);

typedef FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef FreeStringDart = void Function(Pointer<Utf8> ptr);

class LlamaFfiService {
  late final DynamicLibrary _lib;
  late final InitModelDart _initModel;
  late final GenerateTextDart _generateText;
  late final FreeModelDart _freeModel;
  late final FreeStringDart _freeString;

  Pointer<Void>? _modelContext;

  LlamaFfiService() {
    _lib = _loadLibrary();
    _initModel = _lib
        .lookup<NativeFunction<InitModelNative>>('init_model')
        .asFunction<InitModelDart>();
    _generateText = _lib
        .lookup<NativeFunction<GenerateTextNative>>('generate_text')
        .asFunction<GenerateTextDart>();
    _freeModel = _lib
        .lookup<NativeFunction<FreeModelNative>>('free_model')
        .asFunction<FreeModelDart>();
    _freeString = _lib
        .lookup<NativeFunction<FreeStringNative>>('free_string')
        .asFunction<FreeStringDart>();
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libllama_wrapper.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('llama_wrapper.dll');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libllama_wrapper.dylib');
    } else {
      return DynamicLibrary.open('libllama_wrapper.so');
    }
  }

  bool loadModel(String modelPath) {
    if (_modelContext != null) {
      unloadModel();
    }
    final pathPtr = modelPath.toNativeUtf8();
    try {
      _modelContext = _initModel(pathPtr);
      return _modelContext != null && _modelContext!.address != 0;
    } finally {
      calloc.free(pathPtr);
    }
  }

  String generate(String prompt, int maxTokens) {
    if (_modelContext == null || _modelContext!.address == 0) {
      return '';
    }
    final promptPtr = prompt.toNativeUtf8();
    Pointer<Utf8>? resultPtr;
    try {
      resultPtr = _generateText(_modelContext!, promptPtr, maxTokens);
      if (resultPtr == nullptr) {
        return '';
      }
      return resultPtr.toDartString();
    } finally {
      calloc.free(promptPtr);
      if (resultPtr != null && resultPtr != nullptr) {
        _freeString(resultPtr);
      }
    }
  }

  void unloadModel() {
    if (_modelContext != null && _modelContext!.address != 0) {
      _freeModel(_modelContext!);
      _modelContext = null;
    }
  }
}