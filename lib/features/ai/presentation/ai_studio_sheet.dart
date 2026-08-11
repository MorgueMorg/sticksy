import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/checkerboard.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/ui_kit.dart';
import '../data/ai_repository.dart';
import '../domain/sticker_style.dart';

/// Prompt → finished sticker, in one sheet.
///
/// The result is already cut out, trimmed, optionally die-cut and squared to
/// 512px by [AiRepository], so "Add to canvas" drops in a usable sticker.
class AiStudioSheet extends ConsumerStatefulWidget {
  const AiStudioSheet({super.key, required this.onAccept});

  final void Function(Uint8List bytes, String suggestedName) onAccept;

  @override
  ConsumerState<AiStudioSheet> createState() => _AiStudioSheetState();
}

class _AiStudioSheetState extends ConsumerState<AiStudioSheet> {
  final _promptController = TextEditingController();

  StickerStyle _style = StickerStyle.kawaii;
  double _outlineWidth = 14;
  bool _busy = false;
  GenerationStage _stage = GenerationStage.prompting;
  String? _error;
  Uint8List? _result;
  List<String> _ideas = const [];

  static const _suggestions = [
    'a sleepy cat holding a coffee',
    'a dancing avocado wearing sunglasses',
    'a tiny dragon breathing confetti',
    'a happy dumpling giving a thumbs up',
    'an astronaut cat floating with a balloon',
    'a grumpy toast with butter hair',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final subject = _promptController.text.trim();
    if (subject.isEmpty) {
      setState(() => _error = 'Describe your sticker first.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _stage = GenerationStage.prompting;
    });

    final result = await ref.read(aiRepositoryProvider).generateSticker(
          StickerGenerationRequest(
            subject: subject,
            style: _style,
            outlineWidth: _outlineWidth.round(),
            useRemoveBg: ref.read(aiSettingsProvider).hasRemoveBg,
          ),
          onStage: (stage) {
            if (mounted) setState(() => _stage = stage);
          },
        );

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.isSuccess) {
        _result = result.value;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  Future<void> _suggestIdeas() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(aiRepositoryProvider)
        .generateIdeas(_promptController.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.isSuccess) {
        _ideas = result.value;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiSettingsProvider);
    final configured = ref.watch(aiRepositoryProvider).isConfigured;

    void openSettings() {
      // Resolve the router before popping — afterwards this element is
      // deactivating and the lookup can throw.
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push('/settings');
    }

    return SheetSurface(
      title: 'AI Studio',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!configured) ...[
            _SetupCard(onOpenSettings: openSettings),
            SizedBox(height: 20.h),
          ] else if (settings.isFreeTier && _result == null) ...[
            _FreeTierBanner(onUpgrade: openSettings),
            SizedBox(height: 16.h),
          ],
          if (_result != null)
            _ResultPreview(
              bytes: _result!,
              onRetry: _busy ? null : _generate,
              onAccept: () {
                widget.onAccept(_result!, _promptController.text.trim());
                Navigator.of(context).pop();
              },
            )
          else ...[
            TextField(
              controller: _promptController,
              enabled: !_busy,
              minLines: 2,
              maxLines: 4,
              maxLength: 220,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 16.sp, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'a sleepy cat holding a coffee…',
                counterText: '',
              ),
            ),
            SizedBox(height: 10.h),
            _ChipRow(
              items: _ideas.isEmpty ? _suggestions : _ideas,
              onTap: (value) {
                _promptController.text = value;
                setState(() {});
              },
            ),
            SizedBox(height: 20.h),
            const SectionLabel('Style'),
            _StylePicker(
              selected: _style,
              onChanged: (style) => setState(() => _style = style),
            ),
            SizedBox(height: 20.h),
            const SectionLabel('Die-cut border'),
            _OutlineSlider(
              value: _outlineWidth,
              onChanged: (value) => setState(() => _outlineWidth = value),
            ),
            SizedBox(height: 20.h),
            if (_busy)
              _BusyRow(stage: _stage)
            else
              GradientButton(
                label: 'Generate sticker',
                icon: CupertinoIcons.sparkles,
                onPressed: configured ? _generate : null,
              ),
            if (configured && !_busy) ...[
              SizedBox(height: 10.h),
              SoftButton(
                label: 'Suggest ideas',
                icon: CupertinoIcons.lightbulb,
                onPressed: _suggestIdeas,
              ),
            ],
          ],
          if (_error != null) ...[
            SizedBox(height: 16.h),
            _ErrorNote(message: _error!),
          ],
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: AppColors.violet,
      padding: EdgeInsets.all(18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.wand_stars, color: AppColors.violet, size: 20.r),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Connect an AI provider',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Paste an OpenRouter or OpenAI key once and generation works '
            'everywhere in the app. Your key stays on this device.',
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: 14.h),
          GradientButton(
            label: 'Open AI settings',
            icon: CupertinoIcons.settings,
            compact: true,
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

/// Sets expectations on the keyless tier without getting in the way.
class _FreeTierBanner extends StatelessWidget {
  const _FreeTierBanner({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return PressFx(
      onTap: onUpgrade,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.gift, size: 15.r, color: AppColors.success),
            SizedBox(width: 9.w),
            Expanded(
              child: Text(
                'Free mode — no key needed. Tap for sharper results.',
                style: TextStyle(
                  fontSize: 11.5.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 13.r,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.items, required this.onTap});

  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final value = items[index];
          return PressFx(
            onTap: () => onTap(value),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(17.r),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StylePicker extends StatelessWidget {
  const _StylePicker({required this.selected, required this.onChanged});

  final StickerStyle selected;
  final ValueChanged<StickerStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: StickerStyle.values.length,
        separatorBuilder: (_, __) => SizedBox(width: 10.w),
        itemBuilder: (context, index) {
          final style = StickerStyle.values[index];
          final isSelected = style == selected;
          return PressFx(
            onTap: () => onChanged(style),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 76.w,
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: style.colors)
                    : null,
                color: isSelected ? null : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.35)
                      : AppColors.stroke,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(style.emoji, style: TextStyle(fontSize: 24.sp)),
                  SizedBox(height: 6.h),
                  Text(
                    style.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OutlineSlider extends StatelessWidget {
  const _OutlineSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          CupertinoIcons.circle,
          size: 18.r,
          color: value == 0 ? AppColors.textTertiary : AppColors.cyan,
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 32,
            divisions: 16,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44.w,
          child: Text(
            value == 0 ? 'Off' : '${value.round()}px',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _BusyRow extends StatelessWidget {
  const _BusyRow({required this.stage});

  final GenerationStage stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20.r,
            height: 20.r,
            child: const CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.violet,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              stage.label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPreview extends StatelessWidget {
  const _ResultPreview({
    required this.bytes,
    required this.onRetry,
    required this.onAccept,
  });

  final Uint8List bytes;
  final VoidCallback? onRetry;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: CheckerboardBox(
            borderRadius: BorderRadius.circular(24.r),
            child: Padding(
              padding: EdgeInsets.all(12.r),
              child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
        ),
        SizedBox(height: 18.h),
        GradientButton(
          label: 'Add to canvas',
          icon: CupertinoIcons.checkmark_alt,
          onPressed: onAccept,
        ),
        SizedBox(height: 10.h),
        SoftButton(
          label: 'Try again',
          icon: CupertinoIcons.refresh,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 16.r,
            color: AppColors.danger,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
