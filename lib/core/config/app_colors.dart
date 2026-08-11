import 'package:flutter/material.dart';

/// Sticksy palette — deep charcoal base with saturated candy accents.
///
/// Everything visual pulls from here so the app reads as one product instead of
/// a pile of ad-hoc hex codes.
class AppColors {
  const AppColors._();

  // Base surfaces
  static const Color bg = Color(0xFF0A0912);
  static const Color bgLift = Color(0xFF12101C);
  static const Color surface = Color(0xFF181527);
  static const Color surfaceHigh = Color(0xFF221E36);
  static const Color stroke = Color(0xFF2E2A45);

  // Text
  static const Color textPrimary = Color(0xFFF6F4FF);
  static const Color textSecondary = Color(0xFF9E98BF);
  static const Color textTertiary = Color(0xFF6B6690);

  // Accents
  static const Color violet = Color(0xFF7C5CFF);
  static const Color pink = Color(0xFFFF4D9D);
  static const Color cyan = Color(0xFF25D9F8);
  static const Color lime = Color(0xFFA8FF3E);
  static const Color orange = Color(0xFFFF9F45);
  static const Color danger = Color(0xFFFF5A5F);
  static const Color success = Color(0xFF2ED47A);

  /// Signature brand gradient — used on primary actions and the wordmark.
  static const List<Color> brandGradient = [pink, violet, cyan];

  static const List<List<Color>> cardGradients = [
    [Color(0xFFFF4D9D), Color(0xFF7C5CFF)],
    [Color(0xFF25D9F8), Color(0xFF7C5CFF)],
    [Color(0xFFA8FF3E), Color(0xFF25D9F8)],
    [Color(0xFFFF9F45), Color(0xFFFF4D9D)],
    [Color(0xFF7C5CFF), Color(0xFF25D9F8)],
    [Color(0xFFFFD166), Color(0xFFFF9F45)],
  ];

  /// Stable per-pack gradient so a pack always looks the same between launches.
  static List<Color> gradientForSeed(String seed) {
    if (seed.isEmpty) return cardGradients.first;
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return cardGradients[hash % cardGradients.length];
  }

  /// Swatches offered in every colour picker (text, shapes, brush, outline).
  static const List<Color> palette = [
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFFFF4D9D),
    Color(0xFFFF5A5F),
    Color(0xFFFF9F45),
    Color(0xFFFFD166),
    Color(0xFFA8FF3E),
    Color(0xFF2ED47A),
    Color(0xFF25D9F8),
    Color(0xFF4D8DFF),
    Color(0xFF7C5CFF),
    Color(0xFFB06BFF),
    Color(0xFF8E8AA8),
    Color(0xFF5A4632),
  ];

  static LinearGradient linear(
    List<Color> colors, {
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(colors: colors, begin: begin, end: end);
  }
}
