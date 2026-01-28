enum StickerFormat { png, webp }

extension StickerFormatX on StickerFormat {
  String get extension {
    switch (this) {
      case StickerFormat.png:
        return 'png';
      case StickerFormat.webp:
        return 'webp';
    }
  }

  static StickerFormat fromExtension(String value) {
    switch (value.toLowerCase()) {
      case 'webp':
        return StickerFormat.webp;
      case 'png':
      default:
        return StickerFormat.png;
    }
  }
}

class StickerPack {
  const StickerPack({
    required this.id,
    required this.name,
    required this.coverStickerId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? coverStickerId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class StickerItem {
  const StickerItem({
    required this.id,
    required this.packId,
    required this.name,
    required this.filePath,
    required this.width,
    required this.height,
    required this.format,
    required this.layersJson,
    required this.fileSize,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String packId;
  final String name;
  final String filePath;
  final int width;
  final int height;
  final StickerFormat format;
  final String? layersJson;
  final int fileSize;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class PackSummary {
  const PackSummary({
    required this.id,
    required this.name,
    required this.coverStickerId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.stickerCount,
    required this.totalSize,
  });

  final String id;
  final String name;
  final String? coverStickerId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int stickerCount;
  final int totalSize;
}
