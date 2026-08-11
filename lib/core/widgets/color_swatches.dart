import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_colors.dart';
import 'ui_kit.dart';

/// Horizontal swatch strip used by every colour choice in the editor.
class ColorSwatches extends StatelessWidget {
  const ColorSwatches({
    super.key,
    required this.selected,
    required this.onChanged,
    this.colors,
    this.includeTransparent = false,
    this.size = 38,
  });

  final Color selected;
  final ValueChanged<Color> onChanged;
  final List<Color>? colors;
  final bool includeTransparent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = <Color>[
      if (includeTransparent) Colors.transparent,
      ...(colors ?? AppColors.palette),
    ];

    return SizedBox(
      height: size.h + 4.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: palette.length,
        separatorBuilder: (_, __) => SizedBox(width: 10.w),
        itemBuilder: (context, index) {
          final color = palette[index];
          final isTransparent = color == Colors.transparent;
          final isSelected = color.toARGB32() == selected.toARGB32();

          return PressFx(
            onTap: () => onChanged(color),
            scale: 0.88,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: size.r,
              height: size.r,
              decoration: BoxDecoration(
                color: isTransparent ? AppColors.surfaceHigh : color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.violet
                      : Colors.white.withValues(alpha: 0.18),
                  width: isSelected ? 3 : 1,
                ),
              ),
              child: isTransparent
                  ? Icon(
                      CupertinoIcons.slash_circle,
                      size: (size * 0.5).r,
                      color: AppColors.textTertiary,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
