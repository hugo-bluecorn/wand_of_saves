// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'ability_scores.dart';

class AbilityScoresMapper extends ClassMapperBase<AbilityScores> {
  AbilityScoresMapper._();

  static AbilityScoresMapper? _instance;
  static AbilityScoresMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AbilityScoresMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'AbilityScores';

  static int _$strength(AbilityScores v) => v.strength;
  static const Field<AbilityScores, int> _f$strength = Field(
    'strength',
    _$strength,
  );
  static int _$strengthBonus(AbilityScores v) => v.strengthBonus;
  static const Field<AbilityScores, int> _f$strengthBonus = Field(
    'strengthBonus',
    _$strengthBonus,
  );
  static int _$dexterity(AbilityScores v) => v.dexterity;
  static const Field<AbilityScores, int> _f$dexterity = Field(
    'dexterity',
    _$dexterity,
  );
  static int _$constitution(AbilityScores v) => v.constitution;
  static const Field<AbilityScores, int> _f$constitution = Field(
    'constitution',
    _$constitution,
  );
  static int _$intelligence(AbilityScores v) => v.intelligence;
  static const Field<AbilityScores, int> _f$intelligence = Field(
    'intelligence',
    _$intelligence,
  );
  static int _$wisdom(AbilityScores v) => v.wisdom;
  static const Field<AbilityScores, int> _f$wisdom = Field('wisdom', _$wisdom);
  static int _$charisma(AbilityScores v) => v.charisma;
  static const Field<AbilityScores, int> _f$charisma = Field(
    'charisma',
    _$charisma,
  );

  @override
  final MappableFields<AbilityScores> fields = const {
    #strength: _f$strength,
    #strengthBonus: _f$strengthBonus,
    #dexterity: _f$dexterity,
    #constitution: _f$constitution,
    #intelligence: _f$intelligence,
    #wisdom: _f$wisdom,
    #charisma: _f$charisma,
  };

  static AbilityScores _instantiate(DecodingData data) {
    return AbilityScores(
      strength: data.dec(_f$strength),
      strengthBonus: data.dec(_f$strengthBonus),
      dexterity: data.dec(_f$dexterity),
      constitution: data.dec(_f$constitution),
      intelligence: data.dec(_f$intelligence),
      wisdom: data.dec(_f$wisdom),
      charisma: data.dec(_f$charisma),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static AbilityScores fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AbilityScores>(map);
  }

  static AbilityScores fromJson(String json) {
    return ensureInitialized().decodeJson<AbilityScores>(json);
  }
}

mixin AbilityScoresMappable {
  String toJson() {
    return AbilityScoresMapper.ensureInitialized().encodeJson<AbilityScores>(
      this as AbilityScores,
    );
  }

  Map<String, dynamic> toMap() {
    return AbilityScoresMapper.ensureInitialized().encodeMap<AbilityScores>(
      this as AbilityScores,
    );
  }

  AbilityScoresCopyWith<AbilityScores, AbilityScores, AbilityScores>
  get copyWith => _AbilityScoresCopyWithImpl<AbilityScores, AbilityScores>(
    this as AbilityScores,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return AbilityScoresMapper.ensureInitialized().stringifyValue(
      this as AbilityScores,
    );
  }

  @override
  bool operator ==(Object other) {
    return AbilityScoresMapper.ensureInitialized().equalsValue(
      this as AbilityScores,
      other,
    );
  }

  @override
  int get hashCode {
    return AbilityScoresMapper.ensureInitialized().hashValue(
      this as AbilityScores,
    );
  }
}

extension AbilityScoresValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AbilityScores, $Out> {
  AbilityScoresCopyWith<$R, AbilityScores, $Out> get $asAbilityScores =>
      $base.as((v, t, t2) => _AbilityScoresCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AbilityScoresCopyWith<$R, $In extends AbilityScores, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    int? strength,
    int? strengthBonus,
    int? dexterity,
    int? constitution,
    int? intelligence,
    int? wisdom,
    int? charisma,
  });
  AbilityScoresCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _AbilityScoresCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AbilityScores, $Out>
    implements AbilityScoresCopyWith<$R, AbilityScores, $Out> {
  _AbilityScoresCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AbilityScores> $mapper =
      AbilityScoresMapper.ensureInitialized();
  @override
  $R call({
    int? strength,
    int? strengthBonus,
    int? dexterity,
    int? constitution,
    int? intelligence,
    int? wisdom,
    int? charisma,
  }) => $apply(
    FieldCopyWithData({
      if (strength != null) #strength: strength,
      if (strengthBonus != null) #strengthBonus: strengthBonus,
      if (dexterity != null) #dexterity: dexterity,
      if (constitution != null) #constitution: constitution,
      if (intelligence != null) #intelligence: intelligence,
      if (wisdom != null) #wisdom: wisdom,
      if (charisma != null) #charisma: charisma,
    }),
  );
  @override
  AbilityScores $make(CopyWithData data) => AbilityScores(
    strength: data.get(#strength, or: $value.strength),
    strengthBonus: data.get(#strengthBonus, or: $value.strengthBonus),
    dexterity: data.get(#dexterity, or: $value.dexterity),
    constitution: data.get(#constitution, or: $value.constitution),
    intelligence: data.get(#intelligence, or: $value.intelligence),
    wisdom: data.get(#wisdom, or: $value.wisdom),
    charisma: data.get(#charisma, or: $value.charisma),
  );

  @override
  AbilityScoresCopyWith<$R2, AbilityScores, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AbilityScoresCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

