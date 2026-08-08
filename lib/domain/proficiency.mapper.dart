// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'proficiency.dart';

class ProficiencyMapper extends ClassMapperBase<Proficiency> {
  ProficiencyMapper._();

  static ProficiencyMapper? _instance;
  static ProficiencyMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProficiencyMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Proficiency';

  static int _$id(Proficiency v) => v.id;
  static const Field<Proficiency, int> _f$id = Field('id', _$id);
  static int _$pips(Proficiency v) => v.pips;
  static const Field<Proficiency, int> _f$pips = Field('pips', _$pips);
  static int _$effectOffset(Proficiency v) => v.effectOffset;
  static const Field<Proficiency, int> _f$effectOffset = Field(
    'effectOffset',
    _$effectOffset,
  );

  @override
  final MappableFields<Proficiency> fields = const {
    #id: _f$id,
    #pips: _f$pips,
    #effectOffset: _f$effectOffset,
  };

  static Proficiency _instantiate(DecodingData data) {
    return Proficiency(
      id: data.dec(_f$id),
      pips: data.dec(_f$pips),
      effectOffset: data.dec(_f$effectOffset),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Proficiency fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Proficiency>(map);
  }

  static Proficiency fromJson(String json) {
    return ensureInitialized().decodeJson<Proficiency>(json);
  }
}

mixin ProficiencyMappable {
  String toJson() {
    return ProficiencyMapper.ensureInitialized().encodeJson<Proficiency>(
      this as Proficiency,
    );
  }

  Map<String, dynamic> toMap() {
    return ProficiencyMapper.ensureInitialized().encodeMap<Proficiency>(
      this as Proficiency,
    );
  }

  ProficiencyCopyWith<Proficiency, Proficiency, Proficiency> get copyWith =>
      _ProficiencyCopyWithImpl<Proficiency, Proficiency>(
        this as Proficiency,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ProficiencyMapper.ensureInitialized().stringifyValue(
      this as Proficiency,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProficiencyMapper.ensureInitialized().equalsValue(
      this as Proficiency,
      other,
    );
  }

  @override
  int get hashCode {
    return ProficiencyMapper.ensureInitialized().hashValue(this as Proficiency);
  }
}

extension ProficiencyValueCopy<$R, $Out>
    on ObjectCopyWith<$R, Proficiency, $Out> {
  ProficiencyCopyWith<$R, Proficiency, $Out> get $asProficiency =>
      $base.as((v, t, t2) => _ProficiencyCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ProficiencyCopyWith<$R, $In extends Proficiency, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? id, int? pips, int? effectOffset});
  ProficiencyCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ProficiencyCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Proficiency, $Out>
    implements ProficiencyCopyWith<$R, Proficiency, $Out> {
  _ProficiencyCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Proficiency> $mapper =
      ProficiencyMapper.ensureInitialized();
  @override
  $R call({int? id, int? pips, int? effectOffset}) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (pips != null) #pips: pips,
      if (effectOffset != null) #effectOffset: effectOffset,
    }),
  );
  @override
  Proficiency $make(CopyWithData data) => Proficiency(
    id: data.get(#id, or: $value.id),
    pips: data.get(#pips, or: $value.pips),
    effectOffset: data.get(#effectOffset, or: $value.effectOffset),
  );

  @override
  ProficiencyCopyWith<$R2, Proficiency, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ProficiencyCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

