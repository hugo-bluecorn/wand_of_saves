// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'armor_class_modifiers.dart';

class ArmorClassModifiersMapper extends ClassMapperBase<ArmorClassModifiers> {
  ArmorClassModifiersMapper._();

  static ArmorClassModifiersMapper? _instance;
  static ArmorClassModifiersMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ArmorClassModifiersMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ArmorClassModifiers';

  static int _$crushing(ArmorClassModifiers v) => v.crushing;
  static const Field<ArmorClassModifiers, int> _f$crushing = Field(
    'crushing',
    _$crushing,
  );
  static int _$missile(ArmorClassModifiers v) => v.missile;
  static const Field<ArmorClassModifiers, int> _f$missile = Field(
    'missile',
    _$missile,
  );
  static int _$piercing(ArmorClassModifiers v) => v.piercing;
  static const Field<ArmorClassModifiers, int> _f$piercing = Field(
    'piercing',
    _$piercing,
  );
  static int _$slashing(ArmorClassModifiers v) => v.slashing;
  static const Field<ArmorClassModifiers, int> _f$slashing = Field(
    'slashing',
    _$slashing,
  );

  @override
  final MappableFields<ArmorClassModifiers> fields = const {
    #crushing: _f$crushing,
    #missile: _f$missile,
    #piercing: _f$piercing,
    #slashing: _f$slashing,
  };

  static ArmorClassModifiers _instantiate(DecodingData data) {
    return ArmorClassModifiers(
      crushing: data.dec(_f$crushing),
      missile: data.dec(_f$missile),
      piercing: data.dec(_f$piercing),
      slashing: data.dec(_f$slashing),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ArmorClassModifiers fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ArmorClassModifiers>(map);
  }

  static ArmorClassModifiers fromJson(String json) {
    return ensureInitialized().decodeJson<ArmorClassModifiers>(json);
  }
}

mixin ArmorClassModifiersMappable {
  String toJson() {
    return ArmorClassModifiersMapper.ensureInitialized()
        .encodeJson<ArmorClassModifiers>(this as ArmorClassModifiers);
  }

  Map<String, dynamic> toMap() {
    return ArmorClassModifiersMapper.ensureInitialized()
        .encodeMap<ArmorClassModifiers>(this as ArmorClassModifiers);
  }

  ArmorClassModifiersCopyWith<
    ArmorClassModifiers,
    ArmorClassModifiers,
    ArmorClassModifiers
  >
  get copyWith =>
      _ArmorClassModifiersCopyWithImpl<
        ArmorClassModifiers,
        ArmorClassModifiers
      >(this as ArmorClassModifiers, $identity, $identity);
  @override
  String toString() {
    return ArmorClassModifiersMapper.ensureInitialized().stringifyValue(
      this as ArmorClassModifiers,
    );
  }

  @override
  bool operator ==(Object other) {
    return ArmorClassModifiersMapper.ensureInitialized().equalsValue(
      this as ArmorClassModifiers,
      other,
    );
  }

  @override
  int get hashCode {
    return ArmorClassModifiersMapper.ensureInitialized().hashValue(
      this as ArmorClassModifiers,
    );
  }
}

extension ArmorClassModifiersValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ArmorClassModifiers, $Out> {
  ArmorClassModifiersCopyWith<$R, ArmorClassModifiers, $Out>
  get $asArmorClassModifiers => $base.as(
    (v, t, t2) => _ArmorClassModifiersCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ArmorClassModifiersCopyWith<
  $R,
  $In extends ArmorClassModifiers,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? crushing, int? missile, int? piercing, int? slashing});
  ArmorClassModifiersCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ArmorClassModifiersCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ArmorClassModifiers, $Out>
    implements ArmorClassModifiersCopyWith<$R, ArmorClassModifiers, $Out> {
  _ArmorClassModifiersCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ArmorClassModifiers> $mapper =
      ArmorClassModifiersMapper.ensureInitialized();
  @override
  $R call({int? crushing, int? missile, int? piercing, int? slashing}) =>
      $apply(
        FieldCopyWithData({
          if (crushing != null) #crushing: crushing,
          if (missile != null) #missile: missile,
          if (piercing != null) #piercing: piercing,
          if (slashing != null) #slashing: slashing,
        }),
      );
  @override
  ArmorClassModifiers $make(CopyWithData data) => ArmorClassModifiers(
    crushing: data.get(#crushing, or: $value.crushing),
    missile: data.get(#missile, or: $value.missile),
    piercing: data.get(#piercing, or: $value.piercing),
    slashing: data.get(#slashing, or: $value.slashing),
  );

  @override
  ArmorClassModifiersCopyWith<$R2, ArmorClassModifiers, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ArmorClassModifiersCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

