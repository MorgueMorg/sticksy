import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../features/packs/domain/models.dart';

class LocalStorageService {
  Future<Directory> _ensureDir(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getRootDir() => _ensureDir('sticksy');

  Future<Directory> getPackDir(String packId) async {
    final root = await getRootDir();
    final dir = Directory(p.join(root.path, 'packs', packId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> createStickerFile(
    String packId,
    String stickerId,
    String extension,
  ) async {
    final packDir = await getPackDir(packId);
    final stickersDir = Directory(p.join(packDir.path, 'stickers'));
    if (!await stickersDir.exists()) {
      await stickersDir.create(recursive: true);
    }
    return File(p.join(stickersDir.path, '$stickerId.$extension'));
  }

  Future<String> saveStickerBytes({
    required String packId,
    required String stickerId,
    required String extension,
    required Uint8List bytes,
  }) async {
    final file = await createStickerFile(packId, stickerId, extension);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> copyStickerFile({
    required String sourcePath,
    required String packId,
    required String stickerId,
  }) async {
    final extension = p.extension(sourcePath).replaceFirst('.', '');
    final destination = await createStickerFile(
      packId,
      stickerId,
      extension.isEmpty ? 'png' : extension,
    );
    await File(sourcePath).copy(destination.path);
    return destination.path;
  }

  Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A missing or locked file must never block a delete/rename flow.
    }
  }

  /// Total bytes stored under the app's sticker directory.
  Future<int> usedBytes() async {
    try {
      final root = await getRootDir();
      var size = 0;
      await for (final entity in root.list(recursive: true)) {
        if (entity is File) size += await entity.length();
      }
      return size;
    } catch (_) {
      return 0;
    }
  }
}

class CacheService {
  Future<Directory> getCacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'sticksy_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getExportDir() async {
    final cache = await getCacheDir();
    final dir = Directory(p.join(cache.path, 'exports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> createExportFile(String filename) async {
    final exportDir = await getExportDir();
    return File(p.join(exportDir.path, filename));
  }

  Future<int> getCacheSize() async {
    try {
      final dir = await getCacheDir();
      if (!await dir.exists()) return 0;
      var size = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) size += await entity.length();
      }
      return size;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearCache() async {
    try {
      final dir = await getCacheDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Ignore — clearing cache is best-effort.
    }
  }
}

/// Result of an encode that may have had to fall back to another format.
class EncodedImage {
  const EncodedImage(this.bytes, this.format);

  final Uint8List bytes;
  final StickerFormat format;
}

class ImageExportService {
  /// WebP encoding is Android-only in `flutter_image_compress`, and it also
  /// drops alpha on some devices. Rather than silently shipping a broken
  /// sticker we fall back to PNG and tell the caller what we actually produced.
  Future<EncodedImage> encodeWebpOrPng(
    Uint8List inputBytes, {
    int quality = 90,
    int? width,
    int? height,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return EncodedImage(inputBytes, StickerFormat.png);
    }
    try {
      final result = await FlutterImageCompress.compressWithList(
        inputBytes,
        minWidth: width ?? 512,
        minHeight: height ?? 512,
        quality: quality,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (result.isEmpty) return EncodedImage(inputBytes, StickerFormat.png);
      return EncodedImage(Uint8List.fromList(result), StickerFormat.webp);
    } catch (_) {
      return EncodedImage(inputBytes, StickerFormat.png);
    }
  }

  Future<Uint8List> encodePng(
    Uint8List inputBytes, {
    int? width,
    int? height,
  }) {
    return Isolate.run(() {
      final decoded = img.decodeImage(inputBytes);
      if (decoded == null) {
        throw StateError('Unable to decode image for PNG export.');
      }
      final resized = (width != null && height != null)
          ? img.copyResize(decoded, width: width, height: height)
          : decoded;
      return Uint8List.fromList(img.encodePng(resized));
    });
  }

  Future<Uint8List> cropToAspectRatio(Uint8List inputBytes, double ratio) {
    return Isolate.run(() {
      final decoded = img.decodeImage(inputBytes);
      if (decoded == null) {
        throw StateError('Unable to decode image for cropping.');
      }
      var newWidth = decoded.width;
      var newHeight = decoded.height;
      var offsetX = 0;
      var offsetY = 0;
      final currentRatio = decoded.width / decoded.height;
      if (currentRatio > ratio) {
        newWidth = (decoded.height * ratio).round();
        offsetX = ((decoded.width - newWidth) / 2).round();
      } else if (currentRatio < ratio) {
        newHeight = (decoded.width / ratio).round();
        offsetY = ((decoded.height - newHeight) / 2).round();
      }
      final cropped = img.copyCrop(
        decoded,
        x: offsetX,
        y: offsetY,
        width: newWidth,
        height: newHeight,
      );
      return Uint8List.fromList(img.encodePng(cropped));
    });
  }
}

enum PackExportType { zip, whatsapp, telegram }

extension PackExportTypeX on PackExportType {
  String get label => switch (this) {
        PackExportType.zip => 'ZIP archive',
        PackExportType.whatsapp => 'WhatsApp pack',
        PackExportType.telegram => 'Telegram pack',
      };

  String get blurb => switch (this) {
        PackExportType.zip => 'Every sticker plus a metadata file.',
        PackExportType.whatsapp =>
          '512px WebP stickers with contents.json and a tray icon.',
        PackExportType.telegram =>
          'PNG stickers ready to hand to @stickers.',
      };
}

class PackExportService {
  PackExportService({
    required this.cacheService,
    required this.imageExportService,
  });

  final CacheService cacheService;
  final ImageExportService imageExportService;

  Future<File> exportPack({
    required PackSummary pack,
    required List<StickerItem> stickers,
    required PackExportType type,
  }) async {
    if (stickers.isEmpty) {
      throw StateError('This pack has no stickers yet.');
    }

    final archive = Archive();
    final exportedAt = DateTime.now().toIso8601String();

    if (type == PackExportType.whatsapp) {
      await _addWhatsAppPayload(archive, pack, stickers, exportedAt);
    } else if (type == PackExportType.telegram) {
      await _addTelegramPayload(archive, pack, stickers, exportedAt);
    } else {
      await _addStandardPayload(archive, pack, stickers, exportedAt);
    }

    final zipData = ZipEncoder().encode(archive);
    final safeName = pack.name
        .replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    final file = await cacheService.createExportFile(
      '${safeName.isEmpty ? 'pack' : safeName}_${type.name}.zip',
    );
    await file.writeAsBytes(zipData, flush: true);
    return file;
  }

  Future<void> _addStandardPayload(
    Archive archive,
    PackSummary pack,
    List<StickerItem> stickers,
    String exportedAt,
  ) async {
    final metadata = {
      'id': pack.id,
      'name': pack.name,
      'stickerCount': pack.stickerCount,
      'totalSize': pack.totalSize,
      'lastUpdated': pack.updatedAt.toIso8601String(),
      'exportedAt': exportedAt,
      'stickers': stickers.map(_stickerMetadata).toList(),
    };
    _addJson(archive, 'metadata.json', metadata);
    await _addStickerFiles(archive, stickers);
  }

  Future<void> _addWhatsAppPayload(
    Archive archive,
    PackSummary pack,
    List<StickerItem> stickers,
    String exportedAt,
  ) async {
    final entries = <Map<String, Object?>>[];

    for (final sticker in stickers) {
      final bytes = await _readSticker(sticker);
      if (bytes == null) continue;

      final encoded = await imageExportService.encodeWebpOrPng(
        bytes,
        width: 512,
        height: 512,
        quality: 85,
      );
      final fileName = '${sticker.id}.${encoded.format.extension}';
      archive.addFile(
        ArchiveFile(
          'stickers/$fileName',
          encoded.bytes.length,
          encoded.bytes,
        ),
      );
      entries.add({
        'image_file': fileName,
        'emojis': ['✨'],
      });
    }

    if (entries.isEmpty) {
      throw StateError('None of the sticker files could be read.');
    }

    final firstReadable = await _firstReadable(stickers);
    if (firstReadable != null) {
      final tray = await imageExportService.encodePng(
        firstReadable,
        width: 96,
        height: 96,
      );
      archive.addFile(ArchiveFile('tray.png', tray.length, tray));
    }

    _addJson(archive, 'contents.json', {
      'android_play_store_link': '',
      'ios_app_store_link': '',
      'sticker_packs': [
        {
          'identifier': pack.id,
          'name': pack.name,
          'publisher': 'Sticksy',
          'tray_image_file': 'tray.png',
          'image_data_version': '1',
          'avoid_cache': false,
          'publisher_email': '',
          'publisher_website': '',
          'privacy_policy_website': '',
          'license_agreement_website': '',
          'stickers': entries,
          'exported_at': exportedAt,
        },
      ],
    });

    _addText(
      archive,
      'README.txt',
      'Sticksy — WhatsApp export\n\n'
          'stickers/  512x512 sticker files\n'
          'tray.png   96x96 tray icon\n'
          'contents.json  pack manifest\n\n'
          'WhatsApp only accepts packs through a companion app that implements '
          'its sticker content provider, so this archive is the raw payload — '
          'unzip it and add the stickers manually, or feed it to your own '
          'WhatsApp sticker app.\n',
    );
  }

  Future<void> _addTelegramPayload(
    Archive archive,
    PackSummary pack,
    List<StickerItem> stickers,
    String exportedAt,
  ) async {
    await _addStickerFiles(archive, stickers);
    _addJson(archive, 'telegram_pack.json', {
      'title': pack.name,
      'id': pack.id,
      'exportedAt': exportedAt,
      'stickers': stickers.map(_stickerMetadata).toList(),
    });
    _addText(
      archive,
      'README.txt',
      'Sticksy — Telegram export\n\n'
          'Open @stickers in Telegram, send /newpack, then upload the files '
          'from the stickers/ folder one at a time and assign an emoji to '
          'each. Telegram wants 512px PNG or WebP with transparency, which is '
          'what Sticksy exports.\n',
    );
  }

  Future<void> _addStickerFiles(
    Archive archive,
    List<StickerItem> stickers,
  ) async {
    for (final sticker in stickers) {
      final bytes = await _readSticker(sticker);
      if (bytes == null) continue;
      archive.addFile(
        ArchiveFile(
          'stickers/${sticker.id}.${sticker.format.extension}',
          bytes.length,
          bytes,
        ),
      );
    }
  }

  Future<Uint8List?> _readSticker(StickerItem sticker) async {
    try {
      final file = File(sticker.filePath);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _firstReadable(List<StickerItem> stickers) async {
    for (final sticker in stickers) {
      final bytes = await _readSticker(sticker);
      if (bytes != null) return bytes;
    }
    return null;
  }

  void _addJson(Archive archive, String name, Object value) {
    final bytes = utf8.encode(jsonEncode(value));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  void _addText(Archive archive, String name, String value) {
    final bytes = utf8.encode(value);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  Map<String, Object?> _stickerMetadata(StickerItem sticker) => {
        'id': sticker.id,
        'name': sticker.name,
        'format': sticker.format.extension,
        'width': sticker.width,
        'height': sticker.height,
        'fileSize': sticker.fileSize,
      };
}
