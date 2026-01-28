import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../packs/domain/models.dart';
import '../domain/editor_models.dart';

class StickerEditorState {
  const StickerEditorState({
    required this.packId,
    required this.stickerId,
    required this.stickerName,
    required this.canvasSize,
    required this.background,
    required this.filter,
    required this.layers,
    required this.selectedLayerId,
    required this.exportFormat,
    required this.isDrawing,
    required this.drawingColor,
    required this.drawingWidth,
    required this.activeStroke,
    required this.isSaving,
  });

  final String packId;
  final String? stickerId;
  final String stickerName;
  final Size canvasSize;
  final StickerBackground background;
  final StickerFilter filter;
  final List<StickerLayer> layers;
  final String? selectedLayerId;
  final StickerFormat exportFormat;
  final bool isDrawing;
  final Color drawingColor;
  final double drawingWidth;
  final DrawingStroke? activeStroke;
  final bool isSaving;

  StickerEditorState copyWith({
    String? stickerId,
    String? stickerName,
    Size? canvasSize,
    StickerBackground? background,
    StickerFilter? filter,
    List<StickerLayer>? layers,
    String? selectedLayerId,
    StickerFormat? exportFormat,
    bool? isDrawing,
    Color? drawingColor,
    double? drawingWidth,
    DrawingStroke? activeStroke,
    bool? isSaving,
  }) {
    return StickerEditorState(
      packId: packId,
      stickerId: stickerId ?? this.stickerId,
      stickerName: stickerName ?? this.stickerName,
      canvasSize: canvasSize ?? this.canvasSize,
      background: background ?? this.background,
      filter: filter ?? this.filter,
      layers: layers ?? this.layers,
      selectedLayerId: selectedLayerId ?? this.selectedLayerId,
      exportFormat: exportFormat ?? this.exportFormat,
      isDrawing: isDrawing ?? this.isDrawing,
      drawingColor: drawingColor ?? this.drawingColor,
      drawingWidth: drawingWidth ?? this.drawingWidth,
      activeStroke: activeStroke,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  Map<String, dynamic> toJson() => {
        'stickerName': stickerName,
        'canvas': {
          'width': canvasSize.width,
          'height': canvasSize.height,
        },
        'background': background.toJson(),
        'filter': filter.toJson(),
        'exportFormat': exportFormat.extension,
        'layers': layers.map((layer) => layer.toJson()).toList(),
      };
}

class StickerEditorController extends StateNotifier<StickerEditorState> {
  StickerEditorController({
    required String packId,
    StickerItem? initialSticker,
    String? initialImagePath,
  }) : super(
          _initialState(
            packId: packId,
            sticker: initialSticker,
            initialImagePath: initialImagePath,
          ),
        );

  static const _uuid = Uuid();

  static StickerEditorState _initialState({
    required String packId,
    StickerItem? sticker,
    String? initialImagePath,
  }) {
    if (sticker != null && sticker.layersJson != null) {
      return _stateFromJson(
        packId: packId,
        sticker: sticker,
        raw: sticker.layersJson!,
      );
    }

    final layers = <StickerLayer>[];
    if (initialImagePath != null) {
      layers.add(
        ImageLayer(
          id: _uuid.v4(),
          filePath: initialImagePath,
          size: const Size(260, 260),
          transform: const LayerTransform(
            position: Offset.zero,
            scale: 1,
            rotation: 0,
          ),
          opacity: 1,
        ),
      );
    } else if (sticker != null) {
      layers.add(
        ImageLayer(
          id: _uuid.v4(),
          filePath: sticker.filePath,
          size: Size(
            sticker.width.toDouble(),
            sticker.height.toDouble(),
          ),
          transform: const LayerTransform(
            position: Offset.zero,
            scale: 1,
            rotation: 0,
          ),
          opacity: 1,
        ),
      );
    }

    return StickerEditorState(
      packId: packId,
      stickerId: sticker?.id,
      stickerName: sticker?.name ?? 'Untitled Sticker',
      canvasSize: const Size(320, 320),
      background: const StickerBackground(type: BackgroundType.transparent),
      filter: const StickerFilter(),
      layers: layers,
      selectedLayerId: layers.isNotEmpty ? layers.first.id : null,
      exportFormat: sticker?.format ?? StickerFormat.png,
      isDrawing: false,
      drawingColor: const Color(0xFFFFFFFF),
      drawingWidth: 6,
      activeStroke: null,
      isSaving: false,
    );
  }

  static StickerEditorState _stateFromJson({
    required String packId,
    required StickerItem sticker,
    required String raw,
  }) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final canvas = decoded['canvas'] as Map<String, dynamic>? ?? {};
      final layersJson = decoded['layers'] as List<dynamic>? ?? [];
      return StickerEditorState(
        packId: packId,
        stickerId: sticker.id,
        stickerName: decoded['stickerName'] as String? ?? sticker.name,
        canvasSize: Size(
          (canvas['width'] as num?)?.toDouble() ?? 320,
          (canvas['height'] as num?)?.toDouble() ?? 320,
        ),
        background: StickerBackground.fromJson(
          Map<String, dynamic>.from(decoded['background'] as Map? ?? {}),
        ),
        filter: StickerFilter.fromJson(
          Map<String, dynamic>.from(decoded['filter'] as Map? ?? {}),
        ),
        layers: layersJson
            .map((layer) =>
                layerFromJson(Map<String, dynamic>.from(layer as Map)))
            .toList(),
        selectedLayerId: null,
        exportFormat: StickerFormatX.fromExtension(
          decoded['exportFormat'] as String? ?? 'png',
        ),
        isDrawing: false,
        drawingColor: const Color(0xFFFFFFFF),
        drawingWidth: 6,
        activeStroke: null,
        isSaving: false,
      );
    } catch (_) {
      return _initialState(packId: packId, sticker: sticker);
    }
  }

  void setStickerName(String name) {
    state = state.copyWith(stickerName: name);
  }

  void setStickerId(String id) {
    state = state.copyWith(stickerId: id);
  }

  void setCanvasSize(Size size) {
    state = state.copyWith(canvasSize: size);
  }

  void setBackground(StickerBackground background) {
    state = state.copyWith(background: background);
  }

  void setFilter(StickerFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setExportFormat(StickerFormat format) {
    state = state.copyWith(exportFormat: format);
  }

  void setDrawingMode(bool enabled) {
    state = state.copyWith(isDrawing: enabled, selectedLayerId: null);
  }

  void setDrawingColor(Color color) {
    state = state.copyWith(drawingColor: color);
  }

  void setDrawingWidth(double width) {
    state = state.copyWith(drawingWidth: width);
  }

  void startStroke(Offset point) {
    if (!state.isDrawing) return;
    state = state.copyWith(
      activeStroke: DrawingStroke(
        points: [point],
        color: state.drawingColor,
        strokeWidth: state.drawingWidth,
      ),
    );
  }

  void updateStroke(Offset point) {
    if (!state.isDrawing || state.activeStroke == null) return;
    final updated = DrawingStroke(
      points: [...state.activeStroke!.points, point],
      color: state.activeStroke!.color,
      strokeWidth: state.activeStroke!.strokeWidth,
    );
    state = state.copyWith(activeStroke: updated);
  }

  void endStroke() {
    if (!state.isDrawing || state.activeStroke == null) return;
    final stroke = state.activeStroke!;
    final drawingLayer = state.layers.whereType<DrawingLayer>().firstWhereOrNull(
          (layer) => true,
        );

    if (drawingLayer == null) {
      state = state.copyWith(
        layers: [
          ...state.layers,
          DrawingLayer(
            id: _uuid.v4(),
            strokes: [stroke],
            transform: const LayerTransform(
              position: Offset.zero,
              scale: 1,
              rotation: 0,
            ),
            opacity: 1,
          ),
        ],
        activeStroke: null,
      );
      return;
    }

    final updatedLayer = drawingLayer.copyWith(
      strokes: [...drawingLayer.strokes, stroke],
    );
    state = state.copyWith(
      layers: [
        ...state.layers.map(
          (layer) => layer.id == drawingLayer.id ? updatedLayer : layer,
        ),
      ],
      activeStroke: null,
    );
  }

  void addImageLayer(String filePath, Size size) {
    final layer = ImageLayer(
      id: _uuid.v4(),
      filePath: filePath,
      size: size,
      transform: const LayerTransform(
        position: Offset.zero,
        scale: 1,
        rotation: 0,
      ),
      opacity: 1,
    );
    state = state.copyWith(
      layers: [...state.layers, layer],
      selectedLayerId: layer.id,
    );
  }

  void addTextLayer(String text, Color color) {
    final layer = TextLayer(
      id: _uuid.v4(),
      text: text,
      fontSize: 32,
      color: color,
      strokeColor: Colors.black,
      strokeWidth: 2,
      shadow: 4,
      transform: const LayerTransform(
        position: Offset.zero,
        scale: 1,
        rotation: 0,
      ),
      opacity: 1,
    );
    state = state.copyWith(
      layers: [...state.layers, layer],
      selectedLayerId: layer.id,
    );
  }

  void addEmojiLayer(String emoji) {
    final layer = EmojiLayer(
      id: _uuid.v4(),
      emoji: emoji,
      size: 72,
      transform: const LayerTransform(
        position: Offset.zero,
        scale: 1,
        rotation: 0,
      ),
      opacity: 1,
    );
    state = state.copyWith(
      layers: [...state.layers, layer],
      selectedLayerId: layer.id,
    );
  }

  void addShapeLayer(ShapeType shape, Color color) {
    final layer = ShapeLayer(
      id: _uuid.v4(),
      shape: shape,
      color: color,
      strokeColor: Colors.black,
      strokeWidth: 0,
      size: const Size(140, 140),
      transform: const LayerTransform(
        position: Offset.zero,
        scale: 1,
        rotation: 0,
      ),
      opacity: 1,
    );
    state = state.copyWith(
      layers: [...state.layers, layer],
      selectedLayerId: layer.id,
    );
  }

  void replaceImageLayer(String id, String filePath, Size size) {
    state = state.copyWith(
      layers: state.layers.map((layer) {
        if (layer.id != id) return layer;
        if (layer is ImageLayer) {
          return layer.copyWith(filePath: filePath, size: size);
        }
        return layer;
      }).toList(),
    );
  }

  void updateLayerTransform(String id, LayerTransform transform) {
    state = state.copyWith(
      layers: state.layers.map((layer) {
        if (layer.id != id) return layer;
        if (layer is ImageLayer) return layer.copyWith(transform: transform);
        if (layer is TextLayer) return layer.copyWith(transform: transform);
        if (layer is EmojiLayer) return layer.copyWith(transform: transform);
        if (layer is ShapeLayer) return layer.copyWith(transform: transform);
        if (layer is DrawingLayer) return layer.copyWith(transform: transform);
        return layer;
      }).toList(),
    );
  }

  void updateLayerOpacity(String id, double opacity) {
    state = state.copyWith(
      layers: state.layers.map((layer) {
        if (layer.id != id) return layer;
        if (layer is ImageLayer) return layer.copyWith(opacity: opacity);
        if (layer is TextLayer) return layer.copyWith(opacity: opacity);
        if (layer is EmojiLayer) return layer.copyWith(opacity: opacity);
        if (layer is ShapeLayer) return layer.copyWith(opacity: opacity);
        if (layer is DrawingLayer) return layer.copyWith(opacity: opacity);
        return layer;
      }).toList(),
    );
  }

  void selectLayer(String? id) {
    state = state.copyWith(selectedLayerId: id);
  }

  void removeLayer(String id) {
    state = state.copyWith(
      layers: state.layers.where((layer) => layer.id != id).toList(),
      selectedLayerId: state.selectedLayerId == id ? null : state.selectedLayerId,
    );
  }

  void setSaving(bool saving) {
    state = state.copyWith(isSaving: saving);
  }

  String serializeEditorState() {
    return jsonEncode(state.toJson());
  }
}
