// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PacksTable extends Packs with TableInfo<$PacksTable, Pack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PacksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverStickerIdMeta = const VerificationMeta(
    'coverStickerId',
  );
  @override
  late final GeneratedColumn<String> coverStickerId = GeneratedColumn<String>(
    'cover_sticker_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    coverStickerId,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'packs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cover_sticker_id')) {
      context.handle(
        _coverStickerIdMeta,
        coverStickerId.isAcceptableOrUnknown(
          data['cover_sticker_id']!,
          _coverStickerIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pack(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      coverStickerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_sticker_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PacksTable createAlias(String alias) {
    return $PacksTable(attachedDatabase, alias);
  }
}

class Pack extends DataClass implements Insertable<Pack> {
  final String id;
  final String name;
  final String? coverStickerId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Pack({
    required this.id,
    required this.name,
    this.coverStickerId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || coverStickerId != null) {
      map['cover_sticker_id'] = Variable<String>(coverStickerId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PacksCompanion toCompanion(bool nullToAbsent) {
    return PacksCompanion(
      id: Value(id),
      name: Value(name),
      coverStickerId: coverStickerId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverStickerId),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Pack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pack(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      coverStickerId: serializer.fromJson<String?>(json['coverStickerId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'coverStickerId': serializer.toJson<String?>(coverStickerId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Pack copyWith({
    String? id,
    String? name,
    Value<String?> coverStickerId = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Pack(
    id: id ?? this.id,
    name: name ?? this.name,
    coverStickerId: coverStickerId.present
        ? coverStickerId.value
        : this.coverStickerId,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Pack copyWithCompanion(PacksCompanion data) {
    return Pack(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      coverStickerId: data.coverStickerId.present
          ? data.coverStickerId.value
          : this.coverStickerId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pack(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('coverStickerId: $coverStickerId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, coverStickerId, sortOrder, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pack &&
          other.id == this.id &&
          other.name == this.name &&
          other.coverStickerId == this.coverStickerId &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PacksCompanion extends UpdateCompanion<Pack> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> coverStickerId;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PacksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.coverStickerId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PacksCompanion.insert({
    required String id,
    required String name,
    this.coverStickerId = const Value.absent(),
    required int sortOrder,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sortOrder = Value(sortOrder);
  static Insertable<Pack> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? coverStickerId,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (coverStickerId != null) 'cover_sticker_id': coverStickerId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PacksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? coverStickerId,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PacksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      coverStickerId: coverStickerId ?? this.coverStickerId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (coverStickerId.present) {
      map['cover_sticker_id'] = Variable<String>(coverStickerId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PacksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('coverStickerId: $coverStickerId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StickersTable extends Stickers with TableInfo<$StickersTable, Sticker> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StickersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packIdMeta = const VerificationMeta('packId');
  @override
  late final GeneratedColumn<String> packId = GeneratedColumn<String>(
    'pack_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES packs (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layersJsonMeta = const VerificationMeta(
    'layersJson',
  );
  @override
  late final GeneratedColumn<String> layersJson = GeneratedColumn<String>(
    'layers_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    packId,
    name,
    filePath,
    width,
    height,
    format,
    layersJson,
    fileSize,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stickers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sticker> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pack_id')) {
      context.handle(
        _packIdMeta,
        packId.isAcceptableOrUnknown(data['pack_id']!, _packIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('layers_json')) {
      context.handle(
        _layersJsonMeta,
        layersJson.isAcceptableOrUnknown(data['layers_json']!, _layersJsonMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sticker map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sticker(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      packId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pack_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      layersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layers_json'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StickersTable createAlias(String alias) {
    return $StickersTable(attachedDatabase, alias);
  }
}

class Sticker extends DataClass implements Insertable<Sticker> {
  final String id;
  final String packId;
  final String name;
  final String filePath;
  final int width;
  final int height;
  final String format;
  final String? layersJson;
  final int fileSize;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Sticker({
    required this.id,
    required this.packId,
    required this.name,
    required this.filePath,
    required this.width,
    required this.height,
    required this.format,
    this.layersJson,
    required this.fileSize,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pack_id'] = Variable<String>(packId);
    map['name'] = Variable<String>(name);
    map['file_path'] = Variable<String>(filePath);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || layersJson != null) {
      map['layers_json'] = Variable<String>(layersJson);
    }
    map['file_size'] = Variable<int>(fileSize);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StickersCompanion toCompanion(bool nullToAbsent) {
    return StickersCompanion(
      id: Value(id),
      packId: Value(packId),
      name: Value(name),
      filePath: Value(filePath),
      width: Value(width),
      height: Value(height),
      format: Value(format),
      layersJson: layersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(layersJson),
      fileSize: Value(fileSize),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Sticker.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sticker(
      id: serializer.fromJson<String>(json['id']),
      packId: serializer.fromJson<String>(json['packId']),
      name: serializer.fromJson<String>(json['name']),
      filePath: serializer.fromJson<String>(json['filePath']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      format: serializer.fromJson<String>(json['format']),
      layersJson: serializer.fromJson<String?>(json['layersJson']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'packId': serializer.toJson<String>(packId),
      'name': serializer.toJson<String>(name),
      'filePath': serializer.toJson<String>(filePath),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'format': serializer.toJson<String>(format),
      'layersJson': serializer.toJson<String?>(layersJson),
      'fileSize': serializer.toJson<int>(fileSize),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Sticker copyWith({
    String? id,
    String? packId,
    String? name,
    String? filePath,
    int? width,
    int? height,
    String? format,
    Value<String?> layersJson = const Value.absent(),
    int? fileSize,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Sticker(
    id: id ?? this.id,
    packId: packId ?? this.packId,
    name: name ?? this.name,
    filePath: filePath ?? this.filePath,
    width: width ?? this.width,
    height: height ?? this.height,
    format: format ?? this.format,
    layersJson: layersJson.present ? layersJson.value : this.layersJson,
    fileSize: fileSize ?? this.fileSize,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Sticker copyWithCompanion(StickersCompanion data) {
    return Sticker(
      id: data.id.present ? data.id.value : this.id,
      packId: data.packId.present ? data.packId.value : this.packId,
      name: data.name.present ? data.name.value : this.name,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      format: data.format.present ? data.format.value : this.format,
      layersJson: data.layersJson.present
          ? data.layersJson.value
          : this.layersJson,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sticker(')
          ..write('id: $id, ')
          ..write('packId: $packId, ')
          ..write('name: $name, ')
          ..write('filePath: $filePath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('format: $format, ')
          ..write('layersJson: $layersJson, ')
          ..write('fileSize: $fileSize, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    packId,
    name,
    filePath,
    width,
    height,
    format,
    layersJson,
    fileSize,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sticker &&
          other.id == this.id &&
          other.packId == this.packId &&
          other.name == this.name &&
          other.filePath == this.filePath &&
          other.width == this.width &&
          other.height == this.height &&
          other.format == this.format &&
          other.layersJson == this.layersJson &&
          other.fileSize == this.fileSize &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StickersCompanion extends UpdateCompanion<Sticker> {
  final Value<String> id;
  final Value<String> packId;
  final Value<String> name;
  final Value<String> filePath;
  final Value<int> width;
  final Value<int> height;
  final Value<String> format;
  final Value<String?> layersJson;
  final Value<int> fileSize;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StickersCompanion({
    this.id = const Value.absent(),
    this.packId = const Value.absent(),
    this.name = const Value.absent(),
    this.filePath = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.format = const Value.absent(),
    this.layersJson = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StickersCompanion.insert({
    required String id,
    required String packId,
    required String name,
    required String filePath,
    required int width,
    required int height,
    required String format,
    this.layersJson = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       packId = Value(packId),
       name = Value(name),
       filePath = Value(filePath),
       width = Value(width),
       height = Value(height),
       format = Value(format);
  static Insertable<Sticker> custom({
    Expression<String>? id,
    Expression<String>? packId,
    Expression<String>? name,
    Expression<String>? filePath,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? format,
    Expression<String>? layersJson,
    Expression<int>? fileSize,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (packId != null) 'pack_id': packId,
      if (name != null) 'name': name,
      if (filePath != null) 'file_path': filePath,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (format != null) 'format': format,
      if (layersJson != null) 'layers_json': layersJson,
      if (fileSize != null) 'file_size': fileSize,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StickersCompanion copyWith({
    Value<String>? id,
    Value<String>? packId,
    Value<String>? name,
    Value<String>? filePath,
    Value<int>? width,
    Value<int>? height,
    Value<String>? format,
    Value<String?>? layersJson,
    Value<int>? fileSize,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StickersCompanion(
      id: id ?? this.id,
      packId: packId ?? this.packId,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      width: width ?? this.width,
      height: height ?? this.height,
      format: format ?? this.format,
      layersJson: layersJson ?? this.layersJson,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (packId.present) {
      map['pack_id'] = Variable<String>(packId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (layersJson.present) {
      map['layers_json'] = Variable<String>(layersJson.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StickersCompanion(')
          ..write('id: $id, ')
          ..write('packId: $packId, ')
          ..write('name: $name, ')
          ..write('filePath: $filePath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('format: $format, ')
          ..write('layersJson: $layersJson, ')
          ..write('fileSize: $fileSize, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PacksTable packs = $PacksTable(this);
  late final $StickersTable stickers = $StickersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [packs, stickers];
}

typedef $$PacksTableCreateCompanionBuilder =
    PacksCompanion Function({
      required String id,
      required String name,
      Value<String?> coverStickerId,
      required int sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PacksTableUpdateCompanionBuilder =
    PacksCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> coverStickerId,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PacksTableReferences
    extends BaseReferences<_$AppDatabase, $PacksTable, Pack> {
  $$PacksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StickersTable, List<Sticker>> _stickersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.stickers,
    aliasName: $_aliasNameGenerator(db.packs.id, db.stickers.packId),
  );

  $$StickersTableProcessedTableManager get stickersRefs {
    final manager = $$StickersTableTableManager(
      $_db,
      $_db.stickers,
    ).filter((f) => f.packId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stickersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PacksTableFilterComposer extends Composer<_$AppDatabase, $PacksTable> {
  $$PacksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverStickerId => $composableBuilder(
    column: $table.coverStickerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> stickersRefs(
    Expression<bool> Function($$StickersTableFilterComposer f) f,
  ) {
    final $$StickersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stickers,
      getReferencedColumn: (t) => t.packId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StickersTableFilterComposer(
            $db: $db,
            $table: $db.stickers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PacksTableOrderingComposer
    extends Composer<_$AppDatabase, $PacksTable> {
  $$PacksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverStickerId => $composableBuilder(
    column: $table.coverStickerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PacksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PacksTable> {
  $$PacksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get coverStickerId => $composableBuilder(
    column: $table.coverStickerId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> stickersRefs<T extends Object>(
    Expression<T> Function($$StickersTableAnnotationComposer a) f,
  ) {
    final $$StickersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stickers,
      getReferencedColumn: (t) => t.packId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StickersTableAnnotationComposer(
            $db: $db,
            $table: $db.stickers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PacksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PacksTable,
          Pack,
          $$PacksTableFilterComposer,
          $$PacksTableOrderingComposer,
          $$PacksTableAnnotationComposer,
          $$PacksTableCreateCompanionBuilder,
          $$PacksTableUpdateCompanionBuilder,
          (Pack, $$PacksTableReferences),
          Pack,
          PrefetchHooks Function({bool stickersRefs})
        > {
  $$PacksTableTableManager(_$AppDatabase db, $PacksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PacksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PacksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PacksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> coverStickerId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PacksCompanion(
                id: id,
                name: name,
                coverStickerId: coverStickerId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> coverStickerId = const Value.absent(),
                required int sortOrder,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PacksCompanion.insert(
                id: id,
                name: name,
                coverStickerId: coverStickerId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PacksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({stickersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (stickersRefs) db.stickers],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (stickersRefs)
                    await $_getPrefetchedData<Pack, $PacksTable, Sticker>(
                      currentTable: table,
                      referencedTable: $$PacksTableReferences
                          ._stickersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PacksTableReferences(db, table, p0).stickersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.packId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PacksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PacksTable,
      Pack,
      $$PacksTableFilterComposer,
      $$PacksTableOrderingComposer,
      $$PacksTableAnnotationComposer,
      $$PacksTableCreateCompanionBuilder,
      $$PacksTableUpdateCompanionBuilder,
      (Pack, $$PacksTableReferences),
      Pack,
      PrefetchHooks Function({bool stickersRefs})
    >;
typedef $$StickersTableCreateCompanionBuilder =
    StickersCompanion Function({
      required String id,
      required String packId,
      required String name,
      required String filePath,
      required int width,
      required int height,
      required String format,
      Value<String?> layersJson,
      Value<int> fileSize,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StickersTableUpdateCompanionBuilder =
    StickersCompanion Function({
      Value<String> id,
      Value<String> packId,
      Value<String> name,
      Value<String> filePath,
      Value<int> width,
      Value<int> height,
      Value<String> format,
      Value<String?> layersJson,
      Value<int> fileSize,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$StickersTableReferences
    extends BaseReferences<_$AppDatabase, $StickersTable, Sticker> {
  $$StickersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PacksTable _packIdTable(_$AppDatabase db) => db.packs.createAlias(
    $_aliasNameGenerator(db.stickers.packId, db.packs.id),
  );

  $$PacksTableProcessedTableManager get packId {
    final $_column = $_itemColumn<String>('pack_id')!;

    final manager = $$PacksTableTableManager(
      $_db,
      $_db.packs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_packIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StickersTableFilterComposer
    extends Composer<_$AppDatabase, $StickersTable> {
  $$StickersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layersJson => $composableBuilder(
    column: $table.layersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PacksTableFilterComposer get packId {
    final $$PacksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packId,
      referencedTable: $db.packs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PacksTableFilterComposer(
            $db: $db,
            $table: $db.packs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StickersTableOrderingComposer
    extends Composer<_$AppDatabase, $StickersTable> {
  $$StickersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layersJson => $composableBuilder(
    column: $table.layersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PacksTableOrderingComposer get packId {
    final $$PacksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packId,
      referencedTable: $db.packs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PacksTableOrderingComposer(
            $db: $db,
            $table: $db.packs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StickersTableAnnotationComposer
    extends Composer<_$AppDatabase, $StickersTable> {
  $$StickersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get layersJson => $composableBuilder(
    column: $table.layersJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PacksTableAnnotationComposer get packId {
    final $$PacksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packId,
      referencedTable: $db.packs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PacksTableAnnotationComposer(
            $db: $db,
            $table: $db.packs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StickersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StickersTable,
          Sticker,
          $$StickersTableFilterComposer,
          $$StickersTableOrderingComposer,
          $$StickersTableAnnotationComposer,
          $$StickersTableCreateCompanionBuilder,
          $$StickersTableUpdateCompanionBuilder,
          (Sticker, $$StickersTableReferences),
          Sticker,
          PrefetchHooks Function({bool packId})
        > {
  $$StickersTableTableManager(_$AppDatabase db, $StickersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StickersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StickersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StickersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> packId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String?> layersJson = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StickersCompanion(
                id: id,
                packId: packId,
                name: name,
                filePath: filePath,
                width: width,
                height: height,
                format: format,
                layersJson: layersJson,
                fileSize: fileSize,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String packId,
                required String name,
                required String filePath,
                required int width,
                required int height,
                required String format,
                Value<String?> layersJson = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StickersCompanion.insert(
                id: id,
                packId: packId,
                name: name,
                filePath: filePath,
                width: width,
                height: height,
                format: format,
                layersJson: layersJson,
                fileSize: fileSize,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StickersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({packId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (packId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.packId,
                                referencedTable: $$StickersTableReferences
                                    ._packIdTable(db),
                                referencedColumn: $$StickersTableReferences
                                    ._packIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StickersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StickersTable,
      Sticker,
      $$StickersTableFilterComposer,
      $$StickersTableOrderingComposer,
      $$StickersTableAnnotationComposer,
      $$StickersTableCreateCompanionBuilder,
      $$StickersTableUpdateCompanionBuilder,
      (Sticker, $$StickersTableReferences),
      Sticker,
      PrefetchHooks Function({bool packId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PacksTableTableManager get packs =>
      $$PacksTableTableManager(_db, _db.packs);
  $$StickersTableTableManager get stickers =>
      $$StickersTableTableManager(_db, _db.stickers);
}
