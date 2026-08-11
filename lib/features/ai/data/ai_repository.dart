import 'dart:convert';
import 'dart:typed_data';

import '../../../core/config/ai_settings.dart';
import '../../../core/utils/image_ops.dart';
import '../../../core/utils/result.dart';
import '../domain/sticker_style.dart';
import 'ai_client.dart';
import 'remove_bg_client.dart';

/// Stages reported back to the UI so the progress copy isn't a lie.
enum GenerationStage { prompting, drawing, cutting, outlining, finishing }

extension GenerationStageX on GenerationStage {
  String get label => switch (this) {
        GenerationStage.prompting => 'Writing the brief…',
        GenerationStage.drawing => 'Drawing your sticker…',
        GenerationStage.cutting => 'Cutting out the background…',
        GenerationStage.outlining => 'Adding the die-cut border…',
        GenerationStage.finishing => 'Almost there…',
      };
}

typedef StageCallback = void Function(GenerationStage stage);

class StickerGenerationRequest {
  const StickerGenerationRequest({
    required this.subject,
    required this.style,
    this.outlineWidth = 14,
    this.outlineArgb = 0xFFFFFFFF,
    this.useRemoveBg = false,
  });

  final String subject;
  final StickerStyle style;

  /// 0 disables the die-cut border.
  final int outlineWidth;
  final int outlineArgb;

  /// Prefer remove.bg over the local cutout when a key is configured.
  final bool useRemoveBg;
}

abstract class AiRepository {
  bool get isConfigured;
  bool get hasRemoveBg;

  Future<Result<Uint8List>> generateSticker(
    StickerGenerationRequest request, {
    StageCallback? onStage,
  });

  Future<Result<Uint8List>> removeBackground(Uint8List imageBytes);

  Future<Result<Uint8List>> applyOutline(
    Uint8List imageBytes, {
    int width = 14,
    int argbColor = 0xFFFFFFFF,
  });

  Future<Result<List<String>>> generateIdeas(String topic);

  Future<Result<String>> suggestName(String topic);

  Future<Result<bool>> verifyCredentials();
}

class AiRepositoryImpl implements AiRepository {
  AiRepositoryImpl({required this.settings, AiClient? client, RemoveBgClient? removeBg})
      : _client = client ?? AiClient(settings: settings),
        _removeBg = removeBg ??
            (settings.hasRemoveBg
                ? RemoveBgClient(apiKey: settings.removeBgApiKey)
                : null);

  final AiSettings settings;
  final AiClient _client;
  final RemoveBgClient? _removeBg;

  @override
  bool get isConfigured => settings.isConfigured;

  @override
  bool get hasRemoveBg => _removeBg != null;

  void dispose() {
    _client.close();
    _removeBg?.close();
  }

  // -------------------------------------------------------------------------
  // The headline feature: prompt in, finished sticker out.
  // -------------------------------------------------------------------------

  @override
  Future<Result<Uint8List>> generateSticker(
    StickerGenerationRequest request, {
    StageCallback? onStage,
  }) async {
    if (!isConfigured) return Result.failure(_notConfigured);
    final subject = request.subject.trim();
    if (subject.isEmpty) {
      return Result.failure('Describe the sticker you want first.');
    }

    try {
      final preset = settings.imagePreset;

      onStage?.call(GenerationStage.prompting);
      final prompt = StickerPrompt.build(
        subject: subject,
        style: request.style,
        transparentCapable: preset.transparentBackground,
        compact: settings.provider == AiProvider.pollinations,
      );

      onStage?.call(GenerationStage.drawing);
      var bytes = await _client.generateImage(prompt: prompt);

      // Cut out unless the model already handed back real alpha.
      onStage?.call(GenerationStage.cutting);
      final transparency = await ImageOps.transparencyRatio(bytes);
      if (transparency < 0.02) {
        final removeBg = _removeBg;
        if (request.useRemoveBg && removeBg != null) {
          try {
            bytes = await removeBg.removeBackground(bytes);
          } catch (_) {
            // remove.bg is a nice-to-have; never fail a whole generation on it.
            bytes = (await ImageOps.magicCutout(bytes)).bytes;
          }
        } else {
          bytes = (await ImageOps.magicCutout(bytes)).bytes;
        }
      }

      bytes = await ImageOps.trimTransparent(bytes);

      if (request.outlineWidth > 0) {
        onStage?.call(GenerationStage.outlining);
        bytes = await ImageOps.addOutline(
          bytes,
          width: request.outlineWidth,
          argbColor: request.outlineArgb,
        );
      }

      onStage?.call(GenerationStage.finishing);
      bytes = await ImageOps.fitSquare(bytes, size: 512);

      return Result.success(bytes);
    } on AiException catch (error) {
      return Result.failure(error.message);
    } catch (error) {
      return Result.failure('Generation failed: $error');
    }
  }

  // -------------------------------------------------------------------------
  // Editing helpers
  // -------------------------------------------------------------------------

  @override
  Future<Result<Uint8List>> removeBackground(Uint8List imageBytes) async {
    try {
      final removeBg = _removeBg;
      if (removeBg != null) {
        try {
          return Result.success(await removeBg.removeBackground(imageBytes));
        } on AiException catch (error) {
          // Fall back locally rather than dead-ending the user.
          final local = await ImageOps.magicCutout(imageBytes);
          if (!local.changed) return Result.failure(error.message);
          return Result.success(local.bytes);
        }
      }

      final local = await ImageOps.magicCutout(imageBytes);
      if (!local.changed) {
        return Result.failure(
          'Could not find a flat background to remove. This works best on '
          'images with a plain backdrop — or add a remove.bg key in '
          'Settings → AI for tricky photos.',
        );
      }
      return Result.success(local.bytes);
    } catch (error) {
      return Result.failure('Background removal failed: $error');
    }
  }

  @override
  Future<Result<Uint8List>> applyOutline(
    Uint8List imageBytes, {
    int width = 14,
    int argbColor = 0xFFFFFFFF,
  }) async {
    try {
      final trimmed = await ImageOps.trimTransparent(imageBytes);
      final outlined = await ImageOps.addOutline(
        trimmed,
        width: width,
        argbColor: argbColor,
      );
      return Result.success(await ImageOps.fitSquare(outlined, size: 512));
    } catch (error) {
      return Result.failure('Could not add the outline: $error');
    }
  }

  // -------------------------------------------------------------------------
  // Text helpers
  // -------------------------------------------------------------------------

  @override
  Future<Result<List<String>>> generateIdeas(String topic) async {
    if (!isConfigured) return Result.failure(_notConfigured);
    final seed = topic.trim().isEmpty ? 'a fun everyday sticker pack' : topic.trim();
    try {
      final raw = await _client.chat(
        prompt:
            'Give me 8 sticker ideas for the theme "$seed". Each idea is a '
            'short visual description of one sticker, at most 8 words, no '
            'numbering. Respond with JSON only: {"ideas":["...","..."]}',
        jsonMode: true,
      );
      final parsed = _extractJsonObject(raw);
      final ideas = parsed?['ideas'];
      if (ideas is List) {
        final cleaned = ideas
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (cleaned.isNotEmpty) return Result.success(cleaned);
      }
      // Some models ignore json_object; fall back to line splitting.
      final lines = raw
          .split(RegExp(r'[\n\r]+'))
          .map((line) => line.replaceFirst(RegExp(r'^[\s\-\*\d\.\)]+'), '').trim())
          .where((line) => line.isNotEmpty && line.length < 120)
          .toList();
      if (lines.isNotEmpty) return Result.success(lines.take(8).toList());
      return _ideasFallback('No ideas came back. Try a different theme.');
    } on AiException catch (error) {
      return _ideasFallback(error.message);
    } catch (error) {
      return _ideasFallback('Could not generate ideas: $error');
    }
  }

  /// The keyless text endpoint is best-effort. Rather than dead-ending someone
  /// who just wants a nudge, hand back a shuffled set of prompts that are known
  /// to cut out well.
  Result<List<String>> _ideasFallback(String message) {
    if (settings.provider.requiresKey) return Result.failure(message);
    final pool = [..._offlineIdeas]..shuffle();
    return Result.success(pool.take(8).toList());
  }

  static const _offlineIdeas = [
    'a sleepy cat holding a coffee',
    'a dancing avocado in sunglasses',
    'a tiny dragon breathing confetti',
    'a happy dumpling giving a thumbs up',
    'a grumpy toast with butter hair',
    'an astronaut cat with a balloon',
    'a shy cactus wearing headphones',
    'a pizza slice doing a backflip',
    'a duck in a tiny raincoat',
    'a smiling moon drinking tea',
    'a panda hugging a bamboo laptop',
    'a frog holding a "no thanks" sign',
    'a donut with sleepy eyes',
    'a fox curled up in a scarf',
    'a robot handing over a flower',
    'a ghost waving hello politely',
  ];

  @override
  Future<Result<String>> suggestName(String topic) async {
    if (!isConfigured) return Result.failure(_notConfigured);
    final seed = topic.trim().isEmpty ? 'a sticker' : topic.trim();
    try {
      final raw = await _client.chat(
        prompt:
            'Invent a short, catchy name (2-4 words, no quotes, no emoji) for '
            'a sticker of: "$seed". Respond with JSON only: {"name":"..."}',
        jsonMode: true,
        temperature: 1.0,
      );
      final parsed = _extractJsonObject(raw);
      final name = parsed?['name'];
      if (name is String && name.trim().isNotEmpty) {
        return Result.success(_tidyName(name));
      }
      final fallback = _tidyName(raw);
      if (fallback.isNotEmpty) return Result.success(fallback);
      return Result.failure('No name came back. Try again.');
    } on AiException catch (error) {
      return Result.failure(error.message);
    } catch (error) {
      return Result.failure('Could not generate a name: $error');
    }
  }

  @override
  Future<Result<bool>> verifyCredentials() async {
    if (!isConfigured) return Result.failure(_notConfigured);
    try {
      await _client.verifyCredentials();
      return Result.success(true);
    } on AiException catch (error) {
      return Result.failure(error.message);
    } catch (error) {
      return Result.failure('Could not reach the provider: $error');
    }
  }

  static const _notConfigured =
      'AI is not set up yet. Add your API key in Settings → AI.';

  String _tidyName(String raw) {
    var value = raw.trim();
    value = value.replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '');
    value = value.replaceAll('```', '');
    value = value.replaceAll(RegExp(r'^[\s"‘’“”]+'), '');
    value = value.replaceAll(RegExp(r'[\s"‘’“”]+$'), '');
    if (value.length > 40) value = value.substring(0, 40).trim();
    return value;
  }

  /// Pulls the first balanced `{...}` block out of a response that may be
  /// wrapped in prose or a markdown fence.
  Map<String, dynamic>? _extractJsonObject(String raw) {
    final start = raw.indexOf('{');
    if (start == -1) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < raw.length; i++) {
      final char = raw[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (char == '{') depth++;
      if (char == '}') {
        depth--;
        if (depth == 0) {
          try {
            final decoded = jsonDecode(raw.substring(start, i + 1));
            return decoded is Map<String, dynamic> ? decoded : null;
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }
}

/// Stand-in used before the user has configured anything, so the UI can render
/// a friendly setup prompt instead of null-checking a repository everywhere.
class UnconfiguredAiRepository implements AiRepository {
  const UnconfiguredAiRepository();

  static const _message =
      'AI is not set up yet. Add your API key in Settings → AI.';

  @override
  bool get isConfigured => false;

  @override
  bool get hasRemoveBg => false;

  @override
  Future<Result<Uint8List>> generateSticker(
    StickerGenerationRequest request, {
    StageCallback? onStage,
  }) async =>
      Result.failure(_message);

  @override
  Future<Result<Uint8List>> removeBackground(Uint8List imageBytes) async {
    // The local cutout needs no credentials, so this one still works.
    try {
      final local = await ImageOps.magicCutout(imageBytes);
      if (!local.changed) {
        return Result.failure(
          'Could not find a flat background to remove. Works best on images '
          'with a plain backdrop.',
        );
      }
      return Result.success(local.bytes);
    } catch (error) {
      return Result.failure('Background removal failed: $error');
    }
  }

  @override
  Future<Result<Uint8List>> applyOutline(
    Uint8List imageBytes, {
    int width = 14,
    int argbColor = 0xFFFFFFFF,
  }) async {
    try {
      final trimmed = await ImageOps.trimTransparent(imageBytes);
      final outlined = await ImageOps.addOutline(
        trimmed,
        width: width,
        argbColor: argbColor,
      );
      return Result.success(await ImageOps.fitSquare(outlined, size: 512));
    } catch (error) {
      return Result.failure('Could not add the outline: $error');
    }
  }

  @override
  Future<Result<List<String>>> generateIdeas(String topic) async =>
      Result.failure(_message);

  @override
  Future<Result<String>> suggestName(String topic) async =>
      Result.failure(_message);

  @override
  Future<Result<bool>> verifyCredentials() async => Result.failure(_message);
}
