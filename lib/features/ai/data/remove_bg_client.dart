import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Client for remove.bg API (background removal).
/// Get a free API key at https://remove.bg/api
class RemoveBgClient {
  RemoveBgClient({required this.apiKey, http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _url = 'https://api.remove.bg/v1.0/removebg';

  /// Removes background from [imageBytes]. Returns PNG with transparency.
  Future<Uint8List> removeBackground(Uint8List imageBytes) async {
    final request = http.MultipartRequest('POST', Uri.parse(_url))
      ..headers['X-Api-Key'] = apiKey
      ..fields['size'] = 'auto'
      ..files.add(
        http.MultipartFile.fromBytes(
          'image_file',
          imageBytes,
          filename: 'image.png',
        ),
      );

    final streamed = await _client.send(request).timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw StateError('remove.bg request timed out'),
        );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw StateError(
        'remove.bg error ${response.statusCode}: ${response.body}',
      );
    }

    return response.bodyBytes;
  }
}
