import 'package:flutter/material.dart';

/// Transparency checkerboard. Used behind previews and on the editor canvas.
///
/// Important: this is *chrome*, never content — the editor hides it before
/// rasterising, otherwise the pattern gets baked into every exported sticker
/// (which is exactly what the old build did).
class CheckerboardPainter extends CustomPainter {
  CheckerboardPainter({this.square = 16, this.opacity = 1});

  final double square;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()
      ..color = Colors.white.withValues(alpha: 0.05 * opacity);
    final dark = Paint()
      ..color = Colors.black.withValues(alpha: 0.22 * opacity);

    canvas.drawRect(Offset.zero & size, dark);
    for (var y = 0.0; y < size.height; y += square) {
      for (var x = 0.0; x < size.width; x += square) {
        final isLight = (((x / square) + (y / square)).floor()).isEven;
        if (!isLight) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            x,
            y,
            square.clamp(0, size.width - x),
            square.clamp(0, size.height - y),
          ),
          light,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CheckerboardPainter oldDelegate) =>
      oldDelegate.square != square || oldDelegate.opacity != opacity;
}

class CheckerboardBox extends StatelessWidget {
  const CheckerboardBox({
    super.key,
    this.child,
    this.square = 14,
    this.borderRadius,
  });

  final Widget? child;
  final double square;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final painted = CustomPaint(
      painter: CheckerboardPainter(square: square),
      child: child ?? const SizedBox.expand(),
    );
    if (borderRadius == null) return painted;
    return ClipRRect(borderRadius: borderRadius!, child: painted);
  }
}
