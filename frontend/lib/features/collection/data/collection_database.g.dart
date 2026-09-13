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
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _photoDirtyMeta = const VerificationMeta(
    'photoDirty',
  );
  @override
  late final GeneratedColumn<bool> photoDirty = GeneratedColumn<bool>(
    'photo_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("photo_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    dirty,
    deleted,
    photoDirty,
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
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('photo_dirty')) {
      context.handle(
        _photoDirtyMeta,
        photoDirty.isAcceptableOrUnknown(data['photo_dirty']!, _photoDirtyMeta),
      );
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
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      photoDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}photo_dirty'],
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

  /// Schema 3 (M8 sync). True while this row has local changes the server
  /// has not yet seen. New rows are dirty by default so an offline save
  /// still uploads once the person signs in or reconnects.
  final bool dirty;

  /// Schema 3. A tombstone: the row is kept (its sync history matters) but
  /// every read hides it. Set by `DriftCollectionRepository.delete`.
  final bool deleted;

  /// Schema 3. True while this entry's photo has a local change (set or
  /// removed) not yet pushed, independent of [dirty].
  final bool photoDirty;
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
    required this.dirty,
    required this.deleted,
    required this.photoDirty,
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
    map['dirty'] = Variable<bool>(dirty);
    map['deleted'] = Variable<bool>(deleted);
    map['photo_dirty'] = Variable<bool>(photoDirty);
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
      dirty: Value(dirty),
      deleted: Value(deleted),
      photoDirty: Value(photoDirty),
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
      dirty: serializer.fromJson<bool>(json['dirty']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      photoDirty: serializer.fromJson<bool>(json['photoDirty']),
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
      'dirty': serializer.toJson<bool>(dirty),
      'deleted': serializer.toJson<bool>(deleted),
      'photoDirty': serializer.toJson<bool>(photoDirty),
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
    bool? dirty,
    bool? deleted,
    bool? photoDirty,
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
    dirty: dirty ?? this.dirty,
    deleted: deleted ?? this.deleted,
    photoDirty: photoDirty ?? this.photoDirty,
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
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      photoDirty: data.photoDirty.present
          ? data.photoDirty.value
          : this.photoDirty,
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
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty, ')
          ..write('deleted: $deleted, ')
          ..write('photoDirty: $photoDirty')
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
    dirty,
    deleted,
    photoDirty,
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
          other.updatedAt == this.updatedAt &&
          other.dirty == this.dirty &&
          other.deleted == this.deleted &&
          other.photoDirty == this.photoDirty);
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
  final Value<bool> dirty;
  final Value<bool> deleted;
  final Value<bool> photoDirty;
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
    this.dirty = const Value.absent(),
    this.deleted = const Value.absent(),
    this.photoDirty = const Value.absent(),
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
    this.dirty = const Value.absent(),
    this.deleted = const Value.absent(),
    this.photoDirty = const Value.absent(),
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
    Expression<bool>? dirty,
    Expression<bool>? deleted,
    Expression<bool>? photoDirty,
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
      if (dirty != null) 'dirty': dirty,
      if (deleted != null) 'deleted': deleted,
      if (photoDirty != null) 'photo_dirty': photoDirty,
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
    Value<bool>? dirty,
    Value<bool>? deleted,
    Value<bool>? photoDirty,
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
      dirty: dirty ?? this.dirty,
      deleted: deleted ?? this.deleted,
      photoDirty: photoDirty ?? this.photoDirty,
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
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (photoDirty.present) {
      map['photo_dirty'] = Variable<bool>(photoDirty.value);
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
          ..write('dirty: $dirty, ')
          ..write('deleted: $deleted, ')
          ..write('photoDirty: $photoDirty, ')
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

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastRevisionMeta = const VerificationMeta(
    'lastRevision',
  );
  @override
  late final GeneratedColumn<int> lastRevision = GeneratedColumn<int>(
    'last_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, ownerUserId, lastRevision];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    }
    if (data.containsKey('last_revision')) {
      context.handle(
        _lastRevisionMeta,
        lastRevision.isAcceptableOrUnknown(
          data['last_revision']!,
          _lastRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      ),
      lastRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_revision'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final int id;

  /// Null until an account has claimed this device's data.
  final String? ownerUserId;
  final int lastRevision;
  const SyncStateData({
    required this.id,
    this.ownerUserId,
    required this.lastRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    map['last_revision'] = Variable<int>(lastRevision);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      id: Value(id),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      lastRevision: Value(lastRevision),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      id: serializer.fromJson<int>(json['id']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      lastRevision: serializer.fromJson<int>(json['lastRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'lastRevision': serializer.toJson<int>(lastRevision),
    };
  }

  SyncStateData copyWith({
    int? id,
    Value<String?> ownerUserId = const Value.absent(),
    int? lastRevision,
  }) => SyncStateData(
    id: id ?? this.id,
    ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
    lastRevision: lastRevision ?? this.lastRevision,
  );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      id: data.id.present ? data.id.value : this.id,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      lastRevision: data.lastRevision.present
          ? data.lastRevision.value
          : this.lastRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('id: $id, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('lastRevision: $lastRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ownerUserId, lastRevision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.id == this.id &&
          other.ownerUserId == this.ownerUserId &&
          other.lastRevision == this.lastRevision);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<int> id;
  final Value<String?> ownerUserId;
  final Value<int> lastRevision;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.lastRevision = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.lastRevision = const Value.absent(),
  });
  static Insertable<SyncStateData> custom({
    Expression<int>? id,
    Expression<String>? ownerUserId,
    Expression<int>? lastRevision,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (lastRevision != null) 'last_revision': lastRevision,
    });
  }

  SyncStateCompanion copyWith({
    Value<int>? id,
    Value<String?>? ownerUserId,
    Value<int>? lastRevision,
  }) {
    return SyncStateCompanion(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      lastRevision: lastRevision ?? this.lastRevision,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (lastRevision.present) {
      map['last_revision'] = Variable<int>(lastRevision.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('lastRevision: $lastRevision')
          ..write(')'))
        .toString();
  }
}

abstract class _$CollectionDatabase extends GeneratedDatabase {
  _$CollectionDatabase(QueryExecutor e) : super(e);
  $CollectionDatabaseManager get managers => $CollectionDatabaseManager(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $PhotosTable photos = $PhotosTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
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
    syncState,
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
      Value<bool> dirty,
      Value<bool> deleted,
      Value<bool> photoDirty,
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
      Value<bool> dirty,
      Value<bool> deleted,
      Value<bool> photoDirty,
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

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get photoDirty => $composableBuilder(
    column: $table.photoDirty,
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

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get photoDirty => $composableBuilder(
    column: $table.photoDirty,
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

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get photoDirty => $composableBuilder(
    column: $table.photoDirty,
    builder: (column) => column,
  );
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
                Value<bool> dirty = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> photoDirty = const Value.absent(),
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
                dirty: dirty,
                deleted: deleted,
                photoDirty: photoDirty,
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
                Value<bool> dirty = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> photoDirty = const Value.absent(),
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
                dirty: dirty,
                deleted: deleted,
                photoDirty: photoDirty,
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
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      Value<int> id,
      Value<String?> ownerUserId,
      Value<int> lastRevision,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<int> id,
      Value<String?> ownerUserId,
      Value<int> lastRevision,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$CollectionDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastRevision => $composableBuilder(
    column: $table.lastRevision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$CollectionDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastRevision => $composableBuilder(
    column: $table.lastRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$CollectionDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastRevision => $composableBuilder(
    column: $table.lastRevision,
    builder: (column) => column,
  );
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$CollectionDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<
              _$CollectionDatabase,
              $SyncStateTable,
              SyncStateData
            >,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$CollectionDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<int> lastRevision = const Value.absent(),
              }) => SyncStateCompanion(
                id: id,
                ownerUserId: ownerUserId,
                lastRevision: lastRevision,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<int> lastRevision = const Value.absent(),
              }) => SyncStateCompanion.insert(
                id: id,
                ownerUserId: ownerUserId,
                lastRevision: lastRevision,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateTable, SyncStateData>(table),
                  BaseReferences<
                    _$CollectionDatabase,
                    $SyncStateTable,
                    SyncStateData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$CollectionDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$CollectionDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;

class $CollectionDatabaseManager {
  final _$CollectionDatabase _db;
  $CollectionDatabaseManager(this._db);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db, _db.photos);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}
