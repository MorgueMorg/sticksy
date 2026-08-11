import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/image_filters.dart';
import '../../../core/utils/image_ops.dart';
import '../../../core/widgets/checkerboard.dart';
import '../../../core/widgets/color_swatches.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../ai/presentation/ai_studio_sheet.dart';
import '../../packs/domain/models.dart';
import '../domain/editor_models.dart';
import '../state/sticker_editor_controller.dart';

class StickerEditorArgs {
  const StickerEditorArgs({
    required this.packId,
    this.stickerId,
    this.initialImagePath,
    this.openAiStudio = false,
  });

  final String packId;
  final String? stickerId;
  final String? initialImagePath;

  /// Jump straight into AI Studio (used by the "Generate with AI" entry point).
  final bool openAiStudio;
}

class StickerEditorInit {
  const StickerEditorInit({
    required this.packId,
    required this.sticker,
    required this.initialImagePath,
  });

  final String packId;
  final StickerItem? sticker;
  final String? initialImagePath;

  @override
  bool operator ==(Object other) =>
      other is StickerEditorInit &&
      other.packId == packId &&
      other.sticker?.id == sticker?.id &&
      other.initialImagePath == initialImagePath;

  @override
  int get hashCode =>
      Object.hash(packId, sticker?.id ?? '', initialImagePath ?? '');
}

final stickerEditorProvider = StateNotifierProvider.autoDispose
    .family<StickerEditorController, StickerEditorState, StickerEditorInit>(
  (ref, init) => StickerEditorController(
    packId: init.packId,
    initialSticker: init.sticker,
    initialImagePath: init.initialImagePath,
  ),
);

/// Everything gets exported at this size — the sticker standard for WhatsApp
/// and Telegram alike.
const double kExportSize = 512;

class StickerEditorScreen extends ConsumerStatefulWidget {
  const StickerEditorScreen({super.key, this.args});

  final StickerEditorArgs? args;

  @override
  ConsumerState<StickerEditorScreen> createState() =>
      _StickerEditorScreenState();
}

class _StickerEditorScreenState extends ConsumerState<StickerEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  /// When true the canvas renders "clean": no checkerboard, no selection
  /// chrome, no rounded corners. The old editor rasterised the checkerboard
  /// straight into every saved sticker.
  bool _capturing = false;

  StickerEditorInit? _init;
  bool _studioOpened = false;

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null || args.packId.isEmpty) {
      return GradientScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => context.pop(),
          ),
        ),
        body: EmptyState(
          icon: CupertinoIcons.exclamationmark_circle,
          title: 'No pack selected',
          message: 'Open a pack first, then add a sticker to it.',
          actionLabel: 'Back to packs',
          actionIcon: CupertinoIcons.house_fill,
          onAction: () => context.go('/'),
        ),
      );
    }

    final stickerId = args.stickerId;
    if (stickerId == null) return _buildEditor(args, null);

    return ref.watch(stickerByIdProvider(stickerId)).when(
          data: (sticker) => _buildEditor(args, sticker),
          loading: () => const GradientScaffold(
            body: Center(child: CupertinoActivityIndicator(radius: 14)),
          ),
          error: (error, _) => GradientScaffold(
            body: EmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: 'Could not open this sticker',
              message: '$error',
              actionLabel: 'Go back',
              actionIcon: CupertinoIcons.back,
              onAction: () => context.pop(),
            ),
          ),
        );
  }

  Widget _buildEditor(StickerEditorArgs args, StickerItem? sticker) {
    final init = StickerEditorInit(
      packId: args.packId,
      sticker: sticker,
      initialImagePath: args.initialImagePath,
    );
    _init = init;
    final state = ref.watch(stickerEditorProvider(init));
    final controller = ref.read(stickerEditorProvider(init).notifier);

    if (args.openAiStudio && !_studioOpened) {
      _studioOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAiStudio(controller);
      });
    }

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmDialog(
          context,
          title: 'Discard changes?',
          message: 'This sticker has unsaved edits.',
          confirmLabel: 'Discard',
        );
        if (leave && mounted) context.pop();
      },
      child: GradientScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: PressFx(
            onTap: () => _rename(controller, state),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    state.stickerName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(
                  CupertinoIcons.pencil,
                  size: 14.r,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Undo',
              onPressed: state.canUndo ? controller.undo : null,
              icon: const Icon(CupertinoIcons.arrow_uturn_left),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed: state.canRedo ? controller.redo : null,
              icon: const Icon(CupertinoIcons.arrow_uturn_right),
            ),
            SizedBox(width: 4.w),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(child: _buildCanvas(state, controller)),
                  if (state.isDrawing)
                    _DrawBar(state: state, controller: controller)
                  else if (state.selectedLayer != null)
                    _LayerBar(
                      state: state,
                      controller: controller,
                      onEdit: () => _editSelected(state, controller),
                    ),
                  SizedBox(height: 10.h),
                  _Toolbar(
                    state: state,
                    onBackground: () => _backgroundSheet(controller, state),
                    onText: () => _textSheet(controller),
                    onEmoji: () => _emojiSheet(controller),
                    onShape: () => _shapeSheet(controller),
                    onDraw: () => controller.setDrawingMode(!state.isDrawing),
                    onOutline: () => _outlineSheet(controller, state),
                    onFilter: () => _filterSheet(controller, state),
                    onCanvas: () => _canvasSheet(controller, state),
                    onImport: () => _pickImage(controller),
                    onAi: () => _openAiStudio(controller),
                  ),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: SoftButton(
                            label: 'Share',
                            icon: CupertinoIcons.share,
                            onPressed: state.isSaving
                                ? null
                                : () => _exportSticker(state, controller),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          flex: 2,
                          child: GradientButton(
                            label: 'Save sticker',
                            icon: CupertinoIcons.checkmark_alt,
                            busy: state.isSaving,
                            onPressed: state.isSaving
                                ? null
                                : () => _saveSticker(state, controller),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                ],
              ),
              if (state.isSaving)
                const Positioned.fill(child: _BusyOverlay()),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Canvas
  // ---------------------------------------------------------------------------

  Widget _buildCanvas(
    StickerEditorState state,
    StickerEditorController controller,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = state.canvasSize;
        final scale = math
            .min(
              (constraints.maxWidth - 32.w) / size.width,
              (constraints.maxHeight - 24.h) / size.height,
            )
            .clamp(0.05, 4.0);

        return Center(
          child: Transform.scale(
            scale: scale,
            child: RepaintBoundary(
              key: _canvasKey,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: state.isDrawing
                      ? null
                      : () => controller.selectLayer(null),
                  onPanStart: state.isDrawing
                      ? (d) => controller.startStroke(d.localPosition)
                      : null,
                  onPanUpdate: state.isDrawing
                      ? (d) => controller.updateStroke(d.localPosition)
                      : null,
                  onPanEnd:
                      state.isDrawing ? (_) => controller.endStroke() : null,
                  child: _StickerCanvas(
                    state: state,
                    capturing: _capturing,
                    displayScale: scale,
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Rasterising
  // ---------------------------------------------------------------------------

  /// Renders the canvas to PNG bytes with all editor chrome hidden.
  Future<Uint8List?> _flatten(StickerEditorState state) async {
    setState(() => _capturing = true);
    try {
      // Two frames: one to rebuild without chrome, one to guarantee the layer
      // tree has been re-rasterised before we read it back.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final boundary = _canvasKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return null;

      final longest =
          math.max(state.canvasSize.width, state.canvasSize.height);
      final pixelRatio = (kExportSize / longest).clamp(0.5, 6.0);

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// Flatten + die-cut border + square canvas + requested encoding.
  Future<_Rendered?> _render(StickerEditorState state) async {
    var bytes = await _flatten(state);
    if (bytes == null) return null;

    if (state.outline.enabled) {
      bytes = await ImageOps.trimTransparent(bytes);
      bytes = await ImageOps.addOutline(
        bytes,
        width: state.outline.width.round(),
        argbColor: state.outline.color.toARGB32(),
      );
    }
    bytes = await ImageOps.fitSquare(bytes, size: kExportSize.round());

    if (state.exportFormat == StickerFormat.webp) {
      final webp = await ref
          .read(imageExportServiceProvider)
          .encodeWebpOrPng(bytes, quality: 90);
      return _Rendered(webp.bytes, webp.format);
    }
    return _Rendered(bytes, StickerFormat.png);
  }

  Future<void> _saveSticker(
    StickerEditorState state,
    StickerEditorController controller,
  ) async {
    controller.setSaving(true);
    try {
      final rendered = await _render(state);
      if (rendered == null) {
        if (mounted) showAppSnack(context, 'Nothing to save yet.', isError: true);
        return;
      }

      final repository = ref.read(stickerRepositoryProvider);
      final storage = ref.read(storageServiceProvider);
      final stickerId = state.stickerId ?? const Uuid().v4();
      final filePath = await storage.saveStickerBytes(
        packId: state.packId,
        stickerId: stickerId,
        extension: rendered.format.extension,
        bytes: rendered.bytes,
      );

      final layersJson = controller.serializeEditorState();
      final side = kExportSize.round();
      if (state.stickerId == null) {
        await repository.createSticker(
          id: stickerId,
          packId: state.packId,
          name: state.stickerName,
          filePath: filePath,
          width: side,
          height: side,
          format: rendered.format,
          layersJson: layersJson,
          fileSize: rendered.bytes.length,
        );
        controller.setStickerId(stickerId);
      } else {
        await repository.updateSticker(
          id: stickerId,
          name: state.stickerName,
          filePath: filePath,
          width: side,
          height: side,
          format: rendered.format,
          layersJson: layersJson,
          fileSize: rendered.bytes.length,
        );
      }

      controller.markSaved();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showAppSnack(context, 'Saved to your pack');
    } catch (error) {
      if (mounted) showAppSnack(context, 'Save failed: $error', isError: true);
    } finally {
      controller.setSaving(false);
    }
  }

  Future<void> _exportSticker(
    StickerEditorState state,
    StickerEditorController controller,
  ) async {
    controller.setSaving(true);
    try {
      final rendered = await _render(state);
      if (rendered == null) {
        if (mounted) {
          showAppSnack(context, 'Add something to the canvas first.',
              isError: true);
        }
        return;
      }
      final cache = ref.read(cacheServiceProvider);
      final safeName = state.stickerName
          .replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '')
          .trim()
          .replaceAll(' ', '_');
      final file = await cache.createExportFile(
        '${safeName.isEmpty ? 'sticker' : safeName}'
        '_${DateTime.now().millisecondsSinceEpoch}'
        '.${rendered.format.extension}',
      );
      await file.writeAsBytes(rendered.bytes, flush: true);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (error) {
      if (mounted) showAppSnack(context, 'Share failed: $error', isError: true);
    } finally {
      controller.setSaving(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _rename(
    StickerEditorController controller,
    StickerEditorState state,
  ) async {
    final name = await promptForText(
      context,
      title: 'Sticker name',
      initialValue: state.stickerName,
      hint: 'Sleepy cat',
    );
    if (name == null) return;
    controller.setStickerName(name);
    final id = state.stickerId;
    if (id != null) {
      await ref.read(stickerRepositoryProvider).renameSticker(id, name);
    }
  }

  Future<void> _pickImage(StickerEditorController controller) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (file == null) return;
      final bytes = await File(file.path).readAsBytes();
      final size = await _decodeSize(bytes);
      controller.addImageLayer(file.path, _fitInside(size, 360));
    } catch (error) {
      if (mounted) {
        showAppSnack(context, 'Could not open that image.', isError: true);
      }
    }
  }

  Future<void> _openAiStudio(StickerEditorController controller) async {
    await showAppSheet(
      context,
      builder: (_) => AiStudioSheet(
        onAccept: (bytes, suggestedName) async {
          try {
            final cache = ref.read(cacheServiceProvider);
            final file = await cache.createExportFile(
              'ai_${DateTime.now().millisecondsSinceEpoch}.png',
            );
            await file.writeAsBytes(bytes, flush: true);
            final size = await _decodeSize(bytes);
            controller.addImageLayer(file.path, _fitInside(size, 420));
            if (suggestedName.isNotEmpty) {
              controller.setStickerName(_titleCase(suggestedName));
            }
          } catch (error) {
            if (mounted) {
              showAppSnack(context, 'Could not add the image.', isError: true);
            }
          }
        },
      ),
    );
  }

  void _editSelected(
    StickerEditorState state,
    StickerEditorController controller,
  ) {
    final layer = state.selectedLayer;
    if (layer is TextLayer) {
      _textSheet(controller, existing: layer);
    } else if (layer is ShapeLayer) {
      _shapeSheet(controller, existing: layer);
    } else if (layer is ImageLayer) {
      _imageLayerSheet(controller, layer);
    }
  }

  // ---------------------------------------------------------------------------
  // Sheets
  // ---------------------------------------------------------------------------

  Future<void> _backgroundSheet(
    StickerEditorController controller,
    StickerEditorState state,
  ) async {
    await showAppSheet(
      context,
      builder: (context) => SheetSurface(
        title: 'Background',
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final background = _live(state).background;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionLabel('Solid colour'),
                ColorSwatches(
                  includeTransparent: true,
                  selected: background.type == BackgroundType.transparent
                      ? Colors.transparent
                      : (background.color ?? Colors.transparent),
                  onChanged: (color) {
                    controller.setBackground(
                      color == Colors.transparent
                          ? const StickerBackground(
                              type: BackgroundType.transparent,
                            )
                          : StickerBackground(
                              type: BackgroundType.solid,
                              color: color,
                            ),
                    );
                    setSheetState(() {});
                  },
                ),
                SizedBox(height: 22.h),
                const SectionLabel('Gradient'),
                SizedBox(
                  height: 56.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: AppColors.cardGradients.length,
                    separatorBuilder: (_, __) => SizedBox(width: 10.w),
                    itemBuilder: (context, index) {
                      final gradient = AppColors.cardGradients[index];
                      return PressFx(
                        onTap: () {
                          controller.setBackground(
                            StickerBackground(
                              type: BackgroundType.gradient,
                              color: gradient.first,
                              secondaryColor: gradient.last,
                            ),
                          );
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: 76.w,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradient),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  'Transparent backgrounds export with a real alpha channel — '
                  'the checkerboard is only a preview.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textTertiary,
                    height: 1.4,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Live state for sheets. Must reuse the exact family key the screen is
  /// watching, otherwise Riverpod hands back a second, empty controller.
  StickerEditorState _live(StickerEditorState fallback) {
    final init = _init;
    if (init == null) return fallback;
    return ref.read(stickerEditorProvider(init));
  }

  Future<void> _textSheet(
    StickerEditorController controller, {
    TextLayer? existing,
  }) async {
    await showAppSheet(
      context,
      builder: (_) => _TextLayerSheet(
        existing: existing,
        onSubmit: (draft) {
          if (existing == null) {
            controller.addTextLayer(
              draft.text,
              color: draft.color,
              strokeColor: draft.strokeColor,
              strokeWidth: draft.strokeWidth,
              fontSize: draft.fontSize,
              bold: draft.bold,
            );
          } else {
            controller.updateTextLayer(
              existing.id,
              text: draft.text,
              color: draft.color,
              strokeColor: draft.strokeColor,
              strokeWidth: draft.strokeWidth,
              fontSize: draft.fontSize,
              bold: draft.bold,
            );
          }
        },
      ),
    );
  }

  Future<void> _emojiSheet(StickerEditorController controller) async {
    await showAppSheet(
      context,
      builder: (context) => SheetSurface(
        title: 'Emoji',
        child: SizedBox(
          height: 360.h,
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8.h,
              crossAxisSpacing: 8.w,
            ),
            itemCount: _emojis.length,
            itemBuilder: (context, index) {
              final emoji = _emojis[index];
              return PressFx(
                onTap: () {
                  controller.addEmojiLayer(emoji);
                  Navigator.of(context).pop();
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Text(emoji, style: TextStyle(fontSize: 24.sp)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _shapeSheet(
    StickerEditorController controller, {
    ShapeLayer? existing,
  }) async {
    var color = existing?.color ?? AppColors.violet;
    var shape = existing?.shape ?? ShapeType.circle;

    await showAppSheet(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SheetSurface(
          title: existing == null ? 'Add shape' : 'Edit shape',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: ShapeType.values.map((value) {
                  final isSelected = value == shape;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      child: PressFx(
                        onTap: () => setSheetState(() => shape = value),
                        child: Container(
                          height: 72.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.violet
                                  : AppColors.stroke,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Container(
                            width: 34.r,
                            height: 34.r,
                            decoration: BoxDecoration(
                              color: color,
                              shape: value == ShapeType.circle
                                  ? BoxShape.circle
                                  : BoxShape.rectangle,
                              borderRadius: value == ShapeType.roundedSquare
                                  ? BorderRadius.circular(10.r)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 20.h),
              const SectionLabel('Colour'),
              ColorSwatches(
                selected: color,
                onChanged: (value) => setSheetState(() => color = value),
              ),
              SizedBox(height: 20.h),
              GradientButton(
                label: existing == null ? 'Add shape' : 'Apply',
                onPressed: () {
                  if (existing == null) {
                    controller.addShapeLayer(shape, color);
                  } else {
                    controller.updateShapeLayer(
                      existing.id,
                      shape: shape,
                      color: color,
                    );
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _imageLayerSheet(
    StickerEditorController controller,
    ImageLayer layer,
  ) async {
    await showAppSheet(
      context,
      builder: (context) => SheetSurface(
        title: 'Image layer',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftButton(
              label: 'Remove background',
              icon: CupertinoIcons.scissors,
              onPressed: () {
                Navigator.of(context).pop();
                _cutoutLayer(controller, layer);
              },
            ),
            SizedBox(height: 10.h),
            SoftButton(
              label: 'Replace image',
              icon: CupertinoIcons.photo_on_rectangle,
              onPressed: () async {
                Navigator.of(context).pop();
                final file = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 2048,
                  maxHeight: 2048,
                );
                if (file == null) return;
                final bytes = await File(file.path).readAsBytes();
                final size = await _decodeSize(bytes);
                controller.replaceImageLayer(
                  layer.id,
                  file.path,
                  _fitInside(size, 360),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cutoutLayer(
    StickerEditorController controller,
    ImageLayer layer,
  ) async {
    controller.setSaving(true);
    try {
      final bytes = await File(layer.filePath).readAsBytes();
      final result =
          await ref.read(aiRepositoryProvider).removeBackground(bytes);
      if (!result.isSuccess) {
        if (mounted) showAppSnack(context, result.errorMessage, isError: true);
        return;
      }
      final cache = ref.read(cacheServiceProvider);
      final file = await cache.createExportFile(
        'cutout_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(result.value, flush: true);
      final size = await _decodeSize(result.value);
      controller.replaceImageLayer(
        layer.id,
        file.path,
        _fitInside(size, layer.size.longestSide),
      );
      if (mounted) showAppSnack(context, 'Background removed');
    } catch (error) {
      if (mounted) showAppSnack(context, 'Cutout failed: $error', isError: true);
    } finally {
      controller.setSaving(false);
    }
  }

  Future<void> _outlineSheet(
    StickerEditorController controller,
    StickerEditorState state,
  ) async {
    var width = state.outline.width;
    var color = state.outline.color;

    await showAppSheet(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SheetSurface(
          title: 'Die-cut border',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Traces the whole sticker silhouette when you save. Works best '
                'on a transparent background.',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              _LabeledSlider(
                label: 'Thickness',
                value: width,
                min: 0,
                max: 40,
                divisions: 20,
                suffix: width == 0 ? 'Off' : '${width.round()}px',
                onChanged: (value) => setSheetState(() => width = value),
              ),
              const SectionLabel('Colour'),
              ColorSwatches(
                selected: color,
                onChanged: (value) => setSheetState(() => color = value),
              ),
              SizedBox(height: 20.h),
              GradientButton(
                label: 'Apply',
                onPressed: () {
                  controller.setOutline(
                    StickerOutline(width: width, color: color),
                  );
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _filterSheet(
    StickerEditorController controller,
    StickerEditorState state,
  ) async {
    var brightness = state.filter.brightness;
    var saturation = state.filter.saturation;

    await showAppSheet(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SheetSurface(
          title: 'Adjust',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LabeledSlider(
                label: 'Brightness',
                value: brightness,
                min: -0.5,
                max: 0.5,
                divisions: 20,
                suffix: brightness.toStringAsFixed(2),
                onChanged: (value) => setSheetState(() => brightness = value),
              ),
              _LabeledSlider(
                label: 'Saturation',
                value: saturation,
                min: 0,
                max: 2,
                divisions: 20,
                suffix: saturation.toStringAsFixed(2),
                onChanged: (value) => setSheetState(() => saturation = value),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: 'Reset',
                      onPressed: () => setSheetState(() {
                        brightness = 0;
                        saturation = 1;
                      }),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: GradientButton(
                      label: 'Apply',
                      onPressed: () {
                        controller.setFilter(
                          StickerFilter(
                            brightness: brightness,
                            saturation: saturation,
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _canvasSheet(
    StickerEditorController controller,
    StickerEditorState state,
  ) async {
    const presets = [
      StickerSizePreset(label: 'Square', width: 512, height: 512),
      StickerSizePreset(label: 'Portrait', width: 384, height: 512),
      StickerSizePreset(label: 'Landscape', width: 512, height: 384),
      StickerSizePreset(label: 'Tall', width: 384, height: 640),
    ];

    await showAppSheet(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final current = _live(state);
          return SheetSurface(
            title: 'Canvas & export',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionLabel('Shape'),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: presets.map((preset) {
                    final isSelected =
                        current.canvasSize.width == preset.width &&
                            current.canvasSize.height == preset.height;
                    return ChoiceChip(
                      label: Text(preset.label),
                      selected: isSelected,
                      onSelected: (_) {
                        controller
                            .setCanvasSize(Size(preset.width, preset.height));
                        setSheetState(() {});
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 22.h),
                const SectionLabel('Format'),
                SegmentedButton<StickerFormat>(
                  segments: const [
                    ButtonSegment(
                      value: StickerFormat.png,
                      label: Text('PNG'),
                    ),
                    ButtonSegment(
                      value: StickerFormat.webp,
                      label: Text('WebP'),
                    ),
                  ],
                  selected: {current.exportFormat},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) {
                    controller.setExportFormat(value.first);
                    setSheetState(() {});
                  },
                ),
                SizedBox(height: 16.h),
                Text(
                  'Stickers always export at 512×512 with transparency, which '
                  'is what WhatsApp and Telegram expect.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textTertiary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Size> _decodeSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      return size;
    } finally {
      codec.dispose();
    }
  }

  Size _fitInside(Size source, double longest) {
    if (source.width <= 0 || source.height <= 0) {
      return Size(longest, longest);
    }
    final scale = longest / math.max(source.width, source.height);
    return Size(source.width * scale, source.height * scale);
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    final words = value.split(RegExp(r'\s+')).take(4);
    return words
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class _Rendered {
  const _Rendered(this.bytes, this.format);

  final Uint8List bytes;
  final StickerFormat format;
}

class _TextDraft {
  const _TextDraft({
    required this.text,
    required this.color,
    required this.strokeColor,
    required this.strokeWidth,
    required this.fontSize,
    required this.bold,
  });

  final String text;
  final Color color;
  final Color strokeColor;
  final double strokeWidth;
  final double fontSize;
  final bool bold;
}

/// Text editing sheet.
///
/// A real [State] rather than a `StatefulBuilder` + a controller created in the
/// calling method: that pattern disposes the controller when the pop future
/// resolves, which is before the sheet has finished animating out, and the next
/// rebuild then throws "A TextEditingController was used after being disposed".
class _TextLayerSheet extends StatefulWidget {
  const _TextLayerSheet({required this.existing, required this.onSubmit});

  final TextLayer? existing;
  final ValueChanged<_TextDraft> onSubmit;

  @override
  State<_TextLayerSheet> createState() => _TextLayerSheetState();
}

class _TextLayerSheetState extends State<_TextLayerSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.existing?.text ?? '');

  late Color _color = widget.existing?.color ?? Colors.white;
  late Color _strokeColor = widget.existing?.strokeColor ?? Colors.black;
  late double _strokeWidth = widget.existing?.strokeWidth ?? 3;
  late double _fontSize = widget.existing?.fontSize ?? 48;
  late bool _bold = widget.existing?.bold ?? true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(
      _TextDraft(
        text: text,
        color: _color,
        strokeColor: _strokeColor,
        strokeWidth: _strokeWidth,
        fontSize: _fontSize,
        bold: _bold,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    return SheetSurface(
      title: isNew ? 'Add text' : 'Edit text',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: isNew,
            minLines: 1,
            maxLines: 3,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: 16.sp),
            decoration: const InputDecoration(
              hintText: 'LOL',
              counterText: '',
            ),
          ),
          SizedBox(height: 18.h),
          const SectionLabel('Fill'),
          ColorSwatches(
            selected: _color,
            onChanged: (value) => setState(() => _color = value),
          ),
          SizedBox(height: 18.h),
          const SectionLabel('Outline'),
          ColorSwatches(
            selected: _strokeColor,
            onChanged: (value) => setState(() => _strokeColor = value),
          ),
          _LabeledSlider(
            label: 'Outline width',
            value: _strokeWidth,
            min: 0,
            max: 12,
            divisions: 12,
            suffix: _strokeWidth.round().toString(),
            onChanged: (value) => setState(() => _strokeWidth = value),
          ),
          _LabeledSlider(
            label: 'Size',
            value: _fontSize,
            min: 16,
            max: 140,
            divisions: 31,
            suffix: _fontSize.round().toString(),
            onChanged: (value) => setState(() => _fontSize = value),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6.h),
            child: Row(
              children: [
                Text(
                  'Bold',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: _bold,
                  onChanged: (value) => setState(() => _bold = value),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          GradientButton(
            label: isNew ? 'Add text' : 'Apply',
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Canvas rendering
// ---------------------------------------------------------------------------

class _StickerCanvas extends StatelessWidget {
  const _StickerCanvas({
    required this.state,
    required this.capturing,
    required this.displayScale,
    required this.controller,
  });

  final StickerEditorState state;
  final bool capturing;
  final double displayScale;
  final StickerEditorController controller;

  bool get _hasFilter =>
      state.filter.brightness != 0 || state.filter.saturation != 1;

  @override
  Widget build(BuildContext context) {
    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _DrawingPainter(
              layers: state.layers.whereType<DrawingLayer>().toList(),
              activeStroke: state.activeStroke,
            ),
          ),
        ),
        for (final layer in state.layers)
          if (layer.type != StickerLayerType.drawing)
            _LayerWidget(
              key: ValueKey(layer.id),
              layer: layer,
              selected: !capturing && state.selectedLayerId == layer.id,
              enabled: !capturing && !state.isDrawing,
              displayScale: displayScale,
              canvasSize: state.canvasSize,
              onTap: () => controller.selectLayer(layer.id),
              onTransformStart: controller.beginTransform,
              onTransform: (transform) =>
                  controller.updateLayerTransform(layer.id, transform),
              onTransformEnd: controller.endTransform,
            ),
      ],
    );

    if (_hasFilter) {
      content = ColorFiltered(
        colorFilter: ColorFilter.matrix(
          ImageFilters.colorMatrix(
            brightness: state.filter.brightness,
            saturation: state.filter.saturation,
          ),
        ),
        child: content,
      );
    }

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _background(state.background, capturing)),
        content,
      ],
    );

    // Rounded corners are chrome too — a sticker should keep its real edges.
    if (capturing) return stack;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: stack,
    );
  }

  Widget _background(StickerBackground background, bool capturing) {
    switch (background.type) {
      case BackgroundType.solid:
        return ColoredBox(color: background.color ?? Colors.transparent);
      case BackgroundType.gradient:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                background.color ?? Colors.transparent,
                background.secondaryColor ?? Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
      case BackgroundType.transparent:
        // Never rasterised — this is the single most important line in the
        // file. The old build baked this pattern into every exported sticker.
        if (capturing) return const SizedBox.expand();
        return CustomPaint(painter: CheckerboardPainter(square: 18));
    }
  }
}

class _LayerWidget extends StatefulWidget {
  const _LayerWidget({
    super.key,
    required this.layer,
    required this.selected,
    required this.enabled,
    required this.displayScale,
    required this.canvasSize,
    required this.onTap,
    required this.onTransformStart,
    required this.onTransform,
    required this.onTransformEnd,
  });

  final StickerLayer layer;
  final bool selected;
  final bool enabled;
  final double displayScale;
  final Size canvasSize;
  final VoidCallback onTap;
  final VoidCallback onTransformStart;
  final ValueChanged<LayerTransform> onTransform;
  final VoidCallback onTransformEnd;

  @override
  State<_LayerWidget> createState() => _LayerWidgetState();
}

class _LayerWidgetState extends State<_LayerWidget> {
  LayerTransform _startTransform = const LayerTransform(
    position: Offset.zero,
    scale: 1,
    rotation: 0,
  );
  Offset _accumulated = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final transform = widget.layer.transform;

    // Centre + intrinsic sizing, NOT Positioned.fill. The previous version gave
    // every layer a full-canvas hit area, so only the topmost layer could ever
    // be tapped or dragged.
    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(
            transform.position.dx,
            transform.position.dy,
            0,
            1,
          )
          ..rotateZ(transform.rotation)
          ..scaleByDouble(transform.scale, transform.scale, 1, 1),
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: widget.enabled ? widget.onTap : null,
          onScaleStart: widget.enabled
              ? (_) {
                  _startTransform = widget.layer.transform;
                  _accumulated = Offset.zero;
                  widget.onTransformStart();
                }
              : null,
          onScaleUpdate: widget.enabled
              ? (details) {
                  // focalPointDelta is in screen pixels; the canvas is drawn
                  // through Transform.scale, so undo that scale or dragging
                  // runs away from the finger.
                  final scale =
                      widget.displayScale <= 0 ? 1.0 : widget.displayScale;
                  _accumulated += details.focalPointDelta / scale;
                  widget.onTransform(
                    _startTransform.copyWith(
                      position: _startTransform.position + _accumulated,
                      scale: (_startTransform.scale * details.scale)
                          .clamp(0.15, 6.0),
                      rotation: _startTransform.rotation + details.rotation,
                    ),
                  );
                }
              : null,
          onScaleEnd: widget.enabled ? (_) => widget.onTransformEnd() : null,
          child: _Chrome(
            selected: widget.selected,
            child: Opacity(
              opacity: widget.layer.opacity,
              child: _content(widget.layer),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(StickerLayer layer) {
    if (layer is ImageLayer) {
      return SizedBox(
        width: layer.size.width,
        height: layer.size.height,
        child: Image.file(
          File(layer.filePath),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stack) => const _MissingImage(),
        ),
      );
    }

    if (layer is TextLayer) {
      final style = TextStyle(
        fontSize: layer.fontSize,
        height: 1.15,
        fontWeight: layer.bold ? FontWeight.w900 : FontWeight.w600,
        fontStyle: layer.italic ? FontStyle.italic : FontStyle.normal,
      );
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.canvasSize.width * 0.9),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (layer.strokeWidth > 0)
              Text(
                layer.text,
                textAlign: TextAlign.center,
                style: style.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeJoin = StrokeJoin.round
                    ..strokeWidth = layer.strokeWidth * 2
                    ..color = layer.strokeColor,
                ),
              ),
            Text(
              layer.text,
              textAlign: TextAlign.center,
              style: style.copyWith(
                color: layer.color,
                shadows: layer.shadow > 0
                    ? [
                        Shadow(
                          blurRadius: layer.shadow,
                          color: Colors.black.withValues(alpha: 0.45),
                          offset: const Offset(2, 3),
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      );
    }

    if (layer is EmojiLayer) {
      return Text(
        layer.emoji,
        style: TextStyle(fontSize: layer.size, height: 1.2),
      );
    }

    if (layer is ShapeLayer) {
      return Container(
        width: layer.size.width,
        height: layer.size.height,
        decoration: BoxDecoration(
          color: layer.color,
          shape: layer.shape == ShapeType.circle
              ? BoxShape.circle
              : BoxShape.rectangle,
          borderRadius: layer.shape == ShapeType.roundedSquare
              ? BorderRadius.circular(28)
              : null,
          border: layer.strokeWidth > 0
              ? Border.all(color: layer.strokeColor, width: layer.strokeWidth)
              : null,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!selected) return Padding(padding: const EdgeInsets.all(6), child: child);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cyan, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _MissingImage extends StatelessWidget {
  const _MissingImage();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          CupertinoIcons.photo,
          color: AppColors.textTertiary,
          size: 32,
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter({required this.layers, required this.activeStroke});

  final List<DrawingLayer> layers;
  final DrawingStroke? activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    for (final layer in layers) {
      for (final stroke in layer.strokes) {
        _paintStroke(canvas, stroke, layer.opacity);
      }
    }
    final active = activeStroke;
    if (active != null) _paintStroke(canvas, active, 1);
  }

  void _paintStroke(Canvas canvas, DrawingStroke stroke, double opacity) {
    if (stroke.points.isEmpty) return;
    final paint = Paint()
      ..color = stroke.color.withValues(alpha: stroke.color.a * opacity)
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first,
        stroke.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    // Quadratic smoothing through midpoints — plain lineTo looks jagged.
    final path = Path()
      ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (var i = 1; i < stroke.points.length - 1; i++) {
      final current = stroke.points[i];
      final next = stroke.points[i + 1];
      path.quadraticBezierTo(
        current.dx,
        current.dy,
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
    }
    path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) =>
      oldDelegate.layers != layers || oldDelegate.activeStroke != activeStroke;
}

// ---------------------------------------------------------------------------
// Bars
// ---------------------------------------------------------------------------

class _LayerBar extends StatelessWidget {
  const _LayerBar({
    required this.state,
    required this.controller,
    required this.onEdit,
  });

  final StickerEditorState state;
  final StickerEditorController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final layer = state.selectedLayer;
    if (layer == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GlassCard(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        borderRadius: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconPill(
              icon: CupertinoIcons.slider_horizontal_3,
              tooltip: 'Edit',
              size: 36,
              onPressed: onEdit,
            ),
            IconPill(
              icon: CupertinoIcons.square_on_square,
              tooltip: 'Duplicate',
              size: 36,
              onPressed: () => controller.duplicateLayer(layer.id),
            ),
            IconPill(
              icon: CupertinoIcons.arrow_up_square,
              tooltip: 'Bring forward',
              size: 36,
              onPressed: () => controller.reorderLayer(layer.id, 1),
            ),
            IconPill(
              icon: CupertinoIcons.arrow_down_square,
              tooltip: 'Send backward',
              size: 36,
              onPressed: () => controller.reorderLayer(layer.id, -1),
            ),
            IconPill(
              icon: CupertinoIcons.delete,
              tooltip: 'Delete layer',
              size: 36,
              accent: AppColors.danger,
              onPressed: () => controller.removeLayer(layer.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawBar extends StatelessWidget {
  const _DrawBar({required this.state, required this.controller});

  final StickerEditorState state;
  final StickerEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GlassCard(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        borderRadius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorSwatches(
              size: 30,
              selected: state.drawingColor,
              onChanged: controller.setDrawingColor,
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(
                  CupertinoIcons.pencil,
                  size: 16.r,
                  color: AppColors.textTertiary,
                ),
                Expanded(
                  child: Slider(
                    value: state.drawingWidth,
                    min: 2,
                    max: 40,
                    onChanged: controller.setDrawingWidth,
                  ),
                ),
                IconPill(
                  icon: CupertinoIcons.arrow_uturn_left,
                  tooltip: 'Undo stroke',
                  size: 34,
                  onPressed: controller.undoLastStroke,
                ),
                SizedBox(width: 8.w),
                IconPill(
                  icon: CupertinoIcons.checkmark_alt,
                  tooltip: 'Done',
                  size: 34,
                  accent: AppColors.success,
                  onPressed: () => controller.setDrawingMode(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.state,
    required this.onBackground,
    required this.onText,
    required this.onEmoji,
    required this.onShape,
    required this.onDraw,
    required this.onOutline,
    required this.onFilter,
    required this.onCanvas,
    required this.onImport,
    required this.onAi,
  });

  final StickerEditorState state;
  final VoidCallback onBackground;
  final VoidCallback onText;
  final VoidCallback onEmoji;
  final VoidCallback onShape;
  final VoidCallback onDraw;
  final VoidCallback onOutline;
  final VoidCallback onFilter;
  final VoidCallback onCanvas;
  final VoidCallback onImport;
  final VoidCallback onAi;

  @override
  Widget build(BuildContext context) {
    final tools = <_Tool>[
      _Tool(CupertinoIcons.wand_stars, 'AI', onAi, accent: AppColors.pink),
      _Tool(CupertinoIcons.photo_on_rectangle, 'Photo', onImport),
      _Tool(CupertinoIcons.textformat, 'Text', onText),
      _Tool(CupertinoIcons.smiley, 'Emoji', onEmoji),
      _Tool(CupertinoIcons.circle_grid_3x3, 'Shape', onShape),
      _Tool(
        CupertinoIcons.pencil_outline,
        'Draw',
        onDraw,
        active: state.isDrawing,
      ),
      _Tool(
        CupertinoIcons.circle_lefthalf_fill,
        'Border',
        onOutline,
        active: state.outline.enabled,
      ),
      _Tool(CupertinoIcons.square_stack_3d_up, 'BG', onBackground),
      _Tool(CupertinoIcons.slider_horizontal_3, 'Adjust', onFilter),
      _Tool(CupertinoIcons.crop, 'Canvas', onCanvas),
    ];

    return SizedBox(
      height: 78.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: tools.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) => _ToolButton(tool: tools[index]),
      ),
    );
  }
}

class _Tool {
  const _Tool(
    this.icon,
    this.label,
    this.onTap, {
    this.active = false,
    this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? accent;
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool});

  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final accent = tool.accent;
    final highlighted = tool.active || accent != null;
    final color = tool.active
        ? AppColors.cyan
        : (accent ?? AppColors.textSecondary);

    return PressFx(
      onTap: tool.onTap,
      scale: 0.9,
      child: Container(
        width: 64.w,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: highlighted
              ? color.withValues(alpha: 0.14)
              : AppColors.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: highlighted
                ? color.withValues(alpha: 0.45)
                : AppColors.stroke,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tool.icon, size: 22.r, color: color),
            SizedBox(height: 5.h),
            Text(
              tool.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.suffix,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 10.h),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (suffix != null)
                Text(
                  suffix!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: const Center(
        child: CupertinoActivityIndicator(
          radius: 16,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}

const List<String> _emojis = [
  '😀', '😂', '🥹', '😍', '😎', '🤩', '🥳', '😭', '😱', '🤯', '🤔', '😴',
  '😇', '🥰', '😜', '🙃', '😤', '🤬', '🥶', '🤒', '🤠', '👻', '💀', '👽',
  '🤖', '🎃', '❤️', '💜', '💙', '💚', '🧡', '💛', '✨', '🔥', '💥', '⭐',
  '🌈', '☀️', '🌙', '⚡', '❄️', '🍀', '🌸', '🌺', '🍕', '🍔', '🍟', '🍩',
  '🍪', '🍰', '☕', '🍺', '🐱', '🐶', '🐼', '🦊', '🐸', '🦄', '🐝', '🐙',
  '👑', '💎', '🎉', '🎈', '🎁', '🏆', '⚽', '🎮', '🎧', '📸', '💯', '👍',
  '👎', '👋', '🙌', '🤝', '💪', '🫶', '🙏', '👀',
];
