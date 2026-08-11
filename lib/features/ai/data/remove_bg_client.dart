import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'ai_client.dart';

/// remove.bg background removal. Optional — Sticksy falls back to its own
/// local cutout when no key is present. Free keys: https://remove.bg/api
class RemoveBgClient {
  RemoveBgClient({required this.apiKey, http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static final Uri _endpoint = Uri.parse('https://api.remove.bg/v1.0/removebg');

  void close() => _client.close();

  /// Returns a PNG with transparency.
  Future<Uint8List> removeBackground(Uint8List imageBytes) async {
    final request = http.MultipartRequest('POST', _endpoint)
      ..headers['X-Api-Key'] = apiKey.trim()
      ..fields['size'] = 'auto'
      ..fields['format'] = 'png'
      ..files.add(
        http.MultipartFile.fromBytes(
          'image_file',
          imageBytes,
          filename: 'sticker.png',
        ),
      );

    http.Response response;
    try {
      final streamed =
          await _client.send(request).timeout(const Duration(seconds: 90));
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw AiException('No internet connection.');
    } catch (error) {
      if (error.toString().contains('TimeoutException')) {
        throw AiException('remove.bg took too long to respond.');
      }
      throw AiException('Could not reach remove.bg: $error');
    }

    if (response.statusCode != 200) {
      throw AiException(
        _describe(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    }
    if (response.bodyBytes.isEmpty) {
      throw AiException('remove.bg returned an empty image.');
    }
    return response.bodyBytes;
  }

  String _describe(int status, String body) {
    switch (status) {
      case 401:
      case 403:
        return 'remove.bg key rejected. Check it in Settings → AI.';
      case 402:
        return 'remove.bg credits exhausted for this key.';
      case 429:
        return 'remove.bg rate limit reached. Try again shortly.';
      default:
        final trimmed = body.trim();
        if (trimmed.isEmpty) return 'remove.bg error ($status).';
        return trimmed.length > 180
            ? '${trimmed.substring(0, 180)}…'
            : trimmed;
    }
  }
}
