// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'hit_die_tables.dart';

class HitDieTablesMapper extends ClassMapperBase<HitDieTables> {
  HitDieTablesMapper._();

  static HitDieTablesMapper? _instance;
  static HitDieTablesMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = HitDieTablesMapper._());
      _t$_R0Mapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'HitDieTables';

  static Map<String, String> _$tableByClass(HitDieTables v) => v.tableByClass;
  static const Field<HitDieTables, Map<String, String>> _f$tableByClass = Field(
    'tableByClass',
    _$tableByClass,
    opt: true,
    def: const {},
  );
  static Map<String, List<HitDieRow>> _$rowsByTable(HitDieTables v) =>
      v.rowsByTable;
  static const Field<HitDieTables, Map<String, List<HitDieRow>>>
  _f$rowsByTable = Field(
    'rowsByTable',
    _$rowsByTable,
    opt: true,
    def: const {},
  );

  @override
  final MappableFields<HitDieTables> fields = const {
    #tableByClass: _f$tableByClass,
    #rowsByTable: _f$rowsByTable,
  };

  static HitDieTables _instantiate(DecodingData data) {
    return HitDieTables(
      tableByClass: data.dec(_f$tableByClass),
      rowsByTable: data.dec(_f$rowsByTable),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static HitDieTables fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<HitDieTables>(map);
  }

  static HitDieTables fromJson(String json) {
    return ensureInitialized().decodeJson<HitDieTables>(json);
  }
}

mixin HitDieTablesMappable {
  String toJson() {
    return HitDieTablesMapper.ensureInitialized().encodeJson<HitDieTables>(
      this as HitDieTables,
    );
  }

  Map<String, dynamic> toMap() {
    return HitDieTablesMapper.ensureInitialized().encodeMap<HitDieTables>(
      this as HitDieTables,
    );
  }

  HitDieTablesCopyWith<HitDieTables, HitDieTables, HitDieTables> get copyWith =>
      _HitDieTablesCopyWithImpl<HitDieTables, HitDieTables>(
        this as HitDieTables,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return HitDieTablesMapper.ensureInitialized().stringifyValue(
      this as HitDieTables,
    );
  }

  @override
  bool operator ==(Object other) {
    return HitDieTablesMapper.ensureInitialized().equalsValue(
      this as HitDieTables,
      other,
    );
  }

  @override
  int get hashCode {
    return HitDieTablesMapper.ensureInitialized().hashValue(
      this as HitDieTables,
    );
  }
}

extension HitDieTablesValueCopy<$R, $Out>
    on ObjectCopyWith<$R, HitDieTables, $Out> {
  HitDieTablesCopyWith<$R, HitDieTables, $Out> get $asHitDieTables =>
      $base.as((v, t, t2) => _HitDieTablesCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class HitDieTablesCopyWith<$R, $In extends HitDieTables, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, String, ObjectCopyWith<$R, String, String>>
  get tableByClass;
  MapCopyWith<
    $R,
    String,
    List<HitDieRow>,
    ObjectCopyWith<$R, List<HitDieRow>, List<HitDieRow>>
  >
  get rowsByTable;
  $R call({
    Map<String, String>? tableByClass,
    Map<String, List<HitDieRow>>? rowsByTable,
  });
  HitDieTablesCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _HitDieTablesCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, HitDieTables, $Out>
    implements HitDieTablesCopyWith<$R, HitDieTables, $Out> {
  _HitDieTablesCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<HitDieTables> $mapper =
      HitDieTablesMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, String, ObjectCopyWith<$R, String, String>>
  get tableByClass => MapCopyWith(
    $value.tableByClass,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(tableByClass: v),
  );
  @override
  MapCopyWith<
    $R,
    String,
    List<HitDieRow>,
    ObjectCopyWith<$R, List<HitDieRow>, List<HitDieRow>>
  >
  get rowsByTable => MapCopyWith(
    $value.rowsByTable,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(rowsByTable: v),
  );
  @override
  $R call({
    Map<String, String>? tableByClass,
    Map<String, List<HitDieRow>>? rowsByTable,
  }) => $apply(
    FieldCopyWithData({
      if (tableByClass != null) #tableByClass: tableByClass,
      if (rowsByTable != null) #rowsByTable: rowsByTable,
    }),
  );
  @override
  HitDieTables $make(CopyWithData data) => HitDieTables(
    tableByClass: data.get(#tableByClass, or: $value.tableByClass),
    rowsByTable: data.get(#rowsByTable, or: $value.rowsByTable),
  );

  @override
  HitDieTablesCopyWith<$R2, HitDieTables, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _HitDieTablesCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

typedef _t$_R0<A, B, C> = ({A modifier, B rolls, C sides});

class _t$_R0Mapper extends RecordMapperBase<_t$_R0> {
  static _t$_R0Mapper? _instance;
  _t$_R0Mapper._();

  static _t$_R0Mapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = _t$_R0Mapper._());
      MapperBase.addType(<A, B, C>(f) => f<({A modifier, B rolls, C sides})>());
    }
    return _instance!;
  }

  static dynamic _$modifier(_t$_R0 v) => v.modifier;
  static dynamic _arg$modifier<A, B, C>(f) => f<A>();
  static const Field<_t$_R0, dynamic> _f$modifier = Field(
    'modifier',
    _$modifier,
    arg: _arg$modifier,
  );
  static dynamic _$rolls(_t$_R0 v) => v.rolls;
  static dynamic _arg$rolls<A, B, C>(f) => f<B>();
  static const Field<_t$_R0, dynamic> _f$rolls = Field(
    'rolls',
    _$rolls,
    arg: _arg$rolls,
  );
  static dynamic _$sides(_t$_R0 v) => v.sides;
  static dynamic _arg$sides<A, B, C>(f) => f<C>();
  static const Field<_t$_R0, dynamic> _f$sides = Field(
    'sides',
    _$sides,
    arg: _arg$sides,
  );

  @override
  final MappableFields<_t$_R0> fields = const {
    #modifier: _f$modifier,
    #rolls: _f$rolls,
    #sides: _f$sides,
  };

  @override
  Function get typeFactory =>
      <A, B, C>(f) => f<_t$_R0<A, B, C>>();

  static _t$_R0<A, B, C> _instantiate<A, B, C>(DecodingData<_t$_R0> data) {
    return (
      modifier: data.dec(_f$modifier),
      rolls: data.dec(_f$rolls),
      sides: data.dec(_f$sides),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static _t$_R0<A, B, C> fromMap<A, B, C>(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<_t$_R0<A, B, C>>(map);
  }

  static _t$_R0<A, B, C> fromJson<A, B, C>(String json) {
    return ensureInitialized().decodeJson<_t$_R0<A, B, C>>(json);
  }
}

