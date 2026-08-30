// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  /// R24 Sovereign Mantle bridge: primary is your LAN Ollama at
  /// 192.168.4.144:8000 (qwen2.5 for Pathfinder God / Sovereign Tagger).
  /// Fallback loopback 127.0.0.1:11450 is kept for dev outside LAN.
  /// Optional feature: unreachable server falls back to scripted coach.
  static const String defaultBaseUrl = 'http://192.168.4.144:8000';
  static const String fallbackBaseUrl = 'http://127.0.0.1:11450';
  static const String defaultModelName = 'qwen2.5';

  final String baseUrl;
  final String modelName;

  OllamaService({
    this.baseUrl = defaultBaseUrl,
    this.modelName = defaultModelName,
  });

  Future<String> generateResponse(String prompt, {Map<String, dynamic>? options}) async {
    // Try primary Sovereign Mantle endpoint, fallback to loopback
    for (final candidate in [baseUrl, if (baseUrl != fallbackBaseUrl) fallbackBaseUrl]) {
      try {
        final url = Uri.parse('$candidate/api/generate');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': modelName,
            'prompt': prompt,
            'stream': false,
            'options': ?options,
          }),
        ).timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['response'] as String;
        } else {
          throw Exception('Ollama API error: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        if (candidate == fallbackBaseUrl || candidate == baseUrl && baseUrl == fallbackBaseUrl) rethrow;
        // Try fallback on network failure
        continue;
      }
    }
    throw Exception('Ollama unreachable (tried $baseUrl and $fallbackBaseUrl)');
  }

  Future<String> chat(List<Map<String, String>> messages, {Map<String, dynamic>? options}) async {
    for (final candidate in [baseUrl, if (baseUrl != fallbackBaseUrl) fallbackBaseUrl]) {
      try {
        final url = Uri.parse('$candidate/api/chat');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': modelName,
            'messages': messages,
            'stream': false,
            'options': ?options,
          }),
        ).timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['message']['content'] as String;
        } else {
          throw Exception('Ollama API error: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        if (candidate == fallbackBaseUrl || baseUrl == fallbackBaseUrl) rethrow;
        continue;
      }
    }
    throw Exception('Ollama unreachable');
  }

  Stream<String> chatStream(List<Map<String, String>> messages, {Map<String, dynamic>? options}) async* {
    final url = Uri.parse('$baseUrl/api/chat');
    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'model': modelName,
        'messages': messages,
        'stream': true,
        'options': ?options,
      });

    final response = await http.Client().send(request);

    if (response.statusCode == 200) {
      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in stream) {
        if (line.trim().isEmpty) continue;
        final data = jsonDecode(line);
        final content = data['message']['content'] as String;
        yield content;
      }
    } else {
      throw Exception('Ollama API stream error: ${response.statusCode}');
    }
  }
}