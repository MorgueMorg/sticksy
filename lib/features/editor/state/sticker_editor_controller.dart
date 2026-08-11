import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../packs/domain/models.dart';
import '../domain/editor_models.dart';

/// Sentinel so `copyWith` can distinguish "leave unchanged" from "set to null".
/// The old controller used `value ?? this.value`, which made it impossible to
/// deselect a layer — tapping empty canvas did nothing.
const Object _unset = Object();

class StickerEditorState {
  const StickerEditorState({
    required this.packId,
    required this.stickerId,
    required this.stickerName,
    required this.canvasSize,
    required this.background,
    required this.filter,
    required this.outline,
    required this.layers,
    required this.selectedLayerId,
    required this.exportFormat,
    required this.isDrawing,
    required this.drawingColor,
    required this.drawingWidth,
    required this.activeStroke,
    required this.isSaving,
    required this.canUndo,
    required this.canRedo,
    required this.isDirty,
  });

  final String packId;
  final String? stickerId;
  final String stickerName;
  final Size canvasSize;
  final StickerBackground background;
  final StickerFilter filter;
  final StickerOutline outline;
  final List<StickerLayer> layers;
  final String? selectedLayerId;
  final StickerFormat exportFormat;
  final bool isDrawing;
  final Color drawingColor;
  final double drawingWidth;
  final DrawingStroke? activeStroke;
  final bool isSaving;
  final bool canUndo;
  final bool canRedo;
  final bool isDirty;

  bool get isEmpty => layers.isEmpty;

  StickerLayer? get selectedLayer {
    final id = selectedLayerId;
    if (id == null) return null;
    for (final layer in layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  StickerEditorState copyWith({
    Object? stickerId = _unset,
    String? stickerName,
    Size? canvasSize,
    StickerBackground? background,
    StickerFilter? filter,
    StickerOutline? outline,
    List<StickerLayer>? layers,
    Object? selectedLayerId = _unset,
    StickerFormat? exportFormat,
    bool? isDrawing,
    Color? drawingColor,
    double? drawingWidth,
    Object? activeStroke = _unset,
    bool? isSaving,
    bool? canUndo,
    bool? canRedo,
    bool? isDirty,
  }) {
    return StickerEditorState(
      packId: packId,
      stickerId: stickerId == _unset ? this.stickerId : stickerId as String?,
      stickerName: stickerName ?? this.stickerName,
      canvasSize: canvasSize ?? this.canvasSize,
      background: background ?? this.background,
      filter: filter ?? this.filter,
      outline: outline ?? this.outline,
      layers: layers ?? this.layers,
      selectedLayerId: selectedLayerId == _unset
          ? this.selectedLayerId
          : selectedLayerId as String?,
      exportFormat: exportFormat ?? this.exportFormat,
      isDrawing: isDrawing ?? this.isDrawing,
      drawingColor: drawingColor ?? this.drawingColor,
      drawingWidth: drawingWidth ?? this.drawingWidth,
      activeStroke: activeStroke == _unset
          ? this.activeStroke
          : activeStroke as DrawingStroke?,
      isSaving: isSaving ?? this.isSaving,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  /// Serialised document — what gets stored alongside the flattened PNG so a
  /// sticker stays re-editable, and what the undo stack snapshots.
  Map<String, dynamic> toJson() => {
        'stickerName': stickerName,
        'canvas': {'width': canvasSize.width, 'height': canvasSize.height},
        'background': background.toJson(),
        'filter': filter.toJson(),
        'outline': outline.toJson(),
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
  static const _historyLimit = 40;

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  static StickerEditorState _blank({
    required String packId,
    StickerItem? sticker,
    List<StickerLayer> layers = const [],
  }) {
    return StickerEditorState(
      packId: packId,
      stickerId: sticker?.id,
      stickerName: sticker?.name ?? 'Untitled sticker',
      canvasSize: const Size(512, 512),
      background: const StickerBackground(type: BackgroundType.transparent),
      filter: const StickerFilter(),
      outline: const StickerOutline(),
      layers: layers,
      selectedLayerId: layers.isNotEmpty ? layers.last.id : null,
      exportFormat: sticker?.format ?? StickerFormat.png,
      isDrawing: false,
      drawingColor: const Color(0xFFFFFFFF),
      drawingWidth: 8,
      activeStroke: null,
      isSaving: false,
      canUndo: false,
      canRedo: false,
      isDirty: false,
    );
  }

  static StickerEditorState _initialState({
    required String packId,
    StickerItem? sticker,
    String? initialImagePath,
  }) {
    final raw = sticker?.layersJson;
    if (sticker != null && raw != null && raw.isNotEmpty) {
      final restored = _tryRestore(packId: packId, sticker: sticker, raw: raw);
      if (restored != null) return restored;
    }

    final layers = <StickerLayer>[];
    final path = initialImagePath ?? sticker?.filePath;
    if (path != null && path.isNotEmpty) {
      layers.add(
        ImageLayer(
          id: _uuid.v4(),
          filePath: path,
          size: const Size(360, 360),
          transform: const LayerTransform(
            position: Offset.zero,
            scale: 1,
            rotation: 0,
          ),
          opacity: 1,
        ),
      );
    }
    return _blank(packId: packId, sticker: sticker, layers: layers);
  }

  static StickerEditorState? _tryRestore({
    required String packId,
    required StickerItem sticker,
    required String raw,
  }) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final canvas = decoded['canvas'] as Map<String, dynamic>? ?? const {};
      final layersJson = decoded['layers'] as List<dynamic>? ?? const [];
      final layers = layersJson
          .map((layer) => layerFromJson(Map<String, dynamic>.from(layer as Map)))
          .toList();

      return StickerEditorState(
        packId: packId,
        stickerId: sticker.id,
        stickerName: decoded['stickerName'] as String? ?? sticker.name,
        canvasSize: Size(
          (canvas['width'] as num?)?.toDouble() ?? 512,
          (canvas['height'] as num?)?.toDouble() ?? 512,
        ),
        background: StickerBackground.fromJson(
          Map<String, dynamic>.from(decoded['background'] as Map? ?? const {}),
        ),
        filter: StickerFilter.fromJson(
          Map<String, dynamic>.from(decoded['filter'] as Map? ?? const {}),
        ),
        outline: StickerOutline.fromJson(
          Map<String, dynamic>.from(decoded['outline'] as Map? ?? const {}),
        ),
        layers: layers,
        selectedLayerId: null,
        exportFormat: StickerFormatX.fromExtension(
          decoded['exportFormat'] as String? ?? 'png',
        ),
        isDrawing: false,
        drawingColor: const Color(0xFFFFFFFF),
        drawingWidth: 8,
        activeStroke: null,
        isSaving: false,
        canUndo: false,
        canRedo: false,
        isDirty: false,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  void _snapshot() {
    _undoStack.add(jsonEncode(state.toJson()));
    if (_undoStack.length > _historyLimit) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _commit(StickerEditorState next) {
    state = next.copyWith(
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
      isDirty: true,
    );
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(jsonEncode(state.toJson()));
    _restore(_undoStack.removeLast());
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(jsonEncode(state.toJson()));
    _restore(_redoStack.removeLast());
  }

  void _restore(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final canvas = decoded['canvas'] as Map<String, dynamic>? ?? const {};
      final layersJson = decoded['layers'] as List<dynamic>? ?? const [];
      state = state.copyWith(
        stickerName: decoded['stickerName'] as String?,
        canvasSize: Size(
          (canvas['width'] as num?)?.toDouble() ?? state.canvasSize.width,
          (canvas['height'] as num?)?.toDouble() ?? state.canvasSize.height,
        ),
        background: StickerBackground.fromJson(
          Map<String, dynamic>.from(decoded['background'] as Map? ?? const {}),
        ),
        filter: StickerFilter.fromJson(
          Map<String, dynamic>.from(decoded['filter'] as Map? ?? const {}),
        ),
        outline: StickerOutline.fromJson(
          Map<String, dynamic>.from(decoded['outline'] as Map? ?? const {}),
        ),
        layers: layersJson
            .map((layer) =>
                layerFromJson(Map<String, dynamic>.from(layer as Map)))
            .toList(),
        exportFormat: StickerFormatX.fromExtension(
          decoded['exportFormat'] as String? ?? 'png',
        ),
        selectedLayerId: null,
        activeStroke: null,
        canUndo: _undoStack.isNotEmpty,
        canRedo: _redoStack.isNotEmpty,
        isDirty: true,
      );
    } catch (_) {
      // A corrupt snapshot shouldn't wipe the canvas.
    }
  }

  // ---------------------------------------------------------------------------
  // Document properties
  // ---------------------------------------------------------------------------

  void setStickerName(String name) {
    state = state.copyWith(stickerName: name, isDirty: true);
  }

  void setStickerId(String id) => state = state.copyWith(stickerId: id);

  void markSaved() => state = state.copyWith(isDirty: false);

  void setCanvasSize(Size size) {
    _snapshot();
    _commit(state.copyWith(canvasSize: size));
  }

  void setBackground(StickerBackground background) {
    _snapshot();
    _commit(state.copyWith(background: background));
  }

  void setFilter(StickerFilter filter) {
    _snapshot();
    _commit(state.copyWith(filter: filter));
  }

  void setOutline(StickerOutline outline) {
    _snapshot();
    _commit(state.copyWith(outline: outline));
  }

  void setExportFormat(StickerFormat format) {
    state = state.copyWith(exportFormat: format, isDirty: true);
  }

  void setSaving(bool saving) => state = state.copyWith(isSaving: saving);

  // ---------------------------------------------------------------------------
  // Drawing
  // ---------------------------------------------------------------------------

  void setDrawingMode(bool enabled) {
    state = state.copyWith(
      isDrawing: enabled,
      selectedLayerId: null,
      activeStroke: null,
    );
  }

  void setDrawingColor(Color color) =>
      state = state.copyWith(drawingColor: color);

  void setDrawingWidth(double width) =>
      state = state.copyWith(drawingWidth: width);

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
    final active = state.activeStroke;
    if (!state.isDrawing || active == null) return;
    state = state.copyWith(
      activeStroke: DrawingStroke(
        points: [...active.points, point],
        color: active.color,
        strokeWidth: active.strokeWidth,
      ),
    );
  }

  void endStroke() {
    final stroke = state.activeStroke;
    if (!state.isDrawing || stroke == null) return;
    if (stroke.points.length < 2) {
      state = state.copyWith(activeStroke: null);
      return;
    }

    _snapshot();

    DrawingLayer? found;
    for (final layer in state.layers) {
      if (layer is DrawingLayer) {
        found = layer;
        break;
      }
    }
    final target = found;

    if (target == null) {
      _commit(
        state.copyWith(
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
        ),
      );
      return;
    }

    final updated = target.copyWith(strokes: [...target.strokes, stroke]);
    _commit(
      state.copyWith(
        layers: state.layers
            .map((layer) => layer.id == updated.id ? updated : layer)
            .toList(),
        activeStroke: null,
      ),
    );
  }

  void undoLastStroke() {
    DrawingLayer? found;
    for (final layer in state.layers) {
      if (layer is DrawingLayer) {
        found = layer;
        break;
      }
    }
    final target = found;
    if (target == null || target.strokes.isEmpty) return;

    _snapshot();
    final remaining = target.strokes.sublist(0, target.strokes.length - 1);
    if (remaining.isEmpty) {
      _commit(
        state.copyWith(
          layers:
              state.layers.where((layer) => layer.id != target.id).toList(),
        ),
      );
      return;
    }
    final updated = target.copyWith(strokes: remaining);
    _commit(
      state.copyWith(
        layers: state.layers
            .map((layer) => layer.id == updated.id ? updated : layer)
            .toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Layers
  // ---------------------------------------------------------------------------

  void _addLayer(StickerLayer layer) {
    _snapshot();
    _commit(
      state.copyWith(
        layers: [...state.layers, layer],
        selectedLayerId: layer.id,
        isDrawing: false,
      ),
    );
  }

  static const _identity = LayerTransform(
    position: Offset.zero,
    scale: 1,
    rotation: 0,
  );

  void addImageLayer(String filePath, Size size) {
    _addLayer(
      ImageLayer(
        id: _uuid.v4(),
        filePath: filePath,
        size: size,
        transform: _identity,
        opacity: 1,
      ),
    );
  }

  void addTextLayer(
    String text, {
    Color color = Colors.white,
    Color strokeColor = Colors.black,
    double strokeWidth = 3,
    double fontSize = 48,
    bool bold = true,
    bool italic = false,
  }) {
    _addLayer(
      TextLayer(
        id: _uuid.v4(),
        text: text,
        fontSize: fontSize,
        color: color,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
        shadow: 6,
        bold: bold,
        italic: italic,
        transform: _identity,
        opacity: 1,
      ),
    );
  }

  void addEmojiLayer(String emoji) {
    _addLayer(
      EmojiLayer(
        id: _uuid.v4(),
        emoji: emoji,
        size: 96,
        transform: _identity,
        opacity: 1,
      ),
    );
  }

  void addShapeLayer(ShapeType shape, Color color) {
    _addLayer(
      ShapeLayer(
        id: _uuid.v4(),
        shape: shape,
        color: color,
        strokeColor: Colors.black,
        strokeWidth: 0,
        size: const Size(180, 180),
        transform: _identity,
        opacity: 1,
      ),
    );
  }

  void replaceImageLayer(String id, String filePath, Size size) {
    _snapshot();
    _commit(
      state.copyWith(
        layers: state.layers.map((layer) {
          if (layer.id != id || layer is! ImageLayer) return layer;
          return layer.copyWith(filePath: filePath, size: size);
        }).toList(),
      ),
    );
  }

  void updateTextLayer(
    String id, {
    String? text,
    Color? color,
    Color? strokeColor,
    double? strokeWidth,
    double? fontSize,
    double? shadow,
    bool? bold,
    bool? italic,
  }) {
    _snapshot();
    _commit(
      state.copyWith(
        layers: state.layers.map((layer) {
          if (layer.id != id || layer is! TextLayer) return layer;
          return layer.copyWith(
            text: text,
            color: color,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            fontSize: fontSize,
            shadow: shadow,
            bold: bold,
            italic: italic,
          );
        }).toList(),
      ),
    );
  }

  void updateShapeLayer(
    String id, {
    Color? color,
    Color? strokeColor,
    double? strokeWidth,
    ShapeType? shape,
  }) {
    _snapshot();
    _commit(
      state.copyWith(
        layers: state.layers.map((layer) {
          if (layer.id != id || layer is! ShapeLayer) return layer;
          return layer.copyWith(
            color: color,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            shape: shape,
          );
        }).toList(),
      ),
    );
  }

  /// Live drag/pinch. Deliberately does *not* snapshot on every frame — the
  /// gesture start calls [beginTransform] once.
  void updateLayerTransform(String id, LayerTransform transform) {
    state = state.copyWith(
      layers: state.layers
          .map((layer) =>
              layer.id == id ? _withTransform(layer, transform) : layer)
          .toList(),
      isDirty: true,
    );
  }

  void beginTransform() => _snapshot();

  void endTransform() {
    state = state.copyWith(
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
    );
  }

  void updateLayerOpacity(String id, double opacity) {
    state = state.copyWith(
      layers: state.layers
          .map((layer) => layer.id == id ? _withOpacity(layer, opacity) : layer)
          .toList(),
      isDirty: true,
    );
  }

  void selectLayer(String? id) =>
      state = state.copyWith(selectedLayerId: id);

  void removeLayer(String id) {
    _snapshot();
    _commit(
      state.copyWith(
        layers: state.layers.where((layer) => layer.id != id).toList(),
        selectedLayerId: state.selectedLayerId == id ? null : state.selectedLayerId,
      ),
    );
  }

  void duplicateLayer(String id) {
    final index = state.layers.indexWhere((layer) => layer.id == id);
    if (index == -1) return;
    final source = state.layers[index];
    final clone = _cloneLayer(source, _uuid.v4());
    if (clone == null) return;

    _snapshot();
    final next = [...state.layers];
    next.insert(index + 1, clone);
    _commit(state.copyWith(layers: next, selectedLayerId: clone.id));
  }

  /// [delta] of -1 sends backward, +1 brings forward.
  void reorderLayer(String id, int delta) {
    final index = state.layers.indexWhere((layer) => layer.id == id);
    if (index == -1) return;
    final target = (index + delta).clamp(0, state.layers.length - 1);
    if (target == index) return;

    _snapshot();
    final next = [...state.layers];
    final layer = next.removeAt(index);
    next.insert(target, layer);
    _commit(state.copyWith(layers: next));
  }

  void bringToFront(String id) => reorderLayer(id, state.layers.length);

  void sendToBack(String id) => reorderLayer(id, -state.layers.length);

  void clearCanvas() {
    if (state.layers.isEmpty) return;
    _snapshot();
    _commit(state.copyWith(layers: const [], selectedLayerId: null));
  }

  String serializeEditorState() => jsonEncode(state.toJson());
}

// ---------------------------------------------------------------------------
// Layer helpers
// ---------------------------------------------------------------------------

StickerLayer _withTransform(StickerLayer layer, LayerTransform transform) {
  if (layer is ImageLayer) return layer.copyWith(transform: transform);
  if (layer is TextLayer) return layer.copyWith(transform: transform);
  if (layer is EmojiLayer) return layer.copyWith(transform: transform);
  if (layer is ShapeLayer) return layer.copyWith(transform: transform);
  if (layer is DrawingLayer) return layer.copyWith(transform: transform);
  return layer;
}

StickerLayer _withOpacity(StickerLayer layer, double opacity) {
  if (layer is ImageLayer) return layer.copyWith(opacity: opacity);
  if (layer is TextLayer) return layer.copyWith(opacity: opacity);
  if (layer is EmojiLayer) return layer.copyWith(opacity: opacity);
  if (layer is ShapeLayer) return layer.copyWith(opacity: opacity);
  if (layer is DrawingLayer) return layer.copyWith(opacity: opacity);
  return layer;
}

/// Rebuilds a layer with a fresh id, nudged slightly so the copy is visible.
StickerLayer? _cloneLayer(StickerLayer layer, String newId) {
  final nudged = layer.transform.copyWith(
    position: layer.transform.position + const Offset(24, 24),
  );
  if (layer is ImageLayer) {
    return ImageLayer(
      id: newId,
      filePath: layer.filePath,
      size: layer.size,
      transform: nudged,
      opacity: layer.opacity,
    );
  }
  if (layer is TextLayer) {
    return TextLayer(
      id: newId,
      text: layer.text,
      fontSize: layer.fontSize,
      color: layer.color,
      strokeColor: layer.strokeColor,
      strokeWidth: layer.strokeWidth,
      shadow: layer.shadow,
      bold: layer.bold,
      italic: layer.italic,
      transform: nudged,
      opacity: layer.opacity,
    );
  }
  if (layer is EmojiLayer) {
    return EmojiLayer(
      id: newId,
      emoji: layer.emoji,
      size: layer.size,
      transform: nudged,
      opacity: layer.opacity,
    );
  }
  if (layer is ShapeLayer) {
    return ShapeLayer(
      id: newId,
      shape: layer.shape,
      color: layer.color,
      strokeColor: layer.strokeColor,
      strokeWidth: layer.strokeWidth,
      size: layer.size,
      transform: nudged,
      opacity: layer.opacity,
    );
  }
  if (layer is DrawingLayer) {
    return DrawingLayer(
      id: newId,
      strokes: layer.strokes,
      transform: nudged,
      opacity: layer.opacity,
    );
  }
  return null;
}
