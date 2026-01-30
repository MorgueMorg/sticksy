import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Frosted glass card with subtle blur and rounded corners (Cupertino style).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ?? EdgeInsets.all(16.r);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.r, sigmaY: 20.r),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(borderRadius.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.r,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20.r,
                offset: Offset(0, 4.r),
              ),
            ],
          ),
          child: Padding(
            padding: resolvedPadding,
            child: child,
          ),
        ),
      ),
    );
  }
}
