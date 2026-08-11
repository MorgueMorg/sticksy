import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Pixel-level sticker operations.
///
/// These are the difference between "an AI picture" and "a sticker": a cutout
/// so the subject floats, a die-cut outline so it reads on any chat bubble, and
/// a square 512px canvas because that is what WhatsApp and Telegram want.
///
/// Every public method hops to a background isolate — a 1024×1024 flood fill on
/// the UI isolate would drop ~40 frames.
class ImageOps {
  const ImageOps._();

  /// Removes a flat background by flood-filling inward from the border.
  ///
  /// Images that already carry a real alpha channel, or whose border is too
  /// busy to be a background, come back with `changed == false` so callers can
  /// tell "nothing to do" apart from "done".
  static Future<CutoutResult> magicCutout(
    Uint8List bytes, {
    int tolerance = 38,
  }) {
    return Isolate.run(() => _magicCutoutSync(bytes, tolerance));
  }

  /// Classic die-cut sticker border. [width] is in pixels of the source image.
  static Future<Uint8List> addOutline(
    Uint8List bytes, {
    int width = 14,
    int argbColor = 0xFFFFFFFF,
  }) {
    return Isolate.run(() => _addOutlineSync(bytes, width, argbColor));
  }

  /// Crops away fully transparent margins, leaving [padding] px of breathing room.
  static Future<Uint8List> trimTransparent(
    Uint8List bytes, {
    int padding = 6,
  }) {
    return Isolate.run(() => _trimTransparentSync(bytes, padding));
  }

  /// Scales to fit a transparent [size]×[size] canvas without distortion.
  static Future<Uint8List> fitSquare(Uint8List bytes, {int size = 512}) {
    return Isolate.run(() => _fitSquareSync(bytes, size));
  }

  /// Fraction of pixels that are fully transparent (0.0–1.0).
  static Future<double> transparencyRatio(Uint8List bytes) {
    return Isolate.run(() => _transparencyRatioSync(bytes));
  }
}

/// Outcome of [ImageOps.magicCutout].
///
/// `Isolate.run` copies its payload, so identity comparison can't tell whether
/// the operation actually did anything — hence the explicit flag.
class CutoutResult {
  const CutoutResult(this.bytes, this.changed);

  final Uint8List bytes;
  final bool changed;
}

// ---------------------------------------------------------------------------
// Implementations. Top-level so isolate closures capture primitives only.
// ---------------------------------------------------------------------------

img.Image _decodeRgba(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupt image data.');
  }
  return decoded.numChannels == 4 ? decoded : decoded.convert(numChannels: 4);
}

Uint8List _encode(img.Image image) => Uint8List.fromList(img.encodePng(image));

img.Image _buildImage(int width, int height, Uint8List rgba) {
  final out = img.Image(width: width, height: height, numChannels: 4);
  var i = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      out.setPixelRgba(x, y, rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]);
      i += 4;
    }
  }
  return out;
}

double _transparencyRatioSync(Uint8List bytes) {
  final image = _decodeRgba(bytes);
  final data = image.getBytes(order: img.ChannelOrder.rgba);
  final total = image.width * image.height;
  if (total == 0) return 0;
  var clear = 0;
  for (var i = 3; i < data.length; i += 4) {
    if (data[i] < 8) clear++;
  }
  return clear / total;
}

CutoutResult _magicCutoutSync(Uint8List bytes, int tolerance) {
  final image = _decodeRgba(bytes);
  final w = image.width;
  final h = image.height;
  if (w < 2 || h < 2) return CutoutResult(bytes, false);

  final data = image.getBytes(order: img.ChannelOrder.rgba);
  final total = w * h;

  // Already cut out? Leave it alone.
  var clear = 0;
  for (var i = 3; i < data.length; i += 4) {
    if (data[i] < 8) clear++;
  }
  if (clear / total > 0.05) return CutoutResult(bytes, false);

  // Pick the dominant border colour by voting in a coarse 16-level cube.
  final votes = <int, int>{};
  void vote(int x, int y) {
    final i = (y * w + x) * 4;
    final key = ((data[i] >> 4) << 8) | ((data[i + 1] >> 4) << 4) |
        (data[i + 2] >> 4);
    votes[key] = (votes[key] ?? 0) + 1;
  }

  for (var x = 0; x < w; x++) {
    vote(x, 0);
    vote(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    vote(0, y);
    vote(w - 1, y);
  }
  if (votes.isEmpty) return CutoutResult(bytes, false);

  var bestKey = votes.keys.first;
  var bestCount = -1;
  votes.forEach((key, count) {
    if (count > bestCount) {
      bestCount = count;
      bestKey = key;
    }
  });

  final borderPixels = 2 * (w + h);
  // A busy border means the subject bleeds off-canvas; cutting would eat it.
  if (bestCount < borderPixels * 0.35) return CutoutResult(bytes, false);

  final bgR = ((bestKey >> 8) & 0xF) * 17;
  final bgG = ((bestKey >> 4) & 0xF) * 17;
  final bgB = (bestKey & 0xF) * 17;
  final threshold = tolerance * tolerance * 3;

  bool matchesBackground(int index) {
    final i = index * 4;
    final dr = data[i] - bgR;
    final dg = data[i + 1] - bgG;
    final db = data[i + 2] - bgB;
    return dr * dr + dg * dg + db * db <= threshold;
  }

  final removed = Uint8List(total);
  final stack = Int32List(total);
  var top = 0;

  void push(int index) {
    if (removed[index] != 0) return;
    if (!matchesBackground(index)) return;
    removed[index] = 1;
    stack[top++] = index;
  }

  for (var x = 0; x < w; x++) {
    push(x);
    push((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    push(y * w);
    push(y * w + w - 1);
  }

  while (top > 0) {
    final index = stack[--top];
    final x = index % w;
    final y = index ~/ w;
    if (x > 0) push(index - 1);
    if (x < w - 1) push(index + 1);
    if (y > 0) push(index - w);
    if (y < h - 1) push(index + w);
  }

  // Nothing meaningful removed — don't hand back an identical image.
  var removedCount = 0;
  for (var i = 0; i < total; i++) {
    if (removed[i] != 0) removedCount++;
  }
  if (removedCount < total * 0.02) return CutoutResult(bytes, false);

  // Soften the boundary so the cutout doesn't look laser-cut.
  final out = Uint8List(total * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final index = y * w + x;
      final o = index * 4;
      out[o] = data[o];
      out[o + 1] = data[o + 1];
      out[o + 2] = data[o + 2];

      if (removed[index] != 0) {
        out[o + 3] = 0;
        continue;
      }

      var neighbours = 0;
      for (var dy = -1; dy <= 1; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx;
          if (nx < 0 || nx >= w) continue;
          if (removed[ny * w + nx] != 0) neighbours++;
        }
      }
      final factor = 1.0 - (neighbours / 12.0);
      out[o + 3] = (data[o + 3] * factor).round().clamp(0, 255);
    }
  }

  return CutoutResult(_encode(_buildImage(w, h, out)), true);
}

Uint8List _addOutlineSync(Uint8List bytes, int width, int argbColor) {
  if (width <= 0) return bytes;

  final image = _decodeRgba(bytes);
  final sw = image.width;
  final sh = image.height;
  final src = image.getBytes(order: img.ChannelOrder.rgba);

  final pad = width + 2;
  final w = sw + pad * 2;
  final h = sh + pad * 2;
  final total = w * h;

  // Chamfer 3-4 distance transform: 3 units per orthogonal step, 4 per diagonal.
  const int inf = 1 << 24;
  const int ortho = 3;
  const int diag = 4;
  final dist = Int32List(total);

  for (var i = 0; i < total; i++) {
    dist[i] = inf;
  }
  for (var y = 0; y < sh; y++) {
    for (var x = 0; x < sw; x++) {
      if (src[(y * sw + x) * 4 + 3] >= 128) {
        dist[(y + pad) * w + (x + pad)] = 0;
      }
    }
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      var d = dist[i];
      if (y > 0) {
        d = math.min(d, dist[i - w] + ortho);
        if (x > 0) d = math.min(d, dist[i - w - 1] + diag);
        if (x < w - 1) d = math.min(d, dist[i - w + 1] + diag);
      }
      if (x > 0) d = math.min(d, dist[i - 1] + ortho);
      dist[i] = d;
    }
  }
  for (var y = h - 1; y >= 0; y--) {
    for (var x = w - 1; x >= 0; x--) {
      final i = y * w + x;
      var d = dist[i];
      if (y < h - 1) {
        d = math.min(d, dist[i + w] + ortho);
        if (x < w - 1) d = math.min(d, dist[i + w + 1] + diag);
        if (x > 0) d = math.min(d, dist[i + w - 1] + diag);
      }
      if (x < w - 1) d = math.min(d, dist[i + 1] + ortho);
      dist[i] = d;
    }
  }

  final outlineA = ((argbColor >> 24) & 0xFF) / 255.0;
  final outlineR = (argbColor >> 16) & 0xFF;
  final outlineG = (argbColor >> 8) & 0xFF;
  final outlineB = argbColor & 0xFF;
  final edge = width * ortho;

  final out = Uint8List(total * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final o = i * 4;

      // Outline coverage, feathered over the final 3 chamfer units.
      final d = dist[i];
      double coverage;
      if (d >= edge) {
        coverage = 0;
      } else if (d <= edge - ortho) {
        coverage = 1;
      } else {
        coverage = (edge - d) / ortho;
      }
      final backA = coverage * outlineA;

      // Source pixel (if any) composited over the outline.
      var srcR = 0, srcG = 0, srcB = 0;
      var srcA = 0.0;
      final sx = x - pad;
      final sy = y - pad;
      if (sx >= 0 && sx < sw && sy >= 0 && sy < sh) {
        final s = (sy * sw + sx) * 4;
        srcR = src[s];
        srcG = src[s + 1];
        srcB = src[s + 2];
        srcA = src[s + 3] / 255.0;
      }

      final outA = srcA + backA * (1 - srcA);
      if (outA <= 0.0001) {
        out[o] = 0;
        out[o + 1] = 0;
        out[o + 2] = 0;
        out[o + 3] = 0;
        continue;
      }
      final backWeight = backA * (1 - srcA);
      out[o] = ((srcR * srcA + outlineR * backWeight) / outA)
          .round()
          .clamp(0, 255);
      out[o + 1] = ((srcG * srcA + outlineG * backWeight) / outA)
          .round()
          .clamp(0, 255);
      out[o + 2] = ((srcB * srcA + outlineB * backWeight) / outA)
          .round()
          .clamp(0, 255);
      out[o + 3] = (outA * 255).round().clamp(0, 255);
    }
  }

  return _encode(_buildImage(w, h, out));
}

Uint8List _trimTransparentSync(Uint8List bytes, int padding) {
  final image = _decodeRgba(bytes);
  final w = image.width;
  final h = image.height;
  final data = image.getBytes(order: img.ChannelOrder.rgba);

  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (data[(y * w + x) * 4 + 3] > 8) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0 || maxY < 0) return bytes; // fully transparent

  minX = math.max(0, minX - padding);
  minY = math.max(0, minY - padding);
  maxX = math.min(w - 1, maxX + padding);
  maxY = math.min(h - 1, maxY + padding);

  final cropped = img.copyCrop(
    image,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
  return _encode(cropped);
}

Uint8List _fitSquareSync(Uint8List bytes, int size) {
  final image = _decodeRgba(bytes);
  if (image.width == size && image.height == size) return bytes;

  final scale = size / math.max(image.width, image.height);
  final targetW = math.max(1, (image.width * scale).round());
  final targetH = math.max(1, (image.height * scale).round());
  final resized = img.copyResize(
    image,
    width: targetW,
    height: targetH,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(width: size, height: size, numChannels: 4);
  // Explicitly clear: a fresh Image is not guaranteed to be zero-filled.
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      canvas.setPixelRgba(x, y, 0, 0, 0, 0);
    }
  }

  final dx = ((size - targetW) / 2).round();
  final dy = ((size - targetH) / 2).round();
  final data = resized.getBytes(order: img.ChannelOrder.rgba);
  var i = 0;
  for (var y = 0; y < targetH; y++) {
    for (var x = 0; x < targetW; x++) {
      canvas.setPixelRgba(
        x + dx,
        y + dy,
        data[i],
        data[i + 1],
        data[i + 2],
        data[i + 3],
      );
      i += 4;
    }
  }

  return _encode(canvas);
}
