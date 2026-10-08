// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DomainsTable extends Domains with TableInfo<$DomainsTable, Domain> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DomainsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _learnWeightMeta = const VerificationMeta(
    'learnWeight',
  );
  @override
  late final GeneratedColumn<int> learnWeight = GeneratedColumn<int>(
    'learn_weight',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _revisitMeta = const VerificationMeta(
    'revisit',
  );
  @override
  late final GeneratedColumn<bool> revisit = GeneratedColumn<bool>(
    'revisit',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("revisit" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    active,
    createdAt,
    learnWeight,
    revisit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'domain';
  @override
  VerificationContext validateIntegrity(
    Insertable<Domain> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
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
    if (data.containsKey('learn_weight')) {
      context.handle(
        _learnWeightMeta,
        learnWeight.isAcceptableOrUnknown(
          data['learn_weight']!,
          _learnWeightMeta,
        ),
      );
    }
    if (data.containsKey('revisit')) {
      context.handle(
        _revisitMeta,
        revisit.isAcceptableOrUnknown(data['revisit']!, _revisitMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Domain map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Domain(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      learnWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}learn_weight'],
      )!,
      revisit: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}revisit'],
      )!,
    );
  }

  @override
  $DomainsTable createAlias(String alias) {
    return $DomainsTable(attachedDatabase, alias);
  }
}

class Domain extends DataClass implements Insertable<Domain> {
  final int id;
  final String name;
  final bool active;
  final int createdAt;
  final int learnWeight;
  final bool revisit;
  const Domain({
    required this.id,
    required this.name,
    required this.active,
    required this.createdAt,
    required this.learnWeight,
    required this.revisit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<int>(createdAt);
    map['learn_weight'] = Variable<int>(learnWeight);
    map['revisit'] = Variable<bool>(revisit);
    return map;
  }

  DomainsCompanion toCompanion(bool nullToAbsent) {
    return DomainsCompanion(
      id: Value(id),
      name: Value(name),
      active: Value(active),
      createdAt: Value(createdAt),
      learnWeight: Value(learnWeight),
      revisit: Value(revisit),
    );
  }

  factory Domain.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Domain(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      learnWeight: serializer.fromJson<int>(json['learnWeight']),
      revisit: serializer.fromJson<bool>(json['revisit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<int>(createdAt),
      'learnWeight': serializer.toJson<int>(learnWeight),
      'revisit': serializer.toJson<bool>(revisit),
    };
  }

  Domain copyWith({
    int? id,
    String? name,
    bool? active,
    int? createdAt,
    int? learnWeight,
    bool? revisit,
  }) => Domain(
    id: id ?? this.id,
    name: name ?? this.name,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
    learnWeight: learnWeight ?? this.learnWeight,
    revisit: revisit ?? this.revisit,
  );
  Domain copyWithCompanion(DomainsCompanion data) {
    return Domain(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      learnWeight: data.learnWeight.present
          ? data.learnWeight.value
          : this.learnWeight,
      revisit: data.revisit.present ? data.revisit.value : this.revisit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Domain(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('learnWeight: $learnWeight, ')
          ..write('revisit: $revisit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, active, createdAt, learnWeight, revisit);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Domain &&
          other.id == this.id &&
          other.name == this.name &&
          other.active == this.active &&
          other.createdAt == this.createdAt &&
          other.learnWeight == this.learnWeight &&
          other.revisit == this.revisit);
}

class DomainsCompanion extends UpdateCompanion<Domain> {
  final Value<int> id;
  final Value<String> name;
  final Value<bool> active;
  final Value<int> createdAt;
  final Value<int> learnWeight;
  final Value<bool> revisit;
  const DomainsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.learnWeight = const Value.absent(),
    this.revisit = const Value.absent(),
  });
  DomainsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.active = const Value.absent(),
    required int createdAt,
    this.learnWeight = const Value.absent(),
    this.revisit = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Domain> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? active,
    Expression<int>? createdAt,
    Expression<int>? learnWeight,
    Expression<bool>? revisit,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
      if (learnWeight != null) 'learn_weight': learnWeight,
      if (revisit != null) 'revisit': revisit,
    });
  }

  DomainsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<bool>? active,
    Value<int>? createdAt,
    Value<int>? learnWeight,
    Value<bool>? revisit,
  }) {
    return DomainsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      learnWeight: learnWeight ?? this.learnWeight,
      revisit: revisit ?? this.revisit,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (learnWeight.present) {
      map['learn_weight'] = Variable<int>(learnWeight.value);
    }
    if (revisit.present) {
      map['revisit'] = Variable<bool>(revisit.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DomainsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('learnWeight: $learnWeight, ')
          ..write('revisit: $revisit')
          ..write(')'))
        .toString();
  }
}

class $SyllabusItemsTable extends SyllabusItems
    with TableInfo<$SyllabusItemsTable, SyllabusItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyllabusItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _domainIdMeta = const VerificationMeta(
    'domainId',
  );
  @override
  late final GeneratedColumn<int> domainId = GeneratedColumn<int>(
    'domain_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES domain (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('todo'),
  );
  static const VerificationMeta _targetCardsMeta = const VerificationMeta(
    'targetCards',
  );
  @override
  late final GeneratedColumn<int> targetCards = GeneratedColumn<int>(
    'target_cards',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _roundsMeta = const VerificationMeta('rounds');
  @override
  late final GeneratedColumn<int> rounds = GeneratedColumn<int>(
    'rounds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    domainId,
    title,
    level,
    position,
    status,
    targetCards,
    description,
    rounds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'syllabus_item';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyllabusItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('domain_id')) {
      context.handle(
        _domainIdMeta,
        domainId.isAcceptableOrUnknown(data['domain_id']!, _domainIdMeta),
      );
    } else if (isInserting) {
      context.missing(_domainIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('target_cards')) {
      context.handle(
        _targetCardsMeta,
        targetCards.isAcceptableOrUnknown(
          data['target_cards']!,
          _targetCardsMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('rounds')) {
      context.handle(
        _roundsMeta,
        rounds.isAcceptableOrUnknown(data['rounds']!, _roundsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyllabusItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyllabusItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      domainId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}domain_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      targetCards: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_cards'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      rounds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rounds'],
      )!,
    );
  }

  @override
  $SyllabusItemsTable createAlias(String alias) {
    return $SyllabusItemsTable(attachedDatabase, alias);
  }
}

class SyllabusItem extends DataClass implements Insertable<SyllabusItem> {
  final int id;
  final int domainId;
  final String title;
  final int level;
  final int position;
  final String status;
  final int targetCards;
  final String description;
  final int rounds;
  const SyllabusItem({
    required this.id,
    required this.domainId,
    required this.title,
    required this.level,
    required this.position,
    required this.status,
    required this.targetCards,
    required this.description,
    required this.rounds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['domain_id'] = Variable<int>(domainId);
    map['title'] = Variable<String>(title);
    map['level'] = Variable<int>(level);
    map['position'] = Variable<int>(position);
    map['status'] = Variable<String>(status);
    map['target_cards'] = Variable<int>(targetCards);
    map['description'] = Variable<String>(description);
    map['rounds'] = Variable<int>(rounds);
    return map;
  }

  SyllabusItemsCompanion toCompanion(bool nullToAbsent) {
    return SyllabusItemsCompanion(
      id: Value(id),
      domainId: Value(domainId),
      title: Value(title),
      level: Value(level),
      position: Value(position),
      status: Value(status),
      targetCards: Value(targetCards),
      description: Value(description),
      rounds: Value(rounds),
    );
  }

  factory SyllabusItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyllabusItem(
      id: serializer.fromJson<int>(json['id']),
      domainId: serializer.fromJson<int>(json['domainId']),
      title: serializer.fromJson<String>(json['title']),
      level: serializer.fromJson<int>(json['level']),
      position: serializer.fromJson<int>(json['position']),
      status: serializer.fromJson<String>(json['status']),
      targetCards: serializer.fromJson<int>(json['targetCards']),
      description: serializer.fromJson<String>(json['description']),
      rounds: serializer.fromJson<int>(json['rounds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'domainId': serializer.toJson<int>(domainId),
      'title': serializer.toJson<String>(title),
      'level': serializer.toJson<int>(level),
      'position': serializer.toJson<int>(position),
      'status': serializer.toJson<String>(status),
      'targetCards': serializer.toJson<int>(targetCards),
      'description': serializer.toJson<String>(description),
      'rounds': serializer.toJson<int>(rounds),
    };
  }

  SyllabusItem copyWith({
    int? id,
    int? domainId,
    String? title,
    int? level,
    int? position,
    String? status,
    int? targetCards,
    String? description,
    int? rounds,
  }) => SyllabusItem(
    id: id ?? this.id,
    domainId: domainId ?? this.domainId,
    title: title ?? this.title,
    level: level ?? this.level,
    position: position ?? this.position,
    status: status ?? this.status,
    targetCards: targetCards ?? this.targetCards,
    description: description ?? this.description,
    rounds: rounds ?? this.rounds,
  );
  SyllabusItem copyWithCompanion(SyllabusItemsCompanion data) {
    return SyllabusItem(
      id: data.id.present ? data.id.value : this.id,
      domainId: data.domainId.present ? data.domainId.value : this.domainId,
      title: data.title.present ? data.title.value : this.title,
      level: data.level.present ? data.level.value : this.level,
      position: data.position.present ? data.position.value : this.position,
      status: data.status.present ? data.status.value : this.status,
      targetCards: data.targetCards.present
          ? data.targetCards.value
          : this.targetCards,
      description: data.description.present
          ? data.description.value
          : this.description,
      rounds: data.rounds.present ? data.rounds.value : this.rounds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyllabusItem(')
          ..write('id: $id, ')
          ..write('domainId: $domainId, ')
          ..write('title: $title, ')
          ..write('level: $level, ')
          ..write('position: $position, ')
          ..write('status: $status, ')
          ..write('targetCards: $targetCards, ')
          ..write('description: $description, ')
          ..write('rounds: $rounds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    domainId,
    title,
    level,
    position,
    status,
    targetCards,
    description,
    rounds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyllabusItem &&
          other.id == this.id &&
          other.domainId == this.domainId &&
          other.title == this.title &&
          other.level == this.level &&
          other.position == this.position &&
          other.status == this.status &&
          other.targetCards == this.targetCards &&
          other.description == this.description &&
          other.rounds == this.rounds);
}

class SyllabusItemsCompanion extends UpdateCompanion<SyllabusItem> {
  final Value<int> id;
  final Value<int> domainId;
  final Value<String> title;
  final Value<int> level;
  final Value<int> position;
  final Value<String> status;
  final Value<int> targetCards;
  final Value<String> description;
  final Value<int> rounds;
  const SyllabusItemsCompanion({
    this.id = const Value.absent(),
    this.domainId = const Value.absent(),
    this.title = const Value.absent(),
    this.level = const Value.absent(),
    this.position = const Value.absent(),
    this.status = const Value.absent(),
    this.targetCards = const Value.absent(),
    this.description = const Value.absent(),
    this.rounds = const Value.absent(),
  });
  SyllabusItemsCompanion.insert({
    this.id = const Value.absent(),
    required int domainId,
    required String title,
    this.level = const Value.absent(),
    this.position = const Value.absent(),
    this.status = const Value.absent(),
    this.targetCards = const Value.absent(),
    this.description = const Value.absent(),
    this.rounds = const Value.absent(),
  }) : domainId = Value(domainId),
       title = Value(title);
  static Insertable<SyllabusItem> custom({
    Expression<int>? id,
    Expression<int>? domainId,
    Expression<String>? title,
    Expression<int>? level,
    Expression<int>? position,
    Expression<String>? status,
    Expression<int>? targetCards,
    Expression<String>? description,
    Expression<int>? rounds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (domainId != null) 'domain_id': domainId,
      if (title != null) 'title': title,
      if (level != null) 'level': level,
      if (position != null) 'position': position,
      if (status != null) 'status': status,
      if (targetCards != null) 'target_cards': targetCards,
      if (description != null) 'description': description,
      if (rounds != null) 'rounds': rounds,
    });
  }

  SyllabusItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? domainId,
    Value<String>? title,
    Value<int>? level,
    Value<int>? position,
    Value<String>? status,
    Value<int>? targetCards,
    Value<String>? description,
    Value<int>? rounds,
  }) {
    return SyllabusItemsCompanion(
      id: id ?? this.id,
      domainId: domainId ?? this.domainId,
      title: title ?? this.title,
      level: level ?? this.level,
      position: position ?? this.position,
      status: status ?? this.status,
      targetCards: targetCards ?? this.targetCards,
      description: description ?? this.description,
      rounds: rounds ?? this.rounds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (domainId.present) {
      map['domain_id'] = Variable<int>(domainId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (targetCards.present) {
      map['target_cards'] = Variable<int>(targetCards.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rounds.present) {
      map['rounds'] = Variable<int>(rounds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyllabusItemsCompanion(')
          ..write('id: $id, ')
          ..write('domainId: $domainId, ')
          ..write('title: $title, ')
          ..write('level: $level, ')
          ..write('position: $position, ')
          ..write('status: $status, ')
          ..write('targetCards: $targetCards, ')
          ..write('description: $description, ')
          ..write('rounds: $rounds')
          ..write(')'))
        .toString();
  }
}

class $SyllabusPrereqsTable extends SyllabusPrereqs
    with TableInfo<$SyllabusPrereqsTable, SyllabusPrereq> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyllabusPrereqsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES syllabus_item (id)',
    ),
  );
  static const VerificationMeta _prereqIdMeta = const VerificationMeta(
    'prereqId',
  );
  @override
  late final GeneratedColumn<int> prereqId = GeneratedColumn<int>(
    'prereq_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES syllabus_item (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, prereqId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'syllabus_prereq';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyllabusPrereq> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('prereq_id')) {
      context.handle(
        _prereqIdMeta,
        prereqId.isAcceptableOrUnknown(data['prereq_id']!, _prereqIdMeta),
      );
    } else if (isInserting) {
      context.missing(_prereqIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId, prereqId};
  @override
  SyllabusPrereq map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyllabusPrereq(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      )!,
      prereqId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prereq_id'],
      )!,
    );
  }

  @override
  $SyllabusPrereqsTable createAlias(String alias) {
    return $SyllabusPrereqsTable(attachedDatabase, alias);
  }
}

class SyllabusPrereq extends DataClass implements Insertable<SyllabusPrereq> {
  final int itemId;
  final int prereqId;
  const SyllabusPrereq({required this.itemId, required this.prereqId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<int>(itemId);
    map['prereq_id'] = Variable<int>(prereqId);
    return map;
  }

  SyllabusPrereqsCompanion toCompanion(bool nullToAbsent) {
    return SyllabusPrereqsCompanion(
      itemId: Value(itemId),
      prereqId: Value(prereqId),
    );
  }

  factory SyllabusPrereq.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyllabusPrereq(
      itemId: serializer.fromJson<int>(json['itemId']),
      prereqId: serializer.fromJson<int>(json['prereqId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<int>(itemId),
      'prereqId': serializer.toJson<int>(prereqId),
    };
  }

  SyllabusPrereq copyWith({int? itemId, int? prereqId}) => SyllabusPrereq(
    itemId: itemId ?? this.itemId,
    prereqId: prereqId ?? this.prereqId,
  );
  SyllabusPrereq copyWithCompanion(SyllabusPrereqsCompanion data) {
    return SyllabusPrereq(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      prereqId: data.prereqId.present ? data.prereqId.value : this.prereqId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyllabusPrereq(')
          ..write('itemId: $itemId, ')
          ..write('prereqId: $prereqId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, prereqId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyllabusPrereq &&
          other.itemId == this.itemId &&
          other.prereqId == this.prereqId);
}

class SyllabusPrereqsCompanion extends UpdateCompanion<SyllabusPrereq> {
  final Value<int> itemId;
  final Value<int> prereqId;
  final Value<int> rowid;
  const SyllabusPrereqsCompanion({
    this.itemId = const Value.absent(),
    this.prereqId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyllabusPrereqsCompanion.insert({
    required int itemId,
    required int prereqId,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       prereqId = Value(prereqId);
  static Insertable<SyllabusPrereq> custom({
    Expression<int>? itemId,
    Expression<int>? prereqId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (prereqId != null) 'prereq_id': prereqId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyllabusPrereqsCompanion copyWith({
    Value<int>? itemId,
    Value<int>? prereqId,
    Value<int>? rowid,
  }) {
    return SyllabusPrereqsCompanion(
      itemId: itemId ?? this.itemId,
      prereqId: prereqId ?? this.prereqId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (prereqId.present) {
      map['prereq_id'] = Variable<int>(prereqId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyllabusPrereqsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('prereqId: $prereqId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _guidMeta = const VerificationMeta('guid');
  @override
  late final GeneratedColumn<String> guid = GeneratedColumn<String>(
    'guid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _domainIdMeta = const VerificationMeta(
    'domainId',
  );
  @override
  late final GeneratedColumn<int> domainId = GeneratedColumn<int>(
    'domain_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES domain (id)',
    ),
  );
  static const VerificationMeta _syllabusItemIdMeta = const VerificationMeta(
    'syllabusItemId',
  );
  @override
  late final GeneratedColumn<int> syllabusItemId = GeneratedColumn<int>(
    'syllabus_item_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES syllabus_item (id)',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldsJsonMeta = const VerificationMeta(
    'fieldsJson',
  );
  @override
  late final GeneratedColumn<String> fieldsJson = GeneratedColumn<String>(
    'fields_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceRefMeta = const VerificationMeta(
    'sourceRef',
  );
  @override
  late final GeneratedColumn<String> sourceRef = GeneratedColumn<String>(
    'source_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _llmConfidenceMeta = const VerificationMeta(
    'llmConfidence',
  );
  @override
  late final GeneratedColumn<String> llmConfidence = GeneratedColumn<String>(
    'llm_confidence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    guid,
    domainId,
    syllabusItemId,
    type,
    fieldsJson,
    tags,
    sourceType,
    sourceRef,
    llmConfidence,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('guid')) {
      context.handle(
        _guidMeta,
        guid.isAcceptableOrUnknown(data['guid']!, _guidMeta),
      );
    } else if (isInserting) {
      context.missing(_guidMeta);
    }
    if (data.containsKey('domain_id')) {
      context.handle(
        _domainIdMeta,
        domainId.isAcceptableOrUnknown(data['domain_id']!, _domainIdMeta),
      );
    } else if (isInserting) {
      context.missing(_domainIdMeta);
    }
    if (data.containsKey('syllabus_item_id')) {
      context.handle(
        _syllabusItemIdMeta,
        syllabusItemId.isAcceptableOrUnknown(
          data['syllabus_item_id']!,
          _syllabusItemIdMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('fields_json')) {
      context.handle(
        _fieldsJsonMeta,
        fieldsJson.isAcceptableOrUnknown(data['fields_json']!, _fieldsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldsJsonMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('source_ref')) {
      context.handle(
        _sourceRefMeta,
        sourceRef.isAcceptableOrUnknown(data['source_ref']!, _sourceRefMeta),
      );
    }
    if (data.containsKey('llm_confidence')) {
      context.handle(
        _llmConfidenceMeta,
        llmConfidence.isAcceptableOrUnknown(
          data['llm_confidence']!,
          _llmConfidenceMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      guid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guid'],
      )!,
      domainId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}domain_id'],
      )!,
      syllabusItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}syllabus_item_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      fieldsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fields_json'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      ),
      sourceRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_ref'],
      ),
      llmConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}llm_confidence'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final int id;
  final String guid;
  final int domainId;
  final int? syllabusItemId;
  final String type;
  final String fieldsJson;
  final String tags;
  final String? sourceType;
  final String? sourceRef;
  final String? llmConfidence;
  final int createdAt;
  const Note({
    required this.id,
    required this.guid,
    required this.domainId,
    this.syllabusItemId,
    required this.type,
    required this.fieldsJson,
    required this.tags,
    this.sourceType,
    this.sourceRef,
    this.llmConfidence,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['guid'] = Variable<String>(guid);
    map['domain_id'] = Variable<int>(domainId);
    if (!nullToAbsent || syllabusItemId != null) {
      map['syllabus_item_id'] = Variable<int>(syllabusItemId);
    }
    map['type'] = Variable<String>(type);
    map['fields_json'] = Variable<String>(fieldsJson);
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || sourceType != null) {
      map['source_type'] = Variable<String>(sourceType);
    }
    if (!nullToAbsent || sourceRef != null) {
      map['source_ref'] = Variable<String>(sourceRef);
    }
    if (!nullToAbsent || llmConfidence != null) {
      map['llm_confidence'] = Variable<String>(llmConfidence);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      guid: Value(guid),
      domainId: Value(domainId),
      syllabusItemId: syllabusItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(syllabusItemId),
      type: Value(type),
      fieldsJson: Value(fieldsJson),
      tags: Value(tags),
      sourceType: sourceType == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceType),
      sourceRef: sourceRef == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRef),
      llmConfidence: llmConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(llmConfidence),
      createdAt: Value(createdAt),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<int>(json['id']),
      guid: serializer.fromJson<String>(json['guid']),
      domainId: serializer.fromJson<int>(json['domainId']),
      syllabusItemId: serializer.fromJson<int?>(json['syllabusItemId']),
      type: serializer.fromJson<String>(json['type']),
      fieldsJson: serializer.fromJson<String>(json['fieldsJson']),
      tags: serializer.fromJson<String>(json['tags']),
      sourceType: serializer.fromJson<String?>(json['sourceType']),
      sourceRef: serializer.fromJson<String?>(json['sourceRef']),
      llmConfidence: serializer.fromJson<String?>(json['llmConfidence']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'guid': serializer.toJson<String>(guid),
      'domainId': serializer.toJson<int>(domainId),
      'syllabusItemId': serializer.toJson<int?>(syllabusItemId),
      'type': serializer.toJson<String>(type),
      'fieldsJson': serializer.toJson<String>(fieldsJson),
      'tags': serializer.toJson<String>(tags),
      'sourceType': serializer.toJson<String?>(sourceType),
      'sourceRef': serializer.toJson<String?>(sourceRef),
      'llmConfidence': serializer.toJson<String?>(llmConfidence),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Note copyWith({
    int? id,
    String? guid,
    int? domainId,
    Value<int?> syllabusItemId = const Value.absent(),
    String? type,
    String? fieldsJson,
    String? tags,
    Value<String?> sourceType = const Value.absent(),
    Value<String?> sourceRef = const Value.absent(),
    Value<String?> llmConfidence = const Value.absent(),
    int? createdAt,
  }) => Note(
    id: id ?? this.id,
    guid: guid ?? this.guid,
    domainId: domainId ?? this.domainId,
    syllabusItemId: syllabusItemId.present
        ? syllabusItemId.value
        : this.syllabusItemId,
    type: type ?? this.type,
    fieldsJson: fieldsJson ?? this.fieldsJson,
    tags: tags ?? this.tags,
    sourceType: sourceType.present ? sourceType.value : this.sourceType,
    sourceRef: sourceRef.present ? sourceRef.value : this.sourceRef,
    llmConfidence: llmConfidence.present
        ? llmConfidence.value
        : this.llmConfidence,
    createdAt: createdAt ?? this.createdAt,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      guid: data.guid.present ? data.guid.value : this.guid,
      domainId: data.domainId.present ? data.domainId.value : this.domainId,
      syllabusItemId: data.syllabusItemId.present
          ? data.syllabusItemId.value
          : this.syllabusItemId,
      type: data.type.present ? data.type.value : this.type,
      fieldsJson: data.fieldsJson.present
          ? data.fieldsJson.value
          : this.fieldsJson,
      tags: data.tags.present ? data.tags.value : this.tags,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceRef: data.sourceRef.present ? data.sourceRef.value : this.sourceRef,
      llmConfidence: data.llmConfidence.present
          ? data.llmConfidence.value
          : this.llmConfidence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('guid: $guid, ')
          ..write('domainId: $domainId, ')
          ..write('syllabusItemId: $syllabusItemId, ')
          ..write('type: $type, ')
          ..write('fieldsJson: $fieldsJson, ')
          ..write('tags: $tags, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('llmConfidence: $llmConfidence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    guid,
    domainId,
    syllabusItemId,
    type,
    fieldsJson,
    tags,
    sourceType,
    sourceRef,
    llmConfidence,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.guid == this.guid &&
          other.domainId == this.domainId &&
          other.syllabusItemId == this.syllabusItemId &&
          other.type == this.type &&
          other.fieldsJson == this.fieldsJson &&
          other.tags == this.tags &&
          other.sourceType == this.sourceType &&
          other.sourceRef == this.sourceRef &&
          other.llmConfidence == this.llmConfidence &&
          other.createdAt == this.createdAt);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<int> id;
  final Value<String> guid;
  final Value<int> domainId;
  final Value<int?> syllabusItemId;
  final Value<String> type;
  final Value<String> fieldsJson;
  final Value<String> tags;
  final Value<String?> sourceType;
  final Value<String?> sourceRef;
  final Value<String?> llmConfidence;
  final Value<int> createdAt;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.guid = const Value.absent(),
    this.domainId = const Value.absent(),
    this.syllabusItemId = const Value.absent(),
    this.type = const Value.absent(),
    this.fieldsJson = const Value.absent(),
    this.tags = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.llmConfidence = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    required String guid,
    required int domainId,
    this.syllabusItemId = const Value.absent(),
    required String type,
    required String fieldsJson,
    this.tags = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.llmConfidence = const Value.absent(),
    required int createdAt,
  }) : guid = Value(guid),
       domainId = Value(domainId),
       type = Value(type),
       fieldsJson = Value(fieldsJson),
       createdAt = Value(createdAt);
  static Insertable<Note> custom({
    Expression<int>? id,
    Expression<String>? guid,
    Expression<int>? domainId,
    Expression<int>? syllabusItemId,
    Expression<String>? type,
    Expression<String>? fieldsJson,
    Expression<String>? tags,
    Expression<String>? sourceType,
    Expression<String>? sourceRef,
    Expression<String>? llmConfidence,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (guid != null) 'guid': guid,
      if (domainId != null) 'domain_id': domainId,
      if (syllabusItemId != null) 'syllabus_item_id': syllabusItemId,
      if (type != null) 'type': type,
      if (fieldsJson != null) 'fields_json': fieldsJson,
      if (tags != null) 'tags': tags,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceRef != null) 'source_ref': sourceRef,
      if (llmConfidence != null) 'llm_confidence': llmConfidence,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  NotesCompanion copyWith({
    Value<int>? id,
    Value<String>? guid,
    Value<int>? domainId,
    Value<int?>? syllabusItemId,
    Value<String>? type,
    Value<String>? fieldsJson,
    Value<String>? tags,
    Value<String?>? sourceType,
    Value<String?>? sourceRef,
    Value<String?>? llmConfidence,
    Value<int>? createdAt,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      guid: guid ?? this.guid,
      domainId: domainId ?? this.domainId,
      syllabusItemId: syllabusItemId ?? this.syllabusItemId,
      type: type ?? this.type,
      fieldsJson: fieldsJson ?? this.fieldsJson,
      tags: tags ?? this.tags,
      sourceType: sourceType ?? this.sourceType,
      sourceRef: sourceRef ?? this.sourceRef,
      llmConfidence: llmConfidence ?? this.llmConfidence,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (guid.present) {
      map['guid'] = Variable<String>(guid.value);
    }
    if (domainId.present) {
      map['domain_id'] = Variable<int>(domainId.value);
    }
    if (syllabusItemId.present) {
      map['syllabus_item_id'] = Variable<int>(syllabusItemId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (fieldsJson.present) {
      map['fields_json'] = Variable<String>(fieldsJson.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceRef.present) {
      map['source_ref'] = Variable<String>(sourceRef.value);
    }
    if (llmConfidence.present) {
      map['llm_confidence'] = Variable<String>(llmConfidence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('guid: $guid, ')
          ..write('domainId: $domainId, ')
          ..write('syllabusItemId: $syllabusItemId, ')
          ..write('type: $type, ')
          ..write('fieldsJson: $fieldsJson, ')
          ..write('tags: $tags, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('llmConfidence: $llmConfidence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CardsTable extends Cards with TableInfo<$CardsTable, Card> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<int> noteId = GeneratedColumn<int>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES note (id)',
    ),
  );
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
    'ord',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('new'),
  );
  static const VerificationMeta _stepMeta = const VerificationMeta('step');
  @override
  late final GeneratedColumn<int> step = GeneratedColumn<int>(
    'step',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dueMeta = const VerificationMeta('due');
  @override
  late final GeneratedColumn<int> due = GeneratedColumn<int>(
    'due',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stabilityMeta = const VerificationMeta(
    'stability',
  );
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
    'stability',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
    'difficulty',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReviewMeta = const VerificationMeta(
    'lastReview',
  );
  @override
  late final GeneratedColumn<int> lastReview = GeneratedColumn<int>(
    'last_review',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suspendedMeta = const VerificationMeta(
    'suspended',
  );
  @override
  late final GeneratedColumn<bool> suspended = GeneratedColumn<bool>(
    'suspended',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("suspended" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _buriedUntilMeta = const VerificationMeta(
    'buriedUntil',
  );
  @override
  late final GeneratedColumn<int> buriedUntil = GeneratedColumn<int>(
    'buried_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    ord,
    state,
    step,
    due,
    stability,
    difficulty,
    reps,
    lapses,
    lastReview,
    suspended,
    buriedUntil,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card';
  @override
  VerificationContext validateIntegrity(
    Insertable<Card> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('ord')) {
      context.handle(
        _ordMeta,
        ord.isAcceptableOrUnknown(data['ord']!, _ordMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('step')) {
      context.handle(
        _stepMeta,
        step.isAcceptableOrUnknown(data['step']!, _stepMeta),
      );
    }
    if (data.containsKey('due')) {
      context.handle(
        _dueMeta,
        due.isAcceptableOrUnknown(data['due']!, _dueMeta),
      );
    } else if (isInserting) {
      context.missing(_dueMeta);
    }
    if (data.containsKey('stability')) {
      context.handle(
        _stabilityMeta,
        stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    if (data.containsKey('last_review')) {
      context.handle(
        _lastReviewMeta,
        lastReview.isAcceptableOrUnknown(data['last_review']!, _lastReviewMeta),
      );
    }
    if (data.containsKey('suspended')) {
      context.handle(
        _suspendedMeta,
        suspended.isAcceptableOrUnknown(data['suspended']!, _suspendedMeta),
      );
    }
    if (data.containsKey('buried_until')) {
      context.handle(
        _buriedUntilMeta,
        buriedUntil.isAcceptableOrUnknown(
          data['buried_until']!,
          _buriedUntilMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Card map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Card(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}note_id'],
      )!,
      ord: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ord'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      step: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}step'],
      )!,
      due: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due'],
      )!,
      stability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability'],
      ),
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty'],
      ),
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
      lastReview: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_review'],
      ),
      suspended: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}suspended'],
      )!,
      buriedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}buried_until'],
      ),
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class Card extends DataClass implements Insertable<Card> {
  final int id;
  final int noteId;
  final int ord;
  final String state;
  final int step;
  final int due;
  final double? stability;
  final double? difficulty;
  final int reps;
  final int lapses;
  final int? lastReview;
  final bool suspended;
  final int? buriedUntil;
  const Card({
    required this.id,
    required this.noteId,
    required this.ord,
    required this.state,
    required this.step,
    required this.due,
    this.stability,
    this.difficulty,
    required this.reps,
    required this.lapses,
    this.lastReview,
    required this.suspended,
    this.buriedUntil,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['note_id'] = Variable<int>(noteId);
    map['ord'] = Variable<int>(ord);
    map['state'] = Variable<String>(state);
    map['step'] = Variable<int>(step);
    map['due'] = Variable<int>(due);
    if (!nullToAbsent || stability != null) {
      map['stability'] = Variable<double>(stability);
    }
    if (!nullToAbsent || difficulty != null) {
      map['difficulty'] = Variable<double>(difficulty);
    }
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    if (!nullToAbsent || lastReview != null) {
      map['last_review'] = Variable<int>(lastReview);
    }
    map['suspended'] = Variable<bool>(suspended);
    if (!nullToAbsent || buriedUntil != null) {
      map['buried_until'] = Variable<int>(buriedUntil);
    }
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      noteId: Value(noteId),
      ord: Value(ord),
      state: Value(state),
      step: Value(step),
      due: Value(due),
      stability: stability == null && nullToAbsent
          ? const Value.absent()
          : Value(stability),
      difficulty: difficulty == null && nullToAbsent
          ? const Value.absent()
          : Value(difficulty),
      reps: Value(reps),
      lapses: Value(lapses),
      lastReview: lastReview == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReview),
      suspended: Value(suspended),
      buriedUntil: buriedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(buriedUntil),
    );
  }

  factory Card.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Card(
      id: serializer.fromJson<int>(json['id']),
      noteId: serializer.fromJson<int>(json['noteId']),
      ord: serializer.fromJson<int>(json['ord']),
      state: serializer.fromJson<String>(json['state']),
      step: serializer.fromJson<int>(json['step']),
      due: serializer.fromJson<int>(json['due']),
      stability: serializer.fromJson<double?>(json['stability']),
      difficulty: serializer.fromJson<double?>(json['difficulty']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
      lastReview: serializer.fromJson<int?>(json['lastReview']),
      suspended: serializer.fromJson<bool>(json['suspended']),
      buriedUntil: serializer.fromJson<int?>(json['buriedUntil']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'noteId': serializer.toJson<int>(noteId),
      'ord': serializer.toJson<int>(ord),
      'state': serializer.toJson<String>(state),
      'step': serializer.toJson<int>(step),
      'due': serializer.toJson<int>(due),
      'stability': serializer.toJson<double?>(stability),
      'difficulty': serializer.toJson<double?>(difficulty),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
      'lastReview': serializer.toJson<int?>(lastReview),
      'suspended': serializer.toJson<bool>(suspended),
      'buriedUntil': serializer.toJson<int?>(buriedUntil),
    };
  }

  Card copyWith({
    int? id,
    int? noteId,
    int? ord,
    String? state,
    int? step,
    int? due,
    Value<double?> stability = const Value.absent(),
    Value<double?> difficulty = const Value.absent(),
    int? reps,
    int? lapses,
    Value<int?> lastReview = const Value.absent(),
    bool? suspended,
    Value<int?> buriedUntil = const Value.absent(),
  }) => Card(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    ord: ord ?? this.ord,
    state: state ?? this.state,
    step: step ?? this.step,
    due: due ?? this.due,
    stability: stability.present ? stability.value : this.stability,
    difficulty: difficulty.present ? difficulty.value : this.difficulty,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    lastReview: lastReview.present ? lastReview.value : this.lastReview,
    suspended: suspended ?? this.suspended,
    buriedUntil: buriedUntil.present ? buriedUntil.value : this.buriedUntil,
  );
  Card copyWithCompanion(CardsCompanion data) {
    return Card(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      ord: data.ord.present ? data.ord.value : this.ord,
      state: data.state.present ? data.state.value : this.state,
      step: data.step.present ? data.step.value : this.step,
      due: data.due.present ? data.due.value : this.due,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      lastReview: data.lastReview.present
          ? data.lastReview.value
          : this.lastReview,
      suspended: data.suspended.present ? data.suspended.value : this.suspended,
      buriedUntil: data.buriedUntil.present
          ? data.buriedUntil.value
          : this.buriedUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Card(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('ord: $ord, ')
          ..write('state: $state, ')
          ..write('step: $step, ')
          ..write('due: $due, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastReview: $lastReview, ')
          ..write('suspended: $suspended, ')
          ..write('buriedUntil: $buriedUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    noteId,
    ord,
    state,
    step,
    due,
    stability,
    difficulty,
    reps,
    lapses,
    lastReview,
    suspended,
    buriedUntil,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Card &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.ord == this.ord &&
          other.state == this.state &&
          other.step == this.step &&
          other.due == this.due &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty &&
          other.reps == this.reps &&
          other.lapses == this.lapses &&
          other.lastReview == this.lastReview &&
          other.suspended == this.suspended &&
          other.buriedUntil == this.buriedUntil);
}

class CardsCompanion extends UpdateCompanion<Card> {
  final Value<int> id;
  final Value<int> noteId;
  final Value<int> ord;
  final Value<String> state;
  final Value<int> step;
  final Value<int> due;
  final Value<double?> stability;
  final Value<double?> difficulty;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<int?> lastReview;
  final Value<bool> suspended;
  final Value<int?> buriedUntil;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.ord = const Value.absent(),
    this.state = const Value.absent(),
    this.step = const Value.absent(),
    this.due = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.suspended = const Value.absent(),
    this.buriedUntil = const Value.absent(),
  });
  CardsCompanion.insert({
    this.id = const Value.absent(),
    required int noteId,
    this.ord = const Value.absent(),
    this.state = const Value.absent(),
    this.step = const Value.absent(),
    required int due,
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.suspended = const Value.absent(),
    this.buriedUntil = const Value.absent(),
  }) : noteId = Value(noteId),
       due = Value(due);
  static Insertable<Card> custom({
    Expression<int>? id,
    Expression<int>? noteId,
    Expression<int>? ord,
    Expression<String>? state,
    Expression<int>? step,
    Expression<int>? due,
    Expression<double>? stability,
    Expression<double>? difficulty,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<int>? lastReview,
    Expression<bool>? suspended,
    Expression<int>? buriedUntil,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (ord != null) 'ord': ord,
      if (state != null) 'state': state,
      if (step != null) 'step': step,
      if (due != null) 'due': due,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (lastReview != null) 'last_review': lastReview,
      if (suspended != null) 'suspended': suspended,
      if (buriedUntil != null) 'buried_until': buriedUntil,
    });
  }

  CardsCompanion copyWith({
    Value<int>? id,
    Value<int>? noteId,
    Value<int>? ord,
    Value<String>? state,
    Value<int>? step,
    Value<int>? due,
    Value<double?>? stability,
    Value<double?>? difficulty,
    Value<int>? reps,
    Value<int>? lapses,
    Value<int?>? lastReview,
    Value<bool>? suspended,
    Value<int?>? buriedUntil,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      ord: ord ?? this.ord,
      state: state ?? this.state,
      step: step ?? this.step,
      due: due ?? this.due,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastReview: lastReview ?? this.lastReview,
      suspended: suspended ?? this.suspended,
      buriedUntil: buriedUntil ?? this.buriedUntil,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<int>(noteId.value);
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (step.present) {
      map['step'] = Variable<int>(step.value);
    }
    if (due.present) {
      map['due'] = Variable<int>(due.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (lastReview.present) {
      map['last_review'] = Variable<int>(lastReview.value);
    }
    if (suspended.present) {
      map['suspended'] = Variable<bool>(suspended.value);
    }
    if (buriedUntil.present) {
      map['buried_until'] = Variable<int>(buriedUntil.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('ord: $ord, ')
          ..write('state: $state, ')
          ..write('step: $step, ')
          ..write('due: $due, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastReview: $lastReview, ')
          ..write('suspended: $suspended, ')
          ..write('buriedUntil: $buriedUntil')
          ..write(')'))
        .toString();
  }
}

class $FsrsParamsTableTable extends FsrsParamsTable
    with TableInfo<$FsrsParamsTableTable, FsrsParamsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FsrsParamsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _paramsJsonMeta = const VerificationMeta(
    'paramsJson',
  );
  @override
  late final GeneratedColumn<String> paramsJson = GeneratedColumn<String>(
    'params_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _desiredRetentionMeta = const VerificationMeta(
    'desiredRetention',
  );
  @override
  late final GeneratedColumn<double> desiredRetention = GeneratedColumn<double>(
    'desired_retention',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    version,
    paramsJson,
    desiredRetention,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fsrs_params';
  @override
  VerificationContext validateIntegrity(
    Insertable<FsrsParamsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('params_json')) {
      context.handle(
        _paramsJsonMeta,
        paramsJson.isAcceptableOrUnknown(data['params_json']!, _paramsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_paramsJsonMeta);
    }
    if (data.containsKey('desired_retention')) {
      context.handle(
        _desiredRetentionMeta,
        desiredRetention.isAcceptableOrUnknown(
          data['desired_retention']!,
          _desiredRetentionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_desiredRetentionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FsrsParamsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FsrsParamsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      paramsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}params_json'],
      )!,
      desiredRetention: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}desired_retention'],
      )!,
    );
  }

  @override
  $FsrsParamsTableTable createAlias(String alias) {
    return $FsrsParamsTableTable(attachedDatabase, alias);
  }
}

class FsrsParamsTableData extends DataClass
    implements Insertable<FsrsParamsTableData> {
  final int id;
  final int createdAt;
  final String version;
  final String paramsJson;
  final double desiredRetention;
  const FsrsParamsTableData({
    required this.id,
    required this.createdAt,
    required this.version,
    required this.paramsJson,
    required this.desiredRetention,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['version'] = Variable<String>(version);
    map['params_json'] = Variable<String>(paramsJson);
    map['desired_retention'] = Variable<double>(desiredRetention);
    return map;
  }

  FsrsParamsTableCompanion toCompanion(bool nullToAbsent) {
    return FsrsParamsTableCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      version: Value(version),
      paramsJson: Value(paramsJson),
      desiredRetention: Value(desiredRetention),
    );
  }

  factory FsrsParamsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FsrsParamsTableData(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      version: serializer.fromJson<String>(json['version']),
      paramsJson: serializer.fromJson<String>(json['paramsJson']),
      desiredRetention: serializer.fromJson<double>(json['desiredRetention']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'version': serializer.toJson<String>(version),
      'paramsJson': serializer.toJson<String>(paramsJson),
      'desiredRetention': serializer.toJson<double>(desiredRetention),
    };
  }

  FsrsParamsTableData copyWith({
    int? id,
    int? createdAt,
    String? version,
    String? paramsJson,
    double? desiredRetention,
  }) => FsrsParamsTableData(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    version: version ?? this.version,
    paramsJson: paramsJson ?? this.paramsJson,
    desiredRetention: desiredRetention ?? this.desiredRetention,
  );
  FsrsParamsTableData copyWithCompanion(FsrsParamsTableCompanion data) {
    return FsrsParamsTableData(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      version: data.version.present ? data.version.value : this.version,
      paramsJson: data.paramsJson.present
          ? data.paramsJson.value
          : this.paramsJson,
      desiredRetention: data.desiredRetention.present
          ? data.desiredRetention.value
          : this.desiredRetention,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FsrsParamsTableData(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('version: $version, ')
          ..write('paramsJson: $paramsJson, ')
          ..write('desiredRetention: $desiredRetention')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, version, paramsJson, desiredRetention);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FsrsParamsTableData &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.version == this.version &&
          other.paramsJson == this.paramsJson &&
          other.desiredRetention == this.desiredRetention);
}

class FsrsParamsTableCompanion extends UpdateCompanion<FsrsParamsTableData> {
  final Value<int> id;
  final Value<int> createdAt;
  final Value<String> version;
  final Value<String> paramsJson;
  final Value<double> desiredRetention;
  const FsrsParamsTableCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.version = const Value.absent(),
    this.paramsJson = const Value.absent(),
    this.desiredRetention = const Value.absent(),
  });
  FsrsParamsTableCompanion.insert({
    this.id = const Value.absent(),
    required int createdAt,
    required String version,
    required String paramsJson,
    required double desiredRetention,
  }) : createdAt = Value(createdAt),
       version = Value(version),
       paramsJson = Value(paramsJson),
       desiredRetention = Value(desiredRetention);
  static Insertable<FsrsParamsTableData> custom({
    Expression<int>? id,
    Expression<int>? createdAt,
    Expression<String>? version,
    Expression<String>? paramsJson,
    Expression<double>? desiredRetention,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (version != null) 'version': version,
      if (paramsJson != null) 'params_json': paramsJson,
      if (desiredRetention != null) 'desired_retention': desiredRetention,
    });
  }

  FsrsParamsTableCompanion copyWith({
    Value<int>? id,
    Value<int>? createdAt,
    Value<String>? version,
    Value<String>? paramsJson,
    Value<double>? desiredRetention,
  }) {
    return FsrsParamsTableCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
      paramsJson: paramsJson ?? this.paramsJson,
      desiredRetention: desiredRetention ?? this.desiredRetention,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (paramsJson.present) {
      map['params_json'] = Variable<String>(paramsJson.value);
    }
    if (desiredRetention.present) {
      map['desired_retention'] = Variable<double>(desiredRetention.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FsrsParamsTableCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('version: $version, ')
          ..write('paramsJson: $paramsJson, ')
          ..write('desiredRetention: $desiredRetention')
          ..write(')'))
        .toString();
  }
}

class $ReviewLogsTable extends ReviewLogs
    with TableInfo<$ReviewLogsTable, ReviewLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES card (id)',
    ),
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta(
    'reviewedAt',
  );
  @override
  late final GeneratedColumn<int> reviewedAt = GeneratedColumn<int>(
    'reviewed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stateBeforeMeta = const VerificationMeta(
    'stateBefore',
  );
  @override
  late final GeneratedColumn<String> stateBefore = GeneratedColumn<String>(
    'state_before',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueBeforeMeta = const VerificationMeta(
    'dueBefore',
  );
  @override
  late final GeneratedColumn<int> dueBefore = GeneratedColumn<int>(
    'due_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stabilityBeforeMeta = const VerificationMeta(
    'stabilityBefore',
  );
  @override
  late final GeneratedColumn<double> stabilityBefore = GeneratedColumn<double>(
    'stability_before',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultyBeforeMeta = const VerificationMeta(
    'difficultyBefore',
  );
  @override
  late final GeneratedColumn<double> difficultyBefore = GeneratedColumn<double>(
    'difficulty_before',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elapsedDaysMeta = const VerificationMeta(
    'elapsedDays',
  );
  @override
  late final GeneratedColumn<double> elapsedDays = GeneratedColumn<double>(
    'elapsed_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledDaysMeta = const VerificationMeta(
    'scheduledDays',
  );
  @override
  late final GeneratedColumn<double> scheduledDays = GeneratedColumn<double>(
    'scheduled_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fsrsVersionMeta = const VerificationMeta(
    'fsrsVersion',
  );
  @override
  late final GeneratedColumn<String> fsrsVersion = GeneratedColumn<String>(
    'fsrs_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paramsIdMeta = const VerificationMeta(
    'paramsId',
  );
  @override
  late final GeneratedColumn<int> paramsId = GeneratedColumn<int>(
    'params_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES fsrs_params (id)',
    ),
  );
  static const VerificationMeta _revokedAtMeta = const VerificationMeta(
    'revokedAt',
  );
  @override
  late final GeneratedColumn<int> revokedAt = GeneratedColumn<int>(
    'revoked_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    reviewedAt,
    rating,
    durationMs,
    stateBefore,
    dueBefore,
    stabilityBefore,
    difficultyBefore,
    elapsedDays,
    scheduledDays,
    fsrsVersion,
    paramsId,
    revokedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewedAtMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('state_before')) {
      context.handle(
        _stateBeforeMeta,
        stateBefore.isAcceptableOrUnknown(
          data['state_before']!,
          _stateBeforeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stateBeforeMeta);
    }
    if (data.containsKey('due_before')) {
      context.handle(
        _dueBeforeMeta,
        dueBefore.isAcceptableOrUnknown(data['due_before']!, _dueBeforeMeta),
      );
    } else if (isInserting) {
      context.missing(_dueBeforeMeta);
    }
    if (data.containsKey('stability_before')) {
      context.handle(
        _stabilityBeforeMeta,
        stabilityBefore.isAcceptableOrUnknown(
          data['stability_before']!,
          _stabilityBeforeMeta,
        ),
      );
    }
    if (data.containsKey('difficulty_before')) {
      context.handle(
        _difficultyBeforeMeta,
        difficultyBefore.isAcceptableOrUnknown(
          data['difficulty_before']!,
          _difficultyBeforeMeta,
        ),
      );
    }
    if (data.containsKey('elapsed_days')) {
      context.handle(
        _elapsedDaysMeta,
        elapsedDays.isAcceptableOrUnknown(
          data['elapsed_days']!,
          _elapsedDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_elapsedDaysMeta);
    }
    if (data.containsKey('scheduled_days')) {
      context.handle(
        _scheduledDaysMeta,
        scheduledDays.isAcceptableOrUnknown(
          data['scheduled_days']!,
          _scheduledDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledDaysMeta);
    }
    if (data.containsKey('fsrs_version')) {
      context.handle(
        _fsrsVersionMeta,
        fsrsVersion.isAcceptableOrUnknown(
          data['fsrs_version']!,
          _fsrsVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fsrsVersionMeta);
    }
    if (data.containsKey('params_id')) {
      context.handle(
        _paramsIdMeta,
        paramsId.isAcceptableOrUnknown(data['params_id']!, _paramsIdMeta),
      );
    } else if (isInserting) {
      context.missing(_paramsIdMeta);
    }
    if (data.containsKey('revoked_at')) {
      context.handle(
        _revokedAtMeta,
        revokedAt.isAcceptableOrUnknown(data['revoked_at']!, _revokedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reviewed_at'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      stateBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_before'],
      )!,
      dueBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_before'],
      )!,
      stabilityBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability_before'],
      ),
      difficultyBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty_before'],
      ),
      elapsedDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}elapsed_days'],
      )!,
      scheduledDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}scheduled_days'],
      )!,
      fsrsVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fsrs_version'],
      )!,
      paramsId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}params_id'],
      )!,
      revokedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revoked_at'],
      ),
    );
  }

  @override
  $ReviewLogsTable createAlias(String alias) {
    return $ReviewLogsTable(attachedDatabase, alias);
  }
}

class ReviewLog extends DataClass implements Insertable<ReviewLog> {
  final int id;
  final int cardId;
  final int reviewedAt;
  final int rating;
  final int durationMs;
  final String stateBefore;
  final int dueBefore;
  final double? stabilityBefore;
  final double? difficultyBefore;
  final double elapsedDays;
  final double scheduledDays;
  final String fsrsVersion;
  final int paramsId;
  final int? revokedAt;
  const ReviewLog({
    required this.id,
    required this.cardId,
    required this.reviewedAt,
    required this.rating,
    required this.durationMs,
    required this.stateBefore,
    required this.dueBefore,
    this.stabilityBefore,
    this.difficultyBefore,
    required this.elapsedDays,
    required this.scheduledDays,
    required this.fsrsVersion,
    required this.paramsId,
    this.revokedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['card_id'] = Variable<int>(cardId);
    map['reviewed_at'] = Variable<int>(reviewedAt);
    map['rating'] = Variable<int>(rating);
    map['duration_ms'] = Variable<int>(durationMs);
    map['state_before'] = Variable<String>(stateBefore);
    map['due_before'] = Variable<int>(dueBefore);
    if (!nullToAbsent || stabilityBefore != null) {
      map['stability_before'] = Variable<double>(stabilityBefore);
    }
    if (!nullToAbsent || difficultyBefore != null) {
      map['difficulty_before'] = Variable<double>(difficultyBefore);
    }
    map['elapsed_days'] = Variable<double>(elapsedDays);
    map['scheduled_days'] = Variable<double>(scheduledDays);
    map['fsrs_version'] = Variable<String>(fsrsVersion);
    map['params_id'] = Variable<int>(paramsId);
    if (!nullToAbsent || revokedAt != null) {
      map['revoked_at'] = Variable<int>(revokedAt);
    }
    return map;
  }

  ReviewLogsCompanion toCompanion(bool nullToAbsent) {
    return ReviewLogsCompanion(
      id: Value(id),
      cardId: Value(cardId),
      reviewedAt: Value(reviewedAt),
      rating: Value(rating),
      durationMs: Value(durationMs),
      stateBefore: Value(stateBefore),
      dueBefore: Value(dueBefore),
      stabilityBefore: stabilityBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(stabilityBefore),
      difficultyBefore: difficultyBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(difficultyBefore),
      elapsedDays: Value(elapsedDays),
      scheduledDays: Value(scheduledDays),
      fsrsVersion: Value(fsrsVersion),
      paramsId: Value(paramsId),
      revokedAt: revokedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(revokedAt),
    );
  }

  factory ReviewLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewLog(
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<int>(json['cardId']),
      reviewedAt: serializer.fromJson<int>(json['reviewedAt']),
      rating: serializer.fromJson<int>(json['rating']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      stateBefore: serializer.fromJson<String>(json['stateBefore']),
      dueBefore: serializer.fromJson<int>(json['dueBefore']),
      stabilityBefore: serializer.fromJson<double?>(json['stabilityBefore']),
      difficultyBefore: serializer.fromJson<double?>(json['difficultyBefore']),
      elapsedDays: serializer.fromJson<double>(json['elapsedDays']),
      scheduledDays: serializer.fromJson<double>(json['scheduledDays']),
      fsrsVersion: serializer.fromJson<String>(json['fsrsVersion']),
      paramsId: serializer.fromJson<int>(json['paramsId']),
      revokedAt: serializer.fromJson<int?>(json['revokedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<int>(cardId),
      'reviewedAt': serializer.toJson<int>(reviewedAt),
      'rating': serializer.toJson<int>(rating),
      'durationMs': serializer.toJson<int>(durationMs),
      'stateBefore': serializer.toJson<String>(stateBefore),
      'dueBefore': serializer.toJson<int>(dueBefore),
      'stabilityBefore': serializer.toJson<double?>(stabilityBefore),
      'difficultyBefore': serializer.toJson<double?>(difficultyBefore),
      'elapsedDays': serializer.toJson<double>(elapsedDays),
      'scheduledDays': serializer.toJson<double>(scheduledDays),
      'fsrsVersion': serializer.toJson<String>(fsrsVersion),
      'paramsId': serializer.toJson<int>(paramsId),
      'revokedAt': serializer.toJson<int?>(revokedAt),
    };
  }

  ReviewLog copyWith({
    int? id,
    int? cardId,
    int? reviewedAt,
    int? rating,
    int? durationMs,
    String? stateBefore,
    int? dueBefore,
    Value<double?> stabilityBefore = const Value.absent(),
    Value<double?> difficultyBefore = const Value.absent(),
    double? elapsedDays,
    double? scheduledDays,
    String? fsrsVersion,
    int? paramsId,
    Value<int?> revokedAt = const Value.absent(),
  }) => ReviewLog(
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    rating: rating ?? this.rating,
    durationMs: durationMs ?? this.durationMs,
    stateBefore: stateBefore ?? this.stateBefore,
    dueBefore: dueBefore ?? this.dueBefore,
    stabilityBefore: stabilityBefore.present
        ? stabilityBefore.value
        : this.stabilityBefore,
    difficultyBefore: difficultyBefore.present
        ? difficultyBefore.value
        : this.difficultyBefore,
    elapsedDays: elapsedDays ?? this.elapsedDays,
    scheduledDays: scheduledDays ?? this.scheduledDays,
    fsrsVersion: fsrsVersion ?? this.fsrsVersion,
    paramsId: paramsId ?? this.paramsId,
    revokedAt: revokedAt.present ? revokedAt.value : this.revokedAt,
  );
  ReviewLog copyWithCompanion(ReviewLogsCompanion data) {
    return ReviewLog(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      reviewedAt: data.reviewedAt.present
          ? data.reviewedAt.value
          : this.reviewedAt,
      rating: data.rating.present ? data.rating.value : this.rating,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      stateBefore: data.stateBefore.present
          ? data.stateBefore.value
          : this.stateBefore,
      dueBefore: data.dueBefore.present ? data.dueBefore.value : this.dueBefore,
      stabilityBefore: data.stabilityBefore.present
          ? data.stabilityBefore.value
          : this.stabilityBefore,
      difficultyBefore: data.difficultyBefore.present
          ? data.difficultyBefore.value
          : this.difficultyBefore,
      elapsedDays: data.elapsedDays.present
          ? data.elapsedDays.value
          : this.elapsedDays,
      scheduledDays: data.scheduledDays.present
          ? data.scheduledDays.value
          : this.scheduledDays,
      fsrsVersion: data.fsrsVersion.present
          ? data.fsrsVersion.value
          : this.fsrsVersion,
      paramsId: data.paramsId.present ? data.paramsId.value : this.paramsId,
      revokedAt: data.revokedAt.present ? data.revokedAt.value : this.revokedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLog(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('rating: $rating, ')
          ..write('durationMs: $durationMs, ')
          ..write('stateBefore: $stateBefore, ')
          ..write('dueBefore: $dueBefore, ')
          ..write('stabilityBefore: $stabilityBefore, ')
          ..write('difficultyBefore: $difficultyBefore, ')
          ..write('elapsedDays: $elapsedDays, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('fsrsVersion: $fsrsVersion, ')
          ..write('paramsId: $paramsId, ')
          ..write('revokedAt: $revokedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cardId,
    reviewedAt,
    rating,
    durationMs,
    stateBefore,
    dueBefore,
    stabilityBefore,
    difficultyBefore,
    elapsedDays,
    scheduledDays,
    fsrsVersion,
    paramsId,
    revokedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewLog &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.reviewedAt == this.reviewedAt &&
          other.rating == this.rating &&
          other.durationMs == this.durationMs &&
          other.stateBefore == this.stateBefore &&
          other.dueBefore == this.dueBefore &&
          other.stabilityBefore == this.stabilityBefore &&
          other.difficultyBefore == this.difficultyBefore &&
          other.elapsedDays == this.elapsedDays &&
          other.scheduledDays == this.scheduledDays &&
          other.fsrsVersion == this.fsrsVersion &&
          other.paramsId == this.paramsId &&
          other.revokedAt == this.revokedAt);
}

class ReviewLogsCompanion extends UpdateCompanion<ReviewLog> {
  final Value<int> id;
  final Value<int> cardId;
  final Value<int> reviewedAt;
  final Value<int> rating;
  final Value<int> durationMs;
  final Value<String> stateBefore;
  final Value<int> dueBefore;
  final Value<double?> stabilityBefore;
  final Value<double?> difficultyBefore;
  final Value<double> elapsedDays;
  final Value<double> scheduledDays;
  final Value<String> fsrsVersion;
  final Value<int> paramsId;
  final Value<int?> revokedAt;
  const ReviewLogsCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.rating = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.stateBefore = const Value.absent(),
    this.dueBefore = const Value.absent(),
    this.stabilityBefore = const Value.absent(),
    this.difficultyBefore = const Value.absent(),
    this.elapsedDays = const Value.absent(),
    this.scheduledDays = const Value.absent(),
    this.fsrsVersion = const Value.absent(),
    this.paramsId = const Value.absent(),
    this.revokedAt = const Value.absent(),
  });
  ReviewLogsCompanion.insert({
    this.id = const Value.absent(),
    required int cardId,
    required int reviewedAt,
    required int rating,
    this.durationMs = const Value.absent(),
    required String stateBefore,
    required int dueBefore,
    this.stabilityBefore = const Value.absent(),
    this.difficultyBefore = const Value.absent(),
    required double elapsedDays,
    required double scheduledDays,
    required String fsrsVersion,
    required int paramsId,
    this.revokedAt = const Value.absent(),
  }) : cardId = Value(cardId),
       reviewedAt = Value(reviewedAt),
       rating = Value(rating),
       stateBefore = Value(stateBefore),
       dueBefore = Value(dueBefore),
       elapsedDays = Value(elapsedDays),
       scheduledDays = Value(scheduledDays),
       fsrsVersion = Value(fsrsVersion),
       paramsId = Value(paramsId);
  static Insertable<ReviewLog> custom({
    Expression<int>? id,
    Expression<int>? cardId,
    Expression<int>? reviewedAt,
    Expression<int>? rating,
    Expression<int>? durationMs,
    Expression<String>? stateBefore,
    Expression<int>? dueBefore,
    Expression<double>? stabilityBefore,
    Expression<double>? difficultyBefore,
    Expression<double>? elapsedDays,
    Expression<double>? scheduledDays,
    Expression<String>? fsrsVersion,
    Expression<int>? paramsId,
    Expression<int>? revokedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (rating != null) 'rating': rating,
      if (durationMs != null) 'duration_ms': durationMs,
      if (stateBefore != null) 'state_before': stateBefore,
      if (dueBefore != null) 'due_before': dueBefore,
      if (stabilityBefore != null) 'stability_before': stabilityBefore,
      if (difficultyBefore != null) 'difficulty_before': difficultyBefore,
      if (elapsedDays != null) 'elapsed_days': elapsedDays,
      if (scheduledDays != null) 'scheduled_days': scheduledDays,
      if (fsrsVersion != null) 'fsrs_version': fsrsVersion,
      if (paramsId != null) 'params_id': paramsId,
      if (revokedAt != null) 'revoked_at': revokedAt,
    });
  }

  ReviewLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? cardId,
    Value<int>? reviewedAt,
    Value<int>? rating,
    Value<int>? durationMs,
    Value<String>? stateBefore,
    Value<int>? dueBefore,
    Value<double?>? stabilityBefore,
    Value<double?>? difficultyBefore,
    Value<double>? elapsedDays,
    Value<double>? scheduledDays,
    Value<String>? fsrsVersion,
    Value<int>? paramsId,
    Value<int?>? revokedAt,
  }) {
    return ReviewLogsCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rating: rating ?? this.rating,
      durationMs: durationMs ?? this.durationMs,
      stateBefore: stateBefore ?? this.stateBefore,
      dueBefore: dueBefore ?? this.dueBefore,
      stabilityBefore: stabilityBefore ?? this.stabilityBefore,
      difficultyBefore: difficultyBefore ?? this.difficultyBefore,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      fsrsVersion: fsrsVersion ?? this.fsrsVersion,
      paramsId: paramsId ?? this.paramsId,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<int>(reviewedAt.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (stateBefore.present) {
      map['state_before'] = Variable<String>(stateBefore.value);
    }
    if (dueBefore.present) {
      map['due_before'] = Variable<int>(dueBefore.value);
    }
    if (stabilityBefore.present) {
      map['stability_before'] = Variable<double>(stabilityBefore.value);
    }
    if (difficultyBefore.present) {
      map['difficulty_before'] = Variable<double>(difficultyBefore.value);
    }
    if (elapsedDays.present) {
      map['elapsed_days'] = Variable<double>(elapsedDays.value);
    }
    if (scheduledDays.present) {
      map['scheduled_days'] = Variable<double>(scheduledDays.value);
    }
    if (fsrsVersion.present) {
      map['fsrs_version'] = Variable<String>(fsrsVersion.value);
    }
    if (paramsId.present) {
      map['params_id'] = Variable<int>(paramsId.value);
    }
    if (revokedAt.present) {
      map['revoked_at'] = Variable<int>(revokedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogsCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('rating: $rating, ')
          ..write('durationMs: $durationMs, ')
          ..write('stateBefore: $stateBefore, ')
          ..write('dueBefore: $dueBefore, ')
          ..write('stabilityBefore: $stabilityBefore, ')
          ..write('difficultyBefore: $difficultyBefore, ')
          ..write('elapsedDays: $elapsedDays, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('fsrsVersion: $fsrsVersion, ')
          ..write('paramsId: $paramsId, ')
          ..write('revokedAt: $revokedAt')
          ..write(')'))
        .toString();
  }
}

class $PromptLogsTable extends PromptLogs
    with TableInfo<$PromptLogsTable, PromptLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PromptLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _domainIdMeta = const VerificationMeta(
    'domainId',
  );
  @override
  late final GeneratedColumn<int> domainId = GeneratedColumn<int>(
    'domain_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES domain (id)',
    ),
  );
  static const VerificationMeta _syllabusItemIdMeta = const VerificationMeta(
    'syllabusItemId',
  );
  @override
  late final GeneratedColumn<int> syllabusItemId = GeneratedColumn<int>(
    'syllabus_item_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES syllabus_item (id)',
    ),
  );
  static const VerificationMeta _templateVersionMeta = const VerificationMeta(
    'templateVersion',
  );
  @override
  late final GeneratedColumn<String> templateVersion = GeneratedColumn<String>(
    'template_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptTextMeta = const VerificationMeta(
    'promptText',
  );
  @override
  late final GeneratedColumn<String> promptText = GeneratedColumn<String>(
    'prompt_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardsRequestedMeta = const VerificationMeta(
    'cardsRequested',
  );
  @override
  late final GeneratedColumn<int> cardsRequested = GeneratedColumn<int>(
    'cards_requested',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardsImportedMeta = const VerificationMeta(
    'cardsImported',
  );
  @override
  late final GeneratedColumn<int> cardsImported = GeneratedColumn<int>(
    'cards_imported',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('issued'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    domainId,
    syllabusItemId,
    templateVersion,
    promptText,
    cardsRequested,
    cardsImported,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prompt_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<PromptLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('domain_id')) {
      context.handle(
        _domainIdMeta,
        domainId.isAcceptableOrUnknown(data['domain_id']!, _domainIdMeta),
      );
    } else if (isInserting) {
      context.missing(_domainIdMeta);
    }
    if (data.containsKey('syllabus_item_id')) {
      context.handle(
        _syllabusItemIdMeta,
        syllabusItemId.isAcceptableOrUnknown(
          data['syllabus_item_id']!,
          _syllabusItemIdMeta,
        ),
      );
    }
    if (data.containsKey('template_version')) {
      context.handle(
        _templateVersionMeta,
        templateVersion.isAcceptableOrUnknown(
          data['template_version']!,
          _templateVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_templateVersionMeta);
    }
    if (data.containsKey('prompt_text')) {
      context.handle(
        _promptTextMeta,
        promptText.isAcceptableOrUnknown(data['prompt_text']!, _promptTextMeta),
      );
    } else if (isInserting) {
      context.missing(_promptTextMeta);
    }
    if (data.containsKey('cards_requested')) {
      context.handle(
        _cardsRequestedMeta,
        cardsRequested.isAcceptableOrUnknown(
          data['cards_requested']!,
          _cardsRequestedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cardsRequestedMeta);
    }
    if (data.containsKey('cards_imported')) {
      context.handle(
        _cardsImportedMeta,
        cardsImported.isAcceptableOrUnknown(
          data['cards_imported']!,
          _cardsImportedMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PromptLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PromptLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      domainId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}domain_id'],
      )!,
      syllabusItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}syllabus_item_id'],
      ),
      templateVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_version'],
      )!,
      promptText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_text'],
      )!,
      cardsRequested: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cards_requested'],
      )!,
      cardsImported: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cards_imported'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $PromptLogsTable createAlias(String alias) {
    return $PromptLogsTable(attachedDatabase, alias);
  }
}

class PromptLog extends DataClass implements Insertable<PromptLog> {
  final int id;
  final int createdAt;
  final int domainId;
  final int? syllabusItemId;
  final String templateVersion;
  final String promptText;
  final int cardsRequested;
  final int cardsImported;
  final String status;
  const PromptLog({
    required this.id,
    required this.createdAt,
    required this.domainId,
    this.syllabusItemId,
    required this.templateVersion,
    required this.promptText,
    required this.cardsRequested,
    required this.cardsImported,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['domain_id'] = Variable<int>(domainId);
    if (!nullToAbsent || syllabusItemId != null) {
      map['syllabus_item_id'] = Variable<int>(syllabusItemId);
    }
    map['template_version'] = Variable<String>(templateVersion);
    map['prompt_text'] = Variable<String>(promptText);
    map['cards_requested'] = Variable<int>(cardsRequested);
    map['cards_imported'] = Variable<int>(cardsImported);
    map['status'] = Variable<String>(status);
    return map;
  }

  PromptLogsCompanion toCompanion(bool nullToAbsent) {
    return PromptLogsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      domainId: Value(domainId),
      syllabusItemId: syllabusItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(syllabusItemId),
      templateVersion: Value(templateVersion),
      promptText: Value(promptText),
      cardsRequested: Value(cardsRequested),
      cardsImported: Value(cardsImported),
      status: Value(status),
    );
  }

  factory PromptLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PromptLog(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      domainId: serializer.fromJson<int>(json['domainId']),
      syllabusItemId: serializer.fromJson<int?>(json['syllabusItemId']),
      templateVersion: serializer.fromJson<String>(json['templateVersion']),
      promptText: serializer.fromJson<String>(json['promptText']),
      cardsRequested: serializer.fromJson<int>(json['cardsRequested']),
      cardsImported: serializer.fromJson<int>(json['cardsImported']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'domainId': serializer.toJson<int>(domainId),
      'syllabusItemId': serializer.toJson<int?>(syllabusItemId),
      'templateVersion': serializer.toJson<String>(templateVersion),
      'promptText': serializer.toJson<String>(promptText),
      'cardsRequested': serializer.toJson<int>(cardsRequested),
      'cardsImported': serializer.toJson<int>(cardsImported),
      'status': serializer.toJson<String>(status),
    };
  }

  PromptLog copyWith({
    int? id,
    int? createdAt,
    int? domainId,
    Value<int?> syllabusItemId = const Value.absent(),
    String? templateVersion,
    String? promptText,
    int? cardsRequested,
    int? cardsImported,
    String? status,
  }) => PromptLog(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    domainId: domainId ?? this.domainId,
    syllabusItemId: syllabusItemId.present
        ? syllabusItemId.value
        : this.syllabusItemId,
    templateVersion: templateVersion ?? this.templateVersion,
    promptText: promptText ?? this.promptText,
    cardsRequested: cardsRequested ?? this.cardsRequested,
    cardsImported: cardsImported ?? this.cardsImported,
    status: status ?? this.status,
  );
  PromptLog copyWithCompanion(PromptLogsCompanion data) {
    return PromptLog(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      domainId: data.domainId.present ? data.domainId.value : this.domainId,
      syllabusItemId: data.syllabusItemId.present
          ? data.syllabusItemId.value
          : this.syllabusItemId,
      templateVersion: data.templateVersion.present
          ? data.templateVersion.value
          : this.templateVersion,
      promptText: data.promptText.present
          ? data.promptText.value
          : this.promptText,
      cardsRequested: data.cardsRequested.present
          ? data.cardsRequested.value
          : this.cardsRequested,
      cardsImported: data.cardsImported.present
          ? data.cardsImported.value
          : this.cardsImported,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PromptLog(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('domainId: $domainId, ')
          ..write('syllabusItemId: $syllabusItemId, ')
          ..write('templateVersion: $templateVersion, ')
          ..write('promptText: $promptText, ')
          ..write('cardsRequested: $cardsRequested, ')
          ..write('cardsImported: $cardsImported, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    domainId,
    syllabusItemId,
    templateVersion,
    promptText,
    cardsRequested,
    cardsImported,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptLog &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.domainId == this.domainId &&
          other.syllabusItemId == this.syllabusItemId &&
          other.templateVersion == this.templateVersion &&
          other.promptText == this.promptText &&
          other.cardsRequested == this.cardsRequested &&
          other.cardsImported == this.cardsImported &&
          other.status == this.status);
}

class PromptLogsCompanion extends UpdateCompanion<PromptLog> {
  final Value<int> id;
  final Value<int> createdAt;
  final Value<int> domainId;
  final Value<int?> syllabusItemId;
  final Value<String> templateVersion;
  final Value<String> promptText;
  final Value<int> cardsRequested;
  final Value<int> cardsImported;
  final Value<String> status;
  const PromptLogsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.domainId = const Value.absent(),
    this.syllabusItemId = const Value.absent(),
    this.templateVersion = const Value.absent(),
    this.promptText = const Value.absent(),
    this.cardsRequested = const Value.absent(),
    this.cardsImported = const Value.absent(),
    this.status = const Value.absent(),
  });
  PromptLogsCompanion.insert({
    this.id = const Value.absent(),
    required int createdAt,
    required int domainId,
    this.syllabusItemId = const Value.absent(),
    required String templateVersion,
    required String promptText,
    required int cardsRequested,
    this.cardsImported = const Value.absent(),
    this.status = const Value.absent(),
  }) : createdAt = Value(createdAt),
       domainId = Value(domainId),
       templateVersion = Value(templateVersion),
       promptText = Value(promptText),
       cardsRequested = Value(cardsRequested);
  static Insertable<PromptLog> custom({
    Expression<int>? id,
    Expression<int>? createdAt,
    Expression<int>? domainId,
    Expression<int>? syllabusItemId,
    Expression<String>? templateVersion,
    Expression<String>? promptText,
    Expression<int>? cardsRequested,
    Expression<int>? cardsImported,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (domainId != null) 'domain_id': domainId,
      if (syllabusItemId != null) 'syllabus_item_id': syllabusItemId,
      if (templateVersion != null) 'template_version': templateVersion,
      if (promptText != null) 'prompt_text': promptText,
      if (cardsRequested != null) 'cards_requested': cardsRequested,
      if (cardsImported != null) 'cards_imported': cardsImported,
      if (status != null) 'status': status,
    });
  }

  PromptLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? createdAt,
    Value<int>? domainId,
    Value<int?>? syllabusItemId,
    Value<String>? templateVersion,
    Value<String>? promptText,
    Value<int>? cardsRequested,
    Value<int>? cardsImported,
    Value<String>? status,
  }) {
    return PromptLogsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      domainId: domainId ?? this.domainId,
      syllabusItemId: syllabusItemId ?? this.syllabusItemId,
      templateVersion: templateVersion ?? this.templateVersion,
      promptText: promptText ?? this.promptText,
      cardsRequested: cardsRequested ?? this.cardsRequested,
      cardsImported: cardsImported ?? this.cardsImported,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (domainId.present) {
      map['domain_id'] = Variable<int>(domainId.value);
    }
    if (syllabusItemId.present) {
      map['syllabus_item_id'] = Variable<int>(syllabusItemId.value);
    }
    if (templateVersion.present) {
      map['template_version'] = Variable<String>(templateVersion.value);
    }
    if (promptText.present) {
      map['prompt_text'] = Variable<String>(promptText.value);
    }
    if (cardsRequested.present) {
      map['cards_requested'] = Variable<int>(cardsRequested.value);
    }
    if (cardsImported.present) {
      map['cards_imported'] = Variable<int>(cardsImported.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PromptLogsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('domainId: $domainId, ')
          ..write('syllabusItemId: $syllabusItemId, ')
          ..write('templateVersion: $templateVersion, ')
          ..write('promptText: $promptText, ')
          ..write('cardsRequested: $cardsRequested, ')
          ..write('cardsImported: $cardsImported, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $InterestLogsTable extends InterestLogs
    with TableInfo<$InterestLogsTable, InterestLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InterestLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _domainIdMeta = const VerificationMeta(
    'domainId',
  );
  @override
  late final GeneratedColumn<int> domainId = GeneratedColumn<int>(
    'domain_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES domain (id)',
    ),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, ts, domainId, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'interest_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<InterestLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('domain_id')) {
      context.handle(
        _domainIdMeta,
        domainId.isAcceptableOrUnknown(data['domain_id']!, _domainIdMeta),
      );
    } else if (isInserting) {
      context.missing(_domainIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InterestLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InterestLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ts'],
      )!,
      domainId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}domain_id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $InterestLogsTable createAlias(String alias) {
    return $InterestLogsTable(attachedDatabase, alias);
  }
}

class InterestLog extends DataClass implements Insertable<InterestLog> {
  final int id;
  final int ts;
  final int domainId;
  final int value;
  const InterestLog({
    required this.id,
    required this.ts,
    required this.domainId,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ts'] = Variable<int>(ts);
    map['domain_id'] = Variable<int>(domainId);
    map['value'] = Variable<int>(value);
    return map;
  }

  InterestLogsCompanion toCompanion(bool nullToAbsent) {
    return InterestLogsCompanion(
      id: Value(id),
      ts: Value(ts),
      domainId: Value(domainId),
      value: Value(value),
    );
  }

  factory InterestLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InterestLog(
      id: serializer.fromJson<int>(json['id']),
      ts: serializer.fromJson<int>(json['ts']),
      domainId: serializer.fromJson<int>(json['domainId']),
      value: serializer.fromJson<int>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ts': serializer.toJson<int>(ts),
      'domainId': serializer.toJson<int>(domainId),
      'value': serializer.toJson<int>(value),
    };
  }

  InterestLog copyWith({int? id, int? ts, int? domainId, int? value}) =>
      InterestLog(
        id: id ?? this.id,
        ts: ts ?? this.ts,
        domainId: domainId ?? this.domainId,
        value: value ?? this.value,
      );
  InterestLog copyWithCompanion(InterestLogsCompanion data) {
    return InterestLog(
      id: data.id.present ? data.id.value : this.id,
      ts: data.ts.present ? data.ts.value : this.ts,
      domainId: data.domainId.present ? data.domainId.value : this.domainId,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InterestLog(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('domainId: $domainId, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ts, domainId, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InterestLog &&
          other.id == this.id &&
          other.ts == this.ts &&
          other.domainId == this.domainId &&
          other.value == this.value);
}

class InterestLogsCompanion extends UpdateCompanion<InterestLog> {
  final Value<int> id;
  final Value<int> ts;
  final Value<int> domainId;
  final Value<int> value;
  const InterestLogsCompanion({
    this.id = const Value.absent(),
    this.ts = const Value.absent(),
    this.domainId = const Value.absent(),
    this.value = const Value.absent(),
  });
  InterestLogsCompanion.insert({
    this.id = const Value.absent(),
    required int ts,
    required int domainId,
    required int value,
  }) : ts = Value(ts),
       domainId = Value(domainId),
       value = Value(value);
  static Insertable<InterestLog> custom({
    Expression<int>? id,
    Expression<int>? ts,
    Expression<int>? domainId,
    Expression<int>? value,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts,
      if (domainId != null) 'domain_id': domainId,
      if (value != null) 'value': value,
    });
  }

  InterestLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? ts,
    Value<int>? domainId,
    Value<int>? value,
  }) {
    return InterestLogsCompanion(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      domainId: domainId ?? this.domainId,
      value: value ?? this.value,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (domainId.present) {
      map['domain_id'] = Variable<int>(domainId.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InterestLogsCompanion(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('domainId: $domainId, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }
}

class $EngineDecisionsTable extends EngineDecisions
    with TableInfo<$EngineDecisionsTable, EngineDecision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EngineDecisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineVersionMeta = const VerificationMeta(
    'engineVersion',
  );
  @override
  late final GeneratedColumn<String> engineVersion = GeneratedColumn<String>(
    'engine_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedMeta = const VerificationMeta('seed');
  @override
  late final GeneratedColumn<int> seed = GeneratedColumn<int>(
    'seed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _featuresJsonMeta = const VerificationMeta(
    'featuresJson',
  );
  @override
  late final GeneratedColumn<String> featuresJson = GeneratedColumn<String>(
    'features_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoresJsonMeta = const VerificationMeta(
    'scoresJson',
  );
  @override
  late final GeneratedColumn<String> scoresJson = GeneratedColumn<String>(
    'scores_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chosenJsonMeta = const VerificationMeta(
    'chosenJson',
  );
  @override
  late final GeneratedColumn<String> chosenJson = GeneratedColumn<String>(
    'chosen_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ts,
    engineVersion,
    seed,
    featuresJson,
    scoresJson,
    chosenJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'engine_decision';
  @override
  VerificationContext validateIntegrity(
    Insertable<EngineDecision> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('engine_version')) {
      context.handle(
        _engineVersionMeta,
        engineVersion.isAcceptableOrUnknown(
          data['engine_version']!,
          _engineVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_engineVersionMeta);
    }
    if (data.containsKey('seed')) {
      context.handle(
        _seedMeta,
        seed.isAcceptableOrUnknown(data['seed']!, _seedMeta),
      );
    } else if (isInserting) {
      context.missing(_seedMeta);
    }
    if (data.containsKey('features_json')) {
      context.handle(
        _featuresJsonMeta,
        featuresJson.isAcceptableOrUnknown(
          data['features_json']!,
          _featuresJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_featuresJsonMeta);
    }
    if (data.containsKey('scores_json')) {
      context.handle(
        _scoresJsonMeta,
        scoresJson.isAcceptableOrUnknown(data['scores_json']!, _scoresJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_scoresJsonMeta);
    }
    if (data.containsKey('chosen_json')) {
      context.handle(
        _chosenJsonMeta,
        chosenJson.isAcceptableOrUnknown(data['chosen_json']!, _chosenJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_chosenJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EngineDecision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EngineDecision(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ts'],
      )!,
      engineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_version'],
      )!,
      seed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seed'],
      )!,
      featuresJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}features_json'],
      )!,
      scoresJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scores_json'],
      )!,
      chosenJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chosen_json'],
      )!,
    );
  }

  @override
  $EngineDecisionsTable createAlias(String alias) {
    return $EngineDecisionsTable(attachedDatabase, alias);
  }
}

class EngineDecision extends DataClass implements Insertable<EngineDecision> {
  final int id;
  final int ts;
  final String engineVersion;
  final int seed;
  final String featuresJson;
  final String scoresJson;
  final String chosenJson;
  const EngineDecision({
    required this.id,
    required this.ts,
    required this.engineVersion,
    required this.seed,
    required this.featuresJson,
    required this.scoresJson,
    required this.chosenJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ts'] = Variable<int>(ts);
    map['engine_version'] = Variable<String>(engineVersion);
    map['seed'] = Variable<int>(seed);
    map['features_json'] = Variable<String>(featuresJson);
    map['scores_json'] = Variable<String>(scoresJson);
    map['chosen_json'] = Variable<String>(chosenJson);
    return map;
  }

  EngineDecisionsCompanion toCompanion(bool nullToAbsent) {
    return EngineDecisionsCompanion(
      id: Value(id),
      ts: Value(ts),
      engineVersion: Value(engineVersion),
      seed: Value(seed),
      featuresJson: Value(featuresJson),
      scoresJson: Value(scoresJson),
      chosenJson: Value(chosenJson),
    );
  }

  factory EngineDecision.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EngineDecision(
      id: serializer.fromJson<int>(json['id']),
      ts: serializer.fromJson<int>(json['ts']),
      engineVersion: serializer.fromJson<String>(json['engineVersion']),
      seed: serializer.fromJson<int>(json['seed']),
      featuresJson: serializer.fromJson<String>(json['featuresJson']),
      scoresJson: serializer.fromJson<String>(json['scoresJson']),
      chosenJson: serializer.fromJson<String>(json['chosenJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ts': serializer.toJson<int>(ts),
      'engineVersion': serializer.toJson<String>(engineVersion),
      'seed': serializer.toJson<int>(seed),
      'featuresJson': serializer.toJson<String>(featuresJson),
      'scoresJson': serializer.toJson<String>(scoresJson),
      'chosenJson': serializer.toJson<String>(chosenJson),
    };
  }

  EngineDecision copyWith({
    int? id,
    int? ts,
    String? engineVersion,
    int? seed,
    String? featuresJson,
    String? scoresJson,
    String? chosenJson,
  }) => EngineDecision(
    id: id ?? this.id,
    ts: ts ?? this.ts,
    engineVersion: engineVersion ?? this.engineVersion,
    seed: seed ?? this.seed,
    featuresJson: featuresJson ?? this.featuresJson,
    scoresJson: scoresJson ?? this.scoresJson,
    chosenJson: chosenJson ?? this.chosenJson,
  );
  EngineDecision copyWithCompanion(EngineDecisionsCompanion data) {
    return EngineDecision(
      id: data.id.present ? data.id.value : this.id,
      ts: data.ts.present ? data.ts.value : this.ts,
      engineVersion: data.engineVersion.present
          ? data.engineVersion.value
          : this.engineVersion,
      seed: data.seed.present ? data.seed.value : this.seed,
      featuresJson: data.featuresJson.present
          ? data.featuresJson.value
          : this.featuresJson,
      scoresJson: data.scoresJson.present
          ? data.scoresJson.value
          : this.scoresJson,
      chosenJson: data.chosenJson.present
          ? data.chosenJson.value
          : this.chosenJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EngineDecision(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('seed: $seed, ')
          ..write('featuresJson: $featuresJson, ')
          ..write('scoresJson: $scoresJson, ')
          ..write('chosenJson: $chosenJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ts,
    engineVersion,
    seed,
    featuresJson,
    scoresJson,
    chosenJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EngineDecision &&
          other.id == this.id &&
          other.ts == this.ts &&
          other.engineVersion == this.engineVersion &&
          other.seed == this.seed &&
          other.featuresJson == this.featuresJson &&
          other.scoresJson == this.scoresJson &&
          other.chosenJson == this.chosenJson);
}

class EngineDecisionsCompanion extends UpdateCompanion<EngineDecision> {
  final Value<int> id;
  final Value<int> ts;
  final Value<String> engineVersion;
  final Value<int> seed;
  final Value<String> featuresJson;
  final Value<String> scoresJson;
  final Value<String> chosenJson;
  const EngineDecisionsCompanion({
    this.id = const Value.absent(),
    this.ts = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.seed = const Value.absent(),
    this.featuresJson = const Value.absent(),
    this.scoresJson = const Value.absent(),
    this.chosenJson = const Value.absent(),
  });
  EngineDecisionsCompanion.insert({
    this.id = const Value.absent(),
    required int ts,
    required String engineVersion,
    required int seed,
    required String featuresJson,
    required String scoresJson,
    required String chosenJson,
  }) : ts = Value(ts),
       engineVersion = Value(engineVersion),
       seed = Value(seed),
       featuresJson = Value(featuresJson),
       scoresJson = Value(scoresJson),
       chosenJson = Value(chosenJson);
  static Insertable<EngineDecision> custom({
    Expression<int>? id,
    Expression<int>? ts,
    Expression<String>? engineVersion,
    Expression<int>? seed,
    Expression<String>? featuresJson,
    Expression<String>? scoresJson,
    Expression<String>? chosenJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts,
      if (engineVersion != null) 'engine_version': engineVersion,
      if (seed != null) 'seed': seed,
      if (featuresJson != null) 'features_json': featuresJson,
      if (scoresJson != null) 'scores_json': scoresJson,
      if (chosenJson != null) 'chosen_json': chosenJson,
    });
  }

  EngineDecisionsCompanion copyWith({
    Value<int>? id,
    Value<int>? ts,
    Value<String>? engineVersion,
    Value<int>? seed,
    Value<String>? featuresJson,
    Value<String>? scoresJson,
    Value<String>? chosenJson,
  }) {
    return EngineDecisionsCompanion(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      engineVersion: engineVersion ?? this.engineVersion,
      seed: seed ?? this.seed,
      featuresJson: featuresJson ?? this.featuresJson,
      scoresJson: scoresJson ?? this.scoresJson,
      chosenJson: chosenJson ?? this.chosenJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (engineVersion.present) {
      map['engine_version'] = Variable<String>(engineVersion.value);
    }
    if (seed.present) {
      map['seed'] = Variable<int>(seed.value);
    }
    if (featuresJson.present) {
      map['features_json'] = Variable<String>(featuresJson.value);
    }
    if (scoresJson.present) {
      map['scores_json'] = Variable<String>(scoresJson.value);
    }
    if (chosenJson.present) {
      map['chosen_json'] = Variable<String>(chosenJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EngineDecisionsCompanion(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('seed: $seed, ')
          ..write('featuresJson: $featuresJson, ')
          ..write('scoresJson: $scoresJson, ')
          ..write('chosenJson: $chosenJson')
          ..write(')'))
        .toString();
  }
}

class $BackupLogsTable extends BackupLogs
    with TableInfo<$BackupLogsTable, BackupLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _okMeta = const VerificationMeta('ok');
  @override
  late final GeneratedColumn<bool> ok = GeneratedColumn<bool>(
    'ok',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ok" IN (0, 1))',
    ),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, ts, uri, bytes, ok, error];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('ok')) {
      context.handle(_okMeta, ok.isAcceptableOrUnknown(data['ok']!, _okMeta));
    } else if (isInserting) {
      context.missing(_okMeta);
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BackupLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ts'],
      )!,
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      ),
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      ok: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ok'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $BackupLogsTable createAlias(String alias) {
    return $BackupLogsTable(attachedDatabase, alias);
  }
}

class BackupLog extends DataClass implements Insertable<BackupLog> {
  final int id;
  final int ts;
  final String? uri;
  final int bytes;
  final bool ok;
  final String? error;
  const BackupLog({
    required this.id,
    required this.ts,
    this.uri,
    required this.bytes,
    required this.ok,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ts'] = Variable<int>(ts);
    if (!nullToAbsent || uri != null) {
      map['uri'] = Variable<String>(uri);
    }
    map['bytes'] = Variable<int>(bytes);
    map['ok'] = Variable<bool>(ok);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  BackupLogsCompanion toCompanion(bool nullToAbsent) {
    return BackupLogsCompanion(
      id: Value(id),
      ts: Value(ts),
      uri: uri == null && nullToAbsent ? const Value.absent() : Value(uri),
      bytes: Value(bytes),
      ok: Value(ok),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory BackupLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupLog(
      id: serializer.fromJson<int>(json['id']),
      ts: serializer.fromJson<int>(json['ts']),
      uri: serializer.fromJson<String?>(json['uri']),
      bytes: serializer.fromJson<int>(json['bytes']),
      ok: serializer.fromJson<bool>(json['ok']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ts': serializer.toJson<int>(ts),
      'uri': serializer.toJson<String?>(uri),
      'bytes': serializer.toJson<int>(bytes),
      'ok': serializer.toJson<bool>(ok),
      'error': serializer.toJson<String?>(error),
    };
  }

  BackupLog copyWith({
    int? id,
    int? ts,
    Value<String?> uri = const Value.absent(),
    int? bytes,
    bool? ok,
    Value<String?> error = const Value.absent(),
  }) => BackupLog(
    id: id ?? this.id,
    ts: ts ?? this.ts,
    uri: uri.present ? uri.value : this.uri,
    bytes: bytes ?? this.bytes,
    ok: ok ?? this.ok,
    error: error.present ? error.value : this.error,
  );
  BackupLog copyWithCompanion(BackupLogsCompanion data) {
    return BackupLog(
      id: data.id.present ? data.id.value : this.id,
      ts: data.ts.present ? data.ts.value : this.ts,
      uri: data.uri.present ? data.uri.value : this.uri,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      ok: data.ok.present ? data.ok.value : this.ok,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupLog(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('uri: $uri, ')
          ..write('bytes: $bytes, ')
          ..write('ok: $ok, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ts, uri, bytes, ok, error);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupLog &&
          other.id == this.id &&
          other.ts == this.ts &&
          other.uri == this.uri &&
          other.bytes == this.bytes &&
          other.ok == this.ok &&
          other.error == this.error);
}

class BackupLogsCompanion extends UpdateCompanion<BackupLog> {
  final Value<int> id;
  final Value<int> ts;
  final Value<String?> uri;
  final Value<int> bytes;
  final Value<bool> ok;
  final Value<String?> error;
  const BackupLogsCompanion({
    this.id = const Value.absent(),
    this.ts = const Value.absent(),
    this.uri = const Value.absent(),
    this.bytes = const Value.absent(),
    this.ok = const Value.absent(),
    this.error = const Value.absent(),
  });
  BackupLogsCompanion.insert({
    this.id = const Value.absent(),
    required int ts,
    this.uri = const Value.absent(),
    this.bytes = const Value.absent(),
    required bool ok,
    this.error = const Value.absent(),
  }) : ts = Value(ts),
       ok = Value(ok);
  static Insertable<BackupLog> custom({
    Expression<int>? id,
    Expression<int>? ts,
    Expression<String>? uri,
    Expression<int>? bytes,
    Expression<bool>? ok,
    Expression<String>? error,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts,
      if (uri != null) 'uri': uri,
      if (bytes != null) 'bytes': bytes,
      if (ok != null) 'ok': ok,
      if (error != null) 'error': error,
    });
  }

  BackupLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? ts,
    Value<String?>? uri,
    Value<int>? bytes,
    Value<bool>? ok,
    Value<String?>? error,
  }) {
    return BackupLogsCompanion(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      uri: uri ?? this.uri,
      bytes: bytes ?? this.bytes,
      ok: ok ?? this.ok,
      error: error ?? this.error,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (ok.present) {
      map['ok'] = Variable<bool>(ok.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupLogsCompanion(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('uri: $uri, ')
          ..write('bytes: $bytes, ')
          ..write('ok: $ok, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setting';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DomainsTable domains = $DomainsTable(this);
  late final $SyllabusItemsTable syllabusItems = $SyllabusItemsTable(this);
  late final $SyllabusPrereqsTable syllabusPrereqs = $SyllabusPrereqsTable(
    this,
  );
  late final $NotesTable notes = $NotesTable(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $FsrsParamsTableTable fsrsParamsTable = $FsrsParamsTableTable(
    this,
  );
  late final $ReviewLogsTable reviewLogs = $ReviewLogsTable(this);
  late final $PromptLogsTable promptLogs = $PromptLogsTable(this);
  late final $InterestLogsTable interestLogs = $InterestLogsTable(this);
  late final $EngineDecisionsTable engineDecisions = $EngineDecisionsTable(
    this,
  );
  late final $BackupLogsTable backupLogs = $BackupLogsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index cardDueIdx = Index(
    'card_due_idx',
    'CREATE INDEX card_due_idx ON card (due)',
  );
  late final Index cardNoteIdx = Index(
    'card_note_idx',
    'CREATE INDEX card_note_idx ON card (note_id)',
  );
  late final Index reviewLogCardIdx = Index(
    'review_log_card_idx',
    'CREATE INDEX review_log_card_idx ON review_log (card_id)',
  );
  late final Index reviewLogTimeIdx = Index(
    'review_log_time_idx',
    'CREATE INDEX review_log_time_idx ON review_log (reviewed_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    domains,
    syllabusItems,
    syllabusPrereqs,
    notes,
    cards,
    fsrsParamsTable,
    reviewLogs,
    promptLogs,
    interestLogs,
    engineDecisions,
    backupLogs,
    settings,
    cardDueIdx,
    cardNoteIdx,
    reviewLogCardIdx,
    reviewLogTimeIdx,
  ];
}

typedef $$DomainsTableCreateCompanionBuilder = DomainsCompanion Function({
  Value<int> id,
  required String name,
  Value<bool> active,
  required int createdAt,
  Value<int> learnWeight,
  Value<bool> revisit,
});
typedef $$DomainsTableUpdateCompanionBuilder = DomainsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<bool> active,
  Value<int> createdAt,
  Value<int> learnWeight,
  Value<bool> revisit,
});

final class $$DomainsTableReferences
    extends BaseReferences<_$AppDatabase, $DomainsTable, Domain> {
  $$DomainsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SyllabusItemsTable, List<SyllabusItem>>
  _syllabusItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.syllabusItems,
    aliasName: 'domain__id__syllabus_item__domain_id',
  );

  $$SyllabusItemsTableProcessedTableManager get syllabusItemsRefs {
    final manager = $$SyllabusItemsTableTableManager(
      $_db,
      $_db.syllabusItems,
    ).filter((f) => f.domainId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_syllabusItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NotesTable, List<Note>> _notesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: 'domain__id__note__domain_id',
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.domainId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PromptLogsTable, List<PromptLog>>
  _promptLogsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.promptLogs,
    aliasName: 'domain__id__prompt_log__domain_id',
  );

  $$PromptLogsTableProcessedTableManager get promptLogsRefs {
    final manager = $$PromptLogsTableTableManager(
      $_db,
      $_db.promptLogs,
    ).filter((f) => f.domainId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_promptLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InterestLogsTable, List<InterestLog>>
  _interestLogsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.interestLogs,
    aliasName: 'domain__id__interest_log__domain_id',
  );

  $$InterestLogsTableProcessedTableManager get interestLogsRefs {
    final manager = $$InterestLogsTableTableManager(
      $_db,
      $_db.interestLogs,
    ).filter((f) => f.domainId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_interestLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DomainsTableFilterComposer
    extends Composer<_$AppDatabase, $DomainsTable> {
  $$DomainsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get learnWeight => $composableBuilder(
    column: $table.learnWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get revisit => $composableBuilder(
    column: $table.revisit,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> syllabusItemsRefs(
    Expression<bool> Function($$SyllabusItemsTableFilterComposer f) f,
  ) {
    final $$SyllabusItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.domainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableFilterComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.domainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> promptLogsRefs(
    Expression<bool> Function($$PromptLogsTableFilterComposer f) f,
  ) {
    final $$PromptLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.promptLogs,
      getReferencedColumn: (t) => t.domainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PromptLogsTableFilterComposer(
            $db: $db,
            $table: $db.promptLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> interestLogsRefs(
    Expression<bool> Function($$InterestLogsTableFilterComposer f) f,
  ) {
    final $$InterestLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.interestLogs,
      getReferencedColumn: (t) => t.domainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InterestLogsTableFilterComposer(
            $db: $db,
            $table: $db.interestLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DomainsTableOrderingComposer
    extends Composer<_$AppDatabase, $DomainsTable> {
  $$DomainsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get learnWeight => $composableBuilder(
    column: $table.learnWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get revisit => $composableBuilder(
    column: $table.revisit,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DomainsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DomainsTable> {
  $$DomainsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get learnWeight => $composableBuilder(
    column: $table.learnWeight,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get revisit =>
      $composableBuilder(column: $table.revisit, builder: (column) => column);

  Expression<T> syllabusItemsRefs<T extends Object>(
    Expression<T> Function($$SyllabusItemsTableAnnotationComposer a) f,
  ) {
    final $$SyllabusItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.domainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.domainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> promptLogsRefs<T extends Object>(
    Expression<T> Function($$PromptLogsTableAnnotationComposer a) f,
  ) {
    final $$PromptLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.promptLogs,
      getReferencedColumn: (t) => t.domainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PromptLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.promptLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> interestLogsRefs<T extends Object>(
    Expression<T> Function($$InterestLogsTableAnnotationComposer a) f,
  ) {
    final $$InterestLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.interestLogs,
      getReferencedColumn: (t) => t.domainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InterestLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.interestLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DomainsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DomainsTable,
          Domain,
          $$DomainsTableFilterComposer,
          $$DomainsTableOrderingComposer,
          $$DomainsTableAnnotationComposer,
          $$DomainsTableCreateCompanionBuilder,
          $$DomainsTableUpdateCompanionBuilder,
          (Domain, $$DomainsTableReferences),
          Domain,
          PrefetchHooks Function({
            bool syllabusItemsRefs,
            bool notesRefs,
            bool promptLogsRefs,
            bool interestLogsRefs,
          })
        > {
  $$DomainsTableTableManager(_$AppDatabase db, $DomainsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DomainsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DomainsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DomainsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> learnWeight = const Value.absent(),
                Value<bool> revisit = const Value.absent(),
              }) => DomainsCompanion(
                id: id,
                name: name,
                active: active,
                createdAt: createdAt,
                learnWeight: learnWeight,
                revisit: revisit,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<bool> active = const Value.absent(),
                required int createdAt,
                Value<int> learnWeight = const Value.absent(),
                Value<bool> revisit = const Value.absent(),
              }) => DomainsCompanion.insert(
                id: id,
                name: name,
                active: active,
                createdAt: createdAt,
                learnWeight: learnWeight,
                revisit: revisit,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DomainsTable, Domain>(table),
                  $$DomainsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                syllabusItemsRefs = false,
                notesRefs = false,
                promptLogsRefs = false,
                interestLogsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (syllabusItemsRefs) db.syllabusItems,
                    if (notesRefs) db.notes,
                    if (promptLogsRefs) db.promptLogs,
                    if (interestLogsRefs) db.interestLogs,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (syllabusItemsRefs)
                        await $_getPrefetchedData<
                          Domain,
                          $DomainsTable,
                          SyllabusItem
                        >(
                          currentTable: table,
                          referencedTable: $$DomainsTableReferences
                              ._syllabusItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DomainsTableReferences(
                                db,
                                table,
                                p0,
                              ).syllabusItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.domainId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (notesRefs)
                        await $_getPrefetchedData<Domain, $DomainsTable, Note>(
                          currentTable: table,
                          referencedTable: $$DomainsTableReferences
                              ._notesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DomainsTableReferences(db, table, p0).notesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.domainId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (promptLogsRefs)
                        await $_getPrefetchedData<
                          Domain,
                          $DomainsTable,
                          PromptLog
                        >(
                          currentTable: table,
                          referencedTable: $$DomainsTableReferences
                              ._promptLogsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DomainsTableReferences(
                                db,
                                table,
                                p0,
                              ).promptLogsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.domainId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (interestLogsRefs)
                        await $_getPrefetchedData<
                          Domain,
                          $DomainsTable,
                          InterestLog
                        >(
                          currentTable: table,
                          referencedTable: $$DomainsTableReferences
                              ._interestLogsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DomainsTableReferences(
                                db,
                                table,
                                p0,
                              ).interestLogsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.domainId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DomainsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DomainsTable,
      Domain,
      $$DomainsTableFilterComposer,
      $$DomainsTableOrderingComposer,
      $$DomainsTableAnnotationComposer,
      $$DomainsTableCreateCompanionBuilder,
      $$DomainsTableUpdateCompanionBuilder,
      (Domain, $$DomainsTableReferences),
      Domain,
      PrefetchHooks Function({
        bool syllabusItemsRefs,
        bool notesRefs,
        bool promptLogsRefs,
        bool interestLogsRefs,
      })
    >;
typedef $$SyllabusItemsTableCreateCompanionBuilder =
    SyllabusItemsCompanion Function({
      Value<int> id,
      required int domainId,
      required String title,
      Value<int> level,
      Value<int> position,
      Value<String> status,
      Value<int> targetCards,
      Value<String> description,
      Value<int> rounds,
    });
typedef $$SyllabusItemsTableUpdateCompanionBuilder =
    SyllabusItemsCompanion Function({
      Value<int> id,
      Value<int> domainId,
      Value<String> title,
      Value<int> level,
      Value<int> position,
      Value<String> status,
      Value<int> targetCards,
      Value<String> description,
      Value<int> rounds,
    });

final class $$SyllabusItemsTableReferences
    extends BaseReferences<_$AppDatabase, $SyllabusItemsTable, SyllabusItem> {
  $$SyllabusItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DomainsTable _domainIdTable(_$AppDatabase db) =>
      db.domains.createAlias('syllabus_item__domain_id__domain__id');

  $$DomainsTableProcessedTableManager get domainId {
    final $_column = $_itemColumn<int>('domain_id')!;

    final manager = $$DomainsTableTableManager(
      $_db,
      $_db.domains,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_domainIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$NotesTable, List<Note>> _notesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: 'syllabus_item__id__note__syllabus_item_id',
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.syllabusItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PromptLogsTable, List<PromptLog>>
  _promptLogsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.promptLogs,
    aliasName: 'syllabus_item__id__prompt_log__syllabus_item_id',
  );

  $$PromptLogsTableProcessedTableManager get promptLogsRefs {
    final manager = $$PromptLogsTableTableManager(
      $_db,
      $_db.promptLogs,
    ).filter((f) => f.syllabusItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_promptLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SyllabusItemsTableFilterComposer
    extends Composer<_$AppDatabase, $SyllabusItemsTable> {
  $$SyllabusItemsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetCards => $composableBuilder(
    column: $table.targetCards,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rounds => $composableBuilder(
    column: $table.rounds,
    builder: (column) => ColumnFilters(column),
  );

  $$DomainsTableFilterComposer get domainId {
    final $$DomainsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableFilterComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.syllabusItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> promptLogsRefs(
    Expression<bool> Function($$PromptLogsTableFilterComposer f) f,
  ) {
    final $$PromptLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.promptLogs,
      getReferencedColumn: (t) => t.syllabusItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PromptLogsTableFilterComposer(
            $db: $db,
            $table: $db.promptLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SyllabusItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyllabusItemsTable> {
  $$SyllabusItemsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetCards => $composableBuilder(
    column: $table.targetCards,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rounds => $composableBuilder(
    column: $table.rounds,
    builder: (column) => ColumnOrderings(column),
  );

  $$DomainsTableOrderingComposer get domainId {
    final $$DomainsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableOrderingComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyllabusItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyllabusItemsTable> {
  $$SyllabusItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get targetCards => $composableBuilder(
    column: $table.targetCards,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rounds =>
      $composableBuilder(column: $table.rounds, builder: (column) => column);

  $$DomainsTableAnnotationComposer get domainId {
    final $$DomainsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableAnnotationComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.syllabusItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> promptLogsRefs<T extends Object>(
    Expression<T> Function($$PromptLogsTableAnnotationComposer a) f,
  ) {
    final $$PromptLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.promptLogs,
      getReferencedColumn: (t) => t.syllabusItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PromptLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.promptLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SyllabusItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyllabusItemsTable,
          SyllabusItem,
          $$SyllabusItemsTableFilterComposer,
          $$SyllabusItemsTableOrderingComposer,
          $$SyllabusItemsTableAnnotationComposer,
          $$SyllabusItemsTableCreateCompanionBuilder,
          $$SyllabusItemsTableUpdateCompanionBuilder,
          (SyllabusItem, $$SyllabusItemsTableReferences),
          SyllabusItem,
          PrefetchHooks Function({
            bool domainId,
            bool notesRefs,
            bool promptLogsRefs,
          })
        > {
  $$SyllabusItemsTableTableManager(_$AppDatabase db, $SyllabusItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyllabusItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyllabusItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyllabusItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> domainId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> targetCards = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> rounds = const Value.absent(),
              }) => SyllabusItemsCompanion(
                id: id,
                domainId: domainId,
                title: title,
                level: level,
                position: position,
                status: status,
                targetCards: targetCards,
                description: description,
                rounds: rounds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int domainId,
                required String title,
                Value<int> level = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> targetCards = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> rounds = const Value.absent(),
              }) => SyllabusItemsCompanion.insert(
                id: id,
                domainId: domainId,
                title: title,
                level: level,
                position: position,
                status: status,
                targetCards: targetCards,
                description: description,
                rounds: rounds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyllabusItemsTable, SyllabusItem>(table),
                  $$SyllabusItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({domainId = false, notesRefs = false, promptLogsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (notesRefs) db.notes,
                    if (promptLogsRefs) db.promptLogs,
                  ],
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
                        if (domainId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.domainId,
                            referencedTable: $$SyllabusItemsTableReferences
                                ._domainIdTable(db),
                            referencedColumn: $$SyllabusItemsTableReferences
                                ._domainIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (notesRefs)
                        await $_getPrefetchedData<
                          SyllabusItem,
                          $SyllabusItemsTable,
                          Note
                        >(
                          currentTable: table,
                          referencedTable: $$SyllabusItemsTableReferences
                              ._notesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SyllabusItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).notesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.syllabusItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (promptLogsRefs)
                        await $_getPrefetchedData<
                          SyllabusItem,
                          $SyllabusItemsTable,
                          PromptLog
                        >(
                          currentTable: table,
                          referencedTable: $$SyllabusItemsTableReferences
                              ._promptLogsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SyllabusItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).promptLogsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.syllabusItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SyllabusItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyllabusItemsTable,
      SyllabusItem,
      $$SyllabusItemsTableFilterComposer,
      $$SyllabusItemsTableOrderingComposer,
      $$SyllabusItemsTableAnnotationComposer,
      $$SyllabusItemsTableCreateCompanionBuilder,
      $$SyllabusItemsTableUpdateCompanionBuilder,
      (SyllabusItem, $$SyllabusItemsTableReferences),
      SyllabusItem,
      PrefetchHooks Function({
        bool domainId,
        bool notesRefs,
        bool promptLogsRefs,
      })
    >;
typedef $$SyllabusPrereqsTableCreateCompanionBuilder =
    SyllabusPrereqsCompanion Function({
      required int itemId,
      required int prereqId,
      Value<int> rowid,
    });
typedef $$SyllabusPrereqsTableUpdateCompanionBuilder =
    SyllabusPrereqsCompanion Function({
      Value<int> itemId,
      Value<int> prereqId,
      Value<int> rowid,
    });

final class $$SyllabusPrereqsTableReferences
    extends
        BaseReferences<_$AppDatabase, $SyllabusPrereqsTable, SyllabusPrereq> {
  $$SyllabusPrereqsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SyllabusItemsTable _itemIdTable(_$AppDatabase db) => db.syllabusItems
      .createAlias('syllabus_prereq__item_id__syllabus_item__id');

  $$SyllabusItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<int>('item_id')!;

    final manager = $$SyllabusItemsTableTableManager(
      $_db,
      $_db.syllabusItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SyllabusItemsTable _prereqIdTable(_$AppDatabase db) => db
      .syllabusItems
      .createAlias('syllabus_prereq__prereq_id__syllabus_item__id');

  $$SyllabusItemsTableProcessedTableManager get prereqId {
    final $_column = $_itemColumn<int>('prereq_id')!;

    final manager = $$SyllabusItemsTableTableManager(
      $_db,
      $_db.syllabusItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_prereqIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SyllabusPrereqsTableFilterComposer
    extends Composer<_$AppDatabase, $SyllabusPrereqsTable> {
  $$SyllabusPrereqsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SyllabusItemsTableFilterComposer get itemId {
    final $$SyllabusItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableFilterComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SyllabusItemsTableFilterComposer get prereqId {
    final $$SyllabusItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prereqId,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableFilterComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyllabusPrereqsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyllabusPrereqsTable> {
  $$SyllabusPrereqsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SyllabusItemsTableOrderingComposer get itemId {
    final $$SyllabusItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableOrderingComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SyllabusItemsTableOrderingComposer get prereqId {
    final $$SyllabusItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prereqId,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableOrderingComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyllabusPrereqsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyllabusPrereqsTable> {
  $$SyllabusPrereqsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SyllabusItemsTableAnnotationComposer get itemId {
    final $$SyllabusItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SyllabusItemsTableAnnotationComposer get prereqId {
    final $$SyllabusItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prereqId,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyllabusPrereqsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyllabusPrereqsTable,
          SyllabusPrereq,
          $$SyllabusPrereqsTableFilterComposer,
          $$SyllabusPrereqsTableOrderingComposer,
          $$SyllabusPrereqsTableAnnotationComposer,
          $$SyllabusPrereqsTableCreateCompanionBuilder,
          $$SyllabusPrereqsTableUpdateCompanionBuilder,
          (SyllabusPrereq, $$SyllabusPrereqsTableReferences),
          SyllabusPrereq,
          PrefetchHooks Function({bool itemId, bool prereqId})
        > {
  $$SyllabusPrereqsTableTableManager(
    _$AppDatabase db,
    $SyllabusPrereqsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyllabusPrereqsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyllabusPrereqsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyllabusPrereqsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> itemId = const Value.absent(),
                Value<int> prereqId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyllabusPrereqsCompanion(
                itemId: itemId,
                prereqId: prereqId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int itemId,
                required int prereqId,
                Value<int> rowid = const Value.absent(),
              }) => SyllabusPrereqsCompanion.insert(
                itemId: itemId,
                prereqId: prereqId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyllabusPrereqsTable, SyllabusPrereq>(table),
                  $$SyllabusPrereqsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false, prereqId = false}) {
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
                    if (itemId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.itemId,
                        referencedTable: $$SyllabusPrereqsTableReferences
                            ._itemIdTable(db),
                        referencedColumn: $$SyllabusPrereqsTableReferences
                            ._itemIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (prereqId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.prereqId,
                        referencedTable: $$SyllabusPrereqsTableReferences
                            ._prereqIdTable(db),
                        referencedColumn: $$SyllabusPrereqsTableReferences
                            ._prereqIdTable(db)
                            .id,
                      ) as T;
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

typedef $$SyllabusPrereqsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyllabusPrereqsTable,
      SyllabusPrereq,
      $$SyllabusPrereqsTableFilterComposer,
      $$SyllabusPrereqsTableOrderingComposer,
      $$SyllabusPrereqsTableAnnotationComposer,
      $$SyllabusPrereqsTableCreateCompanionBuilder,
      $$SyllabusPrereqsTableUpdateCompanionBuilder,
      (SyllabusPrereq, $$SyllabusPrereqsTableReferences),
      SyllabusPrereq,
      PrefetchHooks Function({bool itemId, bool prereqId})
    >;
typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  Value<int> id,
  required String guid,
  required int domainId,
  Value<int?> syllabusItemId,
  required String type,
  required String fieldsJson,
  Value<String> tags,
  Value<String?> sourceType,
  Value<String?> sourceRef,
  Value<String?> llmConfidence,
  required int createdAt,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<int> id,
  Value<String> guid,
  Value<int> domainId,
  Value<int?> syllabusItemId,
  Value<String> type,
  Value<String> fieldsJson,
  Value<String> tags,
  Value<String?> sourceType,
  Value<String?> sourceRef,
  Value<String?> llmConfidence,
  Value<int> createdAt,
});

final class $$NotesTableReferences
    extends BaseReferences<_$AppDatabase, $NotesTable, Note> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DomainsTable _domainIdTable(_$AppDatabase db) =>
      db.domains.createAlias('note__domain_id__domain__id');

  $$DomainsTableProcessedTableManager get domainId {
    final $_column = $_itemColumn<int>('domain_id')!;

    final manager = $$DomainsTableTableManager(
      $_db,
      $_db.domains,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_domainIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SyllabusItemsTable _syllabusItemIdTable(_$AppDatabase db) =>
      db.syllabusItems.createAlias('note__syllabus_item_id__syllabus_item__id');

  $$SyllabusItemsTableProcessedTableManager? get syllabusItemId {
    final $_column = $_itemColumn<int>('syllabus_item_id');
    if ($_column == null) return null;
    final manager = $$SyllabusItemsTableTableManager(
      $_db,
      $_db.syllabusItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_syllabusItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CardsTable, List<Card>> _cardsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cards,
    aliasName: 'note__id__card__note_id',
  );

  $$CardsTableProcessedTableManager get cardsRefs {
    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
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

  ColumnFilters<String> get guid => $composableBuilder(
    column: $table.guid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldsJson => $composableBuilder(
    column: $table.fieldsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get llmConfidence => $composableBuilder(
    column: $table.llmConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DomainsTableFilterComposer get domainId {
    final $$DomainsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableFilterComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SyllabusItemsTableFilterComposer get syllabusItemId {
    final $$SyllabusItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.syllabusItemId,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableFilterComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> cardsRefs(
    Expression<bool> Function($$CardsTableFilterComposer f) f,
  ) {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
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

  ColumnOrderings<String> get guid => $composableBuilder(
    column: $table.guid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldsJson => $composableBuilder(
    column: $table.fieldsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get llmConfidence => $composableBuilder(
    column: $table.llmConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DomainsTableOrderingComposer get domainId {
    final $$DomainsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableOrderingComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SyllabusItemsTableOrderingComposer get syllabusItemId {
    final $$SyllabusItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.syllabusItemId,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableOrderingComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get guid =>
      $composableBuilder(column: $table.guid, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get fieldsJson => $composableBuilder(
    column: $table.fieldsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => column);

  GeneratedColumn<String> get llmConfidence => $composableBuilder(
    column: $table.llmConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$DomainsTableAnnotationComposer get domainId {
    final $$DomainsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableAnnotationComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SyllabusItemsTableAnnotationComposer get syllabusItemId {
    final $$SyllabusItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.syllabusItemId,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> cardsRefs<T extends Object>(
    Expression<T> Function($$CardsTableAnnotationComposer a) f,
  ) {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, $$NotesTableReferences),
          Note,
          PrefetchHooks Function({
            bool domainId,
            bool syllabusItemId,
            bool cardsRefs,
          })
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> guid = const Value.absent(),
                Value<int> domainId = const Value.absent(),
                Value<int?> syllabusItemId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> fieldsJson = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String?> sourceType = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                Value<String?> llmConfidence = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                guid: guid,
                domainId: domainId,
                syllabusItemId: syllabusItemId,
                type: type,
                fieldsJson: fieldsJson,
                tags: tags,
                sourceType: sourceType,
                sourceRef: sourceRef,
                llmConfidence: llmConfidence,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String guid,
                required int domainId,
                Value<int?> syllabusItemId = const Value.absent(),
                required String type,
                required String fieldsJson,
                Value<String> tags = const Value.absent(),
                Value<String?> sourceType = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                Value<String?> llmConfidence = const Value.absent(),
                required int createdAt,
              }) => NotesCompanion.insert(
                id: id,
                guid: guid,
                domainId: domainId,
                syllabusItemId: syllabusItemId,
                type: type,
                fieldsJson: fieldsJson,
                tags: tags,
                sourceType: sourceType,
                sourceRef: sourceRef,
                llmConfidence: llmConfidence,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotesTable, Note>(table),
                  $$NotesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({domainId = false, syllabusItemId = false, cardsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (cardsRefs) db.cards],
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
                        if (domainId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.domainId,
                            referencedTable: $$NotesTableReferences
                                ._domainIdTable(db),
                            referencedColumn: $$NotesTableReferences
                                ._domainIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (syllabusItemId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.syllabusItemId,
                            referencedTable: $$NotesTableReferences
                                ._syllabusItemIdTable(db),
                            referencedColumn: $$NotesTableReferences
                                ._syllabusItemIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cardsRefs)
                        await $_getPrefetchedData<Note, $NotesTable, Card>(
                          currentTable: table,
                          referencedTable: $$NotesTableReferences
                              ._cardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableReferences(db, table, p0).cardsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, $$NotesTableReferences),
      Note,
      PrefetchHooks Function({
        bool domainId,
        bool syllabusItemId,
        bool cardsRefs,
      })
    >;
typedef $$CardsTableCreateCompanionBuilder = CardsCompanion Function({
  Value<int> id,
  required int noteId,
  Value<int> ord,
  Value<String> state,
  Value<int> step,
  required int due,
  Value<double?> stability,
  Value<double?> difficulty,
  Value<int> reps,
  Value<int> lapses,
  Value<int?> lastReview,
  Value<bool> suspended,
  Value<int?> buriedUntil,
});
typedef $$CardsTableUpdateCompanionBuilder = CardsCompanion Function({
  Value<int> id,
  Value<int> noteId,
  Value<int> ord,
  Value<String> state,
  Value<int> step,
  Value<int> due,
  Value<double?> stability,
  Value<double?> difficulty,
  Value<int> reps,
  Value<int> lapses,
  Value<int?> lastReview,
  Value<bool> suspended,
  Value<int?> buriedUntil,
});

final class $$CardsTableReferences
    extends BaseReferences<_$AppDatabase, $CardsTable, Card> {
  $$CardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NotesTable _noteIdTable(_$AppDatabase db) =>
      db.notes.createAlias('card__note_id__note__id');

  $$NotesTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<int>('note_id')!;

    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ReviewLogsTable, List<ReviewLog>>
  _reviewLogsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reviewLogs,
    aliasName: 'card__id__review_log__card_id',
  );

  $$ReviewLogsTableProcessedTableManager get reviewLogsRefs {
    final manager = $$ReviewLogsTableTableManager(
      $_db,
      $_db.reviewLogs,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_reviewLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CardsTableFilterComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
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

  ColumnFilters<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get step => $composableBuilder(
    column: $table.step,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get suspended => $composableBuilder(
    column: $table.suspended,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get buriedUntil => $composableBuilder(
    column: $table.buriedUntil,
    builder: (column) => ColumnFilters(column),
  );

  $$NotesTableFilterComposer get noteId {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> reviewLogsRefs(
    Expression<bool> Function($$ReviewLogsTableFilterComposer f) f,
  ) {
    final $$ReviewLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewLogs,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewLogsTableFilterComposer(
            $db: $db,
            $table: $db.reviewLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
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

  ColumnOrderings<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get step => $composableBuilder(
    column: $table.step,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get suspended => $composableBuilder(
    column: $table.suspended,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get buriedUntil => $composableBuilder(
    column: $table.buriedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotesTableOrderingComposer get noteId {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableOrderingComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get step =>
      $composableBuilder(column: $table.step, builder: (column) => column);

  GeneratedColumn<int> get due =>
      $composableBuilder(column: $table.due, builder: (column) => column);

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<int> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get suspended =>
      $composableBuilder(column: $table.suspended, builder: (column) => column);

  GeneratedColumn<int> get buriedUntil => $composableBuilder(
    column: $table.buriedUntil,
    builder: (column) => column,
  );

  $$NotesTableAnnotationComposer get noteId {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> reviewLogsRefs<T extends Object>(
    Expression<T> Function($$ReviewLogsTableAnnotationComposer a) f,
  ) {
    final $$ReviewLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewLogs,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardsTable,
          Card,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (Card, $$CardsTableReferences),
          Card,
          PrefetchHooks Function({bool noteId, bool reviewLogsRefs})
        > {
  $$CardsTableTableManager(_$AppDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> noteId = const Value.absent(),
                Value<int> ord = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> step = const Value.absent(),
                Value<int> due = const Value.absent(),
                Value<double?> stability = const Value.absent(),
                Value<double?> difficulty = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int?> lastReview = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
                Value<int?> buriedUntil = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                noteId: noteId,
                ord: ord,
                state: state,
                step: step,
                due: due,
                stability: stability,
                difficulty: difficulty,
                reps: reps,
                lapses: lapses,
                lastReview: lastReview,
                suspended: suspended,
                buriedUntil: buriedUntil,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int noteId,
                Value<int> ord = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> step = const Value.absent(),
                required int due,
                Value<double?> stability = const Value.absent(),
                Value<double?> difficulty = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int?> lastReview = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
                Value<int?> buriedUntil = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                noteId: noteId,
                ord: ord,
                state: state,
                step: step,
                due: due,
                stability: stability,
                difficulty: difficulty,
                reps: reps,
                lapses: lapses,
                lastReview: lastReview,
                suspended: suspended,
                buriedUntil: buriedUntil,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardsTable, Card>(table),
                  $$CardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false, reviewLogsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (reviewLogsRefs) db.reviewLogs],
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
                    if (noteId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.noteId,
                        referencedTable: $$CardsTableReferences._noteIdTable(
                          db,
                        ),
                        referencedColumn: $$CardsTableReferences
                            ._noteIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (reviewLogsRefs)
                    await $_getPrefetchedData<Card, $CardsTable, ReviewLog>(
                      currentTable: table,
                      referencedTable: $$CardsTableReferences
                          ._reviewLogsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CardsTableReferences(db, table, p0).reviewLogsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.cardId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardsTable,
      Card,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (Card, $$CardsTableReferences),
      Card,
      PrefetchHooks Function({bool noteId, bool reviewLogsRefs})
    >;
typedef $$FsrsParamsTableTableCreateCompanionBuilder =
    FsrsParamsTableCompanion Function({
      Value<int> id,
      required int createdAt,
      required String version,
      required String paramsJson,
      required double desiredRetention,
    });
typedef $$FsrsParamsTableTableUpdateCompanionBuilder =
    FsrsParamsTableCompanion Function({
      Value<int> id,
      Value<int> createdAt,
      Value<String> version,
      Value<String> paramsJson,
      Value<double> desiredRetention,
    });

final class $$FsrsParamsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FsrsParamsTableTable,
          FsrsParamsTableData
        > {
  $$FsrsParamsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ReviewLogsTable, List<ReviewLog>>
  _reviewLogsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reviewLogs,
    aliasName: 'fsrs_params__id__review_log__params_id',
  );

  $$ReviewLogsTableProcessedTableManager get reviewLogsRefs {
    final manager = $$ReviewLogsTableTableManager(
      $_db,
      $_db.reviewLogs,
    ).filter((f) => f.paramsId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_reviewLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FsrsParamsTableTableFilterComposer
    extends Composer<_$AppDatabase, $FsrsParamsTableTable> {
  $$FsrsParamsTableTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paramsJson => $composableBuilder(
    column: $table.paramsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get desiredRetention => $composableBuilder(
    column: $table.desiredRetention,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> reviewLogsRefs(
    Expression<bool> Function($$ReviewLogsTableFilterComposer f) f,
  ) {
    final $$ReviewLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewLogs,
      getReferencedColumn: (t) => t.paramsId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewLogsTableFilterComposer(
            $db: $db,
            $table: $db.reviewLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FsrsParamsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FsrsParamsTableTable> {
  $$FsrsParamsTableTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paramsJson => $composableBuilder(
    column: $table.paramsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get desiredRetention => $composableBuilder(
    column: $table.desiredRetention,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FsrsParamsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FsrsParamsTableTable> {
  $$FsrsParamsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get paramsJson => $composableBuilder(
    column: $table.paramsJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get desiredRetention => $composableBuilder(
    column: $table.desiredRetention,
    builder: (column) => column,
  );

  Expression<T> reviewLogsRefs<T extends Object>(
    Expression<T> Function($$ReviewLogsTableAnnotationComposer a) f,
  ) {
    final $$ReviewLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewLogs,
      getReferencedColumn: (t) => t.paramsId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FsrsParamsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FsrsParamsTableTable,
          FsrsParamsTableData,
          $$FsrsParamsTableTableFilterComposer,
          $$FsrsParamsTableTableOrderingComposer,
          $$FsrsParamsTableTableAnnotationComposer,
          $$FsrsParamsTableTableCreateCompanionBuilder,
          $$FsrsParamsTableTableUpdateCompanionBuilder,
          (FsrsParamsTableData, $$FsrsParamsTableTableReferences),
          FsrsParamsTableData,
          PrefetchHooks Function({bool reviewLogsRefs})
        > {
  $$FsrsParamsTableTableTableManager(
    _$AppDatabase db,
    $FsrsParamsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FsrsParamsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FsrsParamsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FsrsParamsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> paramsJson = const Value.absent(),
                Value<double> desiredRetention = const Value.absent(),
              }) => FsrsParamsTableCompanion(
                id: id,
                createdAt: createdAt,
                version: version,
                paramsJson: paramsJson,
                desiredRetention: desiredRetention,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int createdAt,
                required String version,
                required String paramsJson,
                required double desiredRetention,
              }) => FsrsParamsTableCompanion.insert(
                id: id,
                createdAt: createdAt,
                version: version,
                paramsJson: paramsJson,
                desiredRetention: desiredRetention,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FsrsParamsTableTable, FsrsParamsTableData>(
                    table,
                  ),
                  $$FsrsParamsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({reviewLogsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (reviewLogsRefs) db.reviewLogs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (reviewLogsRefs)
                    await $_getPrefetchedData<
                      FsrsParamsTableData,
                      $FsrsParamsTableTable,
                      ReviewLog
                    >(
                      currentTable: table,
                      referencedTable: $$FsrsParamsTableTableReferences
                          ._reviewLogsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FsrsParamsTableTableReferences(
                            db,
                            table,
                            p0,
                          ).reviewLogsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.paramsId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FsrsParamsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FsrsParamsTableTable,
      FsrsParamsTableData,
      $$FsrsParamsTableTableFilterComposer,
      $$FsrsParamsTableTableOrderingComposer,
      $$FsrsParamsTableTableAnnotationComposer,
      $$FsrsParamsTableTableCreateCompanionBuilder,
      $$FsrsParamsTableTableUpdateCompanionBuilder,
      (FsrsParamsTableData, $$FsrsParamsTableTableReferences),
      FsrsParamsTableData,
      PrefetchHooks Function({bool reviewLogsRefs})
    >;
typedef $$ReviewLogsTableCreateCompanionBuilder = ReviewLogsCompanion Function({
  Value<int> id,
  required int cardId,
  required int reviewedAt,
  required int rating,
  Value<int> durationMs,
  required String stateBefore,
  required int dueBefore,
  Value<double?> stabilityBefore,
  Value<double?> difficultyBefore,
  required double elapsedDays,
  required double scheduledDays,
  required String fsrsVersion,
  required int paramsId,
  Value<int?> revokedAt,
});
typedef $$ReviewLogsTableUpdateCompanionBuilder = ReviewLogsCompanion Function({
  Value<int> id,
  Value<int> cardId,
  Value<int> reviewedAt,
  Value<int> rating,
  Value<int> durationMs,
  Value<String> stateBefore,
  Value<int> dueBefore,
  Value<double?> stabilityBefore,
  Value<double?> difficultyBefore,
  Value<double> elapsedDays,
  Value<double> scheduledDays,
  Value<String> fsrsVersion,
  Value<int> paramsId,
  Value<int?> revokedAt,
});

final class $$ReviewLogsTableReferences
    extends BaseReferences<_$AppDatabase, $ReviewLogsTable, ReviewLog> {
  $$ReviewLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardIdTable(_$AppDatabase db) =>
      db.cards.createAlias('review_log__card_id__card__id');

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FsrsParamsTableTable _paramsIdTable(_$AppDatabase db) =>
      db.fsrsParamsTable.createAlias('review_log__params_id__fsrs_params__id');

  $$FsrsParamsTableTableProcessedTableManager get paramsId {
    final $_column = $_itemColumn<int>('params_id')!;

    final manager = $$FsrsParamsTableTableTableManager(
      $_db,
      $_db.fsrsParamsTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_paramsIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReviewLogsTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableFilterComposer({
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

  ColumnFilters<int> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueBefore => $composableBuilder(
    column: $table.dueBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stabilityBefore => $composableBuilder(
    column: $table.stabilityBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficultyBefore => $composableBuilder(
    column: $table.difficultyBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fsrsVersion => $composableBuilder(
    column: $table.fsrsVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revokedAt => $composableBuilder(
    column: $table.revokedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FsrsParamsTableTableFilterComposer get paramsId {
    final $$FsrsParamsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paramsId,
      referencedTable: $db.fsrsParamsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FsrsParamsTableTableFilterComposer(
            $db: $db,
            $table: $db.fsrsParamsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableOrderingComposer({
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

  ColumnOrderings<int> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueBefore => $composableBuilder(
    column: $table.dueBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stabilityBefore => $composableBuilder(
    column: $table.stabilityBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficultyBefore => $composableBuilder(
    column: $table.difficultyBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fsrsVersion => $composableBuilder(
    column: $table.fsrsVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revokedAt => $composableBuilder(
    column: $table.revokedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FsrsParamsTableTableOrderingComposer get paramsId {
    final $$FsrsParamsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paramsId,
      referencedTable: $db.fsrsParamsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FsrsParamsTableTableOrderingComposer(
            $db: $db,
            $table: $db.fsrsParamsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueBefore =>
      $composableBuilder(column: $table.dueBefore, builder: (column) => column);

  GeneratedColumn<double> get stabilityBefore => $composableBuilder(
    column: $table.stabilityBefore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get difficultyBefore => $composableBuilder(
    column: $table.difficultyBefore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fsrsVersion => $composableBuilder(
    column: $table.fsrsVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revokedAt =>
      $composableBuilder(column: $table.revokedAt, builder: (column) => column);

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FsrsParamsTableTableAnnotationComposer get paramsId {
    final $$FsrsParamsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paramsId,
      referencedTable: $db.fsrsParamsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FsrsParamsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.fsrsParamsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewLogsTable,
          ReviewLog,
          $$ReviewLogsTableFilterComposer,
          $$ReviewLogsTableOrderingComposer,
          $$ReviewLogsTableAnnotationComposer,
          $$ReviewLogsTableCreateCompanionBuilder,
          $$ReviewLogsTableUpdateCompanionBuilder,
          (ReviewLog, $$ReviewLogsTableReferences),
          ReviewLog,
          PrefetchHooks Function({bool cardId, bool paramsId})
        > {
  $$ReviewLogsTableTableManager(_$AppDatabase db, $ReviewLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cardId = const Value.absent(),
                Value<int> reviewedAt = const Value.absent(),
                Value<int> rating = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> stateBefore = const Value.absent(),
                Value<int> dueBefore = const Value.absent(),
                Value<double?> stabilityBefore = const Value.absent(),
                Value<double?> difficultyBefore = const Value.absent(),
                Value<double> elapsedDays = const Value.absent(),
                Value<double> scheduledDays = const Value.absent(),
                Value<String> fsrsVersion = const Value.absent(),
                Value<int> paramsId = const Value.absent(),
                Value<int?> revokedAt = const Value.absent(),
              }) => ReviewLogsCompanion(
                id: id,
                cardId: cardId,
                reviewedAt: reviewedAt,
                rating: rating,
                durationMs: durationMs,
                stateBefore: stateBefore,
                dueBefore: dueBefore,
                stabilityBefore: stabilityBefore,
                difficultyBefore: difficultyBefore,
                elapsedDays: elapsedDays,
                scheduledDays: scheduledDays,
                fsrsVersion: fsrsVersion,
                paramsId: paramsId,
                revokedAt: revokedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int cardId,
                required int reviewedAt,
                required int rating,
                Value<int> durationMs = const Value.absent(),
                required String stateBefore,
                required int dueBefore,
                Value<double?> stabilityBefore = const Value.absent(),
                Value<double?> difficultyBefore = const Value.absent(),
                required double elapsedDays,
                required double scheduledDays,
                required String fsrsVersion,
                required int paramsId,
                Value<int?> revokedAt = const Value.absent(),
              }) => ReviewLogsCompanion.insert(
                id: id,
                cardId: cardId,
                reviewedAt: reviewedAt,
                rating: rating,
                durationMs: durationMs,
                stateBefore: stateBefore,
                dueBefore: dueBefore,
                stabilityBefore: stabilityBefore,
                difficultyBefore: difficultyBefore,
                elapsedDays: elapsedDays,
                scheduledDays: scheduledDays,
                fsrsVersion: fsrsVersion,
                paramsId: paramsId,
                revokedAt: revokedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewLogsTable, ReviewLog>(table),
                  $$ReviewLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false, paramsId = false}) {
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
                    if (cardId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cardId,
                        referencedTable: $$ReviewLogsTableReferences
                            ._cardIdTable(db),
                        referencedColumn: $$ReviewLogsTableReferences
                            ._cardIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (paramsId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.paramsId,
                        referencedTable: $$ReviewLogsTableReferences
                            ._paramsIdTable(db),
                        referencedColumn: $$ReviewLogsTableReferences
                            ._paramsIdTable(db)
                            .id,
                      ) as T;
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

typedef $$ReviewLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewLogsTable,
      ReviewLog,
      $$ReviewLogsTableFilterComposer,
      $$ReviewLogsTableOrderingComposer,
      $$ReviewLogsTableAnnotationComposer,
      $$ReviewLogsTableCreateCompanionBuilder,
      $$ReviewLogsTableUpdateCompanionBuilder,
      (ReviewLog, $$ReviewLogsTableReferences),
      ReviewLog,
      PrefetchHooks Function({bool cardId, bool paramsId})
    >;
typedef $$PromptLogsTableCreateCompanionBuilder = PromptLogsCompanion Function({
  Value<int> id,
  required int createdAt,
  required int domainId,
  Value<int?> syllabusItemId,
  required String templateVersion,
  required String promptText,
  required int cardsRequested,
  Value<int> cardsImported,
  Value<String> status,
});
typedef $$PromptLogsTableUpdateCompanionBuilder = PromptLogsCompanion Function({
  Value<int> id,
  Value<int> createdAt,
  Value<int> domainId,
  Value<int?> syllabusItemId,
  Value<String> templateVersion,
  Value<String> promptText,
  Value<int> cardsRequested,
  Value<int> cardsImported,
  Value<String> status,
});

final class $$PromptLogsTableReferences
    extends BaseReferences<_$AppDatabase, $PromptLogsTable, PromptLog> {
  $$PromptLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DomainsTable _domainIdTable(_$AppDatabase db) =>
      db.domains.createAlias('prompt_log__domain_id__domain__id');

  $$DomainsTableProcessedTableManager get domainId {
    final $_column = $_itemColumn<int>('domain_id')!;

    final manager = $$DomainsTableTableManager(
      $_db,
      $_db.domains,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_domainIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SyllabusItemsTable _syllabusItemIdTable(_$AppDatabase db) => db
      .syllabusItems
      .createAlias('prompt_log__syllabus_item_id__syllabus_item__id');

  $$SyllabusItemsTableProcessedTableManager? get syllabusItemId {
    final $_column = $_itemColumn<int>('syllabus_item_id');
    if ($_column == null) return null;
    final manager = $$SyllabusItemsTableTableManager(
      $_db,
      $_db.syllabusItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_syllabusItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PromptLogsTableFilterComposer
    extends Composer<_$AppDatabase, $PromptLogsTable> {
  $$PromptLogsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateVersion => $composableBuilder(
    column: $table.templateVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promptText => $composableBuilder(
    column: $table.promptText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cardsRequested => $composableBuilder(
    column: $table.cardsRequested,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cardsImported => $composableBuilder(
    column: $table.cardsImported,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  $$DomainsTableFilterComposer get domainId {
    final $$DomainsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableFilterComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SyllabusItemsTableFilterComposer get syllabusItemId {
    final $$SyllabusItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.syllabusItemId,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableFilterComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PromptLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $PromptLogsTable> {
  $$PromptLogsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateVersion => $composableBuilder(
    column: $table.templateVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promptText => $composableBuilder(
    column: $table.promptText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cardsRequested => $composableBuilder(
    column: $table.cardsRequested,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cardsImported => $composableBuilder(
    column: $table.cardsImported,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$DomainsTableOrderingComposer get domainId {
    final $$DomainsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableOrderingComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SyllabusItemsTableOrderingComposer get syllabusItemId {
    final $$SyllabusItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.syllabusItemId,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableOrderingComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PromptLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PromptLogsTable> {
  $$PromptLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get templateVersion => $composableBuilder(
    column: $table.templateVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get promptText => $composableBuilder(
    column: $table.promptText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cardsRequested => $composableBuilder(
    column: $table.cardsRequested,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cardsImported => $composableBuilder(
    column: $table.cardsImported,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$DomainsTableAnnotationComposer get domainId {
    final $$DomainsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableAnnotationComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SyllabusItemsTableAnnotationComposer get syllabusItemId {
    final $$SyllabusItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.syllabusItemId,
      referencedTable: $db.syllabusItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyllabusItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.syllabusItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PromptLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PromptLogsTable,
          PromptLog,
          $$PromptLogsTableFilterComposer,
          $$PromptLogsTableOrderingComposer,
          $$PromptLogsTableAnnotationComposer,
          $$PromptLogsTableCreateCompanionBuilder,
          $$PromptLogsTableUpdateCompanionBuilder,
          (PromptLog, $$PromptLogsTableReferences),
          PromptLog,
          PrefetchHooks Function({bool domainId, bool syllabusItemId})
        > {
  $$PromptLogsTableTableManager(_$AppDatabase db, $PromptLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PromptLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PromptLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PromptLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> domainId = const Value.absent(),
                Value<int?> syllabusItemId = const Value.absent(),
                Value<String> templateVersion = const Value.absent(),
                Value<String> promptText = const Value.absent(),
                Value<int> cardsRequested = const Value.absent(),
                Value<int> cardsImported = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => PromptLogsCompanion(
                id: id,
                createdAt: createdAt,
                domainId: domainId,
                syllabusItemId: syllabusItemId,
                templateVersion: templateVersion,
                promptText: promptText,
                cardsRequested: cardsRequested,
                cardsImported: cardsImported,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int createdAt,
                required int domainId,
                Value<int?> syllabusItemId = const Value.absent(),
                required String templateVersion,
                required String promptText,
                required int cardsRequested,
                Value<int> cardsImported = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => PromptLogsCompanion.insert(
                id: id,
                createdAt: createdAt,
                domainId: domainId,
                syllabusItemId: syllabusItemId,
                templateVersion: templateVersion,
                promptText: promptText,
                cardsRequested: cardsRequested,
                cardsImported: cardsImported,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PromptLogsTable, PromptLog>(table),
                  $$PromptLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({domainId = false, syllabusItemId = false}) {
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
                    if (domainId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.domainId,
                        referencedTable: $$PromptLogsTableReferences
                            ._domainIdTable(db),
                        referencedColumn: $$PromptLogsTableReferences
                            ._domainIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (syllabusItemId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.syllabusItemId,
                        referencedTable: $$PromptLogsTableReferences
                            ._syllabusItemIdTable(db),
                        referencedColumn: $$PromptLogsTableReferences
                            ._syllabusItemIdTable(db)
                            .id,
                      ) as T;
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

typedef $$PromptLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PromptLogsTable,
      PromptLog,
      $$PromptLogsTableFilterComposer,
      $$PromptLogsTableOrderingComposer,
      $$PromptLogsTableAnnotationComposer,
      $$PromptLogsTableCreateCompanionBuilder,
      $$PromptLogsTableUpdateCompanionBuilder,
      (PromptLog, $$PromptLogsTableReferences),
      PromptLog,
      PrefetchHooks Function({bool domainId, bool syllabusItemId})
    >;
typedef $$InterestLogsTableCreateCompanionBuilder =
    InterestLogsCompanion Function({
      Value<int> id,
      required int ts,
      required int domainId,
      required int value,
    });
typedef $$InterestLogsTableUpdateCompanionBuilder =
    InterestLogsCompanion Function({
      Value<int> id,
      Value<int> ts,
      Value<int> domainId,
      Value<int> value,
    });

final class $$InterestLogsTableReferences
    extends BaseReferences<_$AppDatabase, $InterestLogsTable, InterestLog> {
  $$InterestLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DomainsTable _domainIdTable(_$AppDatabase db) =>
      db.domains.createAlias('interest_log__domain_id__domain__id');

  $$DomainsTableProcessedTableManager get domainId {
    final $_column = $_itemColumn<int>('domain_id')!;

    final manager = $$DomainsTableTableManager(
      $_db,
      $_db.domains,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_domainIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InterestLogsTableFilterComposer
    extends Composer<_$AppDatabase, $InterestLogsTable> {
  $$InterestLogsTableFilterComposer({
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

  ColumnFilters<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  $$DomainsTableFilterComposer get domainId {
    final $$DomainsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableFilterComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InterestLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $InterestLogsTable> {
  $$InterestLogsTableOrderingComposer({
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

  ColumnOrderings<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  $$DomainsTableOrderingComposer get domainId {
    final $$DomainsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableOrderingComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InterestLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InterestLogsTable> {
  $$InterestLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  $$DomainsTableAnnotationComposer get domainId {
    final $$DomainsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableAnnotationComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InterestLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InterestLogsTable,
          InterestLog,
          $$InterestLogsTableFilterComposer,
          $$InterestLogsTableOrderingComposer,
          $$InterestLogsTableAnnotationComposer,
          $$InterestLogsTableCreateCompanionBuilder,
          $$InterestLogsTableUpdateCompanionBuilder,
          (InterestLog, $$InterestLogsTableReferences),
          InterestLog,
          PrefetchHooks Function({bool domainId})
        > {
  $$InterestLogsTableTableManager(_$AppDatabase db, $InterestLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InterestLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InterestLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InterestLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ts = const Value.absent(),
                Value<int> domainId = const Value.absent(),
                Value<int> value = const Value.absent(),
              }) => InterestLogsCompanion(
                id: id,
                ts: ts,
                domainId: domainId,
                value: value,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ts,
                required int domainId,
                required int value,
              }) => InterestLogsCompanion.insert(
                id: id,
                ts: ts,
                domainId: domainId,
                value: value,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InterestLogsTable, InterestLog>(table),
                  $$InterestLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({domainId = false}) {
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
                    if (domainId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.domainId,
                        referencedTable: $$InterestLogsTableReferences
                            ._domainIdTable(db),
                        referencedColumn: $$InterestLogsTableReferences
                            ._domainIdTable(db)
                            .id,
                      ) as T;
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

typedef $$InterestLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InterestLogsTable,
      InterestLog,
      $$InterestLogsTableFilterComposer,
      $$InterestLogsTableOrderingComposer,
      $$InterestLogsTableAnnotationComposer,
      $$InterestLogsTableCreateCompanionBuilder,
      $$InterestLogsTableUpdateCompanionBuilder,
      (InterestLog, $$InterestLogsTableReferences),
      InterestLog,
      PrefetchHooks Function({bool domainId})
    >;
typedef $$EngineDecisionsTableCreateCompanionBuilder =
    EngineDecisionsCompanion Function({
      Value<int> id,
      required int ts,
      required String engineVersion,
      required int seed,
      required String featuresJson,
      required String scoresJson,
      required String chosenJson,
    });
typedef $$EngineDecisionsTableUpdateCompanionBuilder =
    EngineDecisionsCompanion Function({
      Value<int> id,
      Value<int> ts,
      Value<String> engineVersion,
      Value<int> seed,
      Value<String> featuresJson,
      Value<String> scoresJson,
      Value<String> chosenJson,
    });

class $$EngineDecisionsTableFilterComposer
    extends Composer<_$AppDatabase, $EngineDecisionsTable> {
  $$EngineDecisionsTableFilterComposer({
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

  ColumnFilters<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get featuresJson => $composableBuilder(
    column: $table.featuresJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scoresJson => $composableBuilder(
    column: $table.scoresJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chosenJson => $composableBuilder(
    column: $table.chosenJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EngineDecisionsTableOrderingComposer
    extends Composer<_$AppDatabase, $EngineDecisionsTable> {
  $$EngineDecisionsTableOrderingComposer({
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

  ColumnOrderings<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get featuresJson => $composableBuilder(
    column: $table.featuresJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scoresJson => $composableBuilder(
    column: $table.scoresJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chosenJson => $composableBuilder(
    column: $table.chosenJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EngineDecisionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EngineDecisionsTable> {
  $$EngineDecisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seed =>
      $composableBuilder(column: $table.seed, builder: (column) => column);

  GeneratedColumn<String> get featuresJson => $composableBuilder(
    column: $table.featuresJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scoresJson => $composableBuilder(
    column: $table.scoresJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chosenJson => $composableBuilder(
    column: $table.chosenJson,
    builder: (column) => column,
  );
}

class $$EngineDecisionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EngineDecisionsTable,
          EngineDecision,
          $$EngineDecisionsTableFilterComposer,
          $$EngineDecisionsTableOrderingComposer,
          $$EngineDecisionsTableAnnotationComposer,
          $$EngineDecisionsTableCreateCompanionBuilder,
          $$EngineDecisionsTableUpdateCompanionBuilder,
          (
            EngineDecision,
            BaseReferences<
              _$AppDatabase,
              $EngineDecisionsTable,
              EngineDecision
            >,
          ),
          EngineDecision,
          PrefetchHooks Function()
        > {
  $$EngineDecisionsTableTableManager(
    _$AppDatabase db,
    $EngineDecisionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EngineDecisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EngineDecisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EngineDecisionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ts = const Value.absent(),
                Value<String> engineVersion = const Value.absent(),
                Value<int> seed = const Value.absent(),
                Value<String> featuresJson = const Value.absent(),
                Value<String> scoresJson = const Value.absent(),
                Value<String> chosenJson = const Value.absent(),
              }) => EngineDecisionsCompanion(
                id: id,
                ts: ts,
                engineVersion: engineVersion,
                seed: seed,
                featuresJson: featuresJson,
                scoresJson: scoresJson,
                chosenJson: chosenJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ts,
                required String engineVersion,
                required int seed,
                required String featuresJson,
                required String scoresJson,
                required String chosenJson,
              }) => EngineDecisionsCompanion.insert(
                id: id,
                ts: ts,
                engineVersion: engineVersion,
                seed: seed,
                featuresJson: featuresJson,
                scoresJson: scoresJson,
                chosenJson: chosenJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EngineDecisionsTable, EngineDecision>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EngineDecisionsTable,
                    EngineDecision
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EngineDecisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EngineDecisionsTable,
      EngineDecision,
      $$EngineDecisionsTableFilterComposer,
      $$EngineDecisionsTableOrderingComposer,
      $$EngineDecisionsTableAnnotationComposer,
      $$EngineDecisionsTableCreateCompanionBuilder,
      $$EngineDecisionsTableUpdateCompanionBuilder,
      (
        EngineDecision,
        BaseReferences<_$AppDatabase, $EngineDecisionsTable, EngineDecision>,
      ),
      EngineDecision,
      PrefetchHooks Function()
    >;
typedef $$BackupLogsTableCreateCompanionBuilder = BackupLogsCompanion Function({
  Value<int> id,
  required int ts,
  Value<String?> uri,
  Value<int> bytes,
  required bool ok,
  Value<String?> error,
});
typedef $$BackupLogsTableUpdateCompanionBuilder = BackupLogsCompanion Function({
  Value<int> id,
  Value<int> ts,
  Value<String?> uri,
  Value<int> bytes,
  Value<bool> ok,
  Value<String?> error,
});

class $$BackupLogsTableFilterComposer
    extends Composer<_$AppDatabase, $BackupLogsTable> {
  $$BackupLogsTableFilterComposer({
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

  ColumnFilters<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BackupLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $BackupLogsTable> {
  $$BackupLogsTableOrderingComposer({
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

  ColumnOrderings<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BackupLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BackupLogsTable> {
  $$BackupLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<bool> get ok =>
      $composableBuilder(column: $table.ok, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$BackupLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BackupLogsTable,
          BackupLog,
          $$BackupLogsTableFilterComposer,
          $$BackupLogsTableOrderingComposer,
          $$BackupLogsTableAnnotationComposer,
          $$BackupLogsTableCreateCompanionBuilder,
          $$BackupLogsTableUpdateCompanionBuilder,
          (
            BackupLog,
            BaseReferences<_$AppDatabase, $BackupLogsTable, BackupLog>,
          ),
          BackupLog,
          PrefetchHooks Function()
        > {
  $$BackupLogsTableTableManager(_$AppDatabase db, $BackupLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BackupLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BackupLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ts = const Value.absent(),
                Value<String?> uri = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<bool> ok = const Value.absent(),
                Value<String?> error = const Value.absent(),
              }) => BackupLogsCompanion(
                id: id,
                ts: ts,
                uri: uri,
                bytes: bytes,
                ok: ok,
                error: error,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ts,
                Value<String?> uri = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                required bool ok,
                Value<String?> error = const Value.absent(),
              }) => BackupLogsCompanion.insert(
                id: id,
                ts: ts,
                uri: uri,
                bytes: bytes,
                ok: ok,
                error: error,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BackupLogsTable, BackupLog>(table),
                  BaseReferences<_$AppDatabase, $BackupLogsTable, BackupLog>(
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

typedef $$BackupLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BackupLogsTable,
      BackupLog,
      $$BackupLogsTableFilterComposer,
      $$BackupLogsTableOrderingComposer,
      $$BackupLogsTableAnnotationComposer,
      $$BackupLogsTableCreateCompanionBuilder,
      $$BackupLogsTableUpdateCompanionBuilder,
      (BackupLog, BaseReferences<_$AppDatabase, $BackupLogsTable, BackupLog>),
      BackupLog,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
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

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DomainsTableTableManager get domains =>
      $$DomainsTableTableManager(_db, _db.domains);
  $$SyllabusItemsTableTableManager get syllabusItems =>
      $$SyllabusItemsTableTableManager(_db, _db.syllabusItems);
  $$SyllabusPrereqsTableTableManager get syllabusPrereqs =>
      $$SyllabusPrereqsTableTableManager(_db, _db.syllabusPrereqs);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$FsrsParamsTableTableTableManager get fsrsParamsTable =>
      $$FsrsParamsTableTableTableManager(_db, _db.fsrsParamsTable);
  $$ReviewLogsTableTableManager get reviewLogs =>
      $$ReviewLogsTableTableManager(_db, _db.reviewLogs);
  $$PromptLogsTableTableManager get promptLogs =>
      $$PromptLogsTableTableManager(_db, _db.promptLogs);
  $$InterestLogsTableTableManager get interestLogs =>
      $$InterestLogsTableTableManager(_db, _db.interestLogs);
  $$EngineDecisionsTableTableManager get engineDecisions =>
      $$EngineDecisionsTableTableManager(_db, _db.engineDecisions);
  $$BackupLogsTableTableManager get backupLogs =>
      $$BackupLogsTableTableManager(_db, _db.backupLogs);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
