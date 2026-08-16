// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recovery_database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _anonymousUsernameMeta = const VerificationMeta(
    'anonymousUsername',
  );
  @override
  late final GeneratedColumn<String> anonymousUsername =
      GeneratedColumn<String>(
        'anonymous_username',
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
  static const VerificationMeta _biometricLockEnabledMeta =
      const VerificationMeta('biometricLockEnabled');
  @override
  late final GeneratedColumn<bool> biometricLockEnabled = GeneratedColumn<bool>(
    'biometric_lock_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("biometric_lock_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _selectedGoalsMeta = const VerificationMeta(
    'selectedGoals',
  );
  @override
  late final GeneratedColumn<String> selectedGoals = GeneratedColumn<String>(
    'selected_goals',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activePathsMeta = const VerificationMeta(
    'activePaths',
  );
  @override
  late final GeneratedColumn<String> activePaths = GeneratedColumn<String>(
    'active_paths',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedValuesMeta = const VerificationMeta(
    'selectedValues',
  );
  @override
  late final GeneratedColumn<String> selectedValues = GeneratedColumn<String>(
    'selected_values',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    anonymousUsername,
    createdAt,
    biometricLockEnabled,
    selectedGoals,
    activePaths,
    selectedValues,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Profile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('anonymous_username')) {
      context.handle(
        _anonymousUsernameMeta,
        anonymousUsername.isAcceptableOrUnknown(
          data['anonymous_username']!,
          _anonymousUsernameMeta,
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
    if (data.containsKey('biometric_lock_enabled')) {
      context.handle(
        _biometricLockEnabledMeta,
        biometricLockEnabled.isAcceptableOrUnknown(
          data['biometric_lock_enabled']!,
          _biometricLockEnabledMeta,
        ),
      );
    }
    if (data.containsKey('selected_goals')) {
      context.handle(
        _selectedGoalsMeta,
        selectedGoals.isAcceptableOrUnknown(
          data['selected_goals']!,
          _selectedGoalsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selectedGoalsMeta);
    }
    if (data.containsKey('active_paths')) {
      context.handle(
        _activePathsMeta,
        activePaths.isAcceptableOrUnknown(
          data['active_paths']!,
          _activePathsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activePathsMeta);
    }
    if (data.containsKey('selected_values')) {
      context.handle(
        _selectedValuesMeta,
        selectedValues.isAcceptableOrUnknown(
          data['selected_values']!,
          _selectedValuesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      anonymousUsername: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anonymous_username'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      biometricLockEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}biometric_lock_enabled'],
      )!,
      selectedGoals: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_goals'],
      )!,
      activePaths: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_paths'],
      )!,
      selectedValues: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_values'],
      ),
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  final String id;
  final String? anonymousUsername;
  final int createdAt;
  final bool biometricLockEnabled;
  final String selectedGoals;
  final String activePaths;
  final String? selectedValues;
  const Profile({
    required this.id,
    this.anonymousUsername,
    required this.createdAt,
    required this.biometricLockEnabled,
    required this.selectedGoals,
    required this.activePaths,
    this.selectedValues,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || anonymousUsername != null) {
      map['anonymous_username'] = Variable<String>(anonymousUsername);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['biometric_lock_enabled'] = Variable<bool>(biometricLockEnabled);
    map['selected_goals'] = Variable<String>(selectedGoals);
    map['active_paths'] = Variable<String>(activePaths);
    if (!nullToAbsent || selectedValues != null) {
      map['selected_values'] = Variable<String>(selectedValues);
    }
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      anonymousUsername: anonymousUsername == null && nullToAbsent
          ? const Value.absent()
          : Value(anonymousUsername),
      createdAt: Value(createdAt),
      biometricLockEnabled: Value(biometricLockEnabled),
      selectedGoals: Value(selectedGoals),
      activePaths: Value(activePaths),
      selectedValues: selectedValues == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedValues),
    );
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<String>(json['id']),
      anonymousUsername: serializer.fromJson<String?>(
        json['anonymousUsername'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      biometricLockEnabled: serializer.fromJson<bool>(
        json['biometricLockEnabled'],
      ),
      selectedGoals: serializer.fromJson<String>(json['selectedGoals']),
      activePaths: serializer.fromJson<String>(json['activePaths']),
      selectedValues: serializer.fromJson<String?>(json['selectedValues']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'anonymousUsername': serializer.toJson<String?>(anonymousUsername),
      'createdAt': serializer.toJson<int>(createdAt),
      'biometricLockEnabled': serializer.toJson<bool>(biometricLockEnabled),
      'selectedGoals': serializer.toJson<String>(selectedGoals),
      'activePaths': serializer.toJson<String>(activePaths),
      'selectedValues': serializer.toJson<String?>(selectedValues),
    };
  }

  Profile copyWith({
    String? id,
    Value<String?> anonymousUsername = const Value.absent(),
    int? createdAt,
    bool? biometricLockEnabled,
    String? selectedGoals,
    String? activePaths,
    Value<String?> selectedValues = const Value.absent(),
  }) => Profile(
    id: id ?? this.id,
    anonymousUsername: anonymousUsername.present
        ? anonymousUsername.value
        : this.anonymousUsername,
    createdAt: createdAt ?? this.createdAt,
    biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
    selectedGoals: selectedGoals ?? this.selectedGoals,
    activePaths: activePaths ?? this.activePaths,
    selectedValues: selectedValues.present
        ? selectedValues.value
        : this.selectedValues,
  );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      anonymousUsername: data.anonymousUsername.present
          ? data.anonymousUsername.value
          : this.anonymousUsername,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      biometricLockEnabled: data.biometricLockEnabled.present
          ? data.biometricLockEnabled.value
          : this.biometricLockEnabled,
      selectedGoals: data.selectedGoals.present
          ? data.selectedGoals.value
          : this.selectedGoals,
      activePaths: data.activePaths.present
          ? data.activePaths.value
          : this.activePaths,
      selectedValues: data.selectedValues.present
          ? data.selectedValues.value
          : this.selectedValues,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('anonymousUsername: $anonymousUsername, ')
          ..write('createdAt: $createdAt, ')
          ..write('biometricLockEnabled: $biometricLockEnabled, ')
          ..write('selectedGoals: $selectedGoals, ')
          ..write('activePaths: $activePaths, ')
          ..write('selectedValues: $selectedValues')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    anonymousUsername,
    createdAt,
    biometricLockEnabled,
    selectedGoals,
    activePaths,
    selectedValues,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.anonymousUsername == this.anonymousUsername &&
          other.createdAt == this.createdAt &&
          other.biometricLockEnabled == this.biometricLockEnabled &&
          other.selectedGoals == this.selectedGoals &&
          other.activePaths == this.activePaths &&
          other.selectedValues == this.selectedValues);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<String> id;
  final Value<String?> anonymousUsername;
  final Value<int> createdAt;
  final Value<bool> biometricLockEnabled;
  final Value<String> selectedGoals;
  final Value<String> activePaths;
  final Value<String?> selectedValues;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.anonymousUsername = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.biometricLockEnabled = const Value.absent(),
    this.selectedGoals = const Value.absent(),
    this.activePaths = const Value.absent(),
    this.selectedValues = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    this.anonymousUsername = const Value.absent(),
    required int createdAt,
    this.biometricLockEnabled = const Value.absent(),
    required String selectedGoals,
    required String activePaths,
    this.selectedValues = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       selectedGoals = Value(selectedGoals),
       activePaths = Value(activePaths);
  static Insertable<Profile> custom({
    Expression<String>? id,
    Expression<String>? anonymousUsername,
    Expression<int>? createdAt,
    Expression<bool>? biometricLockEnabled,
    Expression<String>? selectedGoals,
    Expression<String>? activePaths,
    Expression<String>? selectedValues,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (anonymousUsername != null) 'anonymous_username': anonymousUsername,
      if (createdAt != null) 'created_at': createdAt,
      if (biometricLockEnabled != null)
        'biometric_lock_enabled': biometricLockEnabled,
      if (selectedGoals != null) 'selected_goals': selectedGoals,
      if (activePaths != null) 'active_paths': activePaths,
      if (selectedValues != null) 'selected_values': selectedValues,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String?>? anonymousUsername,
    Value<int>? createdAt,
    Value<bool>? biometricLockEnabled,
    Value<String>? selectedGoals,
    Value<String>? activePaths,
    Value<String?>? selectedValues,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      anonymousUsername: anonymousUsername ?? this.anonymousUsername,
      createdAt: createdAt ?? this.createdAt,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      selectedGoals: selectedGoals ?? this.selectedGoals,
      activePaths: activePaths ?? this.activePaths,
      selectedValues: selectedValues ?? this.selectedValues,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (anonymousUsername.present) {
      map['anonymous_username'] = Variable<String>(anonymousUsername.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (biometricLockEnabled.present) {
      map['biometric_lock_enabled'] = Variable<bool>(
        biometricLockEnabled.value,
      );
    }
    if (selectedGoals.present) {
      map['selected_goals'] = Variable<String>(selectedGoals.value);
    }
    if (activePaths.present) {
      map['active_paths'] = Variable<String>(activePaths.value);
    }
    if (selectedValues.present) {
      map['selected_values'] = Variable<String>(selectedValues.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('anonymousUsername: $anonymousUsername, ')
          ..write('createdAt: $createdAt, ')
          ..write('biometricLockEnabled: $biometricLockEnabled, ')
          ..write('selectedGoals: $selectedGoals, ')
          ..write('activePaths: $activePaths, ')
          ..write('selectedValues: $selectedValues, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CountersTable extends Counters with TableInfo<$CountersTable, Counter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CountersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateTimeMeta = const VerificationMeta(
    'startDateTime',
  );
  @override
  late final GeneratedColumn<int> startDateTime = GeneratedColumn<int>(
    'start_date_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, label, startDateTime, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'counters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Counter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('start_date_time')) {
      context.handle(
        _startDateTimeMeta,
        startDateTime.isAcceptableOrUnknown(
          data['start_date_time']!,
          _startDateTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startDateTimeMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Counter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Counter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      startDateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_date_time'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $CountersTable createAlias(String alias) {
    return $CountersTable(attachedDatabase, alias);
  }
}

class Counter extends DataClass implements Insertable<Counter> {
  final String id;
  final String label;
  final int startDateTime;
  final bool isActive;
  const Counter({
    required this.id,
    required this.label,
    required this.startDateTime,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    map['start_date_time'] = Variable<int>(startDateTime);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  CountersCompanion toCompanion(bool nullToAbsent) {
    return CountersCompanion(
      id: Value(id),
      label: Value(label),
      startDateTime: Value(startDateTime),
      isActive: Value(isActive),
    );
  }

  factory Counter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Counter(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      startDateTime: serializer.fromJson<int>(json['startDateTime']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'startDateTime': serializer.toJson<int>(startDateTime),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Counter copyWith({
    String? id,
    String? label,
    int? startDateTime,
    bool? isActive,
  }) => Counter(
    id: id ?? this.id,
    label: label ?? this.label,
    startDateTime: startDateTime ?? this.startDateTime,
    isActive: isActive ?? this.isActive,
  );
  Counter copyWithCompanion(CountersCompanion data) {
    return Counter(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      startDateTime: data.startDateTime.present
          ? data.startDateTime.value
          : this.startDateTime,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Counter(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('startDateTime: $startDateTime, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, label, startDateTime, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Counter &&
          other.id == this.id &&
          other.label == this.label &&
          other.startDateTime == this.startDateTime &&
          other.isActive == this.isActive);
}

class CountersCompanion extends UpdateCompanion<Counter> {
  final Value<String> id;
  final Value<String> label;
  final Value<int> startDateTime;
  final Value<bool> isActive;
  final Value<int> rowid;
  const CountersCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.startDateTime = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CountersCompanion.insert({
    required String id,
    required String label,
    required int startDateTime,
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       label = Value(label),
       startDateTime = Value(startDateTime);
  static Insertable<Counter> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<int>? startDateTime,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (startDateTime != null) 'start_date_time': startDateTime,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CountersCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<int>? startDateTime,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return CountersCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      startDateTime: startDateTime ?? this.startDateTime,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (startDateTime.present) {
      map['start_date_time'] = Variable<int>(startDateTime.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CountersCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('startDateTime: $startDateTime, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalEntriesTable extends JournalEntries
    with TableInfo<$JournalEntriesTable, JournalEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodRatingMeta = const VerificationMeta(
    'moodRating',
  );
  @override
  late final GeneratedColumn<int> moodRating = GeneratedColumn<int>(
    'mood_rating',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentEncryptedMeta = const VerificationMeta(
    'contentEncrypted',
  );
  @override
  late final GeneratedColumn<String> contentEncrypted = GeneratedColumn<String>(
    'content_encrypted',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSyncedToCloudMeta = const VerificationMeta(
    'isSyncedToCloud',
  );
  @override
  late final GeneratedColumn<bool> isSyncedToCloud = GeneratedColumn<bool>(
    'is_synced_to_cloud',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced_to_cloud" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    moodRating,
    contentEncrypted,
    isSyncedToCloud,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<JournalEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('mood_rating')) {
      context.handle(
        _moodRatingMeta,
        moodRating.isAcceptableOrUnknown(data['mood_rating']!, _moodRatingMeta),
      );
    } else if (isInserting) {
      context.missing(_moodRatingMeta);
    }
    if (data.containsKey('content_encrypted')) {
      context.handle(
        _contentEncryptedMeta,
        contentEncrypted.isAcceptableOrUnknown(
          data['content_encrypted']!,
          _contentEncryptedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentEncryptedMeta);
    }
    if (data.containsKey('is_synced_to_cloud')) {
      context.handle(
        _isSyncedToCloudMeta,
        isSyncedToCloud.isAcceptableOrUnknown(
          data['is_synced_to_cloud']!,
          _isSyncedToCloudMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JournalEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
      moodRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mood_rating'],
      )!,
      contentEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_encrypted'],
      )!,
      isSyncedToCloud: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced_to_cloud'],
      )!,
    );
  }

  @override
  $JournalEntriesTable createAlias(String alias) {
    return $JournalEntriesTable(attachedDatabase, alias);
  }
}

class JournalEntry extends DataClass implements Insertable<JournalEntry> {
  final String id;
  final int timestamp;
  final int moodRating;
  final String contentEncrypted;
  final bool isSyncedToCloud;
  const JournalEntry({
    required this.id,
    required this.timestamp,
    required this.moodRating,
    required this.contentEncrypted,
    required this.isSyncedToCloud,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timestamp'] = Variable<int>(timestamp);
    map['mood_rating'] = Variable<int>(moodRating);
    map['content_encrypted'] = Variable<String>(contentEncrypted);
    map['is_synced_to_cloud'] = Variable<bool>(isSyncedToCloud);
    return map;
  }

  JournalEntriesCompanion toCompanion(bool nullToAbsent) {
    return JournalEntriesCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      moodRating: Value(moodRating),
      contentEncrypted: Value(contentEncrypted),
      isSyncedToCloud: Value(isSyncedToCloud),
    );
  }

  factory JournalEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalEntry(
      id: serializer.fromJson<String>(json['id']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      moodRating: serializer.fromJson<int>(json['moodRating']),
      contentEncrypted: serializer.fromJson<String>(json['contentEncrypted']),
      isSyncedToCloud: serializer.fromJson<bool>(json['isSyncedToCloud']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timestamp': serializer.toJson<int>(timestamp),
      'moodRating': serializer.toJson<int>(moodRating),
      'contentEncrypted': serializer.toJson<String>(contentEncrypted),
      'isSyncedToCloud': serializer.toJson<bool>(isSyncedToCloud),
    };
  }

  JournalEntry copyWith({
    String? id,
    int? timestamp,
    int? moodRating,
    String? contentEncrypted,
    bool? isSyncedToCloud,
  }) => JournalEntry(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    moodRating: moodRating ?? this.moodRating,
    contentEncrypted: contentEncrypted ?? this.contentEncrypted,
    isSyncedToCloud: isSyncedToCloud ?? this.isSyncedToCloud,
  );
  JournalEntry copyWithCompanion(JournalEntriesCompanion data) {
    return JournalEntry(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      moodRating: data.moodRating.present
          ? data.moodRating.value
          : this.moodRating,
      contentEncrypted: data.contentEncrypted.present
          ? data.contentEncrypted.value
          : this.contentEncrypted,
      isSyncedToCloud: data.isSyncedToCloud.present
          ? data.isSyncedToCloud.value
          : this.isSyncedToCloud,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntry(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('moodRating: $moodRating, ')
          ..write('contentEncrypted: $contentEncrypted, ')
          ..write('isSyncedToCloud: $isSyncedToCloud')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, timestamp, moodRating, contentEncrypted, isSyncedToCloud);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalEntry &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.moodRating == this.moodRating &&
          other.contentEncrypted == this.contentEncrypted &&
          other.isSyncedToCloud == this.isSyncedToCloud);
}

class JournalEntriesCompanion extends UpdateCompanion<JournalEntry> {
  final Value<String> id;
  final Value<int> timestamp;
  final Value<int> moodRating;
  final Value<String> contentEncrypted;
  final Value<bool> isSyncedToCloud;
  final Value<int> rowid;
  const JournalEntriesCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.moodRating = const Value.absent(),
    this.contentEncrypted = const Value.absent(),
    this.isSyncedToCloud = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalEntriesCompanion.insert({
    required String id,
    required int timestamp,
    required int moodRating,
    required String contentEncrypted,
    this.isSyncedToCloud = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       timestamp = Value(timestamp),
       moodRating = Value(moodRating),
       contentEncrypted = Value(contentEncrypted);
  static Insertable<JournalEntry> custom({
    Expression<String>? id,
    Expression<int>? timestamp,
    Expression<int>? moodRating,
    Expression<String>? contentEncrypted,
    Expression<bool>? isSyncedToCloud,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (moodRating != null) 'mood_rating': moodRating,
      if (contentEncrypted != null) 'content_encrypted': contentEncrypted,
      if (isSyncedToCloud != null) 'is_synced_to_cloud': isSyncedToCloud,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalEntriesCompanion copyWith({
    Value<String>? id,
    Value<int>? timestamp,
    Value<int>? moodRating,
    Value<String>? contentEncrypted,
    Value<bool>? isSyncedToCloud,
    Value<int>? rowid,
  }) {
    return JournalEntriesCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      moodRating: moodRating ?? this.moodRating,
      contentEncrypted: contentEncrypted ?? this.contentEncrypted,
      isSyncedToCloud: isSyncedToCloud ?? this.isSyncedToCloud,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (moodRating.present) {
      map['mood_rating'] = Variable<int>(moodRating.value);
    }
    if (contentEncrypted.present) {
      map['content_encrypted'] = Variable<String>(contentEncrypted.value);
    }
    if (isSyncedToCloud.present) {
      map['is_synced_to_cloud'] = Variable<bool>(isSyncedToCloud.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntriesCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('moodRating: $moodRating, ')
          ..write('contentEncrypted: $contentEncrypted, ')
          ..write('isSyncedToCloud: $isSyncedToCloud, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConstellationPointsTable extends ConstellationPoints
    with TableInfo<$ConstellationPointsTable, ConstellationPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConstellationPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionXMeta = const VerificationMeta(
    'positionX',
  );
  @override
  late final GeneratedColumn<double> positionX = GeneratedColumn<double>(
    'position_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionYMeta = const VerificationMeta(
    'positionY',
  );
  @override
  late final GeneratedColumn<double> positionY = GeneratedColumn<double>(
    'position_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    category,
    timestamp,
    positionX,
    positionY,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'constellation_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConstellationPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('position_x')) {
      context.handle(
        _positionXMeta,
        positionX.isAcceptableOrUnknown(data['position_x']!, _positionXMeta),
      );
    } else if (isInserting) {
      context.missing(_positionXMeta);
    }
    if (data.containsKey('position_y')) {
      context.handle(
        _positionYMeta,
        positionY.isAcceptableOrUnknown(data['position_y']!, _positionYMeta),
      );
    } else if (isInserting) {
      context.missing(_positionYMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConstellationPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConstellationPoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
      positionX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position_x'],
      )!,
      positionY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position_y'],
      )!,
    );
  }

  @override
  $ConstellationPointsTable createAlias(String alias) {
    return $ConstellationPointsTable(attachedDatabase, alias);
  }
}

class ConstellationPoint extends DataClass
    implements Insertable<ConstellationPoint> {
  final String id;
  final String title;
  final String category;
  final int timestamp;
  final double positionX;
  final double positionY;
  const ConstellationPoint({
    required this.id,
    required this.title,
    required this.category,
    required this.timestamp,
    required this.positionX,
    required this.positionY,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['category'] = Variable<String>(category);
    map['timestamp'] = Variable<int>(timestamp);
    map['position_x'] = Variable<double>(positionX);
    map['position_y'] = Variable<double>(positionY);
    return map;
  }

  ConstellationPointsCompanion toCompanion(bool nullToAbsent) {
    return ConstellationPointsCompanion(
      id: Value(id),
      title: Value(title),
      category: Value(category),
      timestamp: Value(timestamp),
      positionX: Value(positionX),
      positionY: Value(positionY),
    );
  }

  factory ConstellationPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConstellationPoint(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<String>(json['category']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      positionX: serializer.fromJson<double>(json['positionX']),
      positionY: serializer.fromJson<double>(json['positionY']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String>(category),
      'timestamp': serializer.toJson<int>(timestamp),
      'positionX': serializer.toJson<double>(positionX),
      'positionY': serializer.toJson<double>(positionY),
    };
  }

  ConstellationPoint copyWith({
    String? id,
    String? title,
    String? category,
    int? timestamp,
    double? positionX,
    double? positionY,
  }) => ConstellationPoint(
    id: id ?? this.id,
    title: title ?? this.title,
    category: category ?? this.category,
    timestamp: timestamp ?? this.timestamp,
    positionX: positionX ?? this.positionX,
    positionY: positionY ?? this.positionY,
  );
  ConstellationPoint copyWithCompanion(ConstellationPointsCompanion data) {
    return ConstellationPoint(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      category: data.category.present ? data.category.value : this.category,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      positionX: data.positionX.present ? data.positionX.value : this.positionX,
      positionY: data.positionY.present ? data.positionY.value : this.positionY,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConstellationPoint(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('timestamp: $timestamp, ')
          ..write('positionX: $positionX, ')
          ..write('positionY: $positionY')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, category, timestamp, positionX, positionY);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConstellationPoint &&
          other.id == this.id &&
          other.title == this.title &&
          other.category == this.category &&
          other.timestamp == this.timestamp &&
          other.positionX == this.positionX &&
          other.positionY == this.positionY);
}

class ConstellationPointsCompanion extends UpdateCompanion<ConstellationPoint> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> category;
  final Value<int> timestamp;
  final Value<double> positionX;
  final Value<double> positionY;
  final Value<int> rowid;
  const ConstellationPointsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.positionX = const Value.absent(),
    this.positionY = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConstellationPointsCompanion.insert({
    required String id,
    required String title,
    required String category,
    required int timestamp,
    required double positionX,
    required double positionY,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       category = Value(category),
       timestamp = Value(timestamp),
       positionX = Value(positionX),
       positionY = Value(positionY);
  static Insertable<ConstellationPoint> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? category,
    Expression<int>? timestamp,
    Expression<double>? positionX,
    Expression<double>? positionY,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (timestamp != null) 'timestamp': timestamp,
      if (positionX != null) 'position_x': positionX,
      if (positionY != null) 'position_y': positionY,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConstellationPointsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? category,
    Value<int>? timestamp,
    Value<double>? positionX,
    Value<double>? positionY,
    Value<int>? rowid,
  }) {
    return ConstellationPointsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (positionX.present) {
      map['position_x'] = Variable<double>(positionX.value);
    }
    if (positionY.present) {
      map['position_y'] = Variable<double>(positionY.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConstellationPointsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('timestamp: $timestamp, ')
          ..write('positionX: $positionX, ')
          ..write('positionY: $positionY, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeeklyGoalsTable extends WeeklyGoals
    with TableInfo<$WeeklyGoalsTable, WeeklyGoal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklyGoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _targetCountMeta = const VerificationMeta(
    'targetCount',
  );
  @override
  late final GeneratedColumn<int> targetCount = GeneratedColumn<int>(
    'target_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentCountMeta = const VerificationMeta(
    'currentCount',
  );
  @override
  late final GeneratedColumn<int> currentCount = GeneratedColumn<int>(
    'current_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    targetCount,
    currentCount,
    isCompleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeeklyGoal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('target_count')) {
      context.handle(
        _targetCountMeta,
        targetCount.isAcceptableOrUnknown(
          data['target_count']!,
          _targetCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetCountMeta);
    }
    if (data.containsKey('current_count')) {
      context.handle(
        _currentCountMeta,
        currentCount.isAcceptableOrUnknown(
          data['current_count']!,
          _currentCountMeta,
        ),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeeklyGoal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklyGoal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      targetCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_count'],
      )!,
      currentCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_count'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
    );
  }

  @override
  $WeeklyGoalsTable createAlias(String alias) {
    return $WeeklyGoalsTable(attachedDatabase, alias);
  }
}

class WeeklyGoal extends DataClass implements Insertable<WeeklyGoal> {
  final String id;
  final String title;
  final int targetCount;
  final int currentCount;
  final bool isCompleted;
  const WeeklyGoal({
    required this.id,
    required this.title,
    required this.targetCount,
    required this.currentCount,
    required this.isCompleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['target_count'] = Variable<int>(targetCount);
    map['current_count'] = Variable<int>(currentCount);
    map['is_completed'] = Variable<bool>(isCompleted);
    return map;
  }

  WeeklyGoalsCompanion toCompanion(bool nullToAbsent) {
    return WeeklyGoalsCompanion(
      id: Value(id),
      title: Value(title),
      targetCount: Value(targetCount),
      currentCount: Value(currentCount),
      isCompleted: Value(isCompleted),
    );
  }

  factory WeeklyGoal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklyGoal(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      targetCount: serializer.fromJson<int>(json['targetCount']),
      currentCount: serializer.fromJson<int>(json['currentCount']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'targetCount': serializer.toJson<int>(targetCount),
      'currentCount': serializer.toJson<int>(currentCount),
      'isCompleted': serializer.toJson<bool>(isCompleted),
    };
  }

  WeeklyGoal copyWith({
    String? id,
    String? title,
    int? targetCount,
    int? currentCount,
    bool? isCompleted,
  }) => WeeklyGoal(
    id: id ?? this.id,
    title: title ?? this.title,
    targetCount: targetCount ?? this.targetCount,
    currentCount: currentCount ?? this.currentCount,
    isCompleted: isCompleted ?? this.isCompleted,
  );
  WeeklyGoal copyWithCompanion(WeeklyGoalsCompanion data) {
    return WeeklyGoal(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      targetCount: data.targetCount.present
          ? data.targetCount.value
          : this.targetCount,
      currentCount: data.currentCount.present
          ? data.currentCount.value
          : this.currentCount,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyGoal(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('targetCount: $targetCount, ')
          ..write('currentCount: $currentCount, ')
          ..write('isCompleted: $isCompleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, targetCount, currentCount, isCompleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklyGoal &&
          other.id == this.id &&
          other.title == this.title &&
          other.targetCount == this.targetCount &&
          other.currentCount == this.currentCount &&
          other.isCompleted == this.isCompleted);
}

class WeeklyGoalsCompanion extends UpdateCompanion<WeeklyGoal> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> targetCount;
  final Value<int> currentCount;
  final Value<bool> isCompleted;
  final Value<int> rowid;
  const WeeklyGoalsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.targetCount = const Value.absent(),
    this.currentCount = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeeklyGoalsCompanion.insert({
    required String id,
    required String title,
    required int targetCount,
    this.currentCount = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       targetCount = Value(targetCount);
  static Insertable<WeeklyGoal> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? targetCount,
    Expression<int>? currentCount,
    Expression<bool>? isCompleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (targetCount != null) 'target_count': targetCount,
      if (currentCount != null) 'current_count': currentCount,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeeklyGoalsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<int>? targetCount,
    Value<int>? currentCount,
    Value<bool>? isCompleted,
    Value<int>? rowid,
  }) {
    return WeeklyGoalsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      isCompleted: isCompleted ?? this.isCompleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (targetCount.present) {
      map['target_count'] = Variable<int>(targetCount.value);
    }
    if (currentCount.present) {
      map['current_count'] = Variable<int>(currentCount.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyGoalsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('targetCount: $targetCount, ')
          ..write('currentCount: $currentCount, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WellnessCheckInsTable extends WellnessCheckIns
    with TableInfo<$WellnessCheckInsTable, WellnessCheckIn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WellnessCheckInsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spiritualMeta = const VerificationMeta(
    'spiritual',
  );
  @override
  late final GeneratedColumn<double> spiritual = GeneratedColumn<double>(
    'spiritual',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intellectualMeta = const VerificationMeta(
    'intellectual',
  );
  @override
  late final GeneratedColumn<double> intellectual = GeneratedColumn<double>(
    'intellectual',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emotionalMeta = const VerificationMeta(
    'emotional',
  );
  @override
  late final GeneratedColumn<double> emotional = GeneratedColumn<double>(
    'emotional',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _physicalMeta = const VerificationMeta(
    'physical',
  );
  @override
  late final GeneratedColumn<double> physical = GeneratedColumn<double>(
    'physical',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _socialMeta = const VerificationMeta('social');
  @override
  late final GeneratedColumn<double> social = GeneratedColumn<double>(
    'social',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occupationalMeta = const VerificationMeta(
    'occupational',
  );
  @override
  late final GeneratedColumn<double> occupational = GeneratedColumn<double>(
    'occupational',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    spiritual,
    intellectual,
    emotional,
    physical,
    social,
    occupational,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wellness_check_ins';
  @override
  VerificationContext validateIntegrity(
    Insertable<WellnessCheckIn> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('spiritual')) {
      context.handle(
        _spiritualMeta,
        spiritual.isAcceptableOrUnknown(data['spiritual']!, _spiritualMeta),
      );
    } else if (isInserting) {
      context.missing(_spiritualMeta);
    }
    if (data.containsKey('intellectual')) {
      context.handle(
        _intellectualMeta,
        intellectual.isAcceptableOrUnknown(
          data['intellectual']!,
          _intellectualMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_intellectualMeta);
    }
    if (data.containsKey('emotional')) {
      context.handle(
        _emotionalMeta,
        emotional.isAcceptableOrUnknown(data['emotional']!, _emotionalMeta),
      );
    } else if (isInserting) {
      context.missing(_emotionalMeta);
    }
    if (data.containsKey('physical')) {
      context.handle(
        _physicalMeta,
        physical.isAcceptableOrUnknown(data['physical']!, _physicalMeta),
      );
    } else if (isInserting) {
      context.missing(_physicalMeta);
    }
    if (data.containsKey('social')) {
      context.handle(
        _socialMeta,
        social.isAcceptableOrUnknown(data['social']!, _socialMeta),
      );
    } else if (isInserting) {
      context.missing(_socialMeta);
    }
    if (data.containsKey('occupational')) {
      context.handle(
        _occupationalMeta,
        occupational.isAcceptableOrUnknown(
          data['occupational']!,
          _occupationalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occupationalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WellnessCheckIn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WellnessCheckIn(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
      spiritual: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}spiritual'],
      )!,
      intellectual: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}intellectual'],
      )!,
      emotional: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}emotional'],
      )!,
      physical: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}physical'],
      )!,
      social: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}social'],
      )!,
      occupational: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}occupational'],
      )!,
    );
  }

  @override
  $WellnessCheckInsTable createAlias(String alias) {
    return $WellnessCheckInsTable(attachedDatabase, alias);
  }
}

class WellnessCheckIn extends DataClass implements Insertable<WellnessCheckIn> {
  final String id;
  final int timestamp;
  final double spiritual;
  final double intellectual;
  final double emotional;
  final double physical;
  final double social;
  final double occupational;
  const WellnessCheckIn({
    required this.id,
    required this.timestamp,
    required this.spiritual,
    required this.intellectual,
    required this.emotional,
    required this.physical,
    required this.social,
    required this.occupational,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timestamp'] = Variable<int>(timestamp);
    map['spiritual'] = Variable<double>(spiritual);
    map['intellectual'] = Variable<double>(intellectual);
    map['emotional'] = Variable<double>(emotional);
    map['physical'] = Variable<double>(physical);
    map['social'] = Variable<double>(social);
    map['occupational'] = Variable<double>(occupational);
    return map;
  }

  WellnessCheckInsCompanion toCompanion(bool nullToAbsent) {
    return WellnessCheckInsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      spiritual: Value(spiritual),
      intellectual: Value(intellectual),
      emotional: Value(emotional),
      physical: Value(physical),
      social: Value(social),
      occupational: Value(occupational),
    );
  }

  factory WellnessCheckIn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WellnessCheckIn(
      id: serializer.fromJson<String>(json['id']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      spiritual: serializer.fromJson<double>(json['spiritual']),
      intellectual: serializer.fromJson<double>(json['intellectual']),
      emotional: serializer.fromJson<double>(json['emotional']),
      physical: serializer.fromJson<double>(json['physical']),
      social: serializer.fromJson<double>(json['social']),
      occupational: serializer.fromJson<double>(json['occupational']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timestamp': serializer.toJson<int>(timestamp),
      'spiritual': serializer.toJson<double>(spiritual),
      'intellectual': serializer.toJson<double>(intellectual),
      'emotional': serializer.toJson<double>(emotional),
      'physical': serializer.toJson<double>(physical),
      'social': serializer.toJson<double>(social),
      'occupational': serializer.toJson<double>(occupational),
    };
  }

  WellnessCheckIn copyWith({
    String? id,
    int? timestamp,
    double? spiritual,
    double? intellectual,
    double? emotional,
    double? physical,
    double? social,
    double? occupational,
  }) => WellnessCheckIn(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    spiritual: spiritual ?? this.spiritual,
    intellectual: intellectual ?? this.intellectual,
    emotional: emotional ?? this.emotional,
    physical: physical ?? this.physical,
    social: social ?? this.social,
    occupational: occupational ?? this.occupational,
  );
  WellnessCheckIn copyWithCompanion(WellnessCheckInsCompanion data) {
    return WellnessCheckIn(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      spiritual: data.spiritual.present ? data.spiritual.value : this.spiritual,
      intellectual: data.intellectual.present
          ? data.intellectual.value
          : this.intellectual,
      emotional: data.emotional.present ? data.emotional.value : this.emotional,
      physical: data.physical.present ? data.physical.value : this.physical,
      social: data.social.present ? data.social.value : this.social,
      occupational: data.occupational.present
          ? data.occupational.value
          : this.occupational,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WellnessCheckIn(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('spiritual: $spiritual, ')
          ..write('intellectual: $intellectual, ')
          ..write('emotional: $emotional, ')
          ..write('physical: $physical, ')
          ..write('social: $social, ')
          ..write('occupational: $occupational')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    spiritual,
    intellectual,
    emotional,
    physical,
    social,
    occupational,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WellnessCheckIn &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.spiritual == this.spiritual &&
          other.intellectual == this.intellectual &&
          other.emotional == this.emotional &&
          other.physical == this.physical &&
          other.social == this.social &&
          other.occupational == this.occupational);
}

class WellnessCheckInsCompanion extends UpdateCompanion<WellnessCheckIn> {
  final Value<String> id;
  final Value<int> timestamp;
  final Value<double> spiritual;
  final Value<double> intellectual;
  final Value<double> emotional;
  final Value<double> physical;
  final Value<double> social;
  final Value<double> occupational;
  final Value<int> rowid;
  const WellnessCheckInsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.spiritual = const Value.absent(),
    this.intellectual = const Value.absent(),
    this.emotional = const Value.absent(),
    this.physical = const Value.absent(),
    this.social = const Value.absent(),
    this.occupational = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WellnessCheckInsCompanion.insert({
    required String id,
    required int timestamp,
    required double spiritual,
    required double intellectual,
    required double emotional,
    required double physical,
    required double social,
    required double occupational,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       timestamp = Value(timestamp),
       spiritual = Value(spiritual),
       intellectual = Value(intellectual),
       emotional = Value(emotional),
       physical = Value(physical),
       social = Value(social),
       occupational = Value(occupational);
  static Insertable<WellnessCheckIn> custom({
    Expression<String>? id,
    Expression<int>? timestamp,
    Expression<double>? spiritual,
    Expression<double>? intellectual,
    Expression<double>? emotional,
    Expression<double>? physical,
    Expression<double>? social,
    Expression<double>? occupational,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (spiritual != null) 'spiritual': spiritual,
      if (intellectual != null) 'intellectual': intellectual,
      if (emotional != null) 'emotional': emotional,
      if (physical != null) 'physical': physical,
      if (social != null) 'social': social,
      if (occupational != null) 'occupational': occupational,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WellnessCheckInsCompanion copyWith({
    Value<String>? id,
    Value<int>? timestamp,
    Value<double>? spiritual,
    Value<double>? intellectual,
    Value<double>? emotional,
    Value<double>? physical,
    Value<double>? social,
    Value<double>? occupational,
    Value<int>? rowid,
  }) {
    return WellnessCheckInsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      spiritual: spiritual ?? this.spiritual,
      intellectual: intellectual ?? this.intellectual,
      emotional: emotional ?? this.emotional,
      physical: physical ?? this.physical,
      social: social ?? this.social,
      occupational: occupational ?? this.occupational,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (spiritual.present) {
      map['spiritual'] = Variable<double>(spiritual.value);
    }
    if (intellectual.present) {
      map['intellectual'] = Variable<double>(intellectual.value);
    }
    if (emotional.present) {
      map['emotional'] = Variable<double>(emotional.value);
    }
    if (physical.present) {
      map['physical'] = Variable<double>(physical.value);
    }
    if (social.present) {
      map['social'] = Variable<double>(social.value);
    }
    if (occupational.present) {
      map['occupational'] = Variable<double>(occupational.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WellnessCheckInsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('spiritual: $spiritual, ')
          ..write('intellectual: $intellectual, ')
          ..write('emotional: $emotional, ')
          ..write('physical: $physical, ')
          ..write('social: $social, ')
          ..write('occupational: $occupational, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$RecoveryDatabase extends GeneratedDatabase {
  _$RecoveryDatabase(QueryExecutor e) : super(e);
  $RecoveryDatabaseManager get managers => $RecoveryDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $CountersTable counters = $CountersTable(this);
  late final $JournalEntriesTable journalEntries = $JournalEntriesTable(this);
  late final $ConstellationPointsTable constellationPoints =
      $ConstellationPointsTable(this);
  late final $WeeklyGoalsTable weeklyGoals = $WeeklyGoalsTable(this);
  late final $WellnessCheckInsTable wellnessCheckIns = $WellnessCheckInsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profiles,
    counters,
    journalEntries,
    constellationPoints,
    weeklyGoals,
    wellnessCheckIns,
  ];
}

typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      required String id,
      Value<String?> anonymousUsername,
      required int createdAt,
      Value<bool> biometricLockEnabled,
      required String selectedGoals,
      required String activePaths,
      Value<String?> selectedValues,
      Value<int> rowid,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<String> id,
      Value<String?> anonymousUsername,
      Value<int> createdAt,
      Value<bool> biometricLockEnabled,
      Value<String> selectedGoals,
      Value<String> activePaths,
      Value<String?> selectedValues,
      Value<int> rowid,
    });

class $$ProfilesTableFilterComposer
    extends Composer<_$RecoveryDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
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

  ColumnFilters<String> get anonymousUsername => $composableBuilder(
    column: $table.anonymousUsername,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get biometricLockEnabled => $composableBuilder(
    column: $table.biometricLockEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedGoals => $composableBuilder(
    column: $table.selectedGoals,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activePaths => $composableBuilder(
    column: $table.activePaths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedValues => $composableBuilder(
    column: $table.selectedValues,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$RecoveryDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get anonymousUsername => $composableBuilder(
    column: $table.anonymousUsername,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get biometricLockEnabled => $composableBuilder(
    column: $table.biometricLockEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedGoals => $composableBuilder(
    column: $table.selectedGoals,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activePaths => $composableBuilder(
    column: $table.activePaths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedValues => $composableBuilder(
    column: $table.selectedValues,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$RecoveryDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get anonymousUsername => $composableBuilder(
    column: $table.anonymousUsername,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get biometricLockEnabled => $composableBuilder(
    column: $table.biometricLockEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedGoals => $composableBuilder(
    column: $table.selectedGoals,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activePaths => $composableBuilder(
    column: $table.activePaths,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedValues => $composableBuilder(
    column: $table.selectedValues,
    builder: (column) => column,
  );
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$RecoveryDatabase,
          $ProfilesTable,
          Profile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (
            Profile,
            BaseReferences<_$RecoveryDatabase, $ProfilesTable, Profile>,
          ),
          Profile,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$RecoveryDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> anonymousUsername = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<bool> biometricLockEnabled = const Value.absent(),
                Value<String> selectedGoals = const Value.absent(),
                Value<String> activePaths = const Value.absent(),
                Value<String?> selectedValues = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                anonymousUsername: anonymousUsername,
                createdAt: createdAt,
                biometricLockEnabled: biometricLockEnabled,
                selectedGoals: selectedGoals,
                activePaths: activePaths,
                selectedValues: selectedValues,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> anonymousUsername = const Value.absent(),
                required int createdAt,
                Value<bool> biometricLockEnabled = const Value.absent(),
                required String selectedGoals,
                required String activePaths,
                Value<String?> selectedValues = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                anonymousUsername: anonymousUsername,
                createdAt: createdAt,
                biometricLockEnabled: biometricLockEnabled,
                selectedGoals: selectedGoals,
                activePaths: activePaths,
                selectedValues: selectedValues,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$RecoveryDatabase,
      $ProfilesTable,
      Profile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (Profile, BaseReferences<_$RecoveryDatabase, $ProfilesTable, Profile>),
      Profile,
      PrefetchHooks Function()
    >;
typedef $$CountersTableCreateCompanionBuilder =
    CountersCompanion Function({
      required String id,
      required String label,
      required int startDateTime,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$CountersTableUpdateCompanionBuilder =
    CountersCompanion Function({
      Value<String> id,
      Value<String> label,
      Value<int> startDateTime,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$CountersTableFilterComposer
    extends Composer<_$RecoveryDatabase, $CountersTable> {
  $$CountersTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startDateTime => $composableBuilder(
    column: $table.startDateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CountersTableOrderingComposer
    extends Composer<_$RecoveryDatabase, $CountersTable> {
  $$CountersTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startDateTime => $composableBuilder(
    column: $table.startDateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CountersTableAnnotationComposer
    extends Composer<_$RecoveryDatabase, $CountersTable> {
  $$CountersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get startDateTime => $composableBuilder(
    column: $table.startDateTime,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$CountersTableTableManager
    extends
        RootTableManager<
          _$RecoveryDatabase,
          $CountersTable,
          Counter,
          $$CountersTableFilterComposer,
          $$CountersTableOrderingComposer,
          $$CountersTableAnnotationComposer,
          $$CountersTableCreateCompanionBuilder,
          $$CountersTableUpdateCompanionBuilder,
          (
            Counter,
            BaseReferences<_$RecoveryDatabase, $CountersTable, Counter>,
          ),
          Counter,
          PrefetchHooks Function()
        > {
  $$CountersTableTableManager(_$RecoveryDatabase db, $CountersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CountersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CountersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CountersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> startDateTime = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CountersCompanion(
                id: id,
                label: label,
                startDateTime: startDateTime,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String label,
                required int startDateTime,
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CountersCompanion.insert(
                id: id,
                label: label,
                startDateTime: startDateTime,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CountersTableProcessedTableManager =
    ProcessedTableManager<
      _$RecoveryDatabase,
      $CountersTable,
      Counter,
      $$CountersTableFilterComposer,
      $$CountersTableOrderingComposer,
      $$CountersTableAnnotationComposer,
      $$CountersTableCreateCompanionBuilder,
      $$CountersTableUpdateCompanionBuilder,
      (Counter, BaseReferences<_$RecoveryDatabase, $CountersTable, Counter>),
      Counter,
      PrefetchHooks Function()
    >;
typedef $$JournalEntriesTableCreateCompanionBuilder =
    JournalEntriesCompanion Function({
      required String id,
      required int timestamp,
      required int moodRating,
      required String contentEncrypted,
      Value<bool> isSyncedToCloud,
      Value<int> rowid,
    });
typedef $$JournalEntriesTableUpdateCompanionBuilder =
    JournalEntriesCompanion Function({
      Value<String> id,
      Value<int> timestamp,
      Value<int> moodRating,
      Value<String> contentEncrypted,
      Value<bool> isSyncedToCloud,
      Value<int> rowid,
    });

class $$JournalEntriesTableFilterComposer
    extends Composer<_$RecoveryDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableFilterComposer({
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

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get moodRating => $composableBuilder(
    column: $table.moodRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentEncrypted => $composableBuilder(
    column: $table.contentEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSyncedToCloud => $composableBuilder(
    column: $table.isSyncedToCloud,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JournalEntriesTableOrderingComposer
    extends Composer<_$RecoveryDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableOrderingComposer({
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

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get moodRating => $composableBuilder(
    column: $table.moodRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentEncrypted => $composableBuilder(
    column: $table.contentEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSyncedToCloud => $composableBuilder(
    column: $table.isSyncedToCloud,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JournalEntriesTableAnnotationComposer
    extends Composer<_$RecoveryDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get moodRating => $composableBuilder(
    column: $table.moodRating,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentEncrypted => $composableBuilder(
    column: $table.contentEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSyncedToCloud => $composableBuilder(
    column: $table.isSyncedToCloud,
    builder: (column) => column,
  );
}

class $$JournalEntriesTableTableManager
    extends
        RootTableManager<
          _$RecoveryDatabase,
          $JournalEntriesTable,
          JournalEntry,
          $$JournalEntriesTableFilterComposer,
          $$JournalEntriesTableOrderingComposer,
          $$JournalEntriesTableAnnotationComposer,
          $$JournalEntriesTableCreateCompanionBuilder,
          $$JournalEntriesTableUpdateCompanionBuilder,
          (
            JournalEntry,
            BaseReferences<
              _$RecoveryDatabase,
              $JournalEntriesTable,
              JournalEntry
            >,
          ),
          JournalEntry,
          PrefetchHooks Function()
        > {
  $$JournalEntriesTableTableManager(
    _$RecoveryDatabase db,
    $JournalEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JournalEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JournalEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<int> moodRating = const Value.absent(),
                Value<String> contentEncrypted = const Value.absent(),
                Value<bool> isSyncedToCloud = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion(
                id: id,
                timestamp: timestamp,
                moodRating: moodRating,
                contentEncrypted: contentEncrypted,
                isSyncedToCloud: isSyncedToCloud,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int timestamp,
                required int moodRating,
                required String contentEncrypted,
                Value<bool> isSyncedToCloud = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion.insert(
                id: id,
                timestamp: timestamp,
                moodRating: moodRating,
                contentEncrypted: contentEncrypted,
                isSyncedToCloud: isSyncedToCloud,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JournalEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$RecoveryDatabase,
      $JournalEntriesTable,
      JournalEntry,
      $$JournalEntriesTableFilterComposer,
      $$JournalEntriesTableOrderingComposer,
      $$JournalEntriesTableAnnotationComposer,
      $$JournalEntriesTableCreateCompanionBuilder,
      $$JournalEntriesTableUpdateCompanionBuilder,
      (
        JournalEntry,
        BaseReferences<_$RecoveryDatabase, $JournalEntriesTable, JournalEntry>,
      ),
      JournalEntry,
      PrefetchHooks Function()
    >;
typedef $$ConstellationPointsTableCreateCompanionBuilder =
    ConstellationPointsCompanion Function({
      required String id,
      required String title,
      required String category,
      required int timestamp,
      required double positionX,
      required double positionY,
      Value<int> rowid,
    });
typedef $$ConstellationPointsTableUpdateCompanionBuilder =
    ConstellationPointsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> category,
      Value<int> timestamp,
      Value<double> positionX,
      Value<double> positionY,
      Value<int> rowid,
    });

class $$ConstellationPointsTableFilterComposer
    extends Composer<_$RecoveryDatabase, $ConstellationPointsTable> {
  $$ConstellationPointsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get positionX => $composableBuilder(
    column: $table.positionX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get positionY => $composableBuilder(
    column: $table.positionY,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConstellationPointsTableOrderingComposer
    extends Composer<_$RecoveryDatabase, $ConstellationPointsTable> {
  $$ConstellationPointsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get positionX => $composableBuilder(
    column: $table.positionX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get positionY => $composableBuilder(
    column: $table.positionY,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConstellationPointsTableAnnotationComposer
    extends Composer<_$RecoveryDatabase, $ConstellationPointsTable> {
  $$ConstellationPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<double> get positionX =>
      $composableBuilder(column: $table.positionX, builder: (column) => column);

  GeneratedColumn<double> get positionY =>
      $composableBuilder(column: $table.positionY, builder: (column) => column);
}

class $$ConstellationPointsTableTableManager
    extends
        RootTableManager<
          _$RecoveryDatabase,
          $ConstellationPointsTable,
          ConstellationPoint,
          $$ConstellationPointsTableFilterComposer,
          $$ConstellationPointsTableOrderingComposer,
          $$ConstellationPointsTableAnnotationComposer,
          $$ConstellationPointsTableCreateCompanionBuilder,
          $$ConstellationPointsTableUpdateCompanionBuilder,
          (
            ConstellationPoint,
            BaseReferences<
              _$RecoveryDatabase,
              $ConstellationPointsTable,
              ConstellationPoint
            >,
          ),
          ConstellationPoint,
          PrefetchHooks Function()
        > {
  $$ConstellationPointsTableTableManager(
    _$RecoveryDatabase db,
    $ConstellationPointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConstellationPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConstellationPointsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConstellationPointsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<double> positionX = const Value.absent(),
                Value<double> positionY = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConstellationPointsCompanion(
                id: id,
                title: title,
                category: category,
                timestamp: timestamp,
                positionX: positionX,
                positionY: positionY,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String category,
                required int timestamp,
                required double positionX,
                required double positionY,
                Value<int> rowid = const Value.absent(),
              }) => ConstellationPointsCompanion.insert(
                id: id,
                title: title,
                category: category,
                timestamp: timestamp,
                positionX: positionX,
                positionY: positionY,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConstellationPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$RecoveryDatabase,
      $ConstellationPointsTable,
      ConstellationPoint,
      $$ConstellationPointsTableFilterComposer,
      $$ConstellationPointsTableOrderingComposer,
      $$ConstellationPointsTableAnnotationComposer,
      $$ConstellationPointsTableCreateCompanionBuilder,
      $$ConstellationPointsTableUpdateCompanionBuilder,
      (
        ConstellationPoint,
        BaseReferences<
          _$RecoveryDatabase,
          $ConstellationPointsTable,
          ConstellationPoint
        >,
      ),
      ConstellationPoint,
      PrefetchHooks Function()
    >;
typedef $$WeeklyGoalsTableCreateCompanionBuilder =
    WeeklyGoalsCompanion Function({
      required String id,
      required String title,
      required int targetCount,
      Value<int> currentCount,
      Value<bool> isCompleted,
      Value<int> rowid,
    });
typedef $$WeeklyGoalsTableUpdateCompanionBuilder =
    WeeklyGoalsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<int> targetCount,
      Value<int> currentCount,
      Value<bool> isCompleted,
      Value<int> rowid,
    });

class $$WeeklyGoalsTableFilterComposer
    extends Composer<_$RecoveryDatabase, $WeeklyGoalsTable> {
  $$WeeklyGoalsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetCount => $composableBuilder(
    column: $table.targetCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentCount => $composableBuilder(
    column: $table.currentCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeeklyGoalsTableOrderingComposer
    extends Composer<_$RecoveryDatabase, $WeeklyGoalsTable> {
  $$WeeklyGoalsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetCount => $composableBuilder(
    column: $table.targetCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentCount => $composableBuilder(
    column: $table.currentCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeeklyGoalsTableAnnotationComposer
    extends Composer<_$RecoveryDatabase, $WeeklyGoalsTable> {
  $$WeeklyGoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get targetCount => $composableBuilder(
    column: $table.targetCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentCount => $composableBuilder(
    column: $table.currentCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );
}

class $$WeeklyGoalsTableTableManager
    extends
        RootTableManager<
          _$RecoveryDatabase,
          $WeeklyGoalsTable,
          WeeklyGoal,
          $$WeeklyGoalsTableFilterComposer,
          $$WeeklyGoalsTableOrderingComposer,
          $$WeeklyGoalsTableAnnotationComposer,
          $$WeeklyGoalsTableCreateCompanionBuilder,
          $$WeeklyGoalsTableUpdateCompanionBuilder,
          (
            WeeklyGoal,
            BaseReferences<_$RecoveryDatabase, $WeeklyGoalsTable, WeeklyGoal>,
          ),
          WeeklyGoal,
          PrefetchHooks Function()
        > {
  $$WeeklyGoalsTableTableManager(_$RecoveryDatabase db, $WeeklyGoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeeklyGoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeeklyGoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeeklyGoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> targetCount = const Value.absent(),
                Value<int> currentCount = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeeklyGoalsCompanion(
                id: id,
                title: title,
                targetCount: targetCount,
                currentCount: currentCount,
                isCompleted: isCompleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required int targetCount,
                Value<int> currentCount = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeeklyGoalsCompanion.insert(
                id: id,
                title: title,
                targetCount: targetCount,
                currentCount: currentCount,
                isCompleted: isCompleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeeklyGoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$RecoveryDatabase,
      $WeeklyGoalsTable,
      WeeklyGoal,
      $$WeeklyGoalsTableFilterComposer,
      $$WeeklyGoalsTableOrderingComposer,
      $$WeeklyGoalsTableAnnotationComposer,
      $$WeeklyGoalsTableCreateCompanionBuilder,
      $$WeeklyGoalsTableUpdateCompanionBuilder,
      (
        WeeklyGoal,
        BaseReferences<_$RecoveryDatabase, $WeeklyGoalsTable, WeeklyGoal>,
      ),
      WeeklyGoal,
      PrefetchHooks Function()
    >;
typedef $$WellnessCheckInsTableCreateCompanionBuilder =
    WellnessCheckInsCompanion Function({
      required String id,
      required int timestamp,
      required double spiritual,
      required double intellectual,
      required double emotional,
      required double physical,
      required double social,
      required double occupational,
      Value<int> rowid,
    });
typedef $$WellnessCheckInsTableUpdateCompanionBuilder =
    WellnessCheckInsCompanion Function({
      Value<String> id,
      Value<int> timestamp,
      Value<double> spiritual,
      Value<double> intellectual,
      Value<double> emotional,
      Value<double> physical,
      Value<double> social,
      Value<double> occupational,
      Value<int> rowid,
    });

class $$WellnessCheckInsTableFilterComposer
    extends Composer<_$RecoveryDatabase, $WellnessCheckInsTable> {
  $$WellnessCheckInsTableFilterComposer({
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

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get spiritual => $composableBuilder(
    column: $table.spiritual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get intellectual => $composableBuilder(
    column: $table.intellectual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get emotional => $composableBuilder(
    column: $table.emotional,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get physical => $composableBuilder(
    column: $table.physical,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get social => $composableBuilder(
    column: $table.social,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get occupational => $composableBuilder(
    column: $table.occupational,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WellnessCheckInsTableOrderingComposer
    extends Composer<_$RecoveryDatabase, $WellnessCheckInsTable> {
  $$WellnessCheckInsTableOrderingComposer({
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

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get spiritual => $composableBuilder(
    column: $table.spiritual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get intellectual => $composableBuilder(
    column: $table.intellectual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get emotional => $composableBuilder(
    column: $table.emotional,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get physical => $composableBuilder(
    column: $table.physical,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get social => $composableBuilder(
    column: $table.social,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get occupational => $composableBuilder(
    column: $table.occupational,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WellnessCheckInsTableAnnotationComposer
    extends Composer<_$RecoveryDatabase, $WellnessCheckInsTable> {
  $$WellnessCheckInsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<double> get spiritual =>
      $composableBuilder(column: $table.spiritual, builder: (column) => column);

  GeneratedColumn<double> get intellectual => $composableBuilder(
    column: $table.intellectual,
    builder: (column) => column,
  );

  GeneratedColumn<double> get emotional =>
      $composableBuilder(column: $table.emotional, builder: (column) => column);

  GeneratedColumn<double> get physical =>
      $composableBuilder(column: $table.physical, builder: (column) => column);

  GeneratedColumn<double> get social =>
      $composableBuilder(column: $table.social, builder: (column) => column);

  GeneratedColumn<double> get occupational => $composableBuilder(
    column: $table.occupational,
    builder: (column) => column,
  );
}

class $$WellnessCheckInsTableTableManager
    extends
        RootTableManager<
          _$RecoveryDatabase,
          $WellnessCheckInsTable,
          WellnessCheckIn,
          $$WellnessCheckInsTableFilterComposer,
          $$WellnessCheckInsTableOrderingComposer,
          $$WellnessCheckInsTableAnnotationComposer,
          $$WellnessCheckInsTableCreateCompanionBuilder,
          $$WellnessCheckInsTableUpdateCompanionBuilder,
          (
            WellnessCheckIn,
            BaseReferences<
              _$RecoveryDatabase,
              $WellnessCheckInsTable,
              WellnessCheckIn
            >,
          ),
          WellnessCheckIn,
          PrefetchHooks Function()
        > {
  $$WellnessCheckInsTableTableManager(
    _$RecoveryDatabase db,
    $WellnessCheckInsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WellnessCheckInsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WellnessCheckInsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WellnessCheckInsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<double> spiritual = const Value.absent(),
                Value<double> intellectual = const Value.absent(),
                Value<double> emotional = const Value.absent(),
                Value<double> physical = const Value.absent(),
                Value<double> social = const Value.absent(),
                Value<double> occupational = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WellnessCheckInsCompanion(
                id: id,
                timestamp: timestamp,
                spiritual: spiritual,
                intellectual: intellectual,
                emotional: emotional,
                physical: physical,
                social: social,
                occupational: occupational,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int timestamp,
                required double spiritual,
                required double intellectual,
                required double emotional,
                required double physical,
                required double social,
                required double occupational,
                Value<int> rowid = const Value.absent(),
              }) => WellnessCheckInsCompanion.insert(
                id: id,
                timestamp: timestamp,
                spiritual: spiritual,
                intellectual: intellectual,
                emotional: emotional,
                physical: physical,
                social: social,
                occupational: occupational,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WellnessCheckInsTableProcessedTableManager =
    ProcessedTableManager<
      _$RecoveryDatabase,
      $WellnessCheckInsTable,
      WellnessCheckIn,
      $$WellnessCheckInsTableFilterComposer,
      $$WellnessCheckInsTableOrderingComposer,
      $$WellnessCheckInsTableAnnotationComposer,
      $$WellnessCheckInsTableCreateCompanionBuilder,
      $$WellnessCheckInsTableUpdateCompanionBuilder,
      (
        WellnessCheckIn,
        BaseReferences<
          _$RecoveryDatabase,
          $WellnessCheckInsTable,
          WellnessCheckIn
        >,
      ),
      WellnessCheckIn,
      PrefetchHooks Function()
    >;

class $RecoveryDatabaseManager {
  final _$RecoveryDatabase _db;
  $RecoveryDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$CountersTableTableManager get counters =>
      $$CountersTableTableManager(_db, _db.counters);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(_db, _db.journalEntries);
  $$ConstellationPointsTableTableManager get constellationPoints =>
      $$ConstellationPointsTableTableManager(_db, _db.constellationPoints);
  $$WeeklyGoalsTableTableManager get weeklyGoals =>
      $$WeeklyGoalsTableTableManager(_db, _db.weeklyGoals);
  $$WellnessCheckInsTableTableManager get wellnessCheckIns =>
      $$WellnessCheckInsTableTableManager(_db, _db.wellnessCheckIns);
}
