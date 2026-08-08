// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'resistances.dart';

class ResistancesMapper extends ClassMapperBase<Resistances> {
  ResistancesMapper._();

  static ResistancesMapper? _instance;
  static ResistancesMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ResistancesMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Resistances';

  static int _$fire(Resistances v) => v.fire;
  static const Field<Resistances, int> _f$fire = Field('fire', _$fire);
  static int _$cold(Resistances v) => v.cold;
  static const Field<Resistances, int> _f$cold = Field('cold', _$cold);
  static int _$electricity(Resistances v) => v.electricity;
  static const Field<Resistances, int> _f$electricity = Field(
    'electricity',
    _$electricity,
  );
  static int _$acid(Resistances v) => v.acid;
  static const Field<Resistances, int> _f$acid = Field('acid', _$acid);
  static int _$magic(Resistances v) => v.magic;
  static const Field<Resistances, int> _f$magic = Field('magic', _$magic);
  static int _$magicFire(Resistances v) => v.magicFire;
  static const Field<Resistances, int> _f$magicFire = Field(
    'magicFire',
    _$magicFire,
  );
  static int _$magicCold(Resistances v) => v.magicCold;
  static const Field<Resistances, int> _f$magicCold = Field(
    'magicCold',
    _$magicCold,
  );
  static int _$slashing(Resistances v) => v.slashing;
  static const Field<Resistances, int> _f$slashing = Field(
    'slashing',
    _$slashing,
  );
  static int _$crushing(Resistances v) => v.crushing;
  static const Field<Resistances, int> _f$crushing = Field(
    'crushing',
    _$crushing,
  );
  static int _$piercing(Resistances v) => v.piercing;
  static const Field<Resistances, int> _f$piercing = Field(
    'piercing',
    _$piercing,
  );
  static int _$missile(Resistances v) => v.missile;
  static const Field<Resistances, int> _f$missile = Field('missile', _$missile);

  @override
  final MappableFields<Resistances> fields = const {
    #fire: _f$fire,
    #cold: _f$cold,
    #electricity: _f$electricity,
    #acid: _f$acid,
    #magic: _f$magic,
    #magicFire: _f$magicFire,
    #magicCold: _f$magicCold,
    #slashing: _f$slashing,
    #crushing: _f$crushing,
    #piercing: _f$piercing,
    #missile: _f$missile,
  };

  static Resistances _instantiate(DecodingData data) {
    return Resistances(
      fire: data.dec(_f$fire),
      cold: data.dec(_f$cold),
      electricity: data.dec(_f$electricity),
      acid: data.dec(_f$acid),
      magic: data.dec(_f$magic),
      magicFire: data.dec(_f$magicFire),
      magicCold: data.dec(_f$magicCold),
      slashing: data.dec(_f$slashing),
      crushing: data.dec(_f$crushing),
      piercing: data.dec(_f$piercing),
      missile: data.dec(_f$missile),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Resistances fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Resistances>(map);
  }

  static Resistances fromJson(String json) {
    return ensureInitialized().decodeJson<Resistances>(json);
  }
}

mixin ResistancesMappable {
  String toJson() {
    return ResistancesMapper.ensureInitialized().encodeJson<Resistances>(
      this as Resistances,
    );
  }

  Map<String, dynamic> toMap() {
    return ResistancesMapper.ensureInitialized().encodeMap<Resistances>(
      this as Resistances,
    );
  }

  ResistancesCopyWith<Resistances, Resistances, Resistances> get copyWith =>
      _ResistancesCopyWithImpl<Resistances, Resistances>(
        this as Resistances,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ResistancesMapper.ensureInitialized().stringifyValue(
      this as Resistances,
    );
  }

  @override
  bool operator ==(Object other) {
    return ResistancesMapper.ensureInitialized().equalsValue(
      this as Resistances,
      other,
    );
  }

  @override
  int get hashCode {
    return ResistancesMapper.ensureInitialized().hashValue(this as Resistances);
  }
}

extension ResistancesValueCopy<$R, $Out>
    on ObjectCopyWith<$R, Resistances, $Out> {
  ResistancesCopyWith<$R, Resistances, $Out> get $asResistances =>
      $base.as((v, t, t2) => _ResistancesCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ResistancesCopyWith<$R, $In extends Resistances, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    int? fire,
    int? cold,
    int? electricity,
    int? acid,
    int? magic,
    int? magicFire,
    int? magicCold,
    int? slashing,
    int? crushing,
    int? piercing,
    int? missile,
  });
  ResistancesCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ResistancesCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Resistances, $Out>
    implements ResistancesCopyWith<$R, Resistances, $Out> {
  _ResistancesCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Resistances> $mapper =
      ResistancesMapper.ensureInitialized();
  @override
  $R call({
    int? fire,
    int? cold,
    int? electricity,
    int? acid,
    int? magic,
    int? magicFire,
    int? magicCold,
    int? slashing,
    int? crushing,
    int? piercing,
    int? missile,
  }) => $apply(
    FieldCopyWithData({
      if (fire != null) #fire: fire,
      if (cold != null) #cold: cold,
      if (electricity != null) #electricity: electricity,
      if (acid != null) #acid: acid,
      if (magic != null) #magic: magic,
      if (magicFire != null) #magicFire: magicFire,
      if (magicCold != null) #magicCold: magicCold,
      if (slashing != null) #slashing: slashing,
      if (crushing != null) #crushing: crushing,
      if (piercing != null) #piercing: piercing,
      if (missile != null) #missile: missile,
    }),
  );
  @override
  Resistances $make(CopyWithData data) => Resistances(
    fire: data.get(#fire, or: $value.fire),
    cold: data.get(#cold, or: $value.cold),
    electricity: data.get(#electricity, or: $value.electricity),
    acid: data.get(#acid, or: $value.acid),
    magic: data.get(#magic, or: $value.magic),
    magicFire: data.get(#magicFire, or: $value.magicFire),
    magicCold: data.get(#magicCold, or: $value.magicCold),
    slashing: data.get(#slashing, or: $value.slashing),
    crushing: data.get(#crushing, or: $value.crushing),
    piercing: data.get(#piercing, or: $value.piercing),
    missile: data.get(#missile, or: $value.missile),
  );

  @override
  ResistancesCopyWith<$R2, Resistances, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ResistancesCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

