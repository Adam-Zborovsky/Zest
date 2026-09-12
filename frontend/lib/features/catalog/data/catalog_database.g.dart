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
  static const VerificationMeta _firstLetterMeta = const VerificationMeta(
    'firstLetter',
  );
  @override
  late final GeneratedColumn<String> firstLetter = GeneratedColumn<String>(
    'first_letter',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 1,
    ),
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
    firstLetter,
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
    if (data.containsKey('first_letter')) {
      context.handle(
        _firstLetterMeta,
        firstLetter.isAcceptableOrUnknown(
          data['first_letter']!,
          _firstLetterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstLetterMeta);
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
      firstLetter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_letter'],
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
  final String firstLetter;
  final String sourceJson;
  final DateTime updatedAt;
  const RecipeRow({
    required this.providerId,
    required this.name,
    required this.firstLetter,
    required this.sourceJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['provider_id'] = Variable<String>(providerId);
    map['name'] = Variable<String>(name);
    map['first_letter'] = Variable<String>(firstLetter);
    map['source_json'] = Variable<String>(sourceJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RecipesCompanion toCompanion(bool nullToAbsent) {
    return RecipesCompanion(
      providerId: Value(providerId),
      name: Value(name),
      firstLetter: Value(firstLetter),
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
      firstLetter: serializer.fromJson<String>(json['firstLetter']),
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
      'firstLetter': serializer.toJson<String>(firstLetter),
      'sourceJson': serializer.toJson<String>(sourceJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RecipeRow copyWith({
    String? providerId,
    String? name,
    String? firstLetter,
    String? sourceJson,
    DateTime? updatedAt,
  }) => RecipeRow(
    providerId: providerId ?? this.providerId,
    name: name ?? this.name,
    firstLetter: firstLetter ?? this.firstLetter,
    sourceJson: sourceJson ?? this.sourceJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RecipeRow copyWithCompanion(RecipesCompanion data) {
    return RecipeRow(
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      name: data.name.present ? data.name.value : this.name,
      firstLetter: data.firstLetter.present
          ? data.firstLetter.value
          : this.firstLetter,
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
          ..write('firstLetter: $firstLetter, ')
          ..write('sourceJson: $sourceJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(providerId, name, firstLetter, sourceJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeRow &&
          other.providerId == this.providerId &&
          other.name == this.name &&
          other.firstLetter == this.firstLetter &&
          other.sourceJson == this.sourceJson &&
          other.updatedAt == this.updatedAt);
}

class RecipesCompanion extends UpdateCompanion<RecipeRow> {
  final Value<String> providerId;
  final Value<String> name;
  final Value<String> firstLetter;
  final Value<String> sourceJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RecipesCompanion({
    this.providerId = const Value.absent(),
    this.name = const Value.absent(),
    this.firstLetter = const Value.absent(),
    this.sourceJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipesCompanion.insert({
    required String providerId,
    required String name,
    required String firstLetter,
    required String sourceJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : providerId = Value(providerId),
       name = Value(name),
       firstLetter = Value(firstLetter),
       sourceJson = Value(sourceJson),
       updatedAt = Value(updatedAt);
  static Insertable<RecipeRow> custom({
    Expression<String>? providerId,
    Expression<String>? name,
    Expression<String>? firstLetter,
    Expression<String>? sourceJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (providerId != null) 'provider_id': providerId,
      if (name != null) 'name': name,
      if (firstLetter != null) 'first_letter': firstLetter,
      if (sourceJson != null) 'source_json': sourceJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipesCompanion copyWith({
    Value<String>? providerId,
    Value<String>? name,
    Value<String>? firstLetter,
    Value<String>? sourceJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RecipesCompanion(
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      firstLetter: firstLetter ?? this.firstLetter,
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
    if (firstLetter.present) {
      map['first_letter'] = Variable<String>(firstLetter.value);
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
          ..write('firstLetter: $firstLetter, ')
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

class $LetterSyncTable extends LetterSync
    with TableInfo<$LetterSyncTable, LetterSyncRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LetterSyncTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _letterMeta = const VerificationMeta('letter');
  @override
  late final GeneratedColumn<String> letter = GeneratedColumn<String>(
    'letter',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 1,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [letter, completedAt, recipeCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'letter_sync';
  @override
  VerificationContext validateIntegrity(
    Insertable<LetterSyncRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('letter')) {
      context.handle(
        _letterMeta,
        letter.isAcceptableOrUnknown(data['letter']!, _letterMeta),
      );
    } else if (isInserting) {
      context.missing(_letterMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {letter};
  @override
  LetterSyncRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LetterSyncRow(
      letter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}letter'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      recipeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recipe_count'],
      )!,
    );
  }

  @override
  $LetterSyncTable createAlias(String alias) {
    return $LetterSyncTable(attachedDatabase, alias);
  }
}

class LetterSyncRow extends DataClass implements Insertable<LetterSyncRow> {
  final String letter;
  final DateTime? completedAt;
  final int recipeCount;
  const LetterSyncRow({
    required this.letter,
    this.completedAt,
    required this.recipeCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['letter'] = Variable<String>(letter);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['recipe_count'] = Variable<int>(recipeCount);
    return map;
  }

  LetterSyncCompanion toCompanion(bool nullToAbsent) {
    return LetterSyncCompanion(
      letter: Value(letter),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      recipeCount: Value(recipeCount),
    );
  }

  factory LetterSyncRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LetterSyncRow(
      letter: serializer.fromJson<String>(json['letter']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      recipeCount: serializer.fromJson<int>(json['recipeCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'letter': serializer.toJson<String>(letter),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'recipeCount': serializer.toJson<int>(recipeCount),
    };
  }

  LetterSyncRow copyWith({
    String? letter,
    Value<DateTime?> completedAt = const Value.absent(),
    int? recipeCount,
  }) => LetterSyncRow(
    letter: letter ?? this.letter,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    recipeCount: recipeCount ?? this.recipeCount,
  );
  LetterSyncRow copyWithCompanion(LetterSyncCompanion data) {
    return LetterSyncRow(
      letter: data.letter.present ? data.letter.value : this.letter,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      recipeCount: data.recipeCount.present
          ? data.recipeCount.value
          : this.recipeCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LetterSyncRow(')
          ..write('letter: $letter, ')
          ..write('completedAt: $completedAt, ')
          ..write('recipeCount: $recipeCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(letter, completedAt, recipeCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LetterSyncRow &&
          other.letter == this.letter &&
          other.completedAt == this.completedAt &&
          other.recipeCount == this.recipeCount);
}

class LetterSyncCompanion extends UpdateCompanion<LetterSyncRow> {
  final Value<String> letter;
  final Value<DateTime?> completedAt;
  final Value<int> recipeCount;
  final Value<int> rowid;
  const LetterSyncCompanion({
    this.letter = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.recipeCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LetterSyncCompanion.insert({
    required String letter,
    this.completedAt = const Value.absent(),
    required int recipeCount,
    this.rowid = const Value.absent(),
  }) : letter = Value(letter),
       recipeCount = Value(recipeCount);
  static Insertable<LetterSyncRow> custom({
    Expression<String>? letter,
    Expression<DateTime>? completedAt,
    Expression<int>? recipeCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (letter != null) 'letter': letter,
      if (completedAt != null) 'completed_at': completedAt,
      if (recipeCount != null) 'recipe_count': recipeCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LetterSyncCompanion copyWith({
    Value<String>? letter,
    Value<DateTime?>? completedAt,
    Value<int>? recipeCount,
    Value<int>? rowid,
  }) {
    return LetterSyncCompanion(
      letter: letter ?? this.letter,
      completedAt: completedAt ?? this.completedAt,
      recipeCount: recipeCount ?? this.recipeCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (letter.present) {
      map['letter'] = Variable<String>(letter.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (recipeCount.present) {
      map['recipe_count'] = Variable<int>(recipeCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LetterSyncCompanion(')
          ..write('letter: $letter, ')
          ..write('completedAt: $completedAt, ')
          ..write('recipeCount: $recipeCount, ')
          ..write('rowid: $rowid')
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
  late final $LetterSyncTable letterSync = $LetterSyncTable(this);
  late final Index recipesFirstLetter = Index(
    'recipes_first_letter',
    'CREATE INDEX recipes_first_letter ON recipes (first_letter)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    recipes,
    ingredientUsages,
    letterSync,
    recipesFirstLetter,
  ];
}

typedef $$RecipesTableCreateCompanionBuilder =
    RecipesCompanion Function({
      required String providerId,
      required String name,
      required String firstLetter,
      required String sourceJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$RecipesTableUpdateCompanionBuilder =
    RecipesCompanion Function({
      Value<String> providerId,
      Value<String> name,
      Value<String> firstLetter,
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

  ColumnFilters<String> get firstLetter => $composableBuilder(
    column: $table.firstLetter,
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

  ColumnOrderings<String> get firstLetter => $composableBuilder(
    column: $table.firstLetter,
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

  GeneratedColumn<String> get firstLetter => $composableBuilder(
    column: $table.firstLetter,
    builder: (column) => column,
  );

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
                Value<String> firstLetter = const Value.absent(),
                Value<String> sourceJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipesCompanion(
                providerId: providerId,
                name: name,
                firstLetter: firstLetter,
                sourceJson: sourceJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String providerId,
                required String name,
                required String firstLetter,
                required String sourceJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RecipesCompanion.insert(
                providerId: providerId,
                name: name,
                firstLetter: firstLetter,
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
typedef $$LetterSyncTableCreateCompanionBuilder =
    LetterSyncCompanion Function({
      required String letter,
      Value<DateTime?> completedAt,
      required int recipeCount,
      Value<int> rowid,
    });
typedef $$LetterSyncTableUpdateCompanionBuilder =
    LetterSyncCompanion Function({
      Value<String> letter,
      Value<DateTime?> completedAt,
      Value<int> recipeCount,
      Value<int> rowid,
    });

class $$LetterSyncTableFilterComposer
    extends Composer<_$CatalogDatabase, $LetterSyncTable> {
  $$LetterSyncTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get letter => $composableBuilder(
    column: $table.letter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recipeCount => $composableBuilder(
    column: $table.recipeCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LetterSyncTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LetterSyncTable> {
  $$LetterSyncTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get letter => $composableBuilder(
    column: $table.letter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recipeCount => $composableBuilder(
    column: $table.recipeCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LetterSyncTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LetterSyncTable> {
  $$LetterSyncTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get letter =>
      $composableBuilder(column: $table.letter, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recipeCount => $composableBuilder(
    column: $table.recipeCount,
    builder: (column) => column,
  );
}

class $$LetterSyncTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LetterSyncTable,
          LetterSyncRow,
          $$LetterSyncTableFilterComposer,
          $$LetterSyncTableOrderingComposer,
          $$LetterSyncTableAnnotationComposer,
          $$LetterSyncTableCreateCompanionBuilder,
          $$LetterSyncTableUpdateCompanionBuilder,
          (
            LetterSyncRow,
            BaseReferences<_$CatalogDatabase, $LetterSyncTable, LetterSyncRow>,
          ),
          LetterSyncRow,
          PrefetchHooks Function()
        > {
  $$LetterSyncTableTableManager(_$CatalogDatabase db, $LetterSyncTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LetterSyncTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LetterSyncTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LetterSyncTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> letter = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> recipeCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LetterSyncCompanion(
                letter: letter,
                completedAt: completedAt,
                recipeCount: recipeCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String letter,
                Value<DateTime?> completedAt = const Value.absent(),
                required int recipeCount,
                Value<int> rowid = const Value.absent(),
              }) => LetterSyncCompanion.insert(
                letter: letter,
                completedAt: completedAt,
                recipeCount: recipeCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LetterSyncTable, LetterSyncRow>(table),
                  BaseReferences<
                    _$CatalogDatabase,
                    $LetterSyncTable,
                    LetterSyncRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LetterSyncTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LetterSyncTable,
      LetterSyncRow,
      $$LetterSyncTableFilterComposer,
      $$LetterSyncTableOrderingComposer,
      $$LetterSyncTableAnnotationComposer,
      $$LetterSyncTableCreateCompanionBuilder,
      $$LetterSyncTableUpdateCompanionBuilder,
      (
        LetterSyncRow,
        BaseReferences<_$CatalogDatabase, $LetterSyncTable, LetterSyncRow>,
      ),
      LetterSyncRow,
      PrefetchHooks Function()
    >;

class $CatalogDatabaseManager {
  final _$CatalogDatabase _db;
  $CatalogDatabaseManager(this._db);
  $$RecipesTableTableManager get recipes =>
      $$RecipesTableTableManager(_db, _db.recipes);
  $$IngredientUsagesTableTableManager get ingredientUsages =>
      $$IngredientUsagesTableTableManager(_db, _db.ingredientUsages);
  $$LetterSyncTableTableManager get letterSync =>
      $$LetterSyncTableTableManager(_db, _db.letterSync);
}
