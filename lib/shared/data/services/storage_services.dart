import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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
    final filePath = p.join(stickersDir.path, '$stickerId.$extension');
    return File(filePath);
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
    final destination = await createStickerFile(packId, stickerId, extension);
    await File(sourcePath).copy(destination.path);
    return destination.path;
  }

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
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
    final dir = await getCacheDir();
    int size = 0;
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }

  Future<void> clearCache() async {
    final dir = await getCacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

class ImageExportService {
  Future<Uint8List> encodeWebp(
    Uint8List inputBytes, {
    int? width,
    int? height,
    int quality = 80,
  }) async {
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) {
      throw StateError('Unable to decode image for WebP export.');
    }
    final targetWidth = width ?? decoded.width;
    final targetHeight = height ?? decoded.height;
    final result = await FlutterImageCompress.compressWithList(
      inputBytes,
      minWidth: targetWidth,
      minHeight: targetHeight,
      quality: quality,
      format: CompressFormat.webp,
    );
    if (result.isEmpty) {
      throw StateError('Unable to encode image for WebP export.');
    }
    return Uint8List.fromList(result);
  }

  Future<Uint8List> encodePng(
    Uint8List inputBytes, {
    int? width,
    int? height,
  }) async {
    return Isolate.run(() {
      final decoded = img.decodeImage(inputBytes);
      if (decoded == null) {
        throw StateError('Unable to decode image for PNG export.');
      }
      final resized = (width != null && height != null)
          ? img.copyResize(decoded, width: width, height: height)
          : decoded;
      final encoded = img.encodePng(resized);
      return Uint8List.fromList(encoded);
    });
  }

  Future<Uint8List> cropToAspectRatio(
    Uint8List inputBytes,
    double ratio,
  ) async {
    return Isolate.run(() {
      final decoded = img.decodeImage(inputBytes);
      if (decoded == null) {
        throw StateError('Unable to decode image for cropping.');
      }
      int newWidth = decoded.width;
      int newHeight = decoded.height;
      int offsetX = 0;
      int offsetY = 0;
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

    final fileName =
        '${pack.name.replaceAll(' ', '_').toLowerCase()}_${type.name}.zip';
    final file = await cacheService.createExportFile(fileName);
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
    final metadataBytes = utf8.encode(jsonEncode(metadata));
    archive.addFile(ArchiveFile(
      'metadata.json',
      metadataBytes.length,
      metadataBytes,
    ));

    await _addStickerFiles(archive, stickers);
  }

  Future<void> _addWhatsAppPayload(
    Archive archive,
    PackSummary pack,
    List<StickerItem> stickers,
    String exportedAt,
  ) async {
    final stickerEntries = <Map<String, Object?>>[];
    for (final sticker in stickers) {
      final bytes = await File(sticker.filePath).readAsBytes();
      final webpBytes = await imageExportService.encodeWebp(
        bytes,
        width: 512,
        height: 512,
        quality: 80,
      );
      final fileName = 'stickers/${sticker.id}.webp';
      archive.addFile(ArchiveFile(fileName, webpBytes.length, webpBytes));
      stickerEntries.add({
        'image_file': fileName.split('/').last,
        'emojis': ['✨'],
      });
    }

    final trayImage = stickers.isNotEmpty
        ? await _buildTrayImage(stickers.first.filePath)
        : Uint8List(0);
    if (trayImage.isNotEmpty) {
      archive.addFile(
        ArchiveFile('tray.png', trayImage.length, trayImage),
      );
    }

    final contents = {
      'sticker_packs': [
        {
          'identifier': pack.id,
          'name': pack.name,
          'publisher': 'Sticker Forge',
          'tray_image_file': 'tray.png',
          'image_data_version': '1',
          'avoid_cache': false,
          'publisher_email': 'support@stickerforge.app',
          'publisher_website': 'https://stickerforge.app',
          'privacy_policy_website': 'https://stickerforge.app/privacy',
          'license_agreement_website': 'https://stickerforge.app/license',
          'stickers': stickerEntries,
          'exported_at': exportedAt,
        }
      ],
    };

    final contentsBytes = utf8.encode(jsonEncode(contents));
    archive.addFile(
      ArchiveFile('contents.json', contentsBytes.length, contentsBytes),
    );
  }

  Future<void> _addTelegramPayload(
    Archive archive,
    PackSummary pack,
    List<StickerItem> stickers,
    String exportedAt,
  ) async {
    await _addStickerFiles(archive, stickers);
    final metadata = {
      'title': pack.name,
      'id': pack.id,
      'exportedAt': exportedAt,
      'stickers': stickers.map(_stickerMetadata).toList(),
      'notes':
          'Use @stickers bot to import these WebP/PNG stickers on Telegram.',
    };
    final metadataBytes = utf8.encode(jsonEncode(metadata));
    archive.addFile(ArchiveFile(
      'telegram_pack.json',
      metadataBytes.length,
      metadataBytes,
    ));
  }

  Future<void> _addStickerFiles(
    Archive archive,
    List<StickerItem> stickers,
  ) async {
    for (final sticker in stickers) {
      final bytes = await File(sticker.filePath).readAsBytes();
      final fileName = 'stickers/${sticker.id}.${sticker.format.extension}';
      archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
    }
  }

  Map<String, Object?> _stickerMetadata(StickerItem sticker) {
    return {
      'id': sticker.id,
      'name': sticker.name,
      'format': sticker.format.extension,
      'width': sticker.width,
      'height': sticker.height,
      'fileSize': sticker.fileSize,
    };
  }

  Future<Uint8List> _buildTrayImage(String stickerPath) async {
    final bytes = await File(stickerPath).readAsBytes();
    return imageExportService.encodePng(
      bytes,
      width: 96,
      height: 96,
    );
  }
}
