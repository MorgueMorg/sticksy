import 'package:flutter/material.dart';

enum StickerLayerType { image, text, emoji, shape, drawing }

enum ShapeType { circle, roundedSquare, square }

class LayerTransform {
  const LayerTransform({
    required this.position,
    required this.scale,
    required this.rotation,
  });

  final Offset position;
  final double scale;
  final double rotation;

  LayerTransform copyWith({
    Offset? position,
    double? scale,
    double? rotation,
  }) {
    return LayerTransform(
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() => {
        'x': position.dx,
        'y': position.dy,
        'scale': scale,
        'rotation': rotation,
      };

  factory LayerTransform.fromJson(Map<String, dynamic> json) {
    return LayerTransform(
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0,
        (json['y'] as num?)?.toDouble() ?? 0,
      ),
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StickerBackground {
  const StickerBackground({
    required this.type,
    this.color,
    this.secondaryColor,
    this.angle = 0,
  });

  final BackgroundType type;
  final Color? color;
  final Color? secondaryColor;
  final double angle;

  StickerBackground copyWith({
    BackgroundType? type,
    Color? color,
    Color? secondaryColor,
    double? angle,
  }) {
    return StickerBackground(
      type: type ?? this.type,
      color: color ?? this.color,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      angle: angle ?? this.angle,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'color': color?.toARGB32(),
        'secondaryColor': secondaryColor?.toARGB32(),
        'angle': angle,
      };

  factory StickerBackground.fromJson(Map<String, dynamic> json) {
    return StickerBackground(
      type: BackgroundType.values.byName(json['type'] as String? ?? 'transparent'),
      color: _decodeColor(json['color']),
      secondaryColor: _decodeColor(json['secondaryColor']),
      angle: (json['angle'] as num?)?.toDouble() ?? 0,
    );
  }
}

enum BackgroundType { transparent, solid, gradient }

class StickerFilter {
  const StickerFilter({
    this.brightness = 0,
    this.saturation = 1,
  });

  final double brightness;
  final double saturation;

  StickerFilter copyWith({double? brightness, double? saturation}) {
    return StickerFilter(
      brightness: brightness ?? this.brightness,
      saturation: saturation ?? this.saturation,
    );
  }

  Map<String, dynamic> toJson() => {
        'brightness': brightness,
        'saturation': saturation,
      };

  factory StickerFilter.fromJson(Map<String, dynamic> json) {
    return StickerFilter(
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 1,
    );
  }
}

abstract class StickerLayer {
  const StickerLayer({
    required this.id,
    required this.transform,
    required this.opacity,
  });

  final String id;
  final LayerTransform transform;
  final double opacity;

  StickerLayerType get type;

  Map<String, dynamic> toJson();
}

class ImageLayer extends StickerLayer {
  const ImageLayer({
    required super.id,
    required this.filePath,
    required this.size,
    required super.transform,
    required super.opacity,
  });

  final String filePath;
  final Size size;

  @override
  StickerLayerType get type => StickerLayerType.image;

  ImageLayer copyWith({
    String? filePath,
    Size? size,
    LayerTransform? transform,
    double? opacity,
  }) {
    return ImageLayer(
      id: id,
      filePath: filePath ?? this.filePath,
      size: size ?? this.size,
      transform: transform ?? this.transform,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'filePath': filePath,
        'width': size.width,
        'height': size.height,
        'transform': transform.toJson(),
        'opacity': opacity,
      };

  factory ImageLayer.fromJson(Map<String, dynamic> json) {
    return ImageLayer(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      size: Size(
        (json['width'] as num?)?.toDouble() ?? 100,
        (json['height'] as num?)?.toDouble() ?? 100,
      ),
      transform: LayerTransform.fromJson(
        Map<String, dynamic>.from(json['transform'] as Map),
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
    );
  }
}

class TextLayer extends StickerLayer {
  const TextLayer({
    required super.id,
    required this.text,
    required this.fontSize,
    required this.color,
    required this.strokeColor,
    required this.strokeWidth,
    required this.shadow,
    required super.transform,
    required super.opacity,
    this.bold = true,
    this.italic = false,
  });

  final String text;
  final double fontSize;
  final Color color;
  final Color strokeColor;
  final double strokeWidth;
  final double shadow;
  final bool bold;
  final bool italic;

  @override
  StickerLayerType get type => StickerLayerType.text;

  TextLayer copyWith({
    String? text,
    double? fontSize,
    Color? color,
    Color? strokeColor,
    double? strokeWidth,
    double? shadow,
    LayerTransform? transform,
    double? opacity,
    bool? bold,
    bool? italic,
  }) {
    return TextLayer(
      id: id,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      shadow: shadow ?? this.shadow,
      transform: transform ?? this.transform,
      opacity: opacity ?? this.opacity,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'text': text,
        'fontSize': fontSize,
        'color': color.toARGB32(),
        'strokeColor': strokeColor.toARGB32(),
        'strokeWidth': strokeWidth,
        'shadow': shadow,
        'bold': bold,
        'italic': italic,
        'transform': transform.toJson(),
        'opacity': opacity,
      };

  factory TextLayer.fromJson(Map<String, dynamic> json) {
    return TextLayer(
      id: json['id'] as String,
      text: json['text'] as String,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24,
      color: Color(json['color'] as int? ?? Colors.white.toARGB32()),
      strokeColor: Color(json['strokeColor'] as int? ?? Colors.black.toARGB32()),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 0,
      shadow: (json['shadow'] as num?)?.toDouble() ?? 0,
      bold: json['bold'] as bool? ?? true,
      italic: json['italic'] as bool? ?? false,
      transform: LayerTransform.fromJson(
        Map<String, dynamic>.from(json['transform'] as Map),
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
    );
  }
}

class EmojiLayer extends StickerLayer {
  const EmojiLayer({
    required super.id,
    required this.emoji,
    required this.size,
    required super.transform,
    required super.opacity,
  });

  final String emoji;
  final double size;

  @override
  StickerLayerType get type => StickerLayerType.emoji;

  EmojiLayer copyWith({
    String? emoji,
    double? size,
    LayerTransform? transform,
    double? opacity,
  }) {
    return EmojiLayer(
      id: id,
      emoji: emoji ?? this.emoji,
      size: size ?? this.size,
      transform: transform ?? this.transform,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'emoji': emoji,
        'size': size,
        'transform': transform.toJson(),
        'opacity': opacity,
      };

  factory EmojiLayer.fromJson(Map<String, dynamic> json) {
    return EmojiLayer(
      id: json['id'] as String,
      emoji: json['emoji'] as String,
      size: (json['size'] as num?)?.toDouble() ?? 64,
      transform: LayerTransform.fromJson(
        Map<String, dynamic>.from(json['transform'] as Map),
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
    );
  }
}

class ShapeLayer extends StickerLayer {
  const ShapeLayer({
    required super.id,
    required this.shape,
    required this.color,
    required this.strokeColor,
    required this.strokeWidth,
    required this.size,
    required super.transform,
    required super.opacity,
  });

  final ShapeType shape;
  final Color color;
  final Color strokeColor;
  final double strokeWidth;
  final Size size;

  @override
  StickerLayerType get type => StickerLayerType.shape;

  ShapeLayer copyWith({
    ShapeType? shape,
    Color? color,
    Color? strokeColor,
    double? strokeWidth,
    Size? size,
    LayerTransform? transform,
    double? opacity,
  }) {
    return ShapeLayer(
      id: id,
      shape: shape ?? this.shape,
      color: color ?? this.color,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      size: size ?? this.size,
      transform: transform ?? this.transform,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'shape': shape.name,
        'color': color.toARGB32(),
        'strokeColor': strokeColor.toARGB32(),
        'strokeWidth': strokeWidth,
        'width': size.width,
        'height': size.height,
        'transform': transform.toJson(),
        'opacity': opacity,
      };

  factory ShapeLayer.fromJson(Map<String, dynamic> json) {
    return ShapeLayer(
      id: json['id'] as String,
      shape: ShapeType.values.byName(json['shape'] as String? ?? 'square'),
      color: Color(json['color'] as int? ?? Colors.white.toARGB32()),
      strokeColor: Color(json['strokeColor'] as int? ?? Colors.black.toARGB32()),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 0,
      size: Size(
        (json['width'] as num?)?.toDouble() ?? 120,
        (json['height'] as num?)?.toDouble() ?? 120,
      ),
      transform: LayerTransform.fromJson(
        Map<String, dynamic>.from(json['transform'] as Map),
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
    );
  }
}

class DrawingStroke {
  const DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  Map<String, dynamic> toJson() => {
        'points': points
            .map((point) => {'x': point.dx, 'y': point.dy})
            .toList(),
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List<dynamic>? ?? [])
        .map((point) => Offset(
              (point['x'] as num?)?.toDouble() ?? 0,
              (point['y'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
    return DrawingStroke(
      points: points,
      color: Color(json['color'] as int? ?? Colors.white.toARGB32()),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 4,
    );
  }
}

class DrawingLayer extends StickerLayer {
  const DrawingLayer({
    required super.id,
    required this.strokes,
    required super.transform,
    required super.opacity,
  });

  final List<DrawingStroke> strokes;

  @override
  StickerLayerType get type => StickerLayerType.drawing;

  DrawingLayer copyWith({
    List<DrawingStroke>? strokes,
    LayerTransform? transform,
    double? opacity,
  }) {
    return DrawingLayer(
      id: id,
      strokes: strokes ?? this.strokes,
      transform: transform ?? this.transform,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
        'transform': transform.toJson(),
        'opacity': opacity,
      };

  factory DrawingLayer.fromJson(Map<String, dynamic> json) {
    return DrawingLayer(
      id: json['id'] as String,
      strokes: (json['strokes'] as List<dynamic>? ?? [])
          .map((stroke) =>
              DrawingStroke.fromJson(Map<String, dynamic>.from(stroke as Map)))
          .toList(),
      transform: LayerTransform.fromJson(
        Map<String, dynamic>.from(json['transform'] as Map),
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
    );
  }
}

StickerLayer layerFromJson(Map<String, dynamic> json) {
  final type = StickerLayerType.values.byName(json['type'] as String);
  switch (type) {
    case StickerLayerType.image:
      return ImageLayer.fromJson(json);
    case StickerLayerType.text:
      return TextLayer.fromJson(json);
    case StickerLayerType.emoji:
      return EmojiLayer.fromJson(json);
    case StickerLayerType.shape:
      return ShapeLayer.fromJson(json);
    case StickerLayerType.drawing:
      return DrawingLayer.fromJson(json);
  }
}

Color? _decodeColor(Object? value) {
  if (value == null) return null;
  if (value is int) {
    return Color(value);
  }
  return null;
}

class StickerSizePreset {
  const StickerSizePreset({
    required this.label,
    required this.width,
    required this.height,
  });

  final String label;
  final double width;
  final double height;
}

/// Die-cut border applied to the flattened sticker at save/export time.
///
/// It can't be a normal layer: the border has to hug the *combined* silhouette
/// of everything on the canvas, which only exists once the layers are merged.
class StickerOutline {
  const StickerOutline({this.width = 0, this.color = const Color(0xFFFFFFFF)});

  /// In exported pixels. 0 disables the border.
  final double width;
  final Color color;

  bool get enabled => width > 0;

  StickerOutline copyWith({double? width, Color? color}) {
    return StickerOutline(
      width: width ?? this.width,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {
        'width': width,
        'color': color.toARGB32(),
      };

  factory StickerOutline.fromJson(Map<String, dynamic> json) {
    return StickerOutline(
      width: (json['width'] as num?)?.toDouble() ?? 0,
      color: Color(json['color'] as int? ?? 0xFFFFFFFF),
    );
  }
}
