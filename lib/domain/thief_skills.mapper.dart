// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'thief_skills.dart';

class ThiefSkillsMapper extends ClassMapperBase<ThiefSkills> {
  ThiefSkillsMapper._();

  static ThiefSkillsMapper? _instance;
  static ThiefSkillsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ThiefSkillsMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ThiefSkills';

  static int _$hideInShadows(ThiefSkills v) => v.hideInShadows;
  static const Field<ThiefSkills, int> _f$hideInShadows = Field(
    'hideInShadows',
    _$hideInShadows,
  );
  static int _$detectIllusion(ThiefSkills v) => v.detectIllusion;
  static const Field<ThiefSkills, int> _f$detectIllusion = Field(
    'detectIllusion',
    _$detectIllusion,
  );
  static int _$setTraps(ThiefSkills v) => v.setTraps;
  static const Field<ThiefSkills, int> _f$setTraps = Field(
    'setTraps',
    _$setTraps,
  );
  static int _$lore(ThiefSkills v) => v.lore;
  static const Field<ThiefSkills, int> _f$lore = Field('lore', _$lore);
  static int _$lockpicking(ThiefSkills v) => v.lockpicking;
  static const Field<ThiefSkills, int> _f$lockpicking = Field(
    'lockpicking',
    _$lockpicking,
  );
  static int _$moveSilently(ThiefSkills v) => v.moveSilently;
  static const Field<ThiefSkills, int> _f$moveSilently = Field(
    'moveSilently',
    _$moveSilently,
  );
  static int _$findTraps(ThiefSkills v) => v.findTraps;
  static const Field<ThiefSkills, int> _f$findTraps = Field(
    'findTraps',
    _$findTraps,
  );
  static int _$pickPockets(ThiefSkills v) => v.pickPockets;
  static const Field<ThiefSkills, int> _f$pickPockets = Field(
    'pickPockets',
    _$pickPockets,
  );

  @override
  final MappableFields<ThiefSkills> fields = const {
    #hideInShadows: _f$hideInShadows,
    #detectIllusion: _f$detectIllusion,
    #setTraps: _f$setTraps,
    #lore: _f$lore,
    #lockpicking: _f$lockpicking,
    #moveSilently: _f$moveSilently,
    #findTraps: _f$findTraps,
    #pickPockets: _f$pickPockets,
  };

  static ThiefSkills _instantiate(DecodingData data) {
    return ThiefSkills(
      hideInShadows: data.dec(_f$hideInShadows),
      detectIllusion: data.dec(_f$detectIllusion),
      setTraps: data.dec(_f$setTraps),
      lore: data.dec(_f$lore),
      lockpicking: data.dec(_f$lockpicking),
      moveSilently: data.dec(_f$moveSilently),
      findTraps: data.dec(_f$findTraps),
      pickPockets: data.dec(_f$pickPockets),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ThiefSkills fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ThiefSkills>(map);
  }

  static ThiefSkills fromJson(String json) {
    return ensureInitialized().decodeJson<ThiefSkills>(json);
  }
}

mixin ThiefSkillsMappable {
  String toJson() {
    return ThiefSkillsMapper.ensureInitialized().encodeJson<ThiefSkills>(
      this as ThiefSkills,
    );
  }

  Map<String, dynamic> toMap() {
    return ThiefSkillsMapper.ensureInitialized().encodeMap<ThiefSkills>(
      this as ThiefSkills,
    );
  }

  ThiefSkillsCopyWith<ThiefSkills, ThiefSkills, ThiefSkills> get copyWith =>
      _ThiefSkillsCopyWithImpl<ThiefSkills, ThiefSkills>(
        this as ThiefSkills,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ThiefSkillsMapper.ensureInitialized().stringifyValue(
      this as ThiefSkills,
    );
  }

  @override
  bool operator ==(Object other) {
    return ThiefSkillsMapper.ensureInitialized().equalsValue(
      this as ThiefSkills,
      other,
    );
  }

  @override
  int get hashCode {
    return ThiefSkillsMapper.ensureInitialized().hashValue(this as ThiefSkills);
  }
}

extension ThiefSkillsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ThiefSkills, $Out> {
  ThiefSkillsCopyWith<$R, ThiefSkills, $Out> get $asThiefSkills =>
      $base.as((v, t, t2) => _ThiefSkillsCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ThiefSkillsCopyWith<$R, $In extends ThiefSkills, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    int? hideInShadows,
    int? detectIllusion,
    int? setTraps,
    int? lore,
    int? lockpicking,
    int? moveSilently,
    int? findTraps,
    int? pickPockets,
  });
  ThiefSkillsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ThiefSkillsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ThiefSkills, $Out>
    implements ThiefSkillsCopyWith<$R, ThiefSkills, $Out> {
  _ThiefSkillsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ThiefSkills> $mapper =
      ThiefSkillsMapper.ensureInitialized();
  @override
  $R call({
    int? hideInShadows,
    int? detectIllusion,
    int? setTraps,
    int? lore,
    int? lockpicking,
    int? moveSilently,
    int? findTraps,
    int? pickPockets,
  }) => $apply(
    FieldCopyWithData({
      if (hideInShadows != null) #hideInShadows: hideInShadows,
      if (detectIllusion != null) #detectIllusion: detectIllusion,
      if (setTraps != null) #setTraps: setTraps,
      if (lore != null) #lore: lore,
      if (lockpicking != null) #lockpicking: lockpicking,
      if (moveSilently != null) #moveSilently: moveSilently,
      if (findTraps != null) #findTraps: findTraps,
      if (pickPockets != null) #pickPockets: pickPockets,
    }),
  );
  @override
  ThiefSkills $make(CopyWithData data) => ThiefSkills(
    hideInShadows: data.get(#hideInShadows, or: $value.hideInShadows),
    detectIllusion: data.get(#detectIllusion, or: $value.detectIllusion),
    setTraps: data.get(#setTraps, or: $value.setTraps),
    lore: data.get(#lore, or: $value.lore),
    lockpicking: data.get(#lockpicking, or: $value.lockpicking),
    moveSilently: data.get(#moveSilently, or: $value.moveSilently),
    findTraps: data.get(#findTraps, or: $value.findTraps),
    pickPockets: data.get(#pickPockets, or: $value.pickPockets),
  );

  @override
  ThiefSkillsCopyWith<$R2, ThiefSkills, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ThiefSkillsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

