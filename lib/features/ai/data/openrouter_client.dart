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
      {'role': 'user', 'content': _buildContent(prompt, images)},
    ];

    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      if (jsonMode) 'response_format': {'type': 'json_object'},
      'temperature': 0.4,
    };

    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String errorMsg = 'Ошибка API ${response.statusCode}';
        try {
          final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
          final error = errorBody?['error'] as Map<String, dynamic>?;
          errorMsg =
              error?['message'] as String? ??
              errorBody?['message'] as String? ??
              response.body;
        } catch (_) {
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        throw StateError(errorMsg);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw StateError('API не вернул варианты ответа.');
      }
      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.isEmpty) {
        throw StateError('API вернул пустой ответ.');
      }
      return content;
    } on StateError {
      rethrow;
    } catch (e) {
      if (e.toString().contains('timeout') ||
          e.toString().contains('TimeoutException')) {
        throw StateError(
          'Превышено время ожидания ответа от API. Попробуйте позже.',
        );
      }
      throw StateError('Ошибка подключения к API: ${e.toString()}');
    }
  }

  Map<String, String> _headers() {
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://sticksy.app',
      'X-Title': 'Sticksy',
    };
  }

  List<Map<String, Object>> _buildContent(
    String prompt,
    List<Uint8List>? images,
  ) {
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
