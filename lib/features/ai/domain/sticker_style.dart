import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';

/// Art directions offered in the AI Studio. Each one contributes a fragment to
/// the generation prompt — the rest of the prompt (die-cut framing, isolated
/// subject, clean edges) is shared so every result cuts out cleanly.
enum StickerStyle {
  kawaii,
  cartoon,
  pixel,
  neon,
  paper,
  claymation,
  lineArt,
  retro,
}

extension StickerStyleX on StickerStyle {
  String get label => switch (this) {
        StickerStyle.kawaii => 'Kawaii',
        StickerStyle.cartoon => 'Cartoon',
        StickerStyle.pixel => 'Pixel',
        StickerStyle.neon => 'Neon',
        StickerStyle.paper => 'Paper cut',
        StickerStyle.claymation => 'Clay 3D',
        StickerStyle.lineArt => 'Line art',
        StickerStyle.retro => 'Retro',
      };

  String get emoji => switch (this) {
        StickerStyle.kawaii => '🌸',
        StickerStyle.cartoon => '🎨',
        StickerStyle.pixel => '👾',
        StickerStyle.neon => '💡',
        StickerStyle.paper => '📄',
        StickerStyle.claymation => '🧱',
        StickerStyle.lineArt => '✏️',
        StickerStyle.retro => '📻',
      };

  List<Color> get colors => switch (this) {
        StickerStyle.kawaii => const [AppColors.pink, Color(0xFFFF9BC8)],
        StickerStyle.cartoon => const [AppColors.orange, AppColors.pink],
        StickerStyle.pixel => const [AppColors.lime, AppColors.cyan],
        StickerStyle.neon => const [AppColors.cyan, AppColors.violet],
        StickerStyle.paper => const [Color(0xFFFFD166), AppColors.orange],
        StickerStyle.claymation => const [AppColors.violet, AppColors.pink],
        StickerStyle.lineArt => const [Color(0xFF8E8AA8), Color(0xFF4A4763)],
        StickerStyle.retro => const [Color(0xFFFF7A45), Color(0xFFB33A6B)],
      };

  String get promptFragment => switch (this) {
        StickerStyle.kawaii =>
          'kawaii chibi style, big expressive eyes, soft pastel palette, '
              'rounded shapes, cute and friendly',
        StickerStyle.cartoon =>
          'bold modern cartoon style, thick confident outlines, flat vibrant '
              'colours, playful exaggerated proportions',
        StickerStyle.pixel =>
          'crisp 32-bit pixel art, limited retro palette, hard pixel edges, '
              'no anti-aliasing',
        StickerStyle.neon =>
          'glowing neon style, luminous rim light, electric saturated colours '
              'against deep contrast',
        StickerStyle.paper =>
          'layered paper cut-out craft style, visible paper texture, soft '
              'stacked shadows between layers',
        StickerStyle.claymation =>
          'cute claymation style, soft 3D clay material, gentle studio '
              'lighting, tactile fingerprint texture',
        StickerStyle.lineArt =>
          'clean minimal line art, single consistent stroke weight, mostly '
              'monochrome with one accent colour',
        StickerStyle.retro =>
          '1970s retro print style, warm muted palette, subtle halftone grain, '
              'bold vintage shapes',
      };
}

/// Prompt scaffolding shared by every generation.
class StickerPrompt {
  const StickerPrompt._();

  static String build({
    required String subject,
    required StickerStyle style,
    required bool transparentCapable,
    bool compact = false,
  }) {
    // The keyless provider takes the prompt in the URL path, and smaller models
    // follow short instructions better than long ones.
    if (compact) {
      return 'die-cut sticker of ${subject.trim()}, ${style.promptFragment}, '
          'single centred subject, plain flat pure white background, '
          'no text, no shadow, no border, crisp clean edges';
    }

    final background = transparentCapable
        ? 'The background must be fully transparent.'
        : 'Place the subject on a completely plain, flat, pure white '
            'background with no gradient, no shadow and no texture, so it can '
            'be cut out automatically.';

    return 'A single die-cut messaging sticker of: ${subject.trim()}.\n'
        'Art direction: ${style.promptFragment}.\n'
        'Composition: one subject only, centred, fully inside the frame with '
        'a small margin, square 1:1 framing. $background\n'
        'Do not draw any text, caption, watermark, frame, border, sticker '
        'outline, drop shadow, or background scenery. Crisp clean silhouette '
        'edges suitable for cutting out.';
  }
}
