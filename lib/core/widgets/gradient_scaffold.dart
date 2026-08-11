import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// App-wide backdrop: deep charcoal with three slow-drifting colour blobs.
///
/// Cheap by construction — radial gradients with soft alpha stops rather than
/// blurred layers, wrapped in a [RepaintBoundary] so the animation never
/// invalidates the UI painted on top of it.
class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false,
    this.animated = true,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;
  final bool animated;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: AuroraBackground(animated: animated)),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: extendBodyBehindAppBar,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          appBar: appBar,
          body: body,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
          bottomNavigationBar: bottomNavigationBar,
        ),
      ],
    );
  }
}

class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, this.animated = true});

  final bool animated;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animated) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animated && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Users who ask the OS to reduce motion get a static backdrop.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgLift, AppColors.bg, Color(0xFF07060D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: reduceMotion || !widget.animated
            ? CustomPaint(painter: _AuroraPainter(0), child: const SizedBox.expand())
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _AuroraPainter(_controller.value),
                  child: const SizedBox.expand(),
                ),
              ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t);

  /// Normalised 0..1 animation position.
  final double t;

  static const _blobs = <_Blob>[
    _Blob(AppColors.violet, 0.22, 0.18, 0.62, 0.20),
    _Blob(AppColors.pink, 0.82, 0.30, 0.55, 0.16),
    _Blob(AppColors.cyan, 0.50, 0.88, 0.70, 0.13),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final tau = math.pi * 2;
    for (var i = 0; i < _blobs.length; i++) {
      final blob = _blobs[i];
      final phase = tau * (t + i / _blobs.length);
      final cx = size.width * (blob.x + 0.06 * math.sin(phase));
      final cy = size.height * (blob.y + 0.05 * math.cos(phase * 0.8));
      final radius = size.shortestSide * blob.radius;

      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            blob.color.withValues(alpha: blob.opacity),
            blob.color.withValues(alpha: blob.opacity * 0.45),
            blob.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => oldDelegate.t != t;
}

class _Blob {
  const _Blob(this.color, this.x, this.y, this.radius, this.opacity);

  final Color color;
  final double x;
  final double y;
  final double radius;
  final double opacity;
}
