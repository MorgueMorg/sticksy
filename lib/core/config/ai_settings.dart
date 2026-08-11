import 'package:shared_preferences/shared_preferences.dart';

/// Which HTTP dialect to speak.
///
/// - [pollinations] is keyless: a plain `GET /prompt/<text>` that responds with
///   image bytes. It is the default so the app generates stickers out of the
///   box, with no account and no card.
/// - [openRouter] uses the dedicated `POST /images` endpoint returning
///   `{"data":[{"b64_json": ...}]}`.
/// - [openAi] uses `POST /images/generations` with `size` instead of
///   `aspect_ratio`.
enum AiProvider { pollinations, openRouter, openAi }

extension AiProviderX on AiProvider {
  String get id => name;

  /// False only for the keyless free tier.
  bool get requiresKey => this != AiProvider.pollinations;

  String get label => switch (this) {
        AiProvider.pollinations => 'Free',
        AiProvider.openRouter => 'OpenRouter',
        AiProvider.openAi => 'OpenAI',
      };

  String get tagline => switch (this) {
        AiProvider.pollinations =>
          'No key, no account. Slower and simpler art, shared rate limits.',
        AiProvider.openRouter =>
          'Best quality and transparent PNGs. Needs a key with credit.',
        AiProvider.openAi => 'Direct OpenAI billing. Needs a key with credit.',
      };

  String get defaultBaseUrl => switch (this) {
        AiProvider.pollinations => 'https://image.pollinations.ai',
        AiProvider.openRouter => 'https://openrouter.ai/api/v1',
        AiProvider.openAi => 'https://api.openai.com/v1',
      };

  String get defaultChatModel => switch (this) {
        AiProvider.pollinations => 'openai',
        AiProvider.openRouter => 'google/gemini-2.5-flash',
        AiProvider.openAi => 'gpt-4o-mini',
      };

  String get defaultImageModel => switch (this) {
        AiProvider.pollinations => 'sana',
        AiProvider.openRouter => 'openai/gpt-image-1-mini',
        AiProvider.openAi => 'gpt-image-1',
      };

  String get keyHint => switch (this) {
        AiProvider.pollinations => 'No key needed',
        AiProvider.openRouter => 'sk-or-v1-…  ·  openrouter.ai/keys',
        AiProvider.openAi => 'sk-…  ·  platform.openai.com/api-keys',
      };

  static AiProvider fromId(String? value) {
    return AiProvider.values.firstWhere(
      (provider) => provider.id == value,
      orElse: () => AiProvider.pollinations,
    );
  }
}

/// A known image model plus the request parameters its endpoint actually
/// accepts. Sending an unsupported parameter is a 400, so this matters.
class ImageModelPreset {
  const ImageModelPreset({
    required this.id,
    required this.label,
    required this.blurb,
    required this.provider,
    this.transparentBackground = false,
    this.quality = false,
    this.aspectRatio = false,
    this.resolution = false,
    this.outputFormat = false,
  });

  final String id;
  final String label;
  final String blurb;
  final AiProvider provider;

  /// Can return a PNG with a real alpha channel — ideal for stickers.
  final bool transparentBackground;
  final bool quality;
  final bool aspectRatio;
  final bool resolution;
  final bool outputFormat;

  static const List<ImageModelPreset> all = [
    ImageModelPreset(
      id: 'sana',
      label: 'DreamShaper',
      blurb: 'Free and fast. Sticksy cuts the background out on device.',
      provider: AiProvider.pollinations,
    ),
    ImageModelPreset(
      id: 'flux',
      label: 'FLUX Schnell',
      blurb: 'Nicer detail. May be unavailable without a Pollinations account.',
      provider: AiProvider.pollinations,
    ),
    ImageModelPreset(
      id: 'openai/gpt-image-1-mini',
      label: 'GPT Image 1 Mini',
      blurb: 'Transparent PNG out of the box. Best default for stickers.',
      provider: AiProvider.openRouter,
      transparentBackground: true,
      quality: true,
      aspectRatio: true,
      outputFormat: true,
    ),
    ImageModelPreset(
      id: 'openai/gpt-image-1',
      label: 'GPT Image 1',
      blurb: 'Same transparency, sharper results, costs more.',
      provider: AiProvider.openRouter,
      transparentBackground: true,
      quality: true,
      aspectRatio: true,
      outputFormat: true,
    ),
    ImageModelPreset(
      id: 'google/gemini-3.1-flash-image',
      label: 'Nano Banana 2',
      blurb: 'Fast and cheap. No alpha — Sticksy cuts the background locally.',
      provider: AiProvider.openRouter,
      aspectRatio: true,
      resolution: true,
    ),
    ImageModelPreset(
      id: 'google/gemini-2.5-flash-image',
      label: 'Nano Banana',
      blurb: 'The original. Cheap, solid, needs the local cutout.',
      provider: AiProvider.openRouter,
      aspectRatio: true,
    ),
    ImageModelPreset(
      id: 'black-forest-labs/flux.2-klein-4b',
      label: 'FLUX.2 Klein',
      blurb: 'Stylised and inexpensive. Needs the local cutout.',
      provider: AiProvider.openRouter,
      aspectRatio: true,
      outputFormat: true,
    ),
    ImageModelPreset(
      id: 'gpt-image-1',
      label: 'GPT Image 1',
      blurb: 'Transparent PNG direct from OpenAI.',
      provider: AiProvider.openAi,
      transparentBackground: true,
      quality: true,
      outputFormat: true,
    ),
    ImageModelPreset(
      id: 'gpt-image-1-mini',
      label: 'GPT Image 1 Mini',
      blurb: 'Cheaper OpenAI option, still transparent.',
      provider: AiProvider.openAi,
      transparentBackground: true,
      quality: true,
      outputFormat: true,
    ),
  ];

  static List<ImageModelPreset> forProvider(AiProvider provider) {
    return all.where((preset) => preset.provider == provider).toList();
  }

  /// Falls back to a permissive descriptor for models typed in by hand.
  static ImageModelPreset resolve(AiProvider provider, String id) {
    for (final preset in all) {
      if (preset.provider == provider && preset.id == id) return preset;
    }
    return ImageModelPreset(
      id: id,
      label: id,
      blurb: 'Custom model.',
      provider: provider,
      aspectRatio: provider == AiProvider.openRouter,
    );
  }
}

/// Everything the AI features need, owned by the user rather than baked into
/// the binary. Replaces the old bundled `.env`, which shipped an empty key and
/// broke the app on launch when it could not be parsed.
class AiSettings {
  const AiSettings({
    this.provider = AiProvider.pollinations,
    this.apiKey = '',
    this.baseUrl = '',
    this.chatModel = '',
    this.imageModel = '',
    this.removeBgApiKey = '',
  });

  final AiProvider provider;
  final String apiKey;
  final String baseUrl;
  final String chatModel;
  final String imageModel;
  final String removeBgApiKey;

  /// The free provider needs no credentials, so generation is available from
  /// a cold install with nothing configured.
  bool get isConfigured =>
      !provider.requiresKey || apiKey.trim().isNotEmpty;

  bool get hasRemoveBg => removeBgApiKey.trim().isNotEmpty;

  /// True when the user is on the keyless tier — used to set expectations
  /// about quality and rate limits in the UI.
  bool get isFreeTier => !provider.requiresKey;

  String get resolvedBaseUrl {
    final value = baseUrl.trim();
    final raw = value.isEmpty ? provider.defaultBaseUrl : value;
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  String get resolvedChatModel {
    final value = chatModel.trim();
    return value.isEmpty ? provider.defaultChatModel : value;
  }

  String get resolvedImageModel {
    final value = imageModel.trim();
    return value.isEmpty ? provider.defaultImageModel : value;
  }

  ImageModelPreset get imagePreset =>
      ImageModelPreset.resolve(provider, resolvedImageModel);

  AiSettings copyWith({
    AiProvider? provider,
    String? apiKey,
    String? baseUrl,
    String? chatModel,
    String? imageModel,
    String? removeBgApiKey,
  }) {
    return AiSettings(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      chatModel: chatModel ?? this.chatModel,
      imageModel: imageModel ?? this.imageModel,
      removeBgApiKey: removeBgApiKey ?? this.removeBgApiKey,
    );
  }

  /// Switching provider resets model/base-url overrides that belonged to the
  /// old one, otherwise you end up posting OpenRouter slugs to OpenAI.
  AiSettings withProvider(AiProvider next) {
    if (next == provider) return this;
    return AiSettings(
      provider: next,
      apiKey: '',
      baseUrl: '',
      chatModel: '',
      imageModel: '',
      removeBgApiKey: removeBgApiKey,
    );
  }
}

class AiSettingsStore {
  static const _kProvider = 'ai_provider';
  static const _kApiKey = 'ai_api_key';
  static const _kBaseUrl = 'ai_base_url';
  static const _kChatModel = 'ai_chat_model';
  static const _kImageModel = 'ai_image_model';
  static const _kRemoveBg = 'ai_removebg_key';

  Future<AiSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AiSettings(
        provider: AiProviderX.fromId(prefs.getString(_kProvider)),
        apiKey: prefs.getString(_kApiKey) ?? '',
        baseUrl: prefs.getString(_kBaseUrl) ?? '',
        chatModel: prefs.getString(_kChatModel) ?? '',
        imageModel: prefs.getString(_kImageModel) ?? '',
        removeBgApiKey: prefs.getString(_kRemoveBg) ?? '',
      );
    } catch (_) {
      // Never let a broken preference store stop the app from launching.
      return const AiSettings();
    }
  }

  Future<void> save(AiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProvider, settings.provider.id);
    await prefs.setString(_kApiKey, settings.apiKey.trim());
    await prefs.setString(_kBaseUrl, settings.baseUrl.trim());
    await prefs.setString(_kChatModel, settings.chatModel.trim());
    await prefs.setString(_kImageModel, settings.imageModel.trim());
    await prefs.setString(_kRemoveBg, settings.removeBgApiKey.trim());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _kProvider,
      _kApiKey,
      _kBaseUrl,
      _kChatModel,
      _kImageModel,
      _kRemoveBg,
    ]) {
      await prefs.remove(key);
    }
  }
}
