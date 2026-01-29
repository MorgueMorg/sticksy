import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/image_filters.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../ai/presentation/ai_tools_sheet.dart';
import '../../packs/domain/models.dart';
import '../domain/editor_models.dart';
import '../state/sticker_editor_controller.dart';

class StickerEditorArgs {
  const StickerEditorArgs({
    required this.packId,
    this.stickerId,
    this.initialImagePath,
  });

  final String packId;
  final String? stickerId;
  final String? initialImagePath;
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
  bool operator ==(Object other) {
    return other is StickerEditorInit &&
        other.packId == packId &&
        other.sticker?.id == sticker?.id &&
        other.initialImagePath == initialImagePath;
  }

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

class StickerEditorScreen extends ConsumerStatefulWidget {
  const StickerEditorScreen({super.key, this.args});

  final StickerEditorArgs? args;

  @override
  ConsumerState<StickerEditorScreen> createState() =>
      _StickerEditorScreenState();
}

class _StickerEditorScreenState extends ConsumerState<StickerEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final _picker = ImagePicker();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args ?? StickerEditorArgs(packId: '');
    if (args.packId.isEmpty) {
      return const GradientScaffold(
        body: Center(child: Text('Missing pack context')),
      );
    }

    if (args.stickerId != null) {
      final stickerAsync = ref.watch(stickerByIdProvider(args.stickerId!));
      return stickerAsync.when(
        data: (sticker) => _buildEditor(context, args, sticker),
        loading: () => const GradientScaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => GradientScaffold(
          body: Center(child: Text('Failed to load sticker: $error')),
        ),
      );
    }

    return _buildEditor(context, args, null);
  }

  Widget _buildEditor(
    BuildContext context,
    StickerEditorArgs args,
    StickerItem? sticker,
  ) {
    final init = StickerEditorInit(
      packId: args.packId,
      sticker: sticker,
      initialImagePath: args.initialImagePath,
    );
    final state = ref.watch(stickerEditorProvider(init));
    final controller = ref.read(stickerEditorProvider(init).notifier);

    return GradientScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Workshop'),
        actions: [
          IconButton(
            tooltip: 'Canvas Settings',
            icon: const Icon(CupertinoIcons.slider_horizontal_3),
            onPressed: () =>
                _showCanvasSettingsSheet(context, state, controller),
          ),
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(CupertinoIcons.pencil),
            onPressed: () => _showRenameDialog(context, controller, state.stickerName, state.stickerId),
          ),
          IconButton(
            tooltip: 'Export',
            icon: const Icon(CupertinoIcons.share),
            onPressed: state.isSaving
                ? null
                : () => _exportSticker(context, state, controller),
          ),
          IconButton(
            tooltip: 'Save',
            icon: const Icon(CupertinoIcons.checkmark_circle),
            onPressed: state.isSaving
                ? null
                : () => _saveSticker(context, state, controller),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(child: _buildCanvas(context, state, controller)),
              ),
              const SizedBox(height: 12),
              _EditorToolbar(
                state: state,
                onBackground: () => _showBackgroundSheet(context, controller),
                onText: () => _showTextSheet(context, controller),
                onEmoji: () => _showEmojiSheet(context, controller),
                onShape: () => _showShapeSheet(context, controller),
                onCrop: () => _cropSelectedLayer(context, state, controller),
                onDraw: () => controller.setDrawingMode(!state.isDrawing),
                onFilter: () => _showFilterSheet(context, state, controller),
                onImport: () => _pickImage(controller),
                onAI: () => _showAiSheet(context, state, controller),
              ),
              const SizedBox(height: 12),
            ],
          ),
          if (state.isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CupertinoActivityIndicator(color: CupertinoColors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCanvas(
    BuildContext context,
    StickerEditorState state,
    StickerEditorController controller,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = state.canvasSize;
        // Вычисляем максимальный размер, который может занять холст (80% от доступного пространства)
        final maxWidth = constraints.maxWidth * 0.9;
        final maxHeight = constraints.maxHeight * 0.9;
        final scale = math
            .min(maxWidth / size.width, maxHeight / size.height)
            .clamp(0.5, 4.0); // Ограничиваем масштаб от 0.5x до 1.5x

        return Center(
          child: Transform.scale(
            scale: scale,
            child: RepaintBoundary(
              key: _canvasKey,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: GestureDetector(
                  onTap: state.isDrawing
                      ? null
                      : () => controller.selectLayer(null),
                  onPanStart: state.isDrawing
                      ? (details) =>
                            controller.startStroke(details.localPosition)
                      : null,
                  onPanUpdate: state.isDrawing
                      ? (details) =>
                            controller.updateStroke(details.localPosition)
                      : null,
                  onPanEnd: state.isDrawing
                      ? (_) => controller.endStroke()
                      : null,
                  child: _StickerCanvas(
                    state: state,
                    onLayerTap: controller.selectLayer,
                    onLayerTransform: controller.updateLayerTransform,
                    onLayerOpacity: controller.updateLayerOpacity,
                    onDeleteLayer: controller.removeLayer,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(StickerEditorController controller) async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await File(file.path).readAsBytes();
    final size = await _decodeImageSize(bytes);
    controller.addImageLayer(file.path, size);
  }

  Future<void> _saveSticker(
    BuildContext context,
    StickerEditorState state,
    StickerEditorController controller,
  ) async {
    controller.setSaving(true);
    try {
      final image = await _captureImage(context);
      if (image == null) return;
      final bytes = await _encodeImage(image, state.exportFormat);
      final repository = ref.read(stickerRepositoryProvider);
      final storage = ref.read(storageServiceProvider);
      final stickerId = state.stickerId ?? const Uuid().v4();
      final filePath = await storage.saveStickerBytes(
        packId: state.packId,
        stickerId: stickerId,
        extension: state.exportFormat.extension,
        bytes: bytes,
      );
      final layersJson = controller.serializeEditorState();
      if (state.stickerId == null) {
        await repository.createSticker(
          id: stickerId,
          packId: state.packId,
          name: state.stickerName,
          filePath: filePath,
          width: image.width,
          height: image.height,
          format: state.exportFormat,
          layersJson: layersJson,
          fileSize: bytes.length,
        );
        controller.setStickerId(stickerId);
      } else {
        await repository.updateSticker(
          id: stickerId,
          name: state.stickerName,
          filePath: filePath,
          width: image.width,
          height: image.height,
          format: state.exportFormat,
          layersJson: layersJson,
          fileSize: bytes.length,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sticker "${state.stickerName}" saved')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    } finally {
      controller.setSaving(false);
    }
  }

  Future<void> _exportSticker(
    BuildContext context,
    StickerEditorState state,
    StickerEditorController controller,
  ) async {
    controller.setSaving(true);
    try {
      final image = await _captureImage(context);
      if (image == null) return;
      final bytes = await _encodeImage(image, state.exportFormat);
      final cacheService = ref.read(cacheServiceProvider);
      final file = await cacheService.createExportFile(
        'sticker_${DateTime.now().millisecondsSinceEpoch}.${state.exportFormat.extension}',
      );
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(file.path)], text: 'Sticker export');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
    } finally {
      controller.setSaving(false);
    }
  }

  Future<ui.Image?> _captureImage(BuildContext context) async {
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final pixelRatio = math.min(MediaQuery.of(context).devicePixelRatio, 3.0);
    return boundary.toImage(pixelRatio: pixelRatio);
  }

  Future<Uint8List> _encodeImage(ui.Image image, StickerFormat format) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();
    if (format == StickerFormat.png) return pngBytes;
    return ref
        .read(imageExportServiceProvider)
        .encodeWebp(pngBytes, quality: 85);
  }

  Future<Size> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return Size(frame.image.width.toDouble(), frame.image.height.toDouble());
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    StickerEditorController controller,
    String currentName,
    String? stickerId,
  ) async {
    _nameController.text = currentName;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sticker name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_nameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    final name = result.trim();
    controller.setStickerName(name);
    if (stickerId != null) {
      await ref.read(stickerRepositoryProvider).renameSticker(stickerId, name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sticker renamed to "$name"')),
        );
      }
    }
  }

  Future<void> _showBackgroundSheet(
    BuildContext context,
    StickerEditorController controller,
  ) async {
    final colors = [
      Colors.transparent,
      const Color(0xFF0C0D14),
      const Color(0xFF7C5CFF),
      const Color(0xFF00C2FF),
      const Color(0xFFFFB56B),
      const Color(0xFFFF6B6B),
      const Color(0xFF2ED47A),
    ];
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Background'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors
                  .map(
                    (color) => GestureDetector(
                      onTap: () {
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
                        Navigator.of(context).pop();
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: color == Colors.transparent
                            ? Colors.white24
                            : color,
                        child: color == Colors.transparent
                            ? const Icon(Icons.layers_clear)
                            : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                controller.setBackground(
                  const StickerBackground(
                    type: BackgroundType.gradient,
                    color: Color(0xFF7C5CFF),
                    secondaryColor: Color(0xFF00C2FF),
                  ),
                );
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.gradient),
              label: const Text('Apply Gradient'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTextSheet(
    BuildContext context,
    StickerEditorController controller,
  ) async {
    final textController = TextEditingController();
    Color selected = Colors.white;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add Text'),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                decoration: const InputDecoration(hintText: 'Your message'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children:
                    [
                          Colors.white,
                          Colors.black,
                          const Color(0xFFFF6B6B),
                          const Color(0xFF7C5CFF),
                          const Color(0xFF00C2FF),
                          const Color(0xFF2ED47A),
                        ]
                        .map(
                          (color) => GestureDetector(
                            onTap: () => setState(() => selected = color),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: color,
                              child: selected == color
                                  ? const Icon(Icons.check, size: 16)
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (textController.text.trim().isEmpty) return;
                  controller.addTextLayer(textController.text.trim(), selected);
                  Navigator.of(context).pop();
                },
                child: const Text('Add Text'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEmojiSheet(
    BuildContext context,
    StickerEditorController controller,
  ) async {
    const emojis = ['✨', '🔥', '🎉', '😂', '😎', '💜', '🌈', '🐱', '🍕', '👑'];
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Emoji'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: emojis
                  .map(
                    (emoji) => GestureDetector(
                      onTap: () {
                        controller.addEmojiLayer(emoji);
                        Navigator.of(context).pop();
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showShapeSheet(
    BuildContext context,
    StickerEditorController controller,
  ) async {
    const shapes = [
      ShapeType.circle,
      ShapeType.roundedSquare,
      ShapeType.square,
    ];
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Shape'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: shapes
                  .map(
                    (shape) => GestureDetector(
                      onTap: () {
                        controller.addShapeLayer(shape, Colors.white);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: shape == ShapeType.circle
                              ? BoxShape.circle
                              : BoxShape.rectangle,
                          borderRadius: shape == ShapeType.roundedSquare
                              ? BorderRadius.circular(12)
                              : null,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    StickerEditorState state,
    StickerEditorController controller,
  ) async {
    double brightness = state.filter.brightness;
    double saturation = state.filter.saturation;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Filters'),
              const SizedBox(height: 12),
              Text('Brightness: ${brightness.toStringAsFixed(2)}'),
              Slider(
                value: brightness,
                min: -0.5,
                max: 0.5,
                onChanged: (value) => setState(() => brightness = value),
              ),
              Text('Saturation: ${saturation.toStringAsFixed(2)}'),
              Slider(
                value: saturation,
                min: 0,
                max: 2,
                onChanged: (value) => setState(() => saturation = value),
              ),
              FilledButton(
                onPressed: () {
                  controller.setFilter(
                    StickerFilter(
                      brightness: brightness,
                      saturation: saturation,
                    ),
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCanvasSettingsSheet(
    BuildContext context,
    StickerEditorState state,
    StickerEditorController controller,
  ) async {
    final presets = [
      const StickerSizePreset(label: 'Square 1:1', width: 512, height: 512),
      const StickerSizePreset(label: 'Portrait 3:4', width: 384, height: 512),
      const StickerSizePreset(label: 'Landscape 4:3', width: 512, height: 384),
      const StickerSizePreset(label: 'Tall 9:16', width: 432, height: 768),
    ];
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Canvas & Export'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets
                  .map(
                    (preset) => ChoiceChip(
                      label: Text(preset.label),
                      selected:
                          state.canvasSize.width == preset.width &&
                          state.canvasSize.height == preset.height,
                      onSelected: (_) {
                        controller.setCanvasSize(
                          Size(preset.width, preset.height),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Export format'),
                const Spacer(),
                SegmentedButton<StickerFormat>(
                  segments: const [
                    ButtonSegment(value: StickerFormat.png, label: Text('PNG')),
                    ButtonSegment(
                      value: StickerFormat.webp,
                      label: Text('WebP'),
                    ),
                  ],
                  selected: {state.exportFormat},
                  onSelectionChanged: (value) =>
                      controller.setExportFormat(value.first),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cropSelectedLayer(
    BuildContext context,
    StickerEditorState state,
    StickerEditorController controller,
  ) async {
    final selected = state.layers.firstWhereOrNull(
      (layer) => layer.id == state.selectedLayerId && layer is ImageLayer,
    );
    if (selected is! ImageLayer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an image layer to crop.')),
      );
      return;
    }
    try {
      final bytes = await File(selected.filePath).readAsBytes();
      final cropped = await ref
          .read(imageExportServiceProvider)
          .cropToAspectRatio(
            bytes,
            state.canvasSize.width / state.canvasSize.height,
          );
      final cache = ref.read(cacheServiceProvider);
      final file = await cache.createExportFile(
        'crop_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(cropped, flush: true);
      final size = await _decodeImageSize(cropped);
      controller.replaceImageLayer(selected.id, file.path, size);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Crop failed: $error')));
    }
  }

  Future<void> _showAiSheet(
    BuildContext context,
    StickerEditorState state,
    StickerEditorController controller,
  ) async {
    final image = await _captureImage(context);
    if (image == null) return;
    final pngBytes = await _encodeImage(image, StickerFormat.png);
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AiToolsSheet(
        imageBytes: pngBytes,
        onApplyImage: (bytes) async {
          final cache = ref.read(cacheServiceProvider);
          final file = await cache.createExportFile(
            'ai_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await file.writeAsBytes(bytes, flush: true);
          final size = await _decodeImageSize(bytes);
          controller.addImageLayer(file.path, size);
          if (mounted) Navigator.of(context).pop();
        },
        onIdeas: (ideas) {
          if (mounted) Navigator.of(context).pop();
          _showIdeas(context, ideas);
        },
        onName: (name) {
          controller.setStickerName(name);
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showIdeas(BuildContext context, List<String> ideas) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Sticker Ideas'),
            const SizedBox(height: 12),
            ...ideas.map(
              (idea) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $idea'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickerCanvas extends StatelessWidget {
  const _StickerCanvas({
    required this.state,
    required this.onLayerTap,
    required this.onLayerTransform,
    required this.onLayerOpacity,
    required this.onDeleteLayer,
  });

  final StickerEditorState state;
  final ValueChanged<String?> onLayerTap;
  final void Function(String, LayerTransform) onLayerTransform;
  final void Function(String, double) onLayerOpacity;
  final void Function(String) onDeleteLayer;

  @override
  Widget build(BuildContext context) {
    final background = _buildBackground(state.background);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.transparent),
        child: Stack(
          children: [
            Positioned.fill(child: background),
            ColorFiltered(
              colorFilter: ColorFilter.matrix(
                ImageFilters.colorMatrix(
                  brightness: state.filter.brightness,
                  saturation: state.filter.saturation,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DrawingPainter(
                        layers: state.layers.whereType<DrawingLayer>().toList(),
                        activeStroke: state.activeStroke,
                      ),
                    ),
                  ),
                  ...state.layers
                      .where((layer) => layer.type != StickerLayerType.drawing)
                      .map(
                        (layer) => _LayerWidget(
                          layer: layer,
                          selected: state.selectedLayerId == layer.id,
                          enabled: !state.isDrawing,
                          onTap: () => onLayerTap(layer.id),
                          onTransform: (transform) =>
                              onLayerTransform(layer.id, transform),
                          onOpacity: (opacity) =>
                              onLayerOpacity(layer.id, opacity),
                          onDelete: () => onDeleteLayer(layer.id),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(StickerBackground background) {
    switch (background.type) {
      case BackgroundType.solid:
        return Container(color: background.color);
      case BackgroundType.gradient:
        return Container(
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
        return CustomPaint(painter: _CheckerboardPainter());
    }
  }
}

class _LayerWidget extends StatefulWidget {
  const _LayerWidget({
    required this.layer,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.onTransform,
    required this.onOpacity,
    required this.onDelete,
  });

  final StickerLayer layer;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final ValueChanged<LayerTransform> onTransform;
  final ValueChanged<double> onOpacity;
  final VoidCallback onDelete;

  @override
  State<_LayerWidget> createState() => _LayerWidgetState();
}

class _LayerWidgetState extends State<_LayerWidget> {
  Offset _startFocal = Offset.zero;
  late LayerTransform _startTransform;

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    final transform = layer.transform;

    final child = Opacity(
      opacity: layer.opacity,
      child: _buildLayerContent(layer),
    );

    final decoratedChild = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: widget.selected ? const EdgeInsets.all(6) : EdgeInsets.zero,
      decoration: BoxDecoration(
        border: widget.selected
            ? Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.2)
            : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );

    return Positioned.fill(
      child: Transform(
        transform: Matrix4.identity()
          ..translateByDouble(
            transform.position.dx,
            transform.position.dy,
            0,
            1,
          )
          ..rotateZ(transform.rotation)
          ..scaleByDouble(transform.scale, transform.scale, transform.scale, 1),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          onScaleStart: widget.enabled
              ? (details) {
                  _startFocal = details.focalPoint;
                  _startTransform = layer.transform;
                }
              : null,
          onScaleUpdate: widget.enabled
              ? (details) {
                  final delta = details.focalPoint - _startFocal;
                  widget.onTransform(
                    _startTransform.copyWith(
                      position: _startTransform.position + delta,
                      scale: (_startTransform.scale * details.scale).clamp(
                        0.2,
                        5,
                      ),
                      rotation: _startTransform.rotation + details.rotation,
                    ),
                  );
                }
              : null,
          onLongPress: widget.enabled ? () => _showLayerMenu(context) : null,
          child: decoratedChild,
        ),
      ),
    );
  }

  Widget _buildLayerContent(StickerLayer layer) {
    if (layer is ImageLayer) {
      return Image.file(
        File(layer.filePath),
        width: layer.size.width,
        height: layer.size.height,
        fit: BoxFit.contain,
      );
    }
    if (layer is TextLayer) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Text(
            layer.text,
            style: TextStyle(
              fontSize: layer.fontSize,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = layer.strokeWidth
                ..color = layer.strokeColor,
            ),
          ),
          Text(
            layer.text,
            style: TextStyle(
              fontSize: layer.fontSize,
              color: layer.color,
              shadows: layer.shadow > 0
                  ? [
                      Shadow(
                        blurRadius: layer.shadow,
                        color: Colors.black54,
                        offset: const Offset(2, 2),
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      );
    }
    if (layer is EmojiLayer) {
      return Text(layer.emoji, style: TextStyle(fontSize: layer.size));
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
              ? BorderRadius.circular(24)
              : null,
          border: layer.strokeWidth > 0
              ? Border.all(color: layer.strokeColor, width: layer.strokeWidth)
              : null,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showLayerMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Layer'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Opacity'),
                Expanded(
                  child: Slider(
                    value: widget.layer.opacity,
                    min: 0.2,
                    max: 1,
                    onChanged: widget.onOpacity,
                  ),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: () {
                widget.onDelete();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove Layer'),
            ),
          ],
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
        _paintStroke(canvas, stroke);
      }
    }
    if (activeStroke != null) {
      _paintStroke(canvas, activeStroke!);
    }
  }

  void _paintStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.length < 2) return;
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (final point in stroke.points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return oldDelegate.layers != layers ||
        oldDelegate.activeStroke != activeStroke;
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const squareSize = 16.0;
    final paintLight = Paint()..color = Colors.white.withValues(alpha: 0.06);
    final paintDark = Paint()..color = Colors.black.withValues(alpha: 0.2);
    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isDark = ((x / squareSize) + (y / squareSize)).floor().isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isDark ? paintDark : paintLight,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.state,
    required this.onBackground,
    required this.onText,
    required this.onEmoji,
    required this.onShape,
    required this.onCrop,
    required this.onDraw,
    required this.onFilter,
    required this.onImport,
    required this.onAI,
  });

  final StickerEditorState state;
  final VoidCallback onBackground;
  final VoidCallback onText;
  final VoidCallback onEmoji;
  final VoidCallback onShape;
  final VoidCallback onCrop;
  final VoidCallback onDraw;
  final VoidCallback onFilter;
  final VoidCallback onImport;
  final VoidCallback onAI;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ToolIcon(icon: CupertinoIcons.square_stack_3d_up, label: 'BG', onTap: onBackground),
            _ToolIcon(icon: CupertinoIcons.textformat, label: 'Text', onTap: onText),
            _ToolIcon(icon: CupertinoIcons.smiley, label: 'Emoji', onTap: onEmoji),
            _ToolIcon(icon: CupertinoIcons.square, label: 'Shape', onTap: onShape),
            _ToolIcon(icon: CupertinoIcons.crop, label: 'Crop', onTap: onCrop),
            _ToolIcon(
              icon: state.isDrawing ? CupertinoIcons.pencil : CupertinoIcons.pencil_outline,
              label: 'Draw',
              onTap: onDraw,
              active: state.isDrawing,
            ),
            _ToolIcon(icon: CupertinoIcons.slider_horizontal_3, label: 'Filter', onTap: onFilter),
            _ToolIcon(icon: CupertinoIcons.photo_on_rectangle, label: 'Add', onTap: onImport),
            _ToolIcon(icon: CupertinoIcons.wand_stars, label: 'AI', onTap: onAI),
          ],
        ),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: active ? CupertinoColors.activeOrange : CupertinoColors.white,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? CupertinoColors.activeOrange : const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
