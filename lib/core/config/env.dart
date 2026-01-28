import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvLoadResult {
  const EnvLoadResult({
    required this.config,
    required this.missingKeys,
    this.errorMessage,
  });

  final EnvConfig? config;
  final List<String> missingKeys;
  final String? errorMessage;

  bool get isValid =>
      config != null && missingKeys.isEmpty && errorMessage == null;
}

class EnvConfig {
  const EnvConfig({
    required this.openRouterModel,
    required this.openRouterApiKey,
    required this.openRouterBaseUrl,
    this.removeBgApiKey,
  });

  final String openRouterModel;
  final String openRouterApiKey;
  final String openRouterBaseUrl;
  final String? removeBgApiKey;
}

class EnvConfigLoader {
  static const _requiredKeys = [
    'OPENROUTER_MODEL',
    'OPENROUTER_API_KEY',
    'OPENROUTER_BASE_URL',
  ];

  static Future<EnvLoadResult> load() async {
    try {
      await dotenv.load(fileName: '.env', mergeWith: const {});
    } catch (error) {
      return EnvLoadResult(
        config: null,
        missingKeys: _requiredKeys,
        errorMessage: 'Unable to load .env. ${error.toString()}',
      );
    }

    String? readValue(String key) {
      final value = dotenv.env[key];
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    }

    // Support both OPENROUTER_* and OPENAI_* (OpenAI-compatible API)
    String? model = readValue('OPENROUTER_MODEL') ?? readValue('OPENAI_MODEL');
    String? apiKey =
        readValue('OPENROUTER_API_KEY') ?? readValue('OPENAI_API_KEY');
    String? baseUrl =
        readValue('OPENROUTER_BASE_URL') ?? readValue('OPENAI_BASE_URL');

    if (model != null && apiKey != null && baseUrl != null) {
      final removeBgKey = readValue('REMOVEBG_API_KEY');
      return EnvLoadResult(
        config: EnvConfig(
          openRouterModel: model,
          openRouterApiKey: apiKey,
          openRouterBaseUrl: baseUrl,
          removeBgApiKey: removeBgKey,
        ),
        missingKeys: const [],
      );
    }

    return EnvLoadResult(
      config: null,
      missingKeys: _requiredKeys,
      errorMessage:
          'Set OPENROUTER_MODEL, OPENROUTER_API_KEY, OPENROUTER_BASE_URL '
          'or OPENAI_MODEL, OPENAI_API_KEY, OPENAI_BASE_URL in .env.',
    );
  }
}
