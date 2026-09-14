// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_database.dart';

// ignore_for_file: type=lint
class $RecipesTable extends Recipes with TableInfo<$RecipesTable, RecipeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
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
    providerId,
    name,
    sourceJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipes';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('source_json')) {
      context.handle(
        _sourceJsonMeta,
        sourceJson.isAcceptableOrUnknown(data['source_json']!, _sourceJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {providerId};
  @override
  RecipeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeRow(
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sourceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RecipesTable createAlias(String alias) {
    return $RecipesTable(attachedDatabase, alias);
  }
}

class RecipeRow extends DataClass implements Insertable<RecipeRow> {
  final String providerId;
  final String name;
  final String sourceJson;
  final DateTime updatedAt;
  const RecipeRow({
    required this.providerId,
    required this.name,
    required this.sourceJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['provider_id'] = Variable<String>(providerId);
    map['name'] = Variable<String>(name);
    map['source_json'] = Variable<String>(sourceJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RecipesCompanion toCompanion(bool nullToAbsent) {
    return RecipesCompanion(
      providerId: Value(providerId),
      name: Value(name),
      sourceJson: Value(sourceJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory RecipeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeRow(
      providerId: serializer.fromJson<String>(json['providerId']),
      name: serializer.fromJson<String>(json['name']),
      sourceJson: serializer.fromJson<String>(json['sourceJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'providerId': serializer.toJson<String>(providerId),
      'name': serializer.toJson<String>(name),
      'sourceJson': serializer.toJson<String>(sourceJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RecipeRow copyWith({
    String? providerId,
    String? name,
    String? sourceJson,
    DateTime? updatedAt,
  }) => RecipeRow(
    providerId: providerId ?? this.providerId,
    name: name ?? this.name,
    sourceJson: sourceJson ?? this.sourceJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RecipeRow copyWithCompanion(RecipesCompanion data) {
    return RecipeRow(
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      name: data.name.present ? data.name.value : this.name,
      sourceJson: data.sourceJson.present
          ? data.sourceJson.value
          : this.sourceJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeRow(')
          ..write('providerId: $providerId, ')
          ..write('name: $name, ')
          ..write('sourceJson: $sourceJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(providerId, name, sourceJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeRow &&
          other.providerId == this.providerId &&
          other.name == this.name &&
          other.sourceJson == this.sourceJson &&
          other.updatedAt == this.updatedAt);
}

class RecipesCompanion extends UpdateCompanion<RecipeRow> {
  final Value<String> providerId;
  final Value<String> name;
  final Value<String> sourceJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RecipesCompanion({
    this.providerId = const Value.absent(),
    this.name = const Value.absent(),
    this.sourceJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipesCompanion.insert({
    required String providerId,
    required String name,
    required String sourceJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : providerId = Value(providerId),
       name = Value(name),
       sourceJson = Value(sourceJson),
       updatedAt = Value(updatedAt);
  static Insertable<RecipeRow> custom({
    Expression<String>? providerId,
    Expression<String>? name,
    Expression<String>? sourceJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (providerId != null) 'provider_id': providerId,
      if (name != null) 'name': name,
      if (sourceJson != null) 'source_json': sourceJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipesCompanion copyWith({
    Value<String>? providerId,
    Value<String>? name,
    Value<String>? sourceJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RecipesCompanion(
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      sourceJson: sourceJson ?? this.sourceJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sourceJson.present) {
      map['source_json'] = Variable<String>(sourceJson.value);
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
    return (StringBuffer('RecipesCompanion(')
          ..write('providerId: $providerId, ')
          ..write('name: $name, ')
          ..write('sourceJson: $sourceJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IngredientUsagesTable extends IngredientUsages
    with TableInfo<$IngredientUsagesTable, IngredientUsageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IngredientUsagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recipeIdMeta = const VerificationMeta(
    'recipeId',
  );
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
    'recipe_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedIngredientMeta =
      const VerificationMeta('normalizedIngredient');
  @override
  late final GeneratedColumn<String> normalizedIngredient =
      GeneratedColumn<String>(
        'normalized_ingredient',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [recipeId, normalizedIngredient];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ingredient_usages';
  @override
  VerificationContext validateIntegrity(
    Insertable<IngredientUsageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('recipe_id')) {
      context.handle(
        _recipeIdMeta,
        recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('normalized_ingredient')) {
      context.handle(
        _normalizedIngredientMeta,
        normalizedIngredient.isAcceptableOrUnknown(
          data['normalized_ingredient']!,
          _normalizedIngredientMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedIngredientMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recipeId, normalizedIngredient};
  @override
  IngredientUsageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IngredientUsageRow(
      recipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_id'],
      )!,
      normalizedIngredient: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_ingredient'],
      )!,
    );
  }

  @override
  $IngredientUsagesTable createAlias(String alias) {
    return $IngredientUsagesTable(attachedDatabase, alias);
  }
}

class IngredientUsageRow extends DataClass
    implements Insertable<IngredientUsageRow> {
  final String recipeId;
  final String normalizedIngredient;
  const IngredientUsageRow({
    required this.recipeId,
    required this.normalizedIngredient,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['recipe_id'] = Variable<String>(recipeId);
    map['normalized_ingredient'] = Variable<String>(normalizedIngredient);
    return map;
  }

  IngredientUsagesCompanion toCompanion(bool nullToAbsent) {
    return IngredientUsagesCompanion(
      recipeId: Value(recipeId),
      normalizedIngredient: Value(normalizedIngredient),
    );
  }

  factory IngredientUsageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IngredientUsageRow(
      recipeId: serializer.fromJson<String>(json['recipeId']),
      normalizedIngredient: serializer.fromJson<String>(
        json['normalizedIngredient'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recipeId': serializer.toJson<String>(recipeId),
      'normalizedIngredient': serializer.toJson<String>(normalizedIngredient),
    };
  }

  IngredientUsageRow copyWith({
    String? recipeId,
    String? normalizedIngredient,
  }) => IngredientUsageRow(
    recipeId: recipeId ?? this.recipeId,
    normalizedIngredient: normalizedIngredient ?? this.normalizedIngredient,
  );
  IngredientUsageRow copyWithCompanion(IngredientUsagesCompanion data) {
    return IngredientUsageRow(
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      normalizedIngredient: data.normalizedIngredient.present
          ? data.normalizedIngredient.value
          : this.normalizedIngredient,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IngredientUsageRow(')
          ..write('recipeId: $recipeId, ')
          ..write('normalizedIngredient: $normalizedIngredient')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recipeId, normalizedIngredient);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IngredientUsageRow &&
          other.recipeId == this.recipeId &&
          other.normalizedIngredient == this.normalizedIngredient);
}

class IngredientUsagesCompanion extends UpdateCompanion<IngredientUsageRow> {
  final Value<String> recipeId;
  final Value<String> normalizedIngredient;
  final Value<int> rowid;
  const IngredientUsagesCompanion({
    this.recipeId = const Value.absent(),
    this.normalizedIngredient = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IngredientUsagesCompanion.insert({
    required String recipeId,
    required String normalizedIngredient,
    this.rowid = const Value.absent(),
  }) : recipeId = Value(recipeId),
       normalizedIngredient = Value(normalizedIngredient);
  static Insertable<IngredientUsageRow> custom({
    Expression<String>? recipeId,
    Expression<String>? normalizedIngredient,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recipeId != null) 'recipe_id': recipeId,
      if (normalizedIngredient != null)
        'normalized_ingredient': normalizedIngredient,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IngredientUsagesCompanion copyWith({
    Value<String>? recipeId,
    Value<String>? normalizedIngredient,
    Value<int>? rowid,
  }) {
    return IngredientUsagesCompanion(
      recipeId: recipeId ?? this.recipeId,
      normalizedIngredient: normalizedIngredient ?? this.normalizedIngredient,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (normalizedIngredient.present) {
      map['normalized_ingredient'] = Variable<String>(
        normalizedIngredient.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IngredientUsagesCompanion(')
          ..write('recipeId: $recipeId, ')
          ..write('normalizedIngredient: $normalizedIngredient, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogSnapshotTableTable extends CatalogSnapshotTable
    with TableInfo<$CatalogSnapshotTableTable, CatalogSnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogSnapshotTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipeCountMeta = const VerificationMeta(
    'recipeCount',
  );
  @override
  late final GeneratedColumn<int> recipeCount = GeneratedColumn<int>(
    'recipe_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appliedAtMeta = const VerificationMeta(
    'appliedAt',
  );
  @override
  late final GeneratedColumn<DateTime> appliedAt = GeneratedColumn<DateTime>(
    'applied_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    publishedAt,
    recipeCount,
    appliedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_snapshot';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogSnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('recipe_count')) {
      context.handle(
        _recipeCountMeta,
        recipeCount.isAcceptableOrUnknown(
          data['recipe_count']!,
          _recipeCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipeCountMeta);
    }
    if (data.containsKey('applied_at')) {
      context.handle(
        _appliedAtMeta,
        appliedAt.isAcceptableOrUnknown(data['applied_at']!, _appliedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_appliedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogSnapshotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogSnapshotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      )!,
      recipeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recipe_count'],
      )!,
      appliedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}applied_at'],
      )!,
    );
  }

  @override
  $CatalogSnapshotTableTable createAlias(String alias) {
    return $CatalogSnapshotTableTable(attachedDatabase, alias);
  }
}

class CatalogSnapshotRow extends DataClass
    implements Insertable<CatalogSnapshotRow> {
  final int id;
  final String version;
  final DateTime publishedAt;
  final int recipeCount;
  final DateTime appliedAt;
  const CatalogSnapshotRow({
    required this.id,
    required this.version,
    required this.publishedAt,
    required this.recipeCount,
    required this.appliedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['version'] = Variable<String>(version);
    map['published_at'] = Variable<DateTime>(publishedAt);
    map['recipe_count'] = Variable<int>(recipeCount);
    map['applied_at'] = Variable<DateTime>(appliedAt);
    return map;
  }

  CatalogSnapshotTableCompanion toCompanion(bool nullToAbsent) {
    return CatalogSnapshotTableCompanion(
      id: Value(id),
      version: Value(version),
      publishedAt: Value(publishedAt),
      recipeCount: Value(recipeCount),
      appliedAt: Value(appliedAt),
    );
  }

  factory CatalogSnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogSnapshotRow(
      id: serializer.fromJson<int>(json['id']),
      version: serializer.fromJson<String>(json['version']),
      publishedAt: serializer.fromJson<DateTime>(json['publishedAt']),
      recipeCount: serializer.fromJson<int>(json['recipeCount']),
      appliedAt: serializer.fromJson<DateTime>(json['appliedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'version': serializer.toJson<String>(version),
      'publishedAt': serializer.toJson<DateTime>(publishedAt),
      'recipeCount': serializer.toJson<int>(recipeCount),
      'appliedAt': serializer.toJson<DateTime>(appliedAt),
    };
  }

  CatalogSnapshotRow copyWith({
    int? id,
    String? version,
    DateTime? publishedAt,
    int? recipeCount,
    DateTime? appliedAt,
  }) => CatalogSnapshotRow(
    id: id ?? this.id,
    version: version ?? this.version,
    publishedAt: publishedAt ?? this.publishedAt,
    recipeCount: recipeCount ?? this.recipeCount,
    appliedAt: appliedAt ?? this.appliedAt,
  );
  CatalogSnapshotRow copyWithCompanion(CatalogSnapshotTableCompanion data) {
    return CatalogSnapshotRow(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      recipeCount: data.recipeCount.present
          ? data.recipeCount.value
          : this.recipeCount,
      appliedAt: data.appliedAt.present ? data.appliedAt.value : this.appliedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogSnapshotRow(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('recipeCount: $recipeCount, ')
          ..write('appliedAt: $appliedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, version, publishedAt, recipeCount, appliedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogSnapshotRow &&
          other.id == this.id &&
          other.version == this.version &&
          other.publishedAt == this.publishedAt &&
          other.recipeCount == this.recipeCount &&
          other.appliedAt == this.appliedAt);
}

class CatalogSnapshotTableCompanion
    extends UpdateCompanion<CatalogSnapshotRow> {
  final Value<int> id;
  final Value<String> version;
  final Value<DateTime> publishedAt;
  final Value<int> recipeCount;
  final Value<DateTime> appliedAt;
  const CatalogSnapshotTableCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.recipeCount = const Value.absent(),
    this.appliedAt = const Value.absent(),
  });
  CatalogSnapshotTableCompanion.insert({
    this.id = const Value.absent(),
    required String version,
    required DateTime publishedAt,
    required int recipeCount,
    required DateTime appliedAt,
  }) : version = Value(version),
       publishedAt = Value(publishedAt),
       recipeCount = Value(recipeCount),
       appliedAt = Value(appliedAt);
  static Insertable<CatalogSnapshotRow> custom({
    Expression<int>? id,
    Expression<String>? version,
    Expression<DateTime>? publishedAt,
    Expression<int>? recipeCount,
    Expression<DateTime>? appliedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (publishedAt != null) 'published_at': publishedAt,
      if (recipeCount != null) 'recipe_count': recipeCount,
      if (appliedAt != null) 'applied_at': appliedAt,
    });
  }

  CatalogSnapshotTableCompanion copyWith({
    Value<int>? id,
    Value<String>? version,
    Value<DateTime>? publishedAt,
    Value<int>? recipeCount,
    Value<DateTime>? appliedAt,
  }) {
    return CatalogSnapshotTableCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      publishedAt: publishedAt ?? this.publishedAt,
      recipeCount: recipeCount ?? this.recipeCount,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (recipeCount.present) {
      map['recipe_count'] = Variable<int>(recipeCount.value);
    }
    if (appliedAt.present) {
      map['applied_at'] = Variable<DateTime>(appliedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogSnapshotTableCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('recipeCount: $recipeCount, ')
          ..write('appliedAt: $appliedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$CatalogDatabase extends GeneratedDatabase {
  _$CatalogDatabase(QueryExecutor e) : super(e);
  $CatalogDatabaseManager get managers => $CatalogDatabaseManager(this);
  late final $RecipesTable recipes = $RecipesTable(this);
  late final $IngredientUsagesTable ingredientUsages = $IngredientUsagesTable(
    this,
  );
  late final $CatalogSnapshotTableTable catalogSnapshotTable =
      $CatalogSnapshotTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    recipes,
    ingredientUsages,
    catalogSnapshotTable,
  ];
}

typedef $$RecipesTableCreateCompanionBuilder =
    RecipesCompanion Function({
      required String providerId,
      required String name,
      required String sourceJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$RecipesTableUpdateCompanionBuilder =
    RecipesCompanion Function({
      Value<String> providerId,
      Value<String> name,
      Value<String> sourceJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$RecipesTableFilterComposer
    extends Composer<_$CatalogDatabase, $RecipesTable> {
  $$RecipesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecipesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $RecipesTable> {
  $$RecipesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecipesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $RecipesTable> {
  $$RecipesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RecipesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $RecipesTable,
          RecipeRow,
          $$RecipesTableFilterComposer,
          $$RecipesTableOrderingComposer,
          $$RecipesTableAnnotationComposer,
          $$RecipesTableCreateCompanionBuilder,
          $$RecipesTableUpdateCompanionBuilder,
          (
            RecipeRow,
            BaseReferences<_$CatalogDatabase, $RecipesTable, RecipeRow>,
          ),
          RecipeRow,
          PrefetchHooks Function()
        > {
  $$RecipesTableTableManager(_$CatalogDatabase db, $RecipesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> providerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> sourceJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipesCompanion(
                providerId: providerId,
                name: name,
                sourceJson: sourceJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String providerId,
                required String name,
                required String sourceJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RecipesCompanion.insert(
                providerId: providerId,
                name: name,
                sourceJson: sourceJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecipesTable, RecipeRow>(table),
                  BaseReferences<_$CatalogDatabase, $RecipesTable, RecipeRow>(
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

typedef $$RecipesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $RecipesTable,
      RecipeRow,
      $$RecipesTableFilterComposer,
      $$RecipesTableOrderingComposer,
      $$RecipesTableAnnotationComposer,
      $$RecipesTableCreateCompanionBuilder,
      $$RecipesTableUpdateCompanionBuilder,
      (RecipeRow, BaseReferences<_$CatalogDatabase, $RecipesTable, RecipeRow>),
      RecipeRow,
      PrefetchHooks Function()
    >;
typedef $$IngredientUsagesTableCreateCompanionBuilder =
    IngredientUsagesCompanion Function({
      required String recipeId,
      required String normalizedIngredient,
      Value<int> rowid,
    });
typedef $$IngredientUsagesTableUpdateCompanionBuilder =
    IngredientUsagesCompanion Function({
      Value<String> recipeId,
      Value<String> normalizedIngredient,
      Value<int> rowid,
    });

class $$IngredientUsagesTableFilterComposer
    extends Composer<_$CatalogDatabase, $IngredientUsagesTable> {
  $$IngredientUsagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recipeId => $composableBuilder(
    column: $table.recipeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedIngredient => $composableBuilder(
    column: $table.normalizedIngredient,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IngredientUsagesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $IngredientUsagesTable> {
  $$IngredientUsagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recipeId => $composableBuilder(
    column: $table.recipeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedIngredient => $composableBuilder(
    column: $table.normalizedIngredient,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IngredientUsagesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $IngredientUsagesTable> {
  $$IngredientUsagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recipeId =>
      $composableBuilder(column: $table.recipeId, builder: (column) => column);

  GeneratedColumn<String> get normalizedIngredient => $composableBuilder(
    column: $table.normalizedIngredient,
    builder: (column) => column,
  );
}

class $$IngredientUsagesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $IngredientUsagesTable,
          IngredientUsageRow,
          $$IngredientUsagesTableFilterComposer,
          $$IngredientUsagesTableOrderingComposer,
          $$IngredientUsagesTableAnnotationComposer,
          $$IngredientUsagesTableCreateCompanionBuilder,
          $$IngredientUsagesTableUpdateCompanionBuilder,
          (
            IngredientUsageRow,
            BaseReferences<
              _$CatalogDatabase,
              $IngredientUsagesTable,
              IngredientUsageRow
            >,
          ),
          IngredientUsageRow,
          PrefetchHooks Function()
        > {
  $$IngredientUsagesTableTableManager(
    _$CatalogDatabase db,
    $IngredientUsagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IngredientUsagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IngredientUsagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IngredientUsagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> recipeId = const Value.absent(),
                Value<String> normalizedIngredient = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IngredientUsagesCompanion(
                recipeId: recipeId,
                normalizedIngredient: normalizedIngredient,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recipeId,
                required String normalizedIngredient,
                Value<int> rowid = const Value.absent(),
              }) => IngredientUsagesCompanion.insert(
                recipeId: recipeId,
                normalizedIngredient: normalizedIngredient,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IngredientUsagesTable, IngredientUsageRow>(
                    table,
                  ),
                  BaseReferences<
                    _$CatalogDatabase,
                    $IngredientUsagesTable,
                    IngredientUsageRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IngredientUsagesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $IngredientUsagesTable,
      IngredientUsageRow,
      $$IngredientUsagesTableFilterComposer,
      $$IngredientUsagesTableOrderingComposer,
      $$IngredientUsagesTableAnnotationComposer,
      $$IngredientUsagesTableCreateCompanionBuilder,
      $$IngredientUsagesTableUpdateCompanionBuilder,
      (
        IngredientUsageRow,
        BaseReferences<
          _$CatalogDatabase,
          $IngredientUsagesTable,
          IngredientUsageRow
        >,
      ),
      IngredientUsageRow,
      PrefetchHooks Function()
    >;
typedef $$CatalogSnapshotTableTableCreateCompanionBuilder =
    CatalogSnapshotTableCompanion Function({
      Value<int> id,
      required String version,
      required DateTime publishedAt,
      required int recipeCount,
      required DateTime appliedAt,
    });
typedef $$CatalogSnapshotTableTableUpdateCompanionBuilder =
    CatalogSnapshotTableCompanion Function({
      Value<int> id,
      Value<String> version,
      Value<DateTime> publishedAt,
      Value<int> recipeCount,
      Value<DateTime> appliedAt,
    });

class $$CatalogSnapshotTableTableFilterComposer
    extends Composer<_$CatalogDatabase, $CatalogSnapshotTableTable> {
  $$CatalogSnapshotTableTableFilterComposer({
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

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recipeCount => $composableBuilder(
    column: $table.recipeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogSnapshotTableTableOrderingComposer
    extends Composer<_$CatalogDatabase, $CatalogSnapshotTableTable> {
  $$CatalogSnapshotTableTableOrderingComposer({
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

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recipeCount => $composableBuilder(
    column: $table.recipeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogSnapshotTableTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $CatalogSnapshotTableTable> {
  $$CatalogSnapshotTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recipeCount => $composableBuilder(
    column: $table.recipeCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get appliedAt =>
      $composableBuilder(column: $table.appliedAt, builder: (column) => column);
}

class $$CatalogSnapshotTableTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $CatalogSnapshotTableTable,
          CatalogSnapshotRow,
          $$CatalogSnapshotTableTableFilterComposer,
          $$CatalogSnapshotTableTableOrderingComposer,
          $$CatalogSnapshotTableTableAnnotationComposer,
          $$CatalogSnapshotTableTableCreateCompanionBuilder,
          $$CatalogSnapshotTableTableUpdateCompanionBuilder,
          (
            CatalogSnapshotRow,
            BaseReferences<
              _$CatalogDatabase,
              $CatalogSnapshotTableTable,
              CatalogSnapshotRow
            >,
          ),
          CatalogSnapshotRow,
          PrefetchHooks Function()
        > {
  $$CatalogSnapshotTableTableTableManager(
    _$CatalogDatabase db,
    $CatalogSnapshotTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogSnapshotTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogSnapshotTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CatalogSnapshotTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<DateTime> publishedAt = const Value.absent(),
                Value<int> recipeCount = const Value.absent(),
                Value<DateTime> appliedAt = const Value.absent(),
              }) => CatalogSnapshotTableCompanion(
                id: id,
                version: version,
                publishedAt: publishedAt,
                recipeCount: recipeCount,
                appliedAt: appliedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String version,
                required DateTime publishedAt,
                required int recipeCount,
                required DateTime appliedAt,
              }) => CatalogSnapshotTableCompanion.insert(
                id: id,
                version: version,
                publishedAt: publishedAt,
                recipeCount: recipeCount,
                appliedAt: appliedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogSnapshotTableTable, CatalogSnapshotRow>(
                    table,
                  ),
                  BaseReferences<
                    _$CatalogDatabase,
                    $CatalogSnapshotTableTable,
                    CatalogSnapshotRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogSnapshotTableTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $CatalogSnapshotTableTable,
      CatalogSnapshotRow,
      $$CatalogSnapshotTableTableFilterComposer,
      $$CatalogSnapshotTableTableOrderingComposer,
      $$CatalogSnapshotTableTableAnnotationComposer,
      $$CatalogSnapshotTableTableCreateCompanionBuilder,
      $$CatalogSnapshotTableTableUpdateCompanionBuilder,
      (
        CatalogSnapshotRow,
        BaseReferences<
          _$CatalogDatabase,
          $CatalogSnapshotTableTable,
          CatalogSnapshotRow
        >,
      ),
      CatalogSnapshotRow,
      PrefetchHooks Function()
    >;

class $CatalogDatabaseManager {
  final _$CatalogDatabase _db;
  $CatalogDatabaseManager(this._db);
  $$RecipesTableTableManager get recipes =>
      $$RecipesTableTableManager(_db, _db.recipes);
  $$IngredientUsagesTableTableManager get ingredientUsages =>
      $$IngredientUsagesTableTableManager(_db, _db.ingredientUsages);
  $$CatalogSnapshotTableTableTableManager get catalogSnapshotTable =>
      $$CatalogSnapshotTableTableTableManager(_db, _db.catalogSnapshotTable);
}
