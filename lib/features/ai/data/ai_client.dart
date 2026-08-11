import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/ai_settings.dart';

class AiException implements Exception {
  AiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// One client for both supported dialects.
///
/// Chat lives at `/chat/completions` on both. Image generation differs:
/// OpenRouter has a dedicated `POST /images`, OpenAI uses
/// `POST /images/generations` with `size` instead of `aspect_ratio`. Both
/// answer with `{"data":[{"b64_json": "..."}]}`.
class AiClient {
  AiClient({required this.settings, http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final AiSettings settings;
  final http.Client _client;
  static final Random _random = Random();

  static const _chatTimeout = Duration(seconds: 60);
  // Image models routinely take a minute or more.
  static const _imageTimeout = Duration(seconds: 180);

  void close() => _client.close();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${settings.apiKey.trim()}',
        'Content-Type': 'application/json',
        if (settings.provider == AiProvider.openRouter) ...{
          'HTTP-Referer': 'https://sticksy.app',
          'X-Title': 'Sticksy',
        },
      };

  Uri _uri(String path) => Uri.parse('${settings.resolvedBaseUrl}$path');

  // -------------------------------------------------------------------------
  // Text
  // -------------------------------------------------------------------------

  Future<String> chat({
    required String prompt,
    bool jsonMode = false,
    double temperature = 0.8,
  }) async {
    if (settings.provider == AiProvider.pollinations) {
      return _chatPollinations(prompt);
    }

    final body = <String, dynamic>{
      'model': settings.resolvedChatModel,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'temperature': temperature,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    };

    final response = await _post(_uri('/chat/completions'), body, _chatTimeout);
    final decoded = _decodeJson(response);
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw AiException('The model returned no choices.');
    }
    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw AiException('The model returned an empty response.');
    }
    return content.trim();
  }

  /// Keyless text completion: the prompt is the URL, the body is the answer.
  Future<String> _chatPollinations(String prompt) async {
    final uri = Uri(
      scheme: 'https',
      host: 'text.pollinations.ai',
      pathSegments: [prompt],
      queryParameters: {'model': settings.resolvedChatModel},
    );
    http.Response response;
    try {
      response = await _client.get(uri).timeout(_chatTimeout);
    } catch (error) {
      throw AiException(_networkMessage(error));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    final text = response.body.trim();
    if (text.isEmpty) throw AiException('Empty response.');
    return text;
  }

  /// Cheap credential check — lists models rather than burning a generation.
  Future<void> verifyCredentials() async {
    if (settings.provider == AiProvider.pollinations) {
      // Nothing to authenticate; just prove the service is reachable.
      try {
        final base = Uri.parse(settings.resolvedBaseUrl);
        final response = await _client
            .get(base.replace(path: '/models'))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode >= 500) {
          throw AiException(
            'The free generator is down right now (${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }
      } on AiException {
        rethrow;
      } catch (error) {
        throw AiException(_networkMessage(error));
      }
      return;
    }

    try {
      final response = await _client
          .get(_uri('/models'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AiException(
          'Key rejected (${response.statusCode}). Check that it is active '
          'and has credit.',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode >= 500) {
        throw AiException(
          'Provider is unavailable right now (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    } on AiException {
      rethrow;
    } catch (error) {
      throw AiException(_networkMessage(error));
    }
  }

  // -------------------------------------------------------------------------
  // Images
  // -------------------------------------------------------------------------

  /// Returns raw image bytes (PNG unless the provider says otherwise).
  Future<Uint8List> generateImage({
    required String prompt,
    bool preferTransparent = true,
  }) async {
    final preset = settings.imagePreset;
    final wantsTransparent = preferTransparent && preset.transparentBackground;

    if (settings.provider == AiProvider.pollinations) {
      return _generateImagePollinations(prompt);
    }

    if (settings.provider == AiProvider.openAi) {
      final body = <String, dynamic>{
        'model': settings.resolvedImageModel,
        'prompt': prompt,
        'n': 1,
        'size': '1024x1024',
        if (preset.quality) 'quality': 'high',
        if (preset.outputFormat) 'output_format': 'png',
        if (wantsTransparent) 'background': 'transparent',
      };
      final response = await _post(
        _uri('/images/generations'),
        body,
        _imageTimeout,
      );
      return _imageFromDataArray(_decodeJson(response));
    }

    final body = <String, dynamic>{
      'model': settings.resolvedImageModel,
      'prompt': prompt,
      'n': 1,
      if (preset.aspectRatio) 'aspect_ratio': '1:1',
      if (preset.resolution) 'resolution': '1K',
      if (preset.quality) 'quality': 'high',
      if (preset.outputFormat) 'output_format': 'png',
      if (wantsTransparent) 'background': 'transparent',
    };

    http.Response response;
    try {
      response = await _post(_uri('/images'), body, _imageTimeout);
    } on AiException catch (error) {
      // Gateways that predate the dedicated Image API still answer through
      // chat completions with image modalities.
      if (error.statusCode == 404 || error.statusCode == 405) {
        return _generateImageViaChat(prompt);
      }
      rethrow;
    }
    return _imageFromDataArray(_decodeJson(response));
  }

  /// Keyless tier: the whole request is a URL.
  ///
  /// `GET https://image.pollinations.ai/prompt/<text>` answers with image bytes
  /// directly — no JSON envelope, no Authorization header. Built with
  /// [Uri.pathSegments] so the prompt is percent-encoded properly and a stray
  /// slash can't invent a new path segment.
  Future<Uint8List> _generateImagePollinations(String prompt) async {
    final base = Uri.parse(settings.resolvedBaseUrl);
    final uri = Uri(
      scheme: base.scheme.isEmpty ? 'https' : base.scheme,
      host: base.host,
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        'prompt',
        prompt,
      ],
      queryParameters: {
        'model': settings.resolvedImageModel,
        'width': '1024',
        'height': '1024',
        'nologo': 'true',
        'private': 'true',
        'safe': 'true',
        // Without a seed the service happily returns a cached image for a
        // repeated prompt, so "Try again" would do nothing.
        'seed': _random.nextInt(1 << 31).toString(),
      },
    );

    http.Response response;
    try {
      response = await _client.get(uri).timeout(_imageTimeout);
    } catch (error) {
      throw AiException(_networkMessage(error));
    }

    if (response.statusCode == 429) {
      throw AiException(
        'The free generator is busy right now. Wait a few seconds and try '
        'again, or connect your own key in Settings → AI for no queue.',
        statusCode: 429,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }

    final bytes = response.bodyBytes;
    if (!_looksLikeImage(bytes)) {
      throw AiException(
        'The free generator returned something that is not an image. Try a '
        'different description.',
      );
    }
    return bytes;
  }

  /// Magic-number sniff so an HTML error page served with status 200 doesn't
  /// get handed to the decoder as if it were a picture.
  static bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 12) return false;
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // RIFF....WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  Future<Uint8List> _generateImageViaChat(String prompt) async {
    final body = <String, dynamic>{
      'model': settings.resolvedImageModel,
      'modalities': ['image', 'text'],
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    };
    final response = await _post(
      _uri('/chat/completions'),
      body,
      _imageTimeout,
    );
    final decoded = _decodeJson(response);
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final message = (choices.first as Map)['message'];
      final images = message is Map ? message['images'] : null;
      if (images is List && images.isNotEmpty) {
        final first = images.first;
        final url = first is Map
            ? (first['image_url'] is Map
                ? (first['image_url'] as Map)['url']
                : first['url'])
            : null;
        if (url is String) return _bytesFromUrlOrDataUrl(url);
      }
    }
    throw AiException('The model replied without an image.');
  }

  Future<Uint8List> _imageFromDataArray(Map<String, dynamic> decoded) async {
    final data = decoded['data'];
    if (data is! List || data.isEmpty) {
      throw AiException('The provider returned no image data.');
    }
    final first = data.first;
    if (first is! Map) {
      throw AiException('Unexpected image payload from the provider.');
    }

    final b64 = first['b64_json'];
    if (b64 is String && b64.isNotEmpty) {
      try {
        return base64Decode(b64);
      } on FormatException {
        throw AiException('The provider returned a corrupt image.');
      }
    }

    final url = first['url'];
    if (url is String && url.isNotEmpty) return _bytesFromUrlOrDataUrl(url);

    throw AiException('The provider returned no image data.');
  }

  Future<Uint8List> _bytesFromUrlOrDataUrl(String url) async {
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      if (comma == -1) throw AiException('Malformed image data URL.');
      try {
        return base64Decode(url.substring(comma + 1));
      } on FormatException {
        throw AiException('The provider returned a corrupt image.');
      }
    }
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw AiException('Could not download the generated image.');
      }
      return response.bodyBytes;
    } on AiException {
      rethrow;
    } catch (error) {
      throw AiException(_networkMessage(error));
    }
  }

  // -------------------------------------------------------------------------
  // Plumbing
  // -------------------------------------------------------------------------

  Future<http.Response> _post(
    Uri uri,
    Map<String, dynamic> body,
    Duration timeout,
  ) async {
    if (!settings.isConfigured) {
      throw AiException('No API key set. Add one in Settings → AI.');
    }

    http.Response response;
    try {
      response = await _client
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(timeout);
    } catch (error) {
      throw AiException(_networkMessage(error));
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw AiException(
      _errorMessage(response),
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw AiException('Unexpected response shape from the provider.');
    } on AiException {
      rethrow;
    } catch (_) {
      throw AiException('Could not parse the provider response.');
    }
  }

  String _errorMessage(http.Response response) {
    String? detail;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          detail = error['message'] as String;
        } else if (error is String) {
          detail = error;
        } else if (decoded['message'] is String) {
          detail = decoded['message'] as String;
        }
      }
    } catch (_) {
      // Fall through to the status-based message.
    }

    switch (response.statusCode) {
      case 401:
      case 403:
        return detail ?? 'API key rejected. Check it in Settings → AI.';
      case 402:
        return detail ?? 'Out of credit on this account.';
      case 404:
        return detail ?? 'Model or endpoint not found. Check the model id.';
      case 429:
        return detail ?? 'Rate limited. Wait a moment and try again.';
      default:
        if (detail != null && detail.trim().isNotEmpty) return detail;
        return 'Request failed (${response.statusCode}).';
    }
  }

  String _networkMessage(Object error) {
    if (error is SocketException) {
      return 'No internet connection.';
    }
    if (error.toString().contains('TimeoutException')) {
      return 'The provider took too long to respond. Try again, or pick a '
          'faster model in Settings → AI.';
    }
    if (error is http.ClientException) {
      return 'Network error: ${error.message}';
    }
    return 'Network error: $error';
  }
}
