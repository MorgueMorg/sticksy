import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

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
    try {
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        return Result.failure('Не удалось декодировать изображение.');
      }

      img.Image styledImage;
      switch (style.toLowerCase()) {
        case 'cartoon':
          styledImage = _applyCartoonStyle(decodedImage);
          break;
        case 'sketch':
          styledImage = _applySketchStyle(decodedImage);
          break;
        case 'pixel':
          styledImage = _applyPixelStyle(decodedImage);
          break;
        default:
          return Result.failure('Неизвестный стиль: $style');
      }

      final pngBytes = Uint8List.fromList(img.encodePng(styledImage));
      return Result.success(pngBytes);
    } catch (e) {
      return Result.failure('Ошибка стилизации: ${e.toString()}');
    }
  }

  /// Применяет мультяшный стиль к изображению
  img.Image _applyCartoonStyle(img.Image image) {
    // Применяем quantization для уменьшения количества цветов (эффект мультика)
    final quantized = img.quantize(image, numberOfColors: 32, method: img.QuantizeMethod.octree);
    
    // Применяем небольшое размытие для сглаживания
    final blurred = img.gaussianBlur(quantized, radius: 1);
    
    // Увеличиваем контраст для более яркого мультяшного эффекта
    final contrasted = img.adjustColor(blurred, contrast: 1.2, saturation: 1.3);
    
    return contrasted;
  }

  /// Применяет эскизный стиль к изображению
  img.Image _applySketchStyle(img.Image image) {
    // Конвертируем в grayscale
    final grayscale = img.grayscale(image);
    
    // Инвертируем цвета для создания эффекта эскиза
    final inverted = img.copyResize(grayscale, width: grayscale.width, height: grayscale.height);
    for (var y = 0; y < inverted.height; y++) {
      for (var x = 0; x < inverted.width; x++) {
        final pixel = inverted.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final gray = ((r + g + b) / 3).round();
        final invertedGray = (255 - gray).clamp(0, 255);
        inverted.setPixel(x, y, img.ColorRgb8(invertedGray, invertedGray, invertedGray));
      }
    }
    
    // Применяем размытие
    final blurred = img.gaussianBlur(inverted, radius: 2);
    
    // Применяем edge detection (Sobel filter) для создания контуров
    final edges = img.copyResize(blurred, width: blurred.width, height: blurred.height);
    for (var y = 1; y < blurred.height - 1; y++) {
      for (var x = 1; x < blurred.width - 1; x++) {
        final p1 = _getGrayValue(blurred.getPixel(x - 1, y - 1));
        final p2 = _getGrayValue(blurred.getPixel(x, y - 1));
        final p3 = _getGrayValue(blurred.getPixel(x + 1, y - 1));
        final p4 = _getGrayValue(blurred.getPixel(x - 1, y));
        final p6 = _getGrayValue(blurred.getPixel(x + 1, y));
        final p7 = _getGrayValue(blurred.getPixel(x - 1, y + 1));
        final p8 = _getGrayValue(blurred.getPixel(x, y + 1));
        final p9 = _getGrayValue(blurred.getPixel(x + 1, y + 1));
        
        final gx = (-p1 - 2 * p4 - p7 + p3 + 2 * p6 + p9);
        final gy = (-p1 - 2 * p2 - p3 + p7 + 2 * p8 + p9);
        final magnitude = (math.sqrt(gx * gx + gy * gy) * 255).clamp(0, 255).toInt();
        
        edges.setPixel(x, y, img.ColorRgb8(magnitude, magnitude, magnitude));
      }
    }
    
    return edges;
  }
  
  int _getGrayValue(img.Color pixel) {
    return ((pixel.r + pixel.g + pixel.b) / 3).round();
  }

  /// Применяет пиксельный стиль к изображению
  img.Image _applyPixelStyle(img.Image image) {
    // Уменьшаем разрешение для пикселизации
    final pixelSize = 8;
    final smallWidth = (image.width / pixelSize).round();
    final smallHeight = (image.height / pixelSize).round();
    
    final small = img.copyResize(image, width: smallWidth, height: smallHeight, interpolation: img.Interpolation.nearest);
    
    // Увеличиваем обратно с nearest neighbor для сохранения пиксельного эффекта
    final pixelated = img.copyResize(small, width: image.width, height: image.height, interpolation: img.Interpolation.nearest);
    
    // Уменьшаем количество цветов для более выраженного пиксельного эффекта
    final quantized = img.quantize(pixelated, numberOfColors: 16, method: img.QuantizeMethod.octree);
    
    return quantized;
  }

  @override
  Future<Result<List<String>>> generateIdeas(String prompt) async {
    if (!_chatEnabled) {
      return Result.failure('Настройте OPENAI_* или OPENROUTER_* в .env.');
    }
    try {
      final response = await chatClient!.completeText(
        prompt: 'Generate 5-8 creative sticker ideas for: "$prompt". '
            'Return ONLY valid JSON in this exact format: {"ideas": ["idea1", "idea2", ...]}. '
            'Do not include any other text, explanations, or markdown formatting.',
        jsonMode: true,
      );
      
      // Try to extract JSON from response (in case it's wrapped in markdown or text)
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        // Remove markdown code blocks
        jsonStr = jsonStr.replaceFirst(RegExp(r'```(?:json)?\s*'), '');
        jsonStr = jsonStr.replaceFirst(RegExp(r'\s*```'), '');
      }
      jsonStr = jsonStr.trim();
      
      // Try to find JSON object in the response (handle nested objects/arrays)
      final jsonStart = jsonStr.indexOf('{');
      if (jsonStart != -1) {
        int braceCount = 0;
        int endIndex = jsonStart;
        for (int i = jsonStart; i < jsonStr.length; i++) {
          if (jsonStr[i] == '{') braceCount++;
          if (jsonStr[i] == '}') braceCount--;
          if (braceCount == 0) {
            endIndex = i + 1;
            break;
          }
        }
        if (endIndex > jsonStart) {
          jsonStr = jsonStr.substring(jsonStart, endIndex);
        }
      }
      
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final ideas = (parsed['ideas'] as List<dynamic>?)
          ?.map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (ideas == null || ideas.isEmpty) {
        return Result.failure('Нет идей в ответе. Попробуйте другой запрос.');
      }
      return Result.success(ideas);
    } catch (e) {
      return Result.failure('Ошибка генерации идей: ${e.toString()}');
    }
  }

  @override
  Future<Result<String>> generateStickerName(String prompt) async {
    if (!_chatEnabled) {
      return Result.failure('Настройте OPENAI_* или OPENROUTER_* в .env.');
    }
    try {
      final response = await chatClient!.completeText(
        prompt: 'Generate a short, catchy sticker name (2-4 words max) for: "$prompt". '
            'Return ONLY valid JSON in this exact format: {"name": "sticker name"}. '
            'Do not include any other text, explanations, or markdown formatting.',
        jsonMode: true,
      );
      
      // Try to extract JSON from response (in case it's wrapped in markdown or text)
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        // Remove markdown code blocks
        jsonStr = jsonStr.replaceFirst(RegExp(r'```(?:json)?\s*'), '');
        jsonStr = jsonStr.replaceFirst(RegExp(r'\s*```'), '');
      }
      jsonStr = jsonStr.trim();
      
      // Try to find JSON object in the response (handle nested objects/arrays)
      final jsonStart = jsonStr.indexOf('{');
      if (jsonStart != -1) {
        int braceCount = 0;
        int endIndex = jsonStart;
        for (int i = jsonStart; i < jsonStr.length; i++) {
          if (jsonStr[i] == '{') braceCount++;
          if (jsonStr[i] == '}') braceCount--;
          if (braceCount == 0) {
            endIndex = i + 1;
            break;
          }
        }
        if (endIndex > jsonStart) {
          jsonStr = jsonStr.substring(jsonStart, endIndex);
        }
      }
      
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final name = parsed['name'] as String?;
      if (name == null || name.trim().isEmpty) {
        return Result.failure('Нет имени в ответе.');
      }
      return Result.success(name.trim());
    } catch (e) {
      return Result.failure('Ошибка генерации имени: ${e.toString()}');
    }
  }
}
