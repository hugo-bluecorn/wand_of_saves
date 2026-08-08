// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'saving_throws.dart';

class SavingThrowsMapper extends ClassMapperBase<SavingThrows> {
  SavingThrowsMapper._();

  static SavingThrowsMapper? _instance;
  static SavingThrowsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SavingThrowsMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'SavingThrows';

  static int _$death(SavingThrows v) => v.death;
  static const Field<SavingThrows, int> _f$death = Field('death', _$death);
  static int _$wands(SavingThrows v) => v.wands;
  static const Field<SavingThrows, int> _f$wands = Field('wands', _$wands);
  static int _$polymorph(SavingThrows v) => v.polymorph;
  static const Field<SavingThrows, int> _f$polymorph = Field(
    'polymorph',
    _$polymorph,
  );
  static int _$breath(SavingThrows v) => v.breath;
  static const Field<SavingThrows, int> _f$breath = Field('breath', _$breath);
  static int _$spells(SavingThrows v) => v.spells;
  static const Field<SavingThrows, int> _f$spells = Field('spells', _$spells);

  @override
  final MappableFields<SavingThrows> fields = const {
    #death: _f$death,
    #wands: _f$wands,
    #polymorph: _f$polymorph,
    #breath: _f$breath,
    #spells: _f$spells,
  };

  static SavingThrows _instantiate(DecodingData data) {
    return SavingThrows(
      death: data.dec(_f$death),
      wands: data.dec(_f$wands),
      polymorph: data.dec(_f$polymorph),
      breath: data.dec(_f$breath),
      spells: data.dec(_f$spells),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SavingThrows fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SavingThrows>(map);
  }

  static SavingThrows fromJson(String json) {
    return ensureInitialized().decodeJson<SavingThrows>(json);
  }
}

mixin SavingThrowsMappable {
  String toJson() {
    return SavingThrowsMapper.ensureInitialized().encodeJson<SavingThrows>(
      this as SavingThrows,
    );
  }

  Map<String, dynamic> toMap() {
    return SavingThrowsMapper.ensureInitialized().encodeMap<SavingThrows>(
      this as SavingThrows,
    );
  }

  SavingThrowsCopyWith<SavingThrows, SavingThrows, SavingThrows> get copyWith =>
      _SavingThrowsCopyWithImpl<SavingThrows, SavingThrows>(
        this as SavingThrows,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SavingThrowsMapper.ensureInitialized().stringifyValue(
      this as SavingThrows,
    );
  }

  @override
  bool operator ==(Object other) {
    return SavingThrowsMapper.ensureInitialized().equalsValue(
      this as SavingThrows,
      other,
    );
  }

  @override
  int get hashCode {
    return SavingThrowsMapper.ensureInitialized().hashValue(
      this as SavingThrows,
    );
  }
}

extension SavingThrowsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SavingThrows, $Out> {
  SavingThrowsCopyWith<$R, SavingThrows, $Out> get $asSavingThrows =>
      $base.as((v, t, t2) => _SavingThrowsCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SavingThrowsCopyWith<$R, $In extends SavingThrows, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? death, int? wands, int? polymorph, int? breath, int? spells});
  SavingThrowsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SavingThrowsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SavingThrows, $Out>
    implements SavingThrowsCopyWith<$R, SavingThrows, $Out> {
  _SavingThrowsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SavingThrows> $mapper =
      SavingThrowsMapper.ensureInitialized();
  @override
  $R call({int? death, int? wands, int? polymorph, int? breath, int? spells}) =>
      $apply(
        FieldCopyWithData({
          if (death != null) #death: death,
          if (wands != null) #wands: wands,
          if (polymorph != null) #polymorph: polymorph,
          if (breath != null) #breath: breath,
          if (spells != null) #spells: spells,
        }),
      );
  @override
  SavingThrows $make(CopyWithData data) => SavingThrows(
    death: data.get(#death, or: $value.death),
    wands: data.get(#wands, or: $value.wands),
    polymorph: data.get(#polymorph, or: $value.polymorph),
    breath: data.get(#breath, or: $value.breath),
    spells: data.get(#spells, or: $value.spells),
  );

  @override
  SavingThrowsCopyWith<$R2, SavingThrows, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SavingThrowsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

