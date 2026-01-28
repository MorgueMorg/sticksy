import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Packs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get coverStickerId => text().nullable()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Stickers extends Table {
  TextColumn get id => text()();
  TextColumn get packId => text().references(Packs, #id)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get filePath => text()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  TextColumn get format => text()();
  TextColumn get layersJson => text().nullable()();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Packs, Stickers])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'sticksy.sqlite'));
    return NativeDatabase(file);
  });
}
