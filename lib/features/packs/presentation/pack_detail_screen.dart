import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/checkerboard.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../shared/data/services/storage_services.dart';
import '../../editor/presentation/sticker_editor_screen.dart';
import '../domain/models.dart';

class PackDetailScreen extends ConsumerWidget {
  const PackDetailScreen({super.key, required this.packId});

  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packAsync = ref.watch(packSummaryProvider(packId));
    final stickersAsync = ref.watch(stickersForPackProvider(packId));
    final gradient = AppColors.gradientForSeed(packId);

    return GradientScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.go('/'),
        ),
        title: Text(packAsync.value?.name ?? 'Pack'),
        actions: [
          IconPill(
            icon: CupertinoIcons.share,
            tooltip: 'Export pack',
            onPressed: () => _exportSheet(context),
          ),
          SizedBox(width: 16.w),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: GradientButton(
          label: 'Add sticker',
          icon: CupertinoIcons.add,
          expand: false,
          colors: gradient,
          onPressed: () => _addSheet(context, gradient),
        ),
      ),
      body: packAsync.when(
        data: (pack) {
          if (pack == null) {
            return EmptyState(
              icon: CupertinoIcons.question_circle,
              title: 'Pack not found',
              message: 'It may have been deleted.',
              actionLabel: 'Back to packs',
              actionIcon: CupertinoIcons.house_fill,
              onAction: () => context.go('/'),
            );
          }
          return stickersAsync.when(
            data: (stickers) => _Body(
              pack: pack,
              stickers: stickers,
              gradient: gradient,
              onAdd: () => _addSheet(context, gradient),
            ),
            loading: () =>
                const Center(child: CupertinoActivityIndicator(radius: 14)),
            error: (error, _) => EmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: 'Could not load stickers',
              message: '$error',
            ),
          );
        },
        loading: () =>
            const Center(child: CupertinoActivityIndicator(radius: 14)),
        error: (error, _) => EmptyState(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'Could not load this pack',
          message: '$error',
        ),
      ),
    );
  }

  void _openEditor(
    BuildContext context, {
    String? initialImagePath,
    bool openAiStudio = false,
  }) {
    context.push(
      '/editor',
      extra: StickerEditorArgs(
        packId: packId,
        initialImagePath: initialImagePath,
        openAiStudio: openAiStudio,
      ),
    );
  }

  void _addSheet(BuildContext context, List<Color> gradient) {
    showAppSheet(
      context,
      builder: (sheetContext) => SheetSurface(
        title: 'Add a sticker',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GradientButton(
              label: 'Generate with AI',
              icon: CupertinoIcons.wand_stars,
              colors: gradient,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _openEditor(context, openAiStudio: true);
              },
            ),
            SizedBox(height: 10.h),
            SoftButton(
              label: 'From gallery',
              icon: CupertinoIcons.photo,
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _pickAndEdit(context, ImageSource.gallery);
              },
            ),
            SizedBox(height: 10.h),
            SoftButton(
              label: 'Take a photo',
              icon: CupertinoIcons.camera,
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _pickAndEdit(context, ImageSource.camera);
              },
            ),
            SizedBox(height: 10.h),
            SoftButton(
              label: 'Blank canvas',
              icon: CupertinoIcons.square_pencil,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _openEditor(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndEdit(BuildContext context, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (file == null || !context.mounted) return;
      _openEditor(context, initialImagePath: file.path);
    } catch (_) {
      if (context.mounted) {
        showAppSnack(
          context,
          'Could not open that source. Check the app permissions.',
          isError: true,
        );
      }
    }
  }

  void _exportSheet(BuildContext context) {
    showAppSheet(
      context,
      builder: (_) => _ExportSheet(packId: packId),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.pack,
    required this.stickers,
    required this.gradient,
    required this.onAdd,
  });

  final PackSummary pack;
  final List<StickerItem> stickers;
  final List<Color> gradient;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (stickers.isEmpty) {
      return EmptyState(
        icon: CupertinoIcons.wand_stars,
        title: 'This pack is empty',
        message:
            'Describe a sticker and let AI draw it, or bring in a photo and '
            'cut it out.',
        actionLabel: 'Add a sticker',
        onAction: onAdd,
        colors: gradient,
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 18.h),
            child: GlassCard(
              tint: gradient.first,
              padding: EdgeInsets.all(18.r),
              child: Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: '${pack.stickerCount}',
                      label: 'stickers',
                      color: gradient.first,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 34.h,
                    color: AppColors.stroke,
                  ),
                  Expanded(
                    child: _Stat(
                      value: formatBytes(pack.totalSize),
                      label: 'on disk',
                      color: gradient.last,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 34.h,
                    color: AppColors.stroke,
                  ),
                  Expanded(
                    child: _Stat(
                      value: formatRelativeDate(pack.updatedAt),
                      label: 'updated',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 120.h),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _StickerTile(
                sticker: stickers[index],
                pack: pack,
              ),
              childCount: stickers.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _StickerTile extends ConsumerWidget {
  const _StickerTile({required this.sticker, required this.pack});

  final StickerItem sticker;
  final PackSummary pack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCover = pack.coverStickerId == sticker.id;

    return PressFx(
      onTap: () => context.push(
        '/editor',
        extra: StickerEditorArgs(
          packId: sticker.packId,
          stickerId: sticker.id,
        ),
      ),
      onLongPress: () => _actions(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isCover ? AppColors.cyan : AppColors.stroke,
                  width: isCover ? 2 : 1,
                ),
              ),
              child: CheckerboardBox(
                square: 10,
                borderRadius: BorderRadius.circular(19.r),
                child: Padding(
                  padding: EdgeInsets.all(6.r),
                  child: Image.file(
                    File(sticker.filePath),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => Icon(
                      CupertinoIcons.photo,
                      color: AppColors.textTertiary,
                      size: 24.r,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            sticker.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _actions(BuildContext context, WidgetRef ref) {
    showAppSheet(
      context,
      builder: (sheetContext) => SheetSurface(
        title: sticker.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftButton(
              label: 'Rename',
              icon: CupertinoIcons.pencil,
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                final name = await promptForText(
                  context,
                  title: 'Rename sticker',
                  initialValue: sticker.name,
                );
                if (name == null) return;
                await ref
                    .read(stickerRepositoryProvider)
                    .renameSticker(sticker.id, name);
              },
            ),
            SizedBox(height: 10.h),
            SoftButton(
              label: 'Use as pack cover',
              icon: CupertinoIcons.star,
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await ref
                    .read(packRepositoryProvider)
                    .setCoverSticker(pack.id, sticker.id);
                if (context.mounted) showAppSnack(context, 'Cover updated');
              },
            ),
            SizedBox(height: 10.h),
            SoftButton(
              label: 'Share',
              icon: CupertinoIcons.share,
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                if (!await File(sticker.filePath).exists()) {
                  if (context.mounted) {
                    showAppSnack(context, 'File is missing.', isError: true);
                  }
                  return;
                }
                await Share.shareXFiles([XFile(sticker.filePath)]);
              },
            ),
            SizedBox(height: 10.h),
            SoftButton(
              label: 'Delete',
              icon: CupertinoIcons.delete,
              destructive: true,
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                final confirmed = await confirmDialog(
                  context,
                  title: 'Delete "${sticker.name}"?',
                  message: 'This sticker will be removed from the pack.',
                );
                if (!confirmed) return;
                await ref
                    .read(stickerRepositoryProvider)
                    .deleteSticker(sticker.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet({required this.packId});

  final String packId;

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  bool _busy = false;

  Future<void> _export(PackExportType type) async {
    // The sheet pops mid-flow, so hold onto the messenger while it is still
    // reachable.
    final messenger = appMessenger(context);
    final pack = ref.read(packSummaryProvider(widget.packId)).value;
    final stickers =
        ref.read(stickersForPackProvider(widget.packId)).value ?? const [];

    if (pack == null || stickers.isEmpty) {
      showAppSnack(
        context,
        'Add a sticker before exporting.',
        isError: true,
        messengerOverride: messenger,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final file = await ref.read(packExportServiceProvider).exportPack(
            pack: pack,
            stickers: stickers,
            type: type,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      await Share.shareXFiles([XFile(file.path)], subject: pack.name);
    } catch (error) {
      showAppSnack(
        context,
        'Export failed: $error',
        isError: true,
        messengerOverride: messenger,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetSurface(
      title: 'Export pack',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final type in PackExportType.values) ...[
            PressFx(
              onTap: _busy ? null : () => _export(type),
              child: Container(
                padding: EdgeInsets.all(16.r),
                margin: EdgeInsets.only(bottom: 10.h),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Row(
                  children: [
                    Icon(
                      switch (type) {
                        PackExportType.zip => CupertinoIcons.archivebox,
                        PackExportType.whatsapp => CupertinoIcons.chat_bubble_2,
                        PackExportType.telegram => CupertinoIcons.paperplane,
                      },
                      size: 22.r,
                      color: AppColors.cyan,
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            type.blurb,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textTertiary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_busy) ...[
            SizedBox(height: 8.h),
            const Center(child: CupertinoActivityIndicator()),
          ],
        ],
      ),
    );
  }
}
