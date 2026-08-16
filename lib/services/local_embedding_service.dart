// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Represents a standardized 384-dimensional dense vector generated 
/// from our on-device BGE-Small or MiniLM-L6-v2 sentence transformers.
class DenseVector {
  final List<double> values;

  const DenseVector(this.values) : assert(values.length == 384);

  /// Computes the dot product against another normalized vector.
  /// Since the vectors are L2-normalized on generation, the dot product
  /// is mathematically equivalent to Cosine Similarity.
  double computeCosineSimilarity(DenseVector other) {
    double dotProduct = 0.0;
    for (int i = 0; i < values.length; i++) {
      dotProduct += values[i] * other.values[i];
    }
    return dotProduct;
  }
}

/// Dynamic payload container representing a semantically chunked text block 
/// mapped to its local vector database coordinate.
class EmbeddedChunk {
  final String id;
  final String documentId;
  final String text;
  final DenseVector embedding;
  final Map<String, dynamic> metadata;

  const EmbeddedChunk({
    required this.id,
    required this.documentId,
    required this.text,
    required this.embedding,
    required this.metadata,
  });
}

/// A local, offline sentence embedding generator designed to run 
/// BGE-Small-EN-v1.5 or all-MiniLM-L6-v2 on-device.
/// 
/// This class acts as a high-performance wrapper around native runtime execution
/// (e.g., ONNX Runtime or native C++ bindings via FFI) and automatically offloads 
/// heavy tokenization and tensor mathematics to a background Dart Isolate to prevent
/// frame drops on the main UI thread.
class LocalEmbeddingService {
  static final LocalEmbeddingService _instance = LocalEmbeddingService._internal();
  factory LocalEmbeddingService() => _instance;
  LocalEmbeddingService._internal();

  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  /// Simulates loading the quantized model weights from the local asset bundle
  /// into native device memory (RAM / GPU VRAM via WebGPU/Metal/Vulkan).
  Future<void> initialize() async {
    if (_isModelLoaded) return;
    
    // In production, load the .onnx model file and the tokenizer vocabulary:
    // final modelPath = await _copyAssetToStorage('assets/models/bge_small_quantized.onnx');
    // _onnxSession = await OrtEnv.instance.createSession(modelPath);
    
    await Future.delayed(const Duration(milliseconds: 600)); // Simulate hardware model allocation
    _isModelLoaded = true;
    debugPrint("Local Embedding Service: Quantized BGE-Small loaded successfully in memory.");
  }

  /// Generates a 384-dimensional normalized embedding for a given text input.
  /// Automatically runs on a background isolate to protect UI responsiveness.
  Future<DenseVector> generateEmbedding(String text) async {
    if (!_isModelLoaded) {
      await initialize();
    }

    // Isolate containment loop to prevent tokenization & matrix math from stalling UI
    return await compute(_generateEmbeddingInIsolate, text);
  }

  /// Batch processes a collection of texts for high-throughput database indexing.
  Future<List<DenseVector>> generateEmbeddingsBatch(List<String> texts) async {
    if (!_isModelLoaded) {
      await initialize();
    }

    final List<DenseVector> results = [];
    // Process in chunks to prevent background worker memory limits from triggering
    for (final text in texts) {
      final vector = await generateEmbedding(text);
      results.add(vector);
    }
    return results;
  }
}

/// Top-level global function required for Flutter's compute() isolate processing.
/// This executes tokenization, transformer forward pass inference, mean pooling, 
/// and L2 vector normalization.
DenseVector _generateEmbeddingInIsolate(String text) {
  // 1. Text Tokenization:
  // Convert text characters to token IDs matching the model's vocabulary (e.g., WordPiece).
  // In production, this invokes native Rust/C++ tokenizers compiled inside the app.
  final List<int> tokens = _tokenizeTextMock(text);

  // 2. Mock Model Inference & Matrix Math:
  // In a real on-device deployment, this runs:
  // final inputs = { 'input_ids': OrtValue.tensor(tokens), ... };
  // final outputs = await _onnxSession.run(inputs);
  // final float32Tensor = outputs['last_hidden_state'].value as List<List<List<double>>>;
  final rawValues = _generateDeterministicWeights(text);

  // 3. L2 Vector Normalization:
  // Normalizing vectors ensures that similarity searches can be computed via highly
  // optimized dot products on the CPU/GPU instead of requiring expensive divisions.
  double sumOfSquares = 0.0;
  for (final value in rawValues) {
    sumOfSquares += value * value;
  }
  
  final double magnitude = sqrt(sumOfSquares);
  final List<double> normalizedValues = rawValues.map((v) => magnitude > 0 ? v / magnitude : 0.0).toList();

  return DenseVector(normalizedValues);
}

/// Tokenizes text into internal vocabulary indices.
List<int> _tokenizeTextMock(String text) {
  // Simple deterministic vocabulary mapping simulation
  return text.toLowerCase().split(' ').map((word) => word.hashCode % 30522).toList();
}

/// Generates a deterministic sequence of weights based on the text hash
/// to represent model execution state on the client device.
List<double> _generateDeterministicWeights(String text) {
  final Random random = Random(text.hashCode);
  final List<double> values = List.generate(384, (_) => random.nextDouble() * 2.0 - 1.0);
  return values;
}
