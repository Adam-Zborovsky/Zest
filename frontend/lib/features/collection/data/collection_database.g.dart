// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_database.dart';

// ignore_for_file: type=lint
class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CollectionEntryKind, String>
  kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<CollectionEntryKind>($EntriesTable.$converterkind);
  static const VerificationMeta _sourceRecipeIdMeta = const VerificationMeta(
    'sourceRecipeId',
  );
  @override
  late final GeneratedColumn<String> sourceRecipeId = GeneratedColumn<String>(
    'source_recipe_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceJsonMeta = const VerificationMeta(
    'sourceJson',
  );
  @override
  late final GeneratedColumn<String> sourceJson = GeneratedColumn<String>(
    'source_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _variationJsonMeta = const VerificationMeta(
    'variationJson',
  );
  @override
  late final GeneratedColumn<String> variationJson = GeneratedColumn<String>(
    'variation_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _hasPhotoMeta = const VerificationMeta(
    'hasPhoto',
  );
  @override
  late final GeneratedColumn<bool> hasPhoto = GeneratedColumn<bool>(
    'has_photo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_photo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    sourceRecipeId,
    sourceJson,
    variationJson,
    day,
    hasPhoto,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_recipe_id')) {
      context.handle(
        _sourceRecipeIdMeta,
        sourceRecipeId.isAcceptableOrUnknown(
          data['source_recipe_id']!,
          _sourceRecipeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceRecipeIdMeta);
    }
    if (data.containsKey('source_json')) {
      context.handle(
        _sourceJsonMeta,
        sourceJson.isAcceptableOrUnknown(data['source_json']!, _sourceJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceJsonMeta);
    }
    if (data.containsKey('variation_json')) {
      context.handle(
        _variationJsonMeta,
        variationJson.isAcceptableOrUnknown(
          data['variation_json']!,
          _variationJsonMeta,
        ),
      );
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    }
    if (data.containsKey('has_photo')) {
      context.handle(
        _hasPhotoMeta,
        hasPhoto.isAcceptableOrUnknown(data['has_photo']!, _hasPhotoMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: $EntriesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      sourceRecipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_recipe_id'],
      )!,
      sourceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_json'],
      )!,
      variationJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variation_json'],
      ),
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      hasPhoto: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_photo'],
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
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }

  static TypeConverter<CollectionEntryKind, String> $converterkind =
      const CollectionEntryKindConverter();
}

class Entry extends DataClass implements Insertable<Entry> {
  final String id;
  final CollectionEntryKind kind;
  final String sourceRecipeId;
  final String sourceJson;
  final String? variationJson;
  final String day;
  final bool hasPhoto;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Entry({
    required this.id,
    required this.kind,
    required this.sourceRecipeId,
    required this.sourceJson,
    this.variationJson,
    required this.day,
    required this.hasPhoto,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['kind'] = Variable<String>($EntriesTable.$converterkind.toSql(kind));
    }
    map['source_recipe_id'] = Variable<String>(sourceRecipeId);
    map['source_json'] = Variable<String>(sourceJson);
    if (!nullToAbsent || variationJson != null) {
      map['variation_json'] = Variable<String>(variationJson);
    }
    map['day'] = Variable<String>(day);
    map['has_photo'] = Variable<bool>(hasPhoto);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      kind: Value(kind),
      sourceRecipeId: Value(sourceRecipeId),
      sourceJson: Value(sourceJson),
      variationJson: variationJson == null && nullToAbsent
          ? const Value.absent()
          : Value(variationJson),
      day: Value(day),
      hasPhoto: Value(hasPhoto),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<CollectionEntryKind>(json['kind']),
      sourceRecipeId: serializer.fromJson<String>(json['sourceRecipeId']),
      sourceJson: serializer.fromJson<String>(json['sourceJson']),
      variationJson: serializer.fromJson<String?>(json['variationJson']),
      day: serializer.fromJson<String>(json['day']),
      hasPhoto: serializer.fromJson<bool>(json['hasPhoto']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<CollectionEntryKind>(kind),
      'sourceRecipeId': serializer.toJson<String>(sourceRecipeId),
      'sourceJson': serializer.toJson<String>(sourceJson),
      'variationJson': serializer.toJson<String?>(variationJson),
      'day': serializer.toJson<String>(day),
      'hasPhoto': serializer.toJson<bool>(hasPhoto),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Entry copyWith({
    String? id,
    CollectionEntryKind? kind,
    String? sourceRecipeId,
    String? sourceJson,
    Value<String?> variationJson = const Value.absent(),
    String? day,
    bool? hasPhoto,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Entry(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    sourceRecipeId: sourceRecipeId ?? this.sourceRecipeId,
    sourceJson: sourceJson ?? this.sourceJson,
    variationJson: variationJson.present
        ? variationJson.value
        : this.variationJson,
    day: day ?? this.day,
    hasPhoto: hasPhoto ?? this.hasPhoto,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      sourceRecipeId: data.sourceRecipeId.present
          ? data.sourceRecipeId.value
          : this.sourceRecipeId,
      sourceJson: data.sourceJson.present
          ? data.sourceJson.value
          : this.sourceJson,
      variationJson: data.variationJson.present
          ? data.variationJson.value
          : this.variationJson,
      day: data.day.present ? data.day.value : this.day,
      hasPhoto: data.hasPhoto.present ? data.hasPhoto.value : this.hasPhoto,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('sourceRecipeId: $sourceRecipeId, ')
          ..write('sourceJson: $sourceJson, ')
          ..write('variationJson: $variationJson, ')
          ..write('day: $day, ')
          ..write('hasPhoto: $hasPhoto, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    sourceRecipeId,
    sourceJson,
    variationJson,
    day,
    hasPhoto,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.sourceRecipeId == this.sourceRecipeId &&
          other.sourceJson == this.sourceJson &&
          other.variationJson == this.variationJson &&
          other.day == this.day &&
          other.hasPhoto == this.hasPhoto &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<String> id;
  final Value<CollectionEntryKind> kind;
  final Value<String> sourceRecipeId;
  final Value<String> sourceJson;
  final Value<String?> variationJson;
  final Value<String> day;
  final Value<bool> hasPhoto;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.sourceRecipeId = const Value.absent(),
    this.sourceJson = const Value.absent(),
    this.variationJson = const Value.absent(),
    this.day = const Value.absent(),
    this.hasPhoto = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required String id,
    required CollectionEntryKind kind,
    required String sourceRecipeId,
    required String sourceJson,
    this.variationJson = const Value.absent(),
    this.day = const Value.absent(),
    this.hasPhoto = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       sourceRecipeId = Value(sourceRecipeId),
       sourceJson = Value(sourceJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Entry> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? sourceRecipeId,
    Expression<String>? sourceJson,
    Expression<String>? variationJson,
    Expression<String>? day,
    Expression<bool>? hasPhoto,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (sourceRecipeId != null) 'source_recipe_id': sourceRecipeId,
      if (sourceJson != null) 'source_json': sourceJson,
      if (variationJson != null) 'variation_json': variationJson,
      if (day != null) 'day': day,
      if (hasPhoto != null) 'has_photo': hasPhoto,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<String>? id,
    Value<CollectionEntryKind>? kind,
    Value<String>? sourceRecipeId,
    Value<String>? sourceJson,
    Value<String?>? variationJson,
    Value<String>? day,
    Value<bool>? hasPhoto,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      sourceRecipeId: sourceRecipeId ?? this.sourceRecipeId,
      sourceJson: sourceJson ?? this.sourceJson,
      variationJson: variationJson ?? this.variationJson,
      day: day ?? this.day,
      hasPhoto: hasPhoto ?? this.hasPhoto,
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
    if (kind.present) {
      map['kind'] = Variable<String>(
        $EntriesTable.$converterkind.toSql(kind.value),
      );
    }
    if (sourceRecipeId.present) {
      map['source_recipe_id'] = Variable<String>(sourceRecipeId.value);
    }
    if (sourceJson.present) {
      map['source_json'] = Variable<String>(sourceJson.value);
    }
    if (variationJson.present) {
      map['variation_json'] = Variable<String>(variationJson.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (hasPhoto.present) {
      map['has_photo'] = Variable<bool>(hasPhoto.value);
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
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('sourceRecipeId: $sourceRecipeId, ')
          ..write('sourceJson: $sourceJson, ')
          ..write('variationJson: $variationJson, ')
          ..write('day: $day, ')
          ..write('hasPhoto: $hasPhoto, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotosTable extends Photos with TableInfo<$PhotosTable, Photo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryId, mimeType, bytes, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Photo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId};
  @override
  Photo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Photo(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PhotosTable createAlias(String alias) {
    return $PhotosTable(attachedDatabase, alias);
  }
}

class Photo extends DataClass implements Insertable<Photo> {
  final String entryId;
  final String mimeType;
  final Uint8List bytes;
  final DateTime updatedAt;
  const Photo({
    required this.entryId,
    required this.mimeType,
    required this.bytes,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['mime_type'] = Variable<String>(mimeType);
    map['bytes'] = Variable<Uint8List>(bytes);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PhotosCompanion toCompanion(bool nullToAbsent) {
    return PhotosCompanion(
      entryId: Value(entryId),
      mimeType: Value(mimeType),
      bytes: Value(bytes),
      updatedAt: Value(updatedAt),
    );
  }

  factory Photo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Photo(
      entryId: serializer.fromJson<String>(json['entryId']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'mimeType': serializer.toJson<String>(mimeType),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Photo copyWith({
    String? entryId,
    String? mimeType,
    Uint8List? bytes,
    DateTime? updatedAt,
  }) => Photo(
    entryId: entryId ?? this.entryId,
    mimeType: mimeType ?? this.mimeType,
    bytes: bytes ?? this.bytes,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Photo copyWithCompanion(PhotosCompanion data) {
    return Photo(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Photo(')
          ..write('entryId: $entryId, ')
          ..write('mimeType: $mimeType, ')
          ..write('bytes: $bytes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(entryId, mimeType, $driftBlobEquality.hash(bytes), updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Photo &&
          other.entryId == this.entryId &&
          other.mimeType == this.mimeType &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.updatedAt == this.updatedAt);
}

class PhotosCompanion extends UpdateCompanion<Photo> {
  final Value<String> entryId;
  final Value<String> mimeType;
  final Value<Uint8List> bytes;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PhotosCompanion({
    this.entryId = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.bytes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotosCompanion.insert({
    required String entryId,
    required String mimeType,
    required Uint8List bytes,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       mimeType = Value(mimeType),
       bytes = Value(bytes),
       updatedAt = Value(updatedAt);
  static Insertable<Photo> custom({
    Expression<String>? entryId,
    Expression<String>? mimeType,
    Expression<Uint8List>? bytes,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (mimeType != null) 'mime_type': mimeType,
      if (bytes != null) 'bytes': bytes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotosCompanion copyWith({
    Value<String>? entryId,
    Value<String>? mimeType,
    Value<Uint8List>? bytes,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PhotosCompanion(
      entryId: entryId ?? this.entryId,
      mimeType: mimeType ?? this.mimeType,
      bytes: bytes ?? this.bytes,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
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
    return (StringBuffer('PhotosCompanion(')
          ..write('entryId: $entryId, ')
          ..write('mimeType: $mimeType, ')
          ..write('bytes: $bytes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CollectionDatabase extends GeneratedDatabase {
  _$CollectionDatabase(QueryExecutor e) : super(e);
  $CollectionDatabaseManager get managers => $CollectionDatabaseManager(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $PhotosTable photos = $PhotosTable(this);
  late final Index entriesSourceRecipeId = Index(
    'entries_source_recipe_id',
    'CREATE INDEX entries_source_recipe_id ON entries (source_recipe_id)',
  );
  late final Index entriesDay = Index(
    'entries_day',
    'CREATE INDEX entries_day ON entries (day)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    entries,
    photos,
    entriesSourceRecipeId,
    entriesDay,
  ];
}

typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      required String id,
      required CollectionEntryKind kind,
      required String sourceRecipeId,
      required String sourceJson,
      Value<String?> variationJson,
      Value<String> day,
      Value<bool> hasPhoto,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<String> id,
      Value<CollectionEntryKind> kind,
      Value<String> sourceRecipeId,
      Value<String> sourceJson,
      Value<String?> variationJson,
      Value<String> day,
      Value<bool> hasPhoto,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$EntriesTableFilterComposer
    extends Composer<_$CollectionDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<
    CollectionEntryKind,
    CollectionEntryKind,
    String
  >
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get sourceRecipeId => $composableBuilder(
    column: $table.sourceRecipeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variationJson => $composableBuilder(
    column: $table.variationJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasPhoto => $composableBuilder(
    column: $table.hasPhoto,
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
}

class $$EntriesTableOrderingComposer
    extends Composer<_$CollectionDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRecipeId => $composableBuilder(
    column: $table.sourceRecipeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variationJson => $composableBuilder(
    column: $table.variationJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasPhoto => $composableBuilder(
    column: $table.hasPhoto,
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

class $$EntriesTableAnnotationComposer
    extends Composer<_$CollectionDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CollectionEntryKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get sourceRecipeId => $composableBuilder(
    column: $table.sourceRecipeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get variationJson => $composableBuilder(
    column: $table.variationJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<bool> get hasPhoto =>
      $composableBuilder(column: $table.hasPhoto, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$CollectionDatabase,
          $EntriesTable,
          Entry,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (Entry, BaseReferences<_$CollectionDatabase, $EntriesTable, Entry>),
          Entry,
          PrefetchHooks Function()
        > {
  $$EntriesTableTableManager(_$CollectionDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<CollectionEntryKind> kind = const Value.absent(),
                Value<String> sourceRecipeId = const Value.absent(),
                Value<String> sourceJson = const Value.absent(),
                Value<String?> variationJson = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<bool> hasPhoto = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                kind: kind,
                sourceRecipeId: sourceRecipeId,
                sourceJson: sourceJson,
                variationJson: variationJson,
                day: day,
                hasPhoto: hasPhoto,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required CollectionEntryKind kind,
                required String sourceRecipeId,
                required String sourceJson,
                Value<String?> variationJson = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<bool> hasPhoto = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                kind: kind,
                sourceRecipeId: sourceRecipeId,
                sourceJson: sourceJson,
                variationJson: variationJson,
                day: day,
                hasPhoto: hasPhoto,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntriesTable, Entry>(table),
                  BaseReferences<_$CollectionDatabase, $EntriesTable, Entry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$CollectionDatabase,
      $EntriesTable,
      Entry,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (Entry, BaseReferences<_$CollectionDatabase, $EntriesTable, Entry>),
      Entry,
      PrefetchHooks Function()
    >;
typedef $$PhotosTableCreateCompanionBuilder =
    PhotosCompanion Function({
      required String entryId,
      required String mimeType,
      required Uint8List bytes,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PhotosTableUpdateCompanionBuilder =
    PhotosCompanion Function({
      Value<String> entryId,
      Value<String> mimeType,
      Value<Uint8List> bytes,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PhotosTableFilterComposer
    extends Composer<_$CollectionDatabase, $PhotosTable> {
  $$PhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhotosTableOrderingComposer
    extends Composer<_$CollectionDatabase, $PhotosTable> {
  $$PhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotosTableAnnotationComposer
    extends Composer<_$CollectionDatabase, $PhotosTable> {
  $$PhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PhotosTableTableManager
    extends
        RootTableManager<
          _$CollectionDatabase,
          $PhotosTable,
          Photo,
          $$PhotosTableFilterComposer,
          $$PhotosTableOrderingComposer,
          $$PhotosTableAnnotationComposer,
          $$PhotosTableCreateCompanionBuilder,
          $$PhotosTableUpdateCompanionBuilder,
          (Photo, BaseReferences<_$CollectionDatabase, $PhotosTable, Photo>),
          Photo,
          PrefetchHooks Function()
        > {
  $$PhotosTableTableManager(_$CollectionDatabase db, $PhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotosCompanion(
                entryId: entryId,
                mimeType: mimeType,
                bytes: bytes,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String mimeType,
                required Uint8List bytes,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PhotosCompanion.insert(
                entryId: entryId,
                mimeType: mimeType,
                bytes: bytes,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PhotosTable, Photo>(table),
                  BaseReferences<_$CollectionDatabase, $PhotosTable, Photo>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$CollectionDatabase,
      $PhotosTable,
      Photo,
      $$PhotosTableFilterComposer,
      $$PhotosTableOrderingComposer,
      $$PhotosTableAnnotationComposer,
      $$PhotosTableCreateCompanionBuilder,
      $$PhotosTableUpdateCompanionBuilder,
      (Photo, BaseReferences<_$CollectionDatabase, $PhotosTable, Photo>),
      Photo,
      PrefetchHooks Function()
    >;

class $CollectionDatabaseManager {
  final _$CollectionDatabase _db;
  $CollectionDatabaseManager(this._db);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db, _db.photos);
}
