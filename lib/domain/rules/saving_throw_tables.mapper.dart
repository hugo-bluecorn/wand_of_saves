// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'saving_throw_tables.dart';

class SavingThrowTablesMapper extends ClassMapperBase<SavingThrowTables> {
  SavingThrowTablesMapper._();

  static SavingThrowTablesMapper? _instance;
  static SavingThrowTablesMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SavingThrowTablesMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'SavingThrowTables';

  static Map<String, Map<String, List<int>>> _$rowsByTable(
    SavingThrowTables v,
  ) => v.rowsByTable;
  static const Field<SavingThrowTables, Map<String, Map<String, List<int>>>>
  _f$rowsByTable = Field(
    'rowsByTable',
    _$rowsByTable,
    opt: true,
    def: const {},
  );

  @override
  final MappableFields<SavingThrowTables> fields = const {
    #rowsByTable: _f$rowsByTable,
  };

  static SavingThrowTables _instantiate(DecodingData data) {
    return SavingThrowTables(rowsByTable: data.dec(_f$rowsByTable));
  }

  @override
  final Function instantiate = _instantiate;

  static SavingThrowTables fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SavingThrowTables>(map);
  }

  static SavingThrowTables fromJson(String json) {
    return ensureInitialized().decodeJson<SavingThrowTables>(json);
  }
}

mixin SavingThrowTablesMappable {
  String toJson() {
    return SavingThrowTablesMapper.ensureInitialized()
        .encodeJson<SavingThrowTables>(this as SavingThrowTables);
  }

  Map<String, dynamic> toMap() {
    return SavingThrowTablesMapper.ensureInitialized()
        .encodeMap<SavingThrowTables>(this as SavingThrowTables);
  }

  SavingThrowTablesCopyWith<
    SavingThrowTables,
    SavingThrowTables,
    SavingThrowTables
  >
  get copyWith =>
      _SavingThrowTablesCopyWithImpl<SavingThrowTables, SavingThrowTables>(
        this as SavingThrowTables,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SavingThrowTablesMapper.ensureInitialized().stringifyValue(
      this as SavingThrowTables,
    );
  }

  @override
  bool operator ==(Object other) {
    return SavingThrowTablesMapper.ensureInitialized().equalsValue(
      this as SavingThrowTables,
      other,
    );
  }

  @override
  int get hashCode {
    return SavingThrowTablesMapper.ensureInitialized().hashValue(
      this as SavingThrowTables,
    );
  }
}

extension SavingThrowTablesValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SavingThrowTables, $Out> {
  SavingThrowTablesCopyWith<$R, SavingThrowTables, $Out>
  get $asSavingThrowTables => $base.as(
    (v, t, t2) => _SavingThrowTablesCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class SavingThrowTablesCopyWith<
  $R,
  $In extends SavingThrowTables,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<
    $R,
    String,
    Map<String, List<int>>,
    ObjectCopyWith<$R, Map<String, List<int>>, Map<String, List<int>>>
  >
  get rowsByTable;
  $R call({Map<String, Map<String, List<int>>>? rowsByTable});
  SavingThrowTablesCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SavingThrowTablesCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SavingThrowTables, $Out>
    implements SavingThrowTablesCopyWith<$R, SavingThrowTables, $Out> {
  _SavingThrowTablesCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SavingThrowTables> $mapper =
      SavingThrowTablesMapper.ensureInitialized();
  @override
  MapCopyWith<
    $R,
    String,
    Map<String, List<int>>,
    ObjectCopyWith<$R, Map<String, List<int>>, Map<String, List<int>>>
  >
  get rowsByTable => MapCopyWith(
    $value.rowsByTable,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(rowsByTable: v),
  );
  @override
  $R call({Map<String, Map<String, List<int>>>? rowsByTable}) => $apply(
    FieldCopyWithData({if (rowsByTable != null) #rowsByTable: rowsByTable}),
  );
  @override
  SavingThrowTables $make(CopyWithData data) => SavingThrowTables(
    rowsByTable: data.get(#rowsByTable, or: $value.rowsByTable),
  );

  @override
  SavingThrowTablesCopyWith<$R2, SavingThrowTables, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SavingThrowTablesCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

