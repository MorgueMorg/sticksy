import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/data/local/app_database.dart';
import '../../../shared/data/services/storage_services.dart';
import '../domain/models.dart';

abstract class PackRepository {
  Stream<List<PackSummary>> watchPackSummaries();
  Future<PackSummary?> getPackSummary(String id);
  Future<String> createPack(String name);
  Future<void> renamePack(String id, String name);
  Future<void> deletePack(String id);
  Future<void> duplicatePack(String id);
  Future<void> reorderPacks(List<String> orderedIds);
  Future<void> setCoverSticker(String packId, String? stickerId);
}

abstract class StickerRepository {
  Stream<List<StickerItem>> watchStickers(String packId);
  Future<StickerItem?> getSticker(String id);
  Future<String> createSticker({
    String? id,
    required String packId,
    required String name,
    required String filePath,
    required int width,
    required int height,
    required StickerFormat format,
    String? layersJson,
    int fileSize = 0,
  });
  Future<void> updateSticker({
    required String id,
    required String name,
    required String filePath,
    required int width,
    required int height,
    required StickerFormat format,
    String? layersJson,
    int fileSize = 0,
  });
  Future<void> renameSticker(String id, String name);
  Future<void> deleteSticker(String id);
}

class PackRepositoryImpl implements PackRepository {
  PackRepositoryImpl({
    required this.database,
    required this.storage,
  });

  final AppDatabase database;
  final LocalStorageService storage;
  final _uuid = const Uuid();

  @override
  Stream<List<PackSummary>> watchPackSummaries() {
    final query = database.customSelect(
      '''
      SELECT p.*, 
        COUNT(s.id) AS sticker_count, 
        COALESCE(SUM(s.file_size), 0) AS total_size
      FROM packs p
      LEFT JOIN stickers s ON s.pack_id = p.id
      GROUP BY p.id
      ORDER BY p.sort_order ASC
      ''',
      readsFrom: {database.packs, database.stickers},
    );
    return query.watch().map(
          (rows) => rows
              .map((row) => PackSummary(
                    id: row.read<String>('id'),
                    name: row.read<String>('name'),
                    coverStickerId: row.readNullable<String>('cover_sticker_id'),
                    sortOrder: row.read<int>('sort_order'),
                    createdAt: row.read<DateTime>('created_at'),
                    updatedAt: row.read<DateTime>('updated_at'),
                    stickerCount: row.read<int>('sticker_count'),
                    totalSize: row.read<int>('total_size'),
                  ))
              .toList(),
        );
  }

  @override
  Future<PackSummary?> getPackSummary(String id) async {
    final results = await database.customSelect(
      '''
      SELECT p.*, 
        COUNT(s.id) AS sticker_count, 
        COALESCE(SUM(s.file_size), 0) AS total_size
      FROM packs p
      LEFT JOIN stickers s ON s.pack_id = p.id
      WHERE p.id = ?
      GROUP BY p.id
      ''',
      variables: [Variable.withString(id)],
      readsFrom: {database.packs, database.stickers},
    ).get();
    return results
        .map((row) => PackSummary(
              id: row.read<String>('id'),
              name: row.read<String>('name'),
              coverStickerId: row.readNullable<String>('cover_sticker_id'),
              sortOrder: row.read<int>('sort_order'),
              createdAt: row.read<DateTime>('created_at'),
              updatedAt: row.read<DateTime>('updated_at'),
              stickerCount: row.read<int>('sticker_count'),
              totalSize: row.read<int>('total_size'),
            ))
        .firstOrNull;
  }

  @override
  Future<String> createPack(String name) async {
    final lastPack = await (database.select(database.packs)
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();
    final sortOrder = (lastPack?.sortOrder ?? -1) + 1;
    final packId = _uuid.v4();
    await database.into(database.packs).insert(
          PacksCompanion.insert(
            id: packId,
            name: name,
            coverStickerId: const Value(null),
            sortOrder: sortOrder,
          ),
        );
    return packId;
  }

  @override
  Future<void> renamePack(String id, String name) async {
    await (database.update(database.packs)..where((tbl) => tbl.id.equals(id)))
        .write(
      PacksCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> setCoverSticker(String packId, String? stickerId) async {
    await (database.update(database.packs)
          ..where((tbl) => tbl.id.equals(packId)))
        .write(
      PacksCompanion(
        coverStickerId: Value(stickerId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deletePack(String id) async {
    await database.transaction(() async {
      final stickers = await (database.select(database.stickers)
            ..where((tbl) => tbl.packId.equals(id)))
          .get();
      for (final sticker in stickers) {
        await storage.deleteFile(sticker.filePath);
      }
      await (database.delete(database.stickers)
            ..where((tbl) => tbl.packId.equals(id)))
          .go();
      await (database.delete(database.packs)..where((tbl) => tbl.id.equals(id)))
          .go();
    });
  }

  @override
  Future<void> duplicatePack(String id) async {
    await database.transaction(() async {
      final pack =
          await (database.select(database.packs)..where((p) => p.id.equals(id)))
              .getSingleOrNull();
      if (pack == null) return;

      final stickers = await (database.select(database.stickers)
            ..where((s) => s.packId.equals(id)))
          .get();
      final newPackId = _uuid.v4();
      await database.into(database.packs).insert(
            PacksCompanion.insert(
              id: newPackId,
              name: '${pack.name} Copy',
              coverStickerId: const Value(null),
              sortOrder: pack.sortOrder + 1,
            ),
          );

      for (final sticker in stickers) {
        final newStickerId = _uuid.v4();
        final newPath = await storage.copyStickerFile(
          sourcePath: sticker.filePath,
          packId: newPackId,
          stickerId: newStickerId,
        );
        await database.into(database.stickers).insert(
              StickersCompanion.insert(
                id: newStickerId,
                packId: newPackId,
                name: sticker.name,
                filePath: newPath,
                width: sticker.width,
                height: sticker.height,
                format: sticker.format,
                layersJson: Value(sticker.layersJson),
                fileSize: Value(sticker.fileSize),
              ),
            );
      }
    });
  }

  @override
  Future<void> reorderPacks(List<String> orderedIds) async {
    await database.batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          database.packs,
          PacksCompanion(sortOrder: Value(i), updatedAt: Value(DateTime.now())),
          where: (tbl) => tbl.id.equals(orderedIds[i]),
        );
      }
    });
  }
}

class StickerRepositoryImpl implements StickerRepository {
  StickerRepositoryImpl({
    required this.database,
    required this.storage,
  });

  final AppDatabase database;
  final LocalStorageService storage;
  final _uuid = const Uuid();

  @override
  Stream<List<StickerItem>> watchStickers(String packId) {
    return (database.select(database.stickers)
          ..where((tbl) => tbl.packId.equals(packId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch()
        .map((rows) => rows.map(_mapSticker).toList());
  }

  @override
  Future<StickerItem?> getSticker(String id) async {
    final sticker = await (database.select(database.stickers)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    if (sticker == null) return null;
    return _mapSticker(sticker);
  }

  @override
  Future<String> createSticker({
    String? id,
    required String packId,
    required String name,
    required String filePath,
    required int width,
    required int height,
    required StickerFormat format,
    String? layersJson,
    int fileSize = 0,
  }) async {
    final stickerId = id ?? _uuid.v4();
    await database.into(database.stickers).insert(
          StickersCompanion.insert(
            id: stickerId,
            packId: packId,
            name: name,
            filePath: filePath,
            width: width,
            height: height,
            format: format.extension,
            layersJson: Value(layersJson),
            fileSize: Value(fileSize),
          ),
        );
    await _touchPack(packId);
    return stickerId;
  }

  @override
  Future<void> updateSticker({
    required String id,
    required String name,
    required String filePath,
    required int width,
    required int height,
    required StickerFormat format,
    String? layersJson,
    int fileSize = 0,
  }) async {
    final existing = await (database.select(database.stickers)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    if (existing != null && existing.filePath != filePath) {
      await storage.deleteFile(existing.filePath);
    }
    await (database.update(database.stickers)..where((tbl) => tbl.id.equals(id)))
        .write(
      StickersCompanion(
        name: Value(name),
        filePath: Value(filePath),
        width: Value(width),
        height: Value(height),
        format: Value(format.extension),
        layersJson: Value(layersJson),
        fileSize: Value(fileSize),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (existing != null) {
      await _touchPack(existing.packId);
    }
  }

  @override
  Future<void> renameSticker(String id, String name) async {
    await (database.update(database.stickers)..where((tbl) => tbl.id.equals(id)))
        .write(
      StickersCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> deleteSticker(String id) async {
    final sticker = await (database.select(database.stickers)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    if (sticker == null) return;
    await storage.deleteFile(sticker.filePath);
    await (database.delete(database.stickers)..where((tbl) => tbl.id.equals(id)))
        .go();
    final pack = await (database.select(database.packs)
          ..where((tbl) => tbl.id.equals(sticker.packId)))
        .getSingleOrNull();
    if (pack != null && pack.coverStickerId == sticker.id) {
      await (database.update(database.packs)
            ..where((tbl) => tbl.id.equals(pack.id)))
          .write(
        PacksCompanion(
          coverStickerId: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
    await _touchPack(sticker.packId);
  }

  Future<void> _touchPack(String packId) async {
    await (database.update(database.packs)
          ..where((tbl) => tbl.id.equals(packId)))
        .write(PacksCompanion(updatedAt: Value(DateTime.now())));
  }

  StickerItem _mapSticker(Sticker sticker) {
    return StickerItem(
      id: sticker.id,
      packId: sticker.packId,
      name: sticker.name,
      filePath: sticker.filePath,
      width: sticker.width,
      height: sticker.height,
      format: StickerFormatX.fromExtension(sticker.format),
      layersJson: sticker.layersJson,
      fileSize: sticker.fileSize,
      createdAt: sticker.createdAt,
      updatedAt: sticker.updatedAt,
    );
  }
}
