// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/privacy/privacy_capability.dart';

/// Optional network inference on an independently configured Ollama server.
/// No server is contacted without explicit consent for the current session.
class OllamaService {
  static const String defaultBaseUrl =
      String.fromEnvironment('RFA_OLLAMA_BASE_URL', defaultValue: '');
  static const String defaultModelName = 'qwen2.5';

  final String baseUrl;
  final String modelName;

  OllamaService({
    this.baseUrl = defaultBaseUrl,
    this.modelName = defaultModelName,
  });

  Uri _authorizedEndpoint(String action) {
    if (!PrivacyCapabilityService.isGrantedSync(
        PrivacyCapability.ollamaBridge)) {
      throw StateError('Ollama network use requires explicit session consent.');
    }
    final endpoint = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw StateError('No valid Ollama server URL is configured.');
    }
    return Uri.parse('${endpoint}/api/${action}');
  }

  Future<String> generateResponse(
    String prompt, {
    Map<String, dynamic>? options,
  }) async {
    final url = _authorizedEndpoint('generate');
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
    if (response.statusCode != 200) {
      throw StateError('Ollama API returned HTTP ${response.statusCode}.');
    }
    final data = jsonDecode(response.body);
    return data['response'] as String;
  }

  Future<String> chat(
    List<Map<String, String>> messages, {
    Map<String, dynamic>? options,
  }) async {
    final url = _authorizedEndpoint('chat');
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
    if (response.statusCode != 200) {
      throw StateError('Ollama API returned HTTP ${response.statusCode}.');
    }
    final data = jsonDecode(response.body);
    return data['message']['content'] as String;
  }

  Stream<String> chatStream(
    List<Map<String, String>> messages, {
    Map<String, dynamic>? options,
  }) async* {
    final url = _authorizedEndpoint('chat');
    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'model': modelName,
        'messages': messages,
        'stream': true,
        'options': ?options,
      });

    final client = http.Client();
    try {
      final response = await client.send(request).timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        throw StateError('Ollama stream returned HTTP ${response.statusCode}.');
      }
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in stream) {
        if (!PrivacyCapabilityService.isGrantedSync(
            PrivacyCapability.ollamaBridge)) {
          throw StateError('Ollama authorization was revoked during streaming.');
        }
        if (line.trim().isEmpty) continue;
        try {
          final data = jsonDecode(line);
          final msg = data['message'];
          if (msg is! Map) continue;
          final content = msg['content'];
          if (content is String && content.isNotEmpty) yield content;
        } catch (_) {
          // A partial or non-JSON keep-alive line must not kill the stream.
        }
      }
    } finally {
      client.close();
    }
  }
}
