// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  /// Standard local Ollama endpoint. Optional feature: unreachable
  /// server simply falls back to the scripted coach downstream.
  static const String defaultBaseUrl = 'http://127.0.0.1:11434';
  static const String defaultModelName = 'qwen2.5';

  final String baseUrl;
  final String modelName;

  OllamaService({
    this.baseUrl = defaultBaseUrl,
    this.modelName = defaultModelName,
  });

  Future<String> generateResponse(String prompt, {Map<String, dynamic>? options}) async {
    final url = Uri.parse('$baseUrl/api/generate');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': modelName,
        'prompt': prompt,
        'stream': false,
        'options': ?options,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'] as String;
    } else {
      throw Exception('Ollama API error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<String> chat(List<Map<String, String>> messages, {Map<String, dynamic>? options}) async {
    final url = Uri.parse('$baseUrl/api/chat');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': modelName,
        'messages': messages,
        'stream': false,
        'options': ?options,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message']['content'] as String;
    } else {
      throw Exception('Ollama API error: ${response.statusCode} - ${response.body}');
    }
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