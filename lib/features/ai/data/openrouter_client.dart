import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class OpenRouterClient {
  OpenRouterClient({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final String model;
  final http.Client _client;

  Future<String> completeText({
    required String prompt,
    List<Uint8List>? images,
    bool jsonMode = false,
  }) async {
    final messages = [
      {
        'role': 'user',
        'content': _buildContent(prompt, images),
      },
    ];

    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      if (jsonMode) 'response_format': {'type': 'json_object'},
      'temperature': 0.4,
    };

    final response = await _client.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('OpenRouter error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw StateError('OpenRouter returned no choices.');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw StateError('OpenRouter returned empty content.');
    }
    return content;
  }

  Map<String, String> _headers() {
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://stickerforge.app',
      'X-Title': 'Sticker Forge',
    };
  }

  List<Map<String, Object>> _buildContent(String prompt, List<Uint8List>? images) {
    final content = <Map<String, Object>>[
      {'type': 'text', 'text': prompt},
    ];
    if (images != null && images.isNotEmpty) {
      for (final bytes in images) {
        final base64 = base64Encode(bytes);
        content.add({
          'type': 'image_url',
          'image_url': {'url': 'data:image/png;base64,$base64'},
        });
      }
    }
    return content;
  }
}
