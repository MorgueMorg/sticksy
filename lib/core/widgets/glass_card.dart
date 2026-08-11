import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_colors.dart';

/// Translucent panel with a hairline border and soft drop shadow.
///
/// Blur is opt-in ([blur] = true) because `BackdropFilter` is expensive and
/// buys almost nothing over a near-flat backdrop — the old version blurred
/// every card in every list.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24,
    this.blur = false,
    this.tint,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool blur;

  /// Optional accent used for a very subtle coloured wash.
  final Color? tint;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius.r);
    final resolvedPadding = padding ?? EdgeInsets.all(16.r);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: tint == null
            ? AppColors.surface.withValues(alpha: blur ? 0.72 : 0.92)
            : Color.alphaBlend(
                tint!.withValues(alpha: 0.14),
                AppColors.surface,
              ),
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? AppColors.stroke.withValues(alpha: 0.9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24.r,
            offset: Offset(0, 8.r),
          ),
        ],
      ),
      child: Padding(padding: resolvedPadding, child: child),
    );

    if (!blur) return content;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: content,
      ),
    );
  }
}

/// Bottom-sheet container: rounded top corners, grab handle, safe-area aware
/// and keyboard aware. Every sheet in the app uses this so they all match.
class SheetSurface extends StatelessWidget {
  const SheetSurface({
    super.key,
    required this.child,
    this.title,
    this.padding,
    this.scrollable = true,
  });

  final Widget child;
  final String? title;
  final EdgeInsetsGeometry? padding;

  /// Scrolls the body so a sheet can never overflow when space is tight.
  /// Set false only if [child] manages its own scrolling.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // Budget against the space actually left once the keyboard and status bar
    // have taken their cut. Using a flat percentage of screen height while
    // *also* padding by viewInsets asks for more room than exists, which is how
    // a two-field sheet ends up reporting a five-figure overflow.
    final available = media.size.height -
        media.viewInsets.bottom -
        media.padding.top -
        24;
    final maxHeight = available.clamp(200.0, media.size.height);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: AppColors.bgLift,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border(
            top: BorderSide(color: AppColors.stroke.withValues(alpha: 0.9)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              if (title != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Flexible(
                child: scrollable
                    ? SingleChildScrollView(
                        padding: padding ??
                            EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
                        child: child,
                      )
                    : Padding(
                        padding: padding ??
                            EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
                        child: child,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
