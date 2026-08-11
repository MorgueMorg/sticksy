import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_colors.dart';
import 'glass_card.dart';

/// Shared interaction + layout primitives. Everything tappable in the app is
/// built from these so press feel, haptics and radii stay consistent.

// ---------------------------------------------------------------------------
// Press feedback
// ---------------------------------------------------------------------------

/// Wraps [child] with a springy scale-down on press plus a light haptic tick.
class PressFx extends StatefulWidget {
  const PressFx({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptics = true,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptics;
  final BorderRadius? borderRadius;

  @override
  State<PressFx> createState() => _PressFxState();
}

class _PressFxState extends State<PressFx> {
  bool _down = false;

  void _set(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptics) HapticFeedback.lightImpact();
              widget.onTap?.call();
            }
          : null,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (widget.haptics) HapticFeedback.mediumImpact();
              widget.onLongPress!.call();
            },
      child: AnimatedScale(
        scale: _down && enabled ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 140),
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

/// Primary call to action — brand gradient, bold label, optional leading icon.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.colors,
    this.expand = true,
    this.busy = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final List<Color>? colors;
  final bool expand;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = colors ?? const [AppColors.pink, AppColors.violet];
    final enabled = onPressed != null && !busy;

    final content = Container(
      width: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18.w : 24.w,
        vertical: compact ? 12.h : 16.h,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: palette.last.withValues(alpha: 0.35),
                  blurRadius: 20.r,
                  offset: Offset(0, 8.r),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            SizedBox(
              width: 18.r,
              height: 18.r,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 20.r, color: Colors.white),
          if (busy || icon != null) SizedBox(width: 10.w),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 14.sp : 16.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );

    return PressFx(onTap: enabled ? onPressed : null, child: content);
  }
}

/// Secondary action — flat surface, hairline border.
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.destructive = false,
    this.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool destructive;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? AppColors.danger : (accent ?? AppColors.textPrimary);
    return PressFx(
      onTap: onPressed,
      child: Container(
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: destructive
                ? AppColors.danger.withValues(alpha: 0.4)
                : AppColors.stroke,
          ),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19.r, color: color),
              SizedBox(width: 10.w),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular icon button used in app bars and toolbars.
class IconPill extends StatelessWidget {
  const IconPill({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.accent,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = PressFx(
      onTap: onPressed,
      scale: 0.9,
      child: Container(
        width: size.r,
        height: size.r,
        decoration: BoxDecoration(
          color: (accent ?? AppColors.surfaceHigh).withValues(
            alpha: accent == null ? 1 : 0.18,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: accent?.withValues(alpha: 0.45) ?? AppColors.stroke,
          ),
        ),
        child: Icon(
          icon,
          size: (size * 0.46).r,
          color: accent ?? AppColors.textPrimary,
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

// ---------------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------------

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Big friendly nothing-here state with a gradient glyph.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.colors,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final palette = colors ?? const [AppColors.pink, AppColors.violet];
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(28.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96.r,
              height: 96.r,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: palette),
                borderRadius: BorderRadius.circular(32.r),
                boxShadow: [
                  BoxShadow(
                    color: palette.last.withValues(alpha: 0.4),
                    blurRadius: 32.r,
                    offset: Offset(0, 12.r),
                  ),
                ],
              ),
              child: Icon(icon, size: 44.r, color: Colors.white),
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 21.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15.sp,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 26.h),
              GradientButton(
                label: actionLabel!,
                icon: actionIcon ?? CupertinoIcons.add,
                onPressed: onAction,
                expand: false,
                colors: palette,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small coloured chip used for counts and formats.
class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.r, color: c),
            SizedBox(width: 5.w),
          ],
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feedback helpers
// ---------------------------------------------------------------------------

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    isScrollControlled: true,
    useSafeArea: true,
    builder: builder,
  );
}

/// Grab the messenger *before* popping a sheet, then pass it to
/// [showAppSnack]. Looking it up from a context that is being torn down is a
/// classic source of "Looking up a deactivated widget's ancestor" crashes.
ScaffoldMessengerState? appMessenger(BuildContext context) =>
    ScaffoldMessenger.maybeOf(context);

void showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
  ScaffoldMessengerState? messengerOverride,
}) {
  final messenger =
      messengerOverride ?? (context.mounted ? ScaffoldMessenger.maybeOf(context) : null);
  if (messenger == null) return;
  HapticFeedback.selectionClick();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: Duration(seconds: isError ? 5 : 2),
        backgroundColor:
            isError ? AppColors.danger : AppColors.surfaceHigh,
        content: Row(
          children: [
            Icon(
              isError
                  ? CupertinoIcons.exclamationmark_triangle_fill
                  : CupertinoIcons.checkmark_circle_fill,
              size: 18.r,
              color: Colors.white,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

/// Confirmation dialog with a destructive default. Returns true on confirm.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
      child: GlassCard(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            SizedBox(height: 22.h),
            GradientButton(
              label: confirmLabel,
              colors: destructive
                  ? const [AppColors.danger, Color(0xFFB3323A)]
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            SizedBox(height: 10.h),
            SoftButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Single-field text prompt sheet. Returns the trimmed value or null.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String? initialValue,
  String hint = '',
  String confirmLabel = 'Save',
  int maxLength = 60,
}) {
  return showAppSheet<String>(
    context,
    builder: (context) => _TextPromptSheet(
      title: title,
      initialValue: initialValue ?? '',
      hint: hint,
      confirmLabel: confirmLabel,
      maxLength: maxLength,
    ),
  );
}

/// The controller has to be owned by a [State].
///
/// Disposing it in a `finally` after `await showModalBottomSheet` looks right
/// but isn't: that future completes the moment `Navigator.pop` is called, while
/// the sheet keeps rebuilding for the whole dismiss animation. The next rebuild
/// then hits a disposed controller, which throws during build and cascades into
/// bogus overflow and `!attached` assertions.
class _TextPromptSheet extends StatefulWidget {
  const _TextPromptSheet({
    required this.title,
    required this.initialValue,
    required this.hint,
    required this.confirmLabel,
    required this.maxLength,
  });

  final String title;
  final String initialValue;
  final String hint;
  final String confirmLabel;
  final int maxLength;

  @override
  State<_TextPromptSheet> createState() => _TextPromptSheetState();
}

class _TextPromptSheetState extends State<_TextPromptSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return SheetSurface(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: 16.sp, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: widget.hint,
              counterText: '',
            ),
            onSubmitted: (_) => _submit(),
          ),
          SizedBox(height: 16.h),
          GradientButton(label: widget.confirmLabel, onPressed: _submit),
        ],
      ),
    );
  }
}
