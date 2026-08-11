import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sticksy/core/config/ai_settings.dart';
import 'package:sticksy/core/utils/formatting.dart';
import 'package:sticksy/core/utils/image_ops.dart';
import 'package:sticksy/core/utils/result.dart';
import 'package:sticksy/features/editor/domain/editor_models.dart';
import 'package:sticksy/features/editor/state/sticker_editor_controller.dart';

void main() {
  group('formatting', () {
    test('formats byte sizes', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2.0 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    });

    test('pluralises', () {
      expect(pluralise(1, 'sticker'), '1 sticker');
      expect(pluralise(3, 'sticker'), '3 stickers');
    });
  });

  group('Result', () {
    test('reports success even for falsy payloads', () {
      // The old implementation defined success as `data != null`, so this
      // case was silently treated as a failure.
      final result = Result.success<bool>(false);
      expect(result.isSuccess, isTrue);
      expect(result.value, isFalse);
    });

    test('carries a failure message', () {
      final result = Result.failure<int>('nope');
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'nope');
    });
  });

  group('AiSettings', () {
    test('a cold install can generate with no key at all', () {
      // The whole point of the free tier: default construction is usable.
      const settings = AiSettings();
      expect(settings.provider, AiProvider.pollinations);
      expect(settings.isConfigured, isTrue);
      expect(settings.isFreeTier, isTrue);
      expect(settings.resolvedBaseUrl, 'https://image.pollinations.ai');
      expect(settings.resolvedImageModel, 'sana');
    });

    test('key providers stay locked until a key is supplied', () {
      const empty = AiSettings(provider: AiProvider.openRouter);
      expect(empty.isConfigured, isFalse);

      const withKey = AiSettings(provider: AiProvider.openRouter, apiKey: 'k');
      expect(withKey.isConfigured, isTrue);
      expect(withKey.isFreeTier, isFalse);
      expect(withKey.resolvedBaseUrl, 'https://openrouter.ai/api/v1');
      expect(withKey.resolvedImageModel, 'openai/gpt-image-1-mini');
    });

    test('strips a trailing slash from a custom base url', () {
      const settings = AiSettings(apiKey: 'k', baseUrl: 'https://x.dev/v1/');
      expect(settings.resolvedBaseUrl, 'https://x.dev/v1');
    });

    test('switching provider clears provider-specific overrides', () {
      const settings = AiSettings(
        provider: AiProvider.openRouter,
        apiKey: 'k',
        imageModel: 'openai/gpt-image-1',
        removeBgApiKey: 'rb',
      );
      final next = settings.withProvider(AiProvider.openAi);
      expect(next.apiKey, isEmpty);
      expect(next.imageModel, isEmpty);
      expect(next.resolvedImageModel, 'gpt-image-1');
      // remove.bg is provider-independent, so it survives.
      expect(next.removeBgApiKey, 'rb');
    });

    test('presets only send parameters the endpoint supports', () {
      final nanoBanana = ImageModelPreset.resolve(
        AiProvider.openRouter,
        'google/gemini-3.1-flash-image',
      );
      expect(nanoBanana.transparentBackground, isFalse);
      expect(nanoBanana.aspectRatio, isTrue);
    });
  });

  group('ImageOps', () {
    /// Solid red square centred on a white background.
    Uint8List sample({int size = 64, int subject = 24}) {
      final image = img.Image(width: size, height: size, numChannels: 4);
      final start = (size - subject) ~/ 2;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final inside = x >= start &&
              x < start + subject &&
              y >= start &&
              y < start + subject;
          if (inside) {
            image.setPixelRgba(x, y, 220, 40, 60, 255);
          } else {
            image.setPixelRgba(x, y, 255, 255, 255, 255);
          }
        }
      }
      return Uint8List.fromList(img.encodePng(image));
    }

    test('magicCutout removes a flat background', () async {
      final result = await ImageOps.magicCutout(sample());
      expect(result.changed, isTrue);

      final decoded = img.decodeImage(result.bytes)!;
      expect(decoded.getPixel(0, 0).a, 0, reason: 'corner should be cut away');
      expect(decoded.getPixel(32, 32).a, greaterThan(200),
          reason: 'subject should survive');
    });

    test('magicCutout leaves an already-transparent image alone', () async {
      final transparent = img.Image(width: 32, height: 32, numChannels: 4);
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          transparent.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
      final result = await ImageOps.magicCutout(
        Uint8List.fromList(img.encodePng(transparent)),
      );
      expect(result.changed, isFalse);
    });

    test('trimTransparent crops to the subject', () async {
      final cut = await ImageOps.magicCutout(sample(size: 64, subject: 20));
      final trimmed = await ImageOps.trimTransparent(cut.bytes, padding: 0);
      final decoded = img.decodeImage(trimmed)!;
      expect(decoded.width, lessThan(40));
      expect(decoded.height, lessThan(40));
    });

    test('addOutline grows the canvas and paints a border', () async {
      final cut = await ImageOps.magicCutout(sample());
      final outlined = await ImageOps.addOutline(cut.bytes, width: 6);
      final decoded = img.decodeImage(outlined)!;

      expect(decoded.width, 64 + (6 + 2) * 2);
      // Just outside the subject there should now be opaque white.
      final edge = decoded.getPixel(decoded.width ~/ 2, 8 + 20 - 3);
      expect(edge.a, greaterThan(0));
    });

    test('fitSquare produces an exact square canvas', () async {
      final wide = img.Image(width: 80, height: 40, numChannels: 4);
      for (var y = 0; y < 40; y++) {
        for (var x = 0; x < 80; x++) {
          wide.setPixelRgba(x, y, 10, 200, 90, 255);
        }
      }
      final squared = await ImageOps.fitSquare(
        Uint8List.fromList(img.encodePng(wide)),
        size: 128,
      );
      final decoded = img.decodeImage(squared)!;
      expect(decoded.width, 128);
      expect(decoded.height, 128);
      // Letterbox bands stay transparent.
      expect(decoded.getPixel(4, 2).a, 0);
    });
  });

  group('StickerEditorController', () {
    StickerEditorController build() =>
        StickerEditorController(packId: 'pack-1');

    test('adds, undoes and redoes layers', () {
      final controller = build();
      expect(controller.state.layers, isEmpty);
      expect(controller.state.canUndo, isFalse);

      controller.addEmojiLayer('🔥');
      expect(controller.state.layers.length, 1);
      expect(controller.state.canUndo, isTrue);

      controller.undo();
      expect(controller.state.layers, isEmpty);
      expect(controller.state.canRedo, isTrue);

      controller.redo();
      expect(controller.state.layers.length, 1);
    });

    test('can deselect a layer', () {
      // copyWith used `value ?? this.value`, which made null unreachable —
      // tapping empty canvas never cleared the selection.
      final controller = build();
      controller.addEmojiLayer('✨');
      expect(controller.state.selectedLayerId, isNotNull);

      controller.selectLayer(null);
      expect(controller.state.selectedLayerId, isNull);
    });

    test('duplicates a layer with a new id and an offset', () {
      final controller = build();
      controller.addShapeLayer(ShapeType.circle, const Color(0xFF7C5CFF));
      final original = controller.state.layers.single;

      controller.duplicateLayer(original.id);
      expect(controller.state.layers.length, 2);

      final copy = controller.state.layers.last;
      expect(copy.id, isNot(original.id));
      expect(copy.transform.position, isNot(original.transform.position));
    });

    test('reorders layers within bounds', () {
      final controller = build();
      controller.addEmojiLayer('1');
      controller.addEmojiLayer('2');
      final first = controller.state.layers.first.id;

      controller.bringToFront(first);
      expect(controller.state.layers.last.id, first);

      controller.sendToBack(first);
      expect(controller.state.layers.first.id, first);
    });

    test('round-trips the document through JSON', () {
      final controller = build();
      controller.addTextLayer('hello', fontSize: 40);
      controller.setOutline(
        const StickerOutline(width: 12, color: Color(0xFFFFFFFF)),
      );

      final restored = StickerEditorController(
        packId: 'pack-1',
        initialSticker: null,
      );
      expect(restored.state.outline.width, 0);

      final json = controller.serializeEditorState();
      expect(json, contains('hello'));
      expect(json, contains('outline'));
    });
  });
}
