// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'carried_item.dart';

class CarriedItemMapper extends ClassMapperBase<CarriedItem> {
  CarriedItemMapper._();

  static CarriedItemMapper? _instance;
  static CarriedItemMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CarriedItemMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'CarriedItem';

  static String _$resref(CarriedItem v) => v.resref;
  static const Field<CarriedItem, String> _f$resref = Field('resref', _$resref);
  static int _$index(CarriedItem v) => v.index;
  static const Field<CarriedItem, int> _f$index = Field('index', _$index);
  static int _$slotIndex(CarriedItem v) => v.slotIndex;
  static const Field<CarriedItem, int> _f$slotIndex = Field(
    'slotIndex',
    _$slotIndex,
  );
  static int _$quantity(CarriedItem v) => v.quantity;
  static const Field<CarriedItem, int> _f$quantity = Field(
    'quantity',
    _$quantity,
    opt: true,
    def: 1,
  );
  static bool _$isIdentified(CarriedItem v) => v.isIdentified;
  static const Field<CarriedItem, bool> _f$isIdentified = Field(
    'isIdentified',
    _$isIdentified,
    opt: true,
    def: true,
  );

  @override
  final MappableFields<CarriedItem> fields = const {
    #resref: _f$resref,
    #index: _f$index,
    #slotIndex: _f$slotIndex,
    #quantity: _f$quantity,
    #isIdentified: _f$isIdentified,
  };

  static CarriedItem _instantiate(DecodingData data) {
    return CarriedItem(
      resref: data.dec(_f$resref),
      index: data.dec(_f$index),
      slotIndex: data.dec(_f$slotIndex),
      quantity: data.dec(_f$quantity),
      isIdentified: data.dec(_f$isIdentified),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CarriedItem fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CarriedItem>(map);
  }

  static CarriedItem fromJson(String json) {
    return ensureInitialized().decodeJson<CarriedItem>(json);
  }
}

mixin CarriedItemMappable {
  String toJson() {
    return CarriedItemMapper.ensureInitialized().encodeJson<CarriedItem>(
      this as CarriedItem,
    );
  }

  Map<String, dynamic> toMap() {
    return CarriedItemMapper.ensureInitialized().encodeMap<CarriedItem>(
      this as CarriedItem,
    );
  }

  CarriedItemCopyWith<CarriedItem, CarriedItem, CarriedItem> get copyWith =>
      _CarriedItemCopyWithImpl<CarriedItem, CarriedItem>(
        this as CarriedItem,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CarriedItemMapper.ensureInitialized().stringifyValue(
      this as CarriedItem,
    );
  }

  @override
  bool operator ==(Object other) {
    return CarriedItemMapper.ensureInitialized().equalsValue(
      this as CarriedItem,
      other,
    );
  }

  @override
  int get hashCode {
    return CarriedItemMapper.ensureInitialized().hashValue(this as CarriedItem);
  }
}

extension CarriedItemValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CarriedItem, $Out> {
  CarriedItemCopyWith<$R, CarriedItem, $Out> get $asCarriedItem =>
      $base.as((v, t, t2) => _CarriedItemCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CarriedItemCopyWith<$R, $In extends CarriedItem, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? resref,
    int? index,
    int? slotIndex,
    int? quantity,
    bool? isIdentified,
  });
  CarriedItemCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CarriedItemCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CarriedItem, $Out>
    implements CarriedItemCopyWith<$R, CarriedItem, $Out> {
  _CarriedItemCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CarriedItem> $mapper =
      CarriedItemMapper.ensureInitialized();
  @override
  $R call({
    String? resref,
    int? index,
    int? slotIndex,
    int? quantity,
    bool? isIdentified,
  }) => $apply(
    FieldCopyWithData({
      if (resref != null) #resref: resref,
      if (index != null) #index: index,
      if (slotIndex != null) #slotIndex: slotIndex,
      if (quantity != null) #quantity: quantity,
      if (isIdentified != null) #isIdentified: isIdentified,
    }),
  );
  @override
  CarriedItem $make(CopyWithData data) => CarriedItem(
    resref: data.get(#resref, or: $value.resref),
    index: data.get(#index, or: $value.index),
    slotIndex: data.get(#slotIndex, or: $value.slotIndex),
    quantity: data.get(#quantity, or: $value.quantity),
    isIdentified: data.get(#isIdentified, or: $value.isIdentified),
  );

  @override
  CarriedItemCopyWith<$R2, CarriedItem, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CarriedItemCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

