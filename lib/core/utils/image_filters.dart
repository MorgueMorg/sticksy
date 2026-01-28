import 'dart:math' as math;

class ImageFilters {
  static List<double> colorMatrix({
    double brightness = 0,
    double saturation = 1,
  }) {
    final b = brightness.clamp(-1.0, 1.0);
    final s = saturation.clamp(0.0, 2.0);

    final double invSat = 1 - s;
    const double r = 0.2126;
    const double g = 0.7152;
    const double bCoef = 0.0722;

    final a = invSat * r;
    final bSat = invSat * g;
    final c = invSat * bCoef;

    return [
      a + s,
      bSat,
      c,
      0,
      255 * b,
      a,
      bSat + s,
      c,
      0,
      255 * b,
      a,
      bSat,
      c + s,
      0,
      255 * b,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  static double clampAngle(double angle) {
    final twoPi = math.pi * 2;
    if (angle > twoPi) return angle % twoPi;
    if (angle < -twoPi) return angle % twoPi;
    return angle;
  }
}
