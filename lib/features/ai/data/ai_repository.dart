import 'dart:convert';
import 'dart:typed_data';

import '../../../core/utils/result.dart';
import 'openrouter_client.dart';
import 'remove_bg_client.dart';

abstract class AiRepository {
  Future<Result<Uint8List>> removeBackground(Uint8List imageBytes);
  Future<Result<Uint8List>> stylizeSticker(
    Uint8List imageBytes,
    String style,
  );
  Future<Result<List<String>>> generateIdeas(String prompt);
  Future<Result<String>> generateStickerName(String prompt);
}

class AiRepositoryImpl implements AiRepository {
  AiRepositoryImpl({
    required this.chatClient,
    required this.removeBgClient,
  });

  final OpenRouterClient? chatClient;
  final RemoveBgClient? removeBgClient;

  bool get _chatEnabled => chatClient != null;

  @override
  Future<Result<Uint8List>> removeBackground(Uint8List imageBytes) async {
    if (removeBgClient != null) {
      try {
        final png = await removeBgClient!.removeBackground(imageBytes);
        return Result.success(png);
      } catch (e) {
        return Result.failure('Удаление фона (remove.bg): $e');
      }
    }
    return Result.failure(
      'Добавьте REMOVEBG_API_KEY в .env для удаления фона. '
      'Бесплатный ключ: remove.bg/api',
    );
  }

  @override
  Future<Result<Uint8List>> stylizeSticker(
    Uint8List imageBytes,
    String style,
  ) async {
    return Result.failure(
      'Стили (Cartoon, Pixel, Sketch) пока не поддерживаются. '
      'Используйте «Удаление фона» или «Генератор идей».',
    );
  }

  @override
  Future<Result<List<String>>> generateIdeas(String prompt) async {
    if (!_chatEnabled) {
      return Result.failure('Настройте OPENAI_* или OPENROUTER_* в .env.');
    }
    try {
      final response = await chatClient!.completeText(
        prompt: 'Generate sticker ideas for: "$prompt". '
            'Return JSON with "ideas" as a string array.',
        jsonMode: true,
      );
      final parsed = jsonDecode(response) as Map<String, dynamic>;
      final ideas = (parsed['ideas'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList();
      if (ideas == null || ideas.isEmpty) {
        return Result.failure('Нет идей в ответе. Попробуйте другой запрос.');
      }
      return Result.success(ideas);
    } catch (e) {
      return Result.failure('Идеи: $e');
    }
  }

  @override
  Future<Result<String>> generateStickerName(String prompt) async {
    if (!_chatEnabled) {
      return Result.failure('Настройте OPENAI_* или OPENROUTER_* в .env.');
    }
    try {
      final response = await chatClient!.completeText(
        prompt: 'Generate a short, catchy sticker name for: "$prompt". '
            'Return JSON with "name" as a string.',
        jsonMode: true,
      );
      final parsed = jsonDecode(response) as Map<String, dynamic>;
      final name = parsed['name'] as String?;
      if (name == null || name.isEmpty) {
        return Result.failure('Нет имени в ответе.');
      }
      return Result.success(name);
    } catch (e) {
      return Result.failure('Имя: $e');
    }
  }
}
