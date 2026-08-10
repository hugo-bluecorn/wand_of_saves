// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'name_tables.dart';

class NameTablesMapper extends ClassMapperBase<NameTables> {
  NameTablesMapper._();

  static NameTablesMapper? _instance;
  static NameTablesMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = NameTablesMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'NameTables';

  static Map<int, String> _$raceNames(NameTables v) => v.raceNames;
  static const Field<NameTables, Map<int, String>> _f$raceNames = Field(
    'raceNames',
    _$raceNames,
    opt: true,
    def: const {},
  );
  static Map<int, String> _$classNames(NameTables v) => v.classNames;
  static const Field<NameTables, Map<int, String>> _f$classNames = Field(
    'classNames',
    _$classNames,
    opt: true,
    def: const {},
  );
  static Map<String, String> _$kitNames(NameTables v) => v.kitNames;
  static const Field<NameTables, Map<String, String>> _f$kitNames = Field(
    'kitNames',
    _$kitNames,
    opt: true,
    def: const {},
  );

  @override
  final MappableFields<NameTables> fields = const {
    #raceNames: _f$raceNames,
    #classNames: _f$classNames,
    #kitNames: _f$kitNames,
  };

  static NameTables _instantiate(DecodingData data) {
    return NameTables(
      raceNames: data.dec(_f$raceNames),
      classNames: data.dec(_f$classNames),
      kitNames: data.dec(_f$kitNames),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static NameTables fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<NameTables>(map);
  }

  static NameTables fromJson(String json) {
    return ensureInitialized().decodeJson<NameTables>(json);
  }
}

mixin NameTablesMappable {
  String toJson() {
    return NameTablesMapper.ensureInitialized().encodeJson<NameTables>(
      this as NameTables,
    );
  }

  Map<String, dynamic> toMap() {
    return NameTablesMapper.ensureInitialized().encodeMap<NameTables>(
      this as NameTables,
    );
  }

  NameTablesCopyWith<NameTables, NameTables, NameTables> get copyWith =>
      _NameTablesCopyWithImpl<NameTables, NameTables>(
        this as NameTables,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return NameTablesMapper.ensureInitialized().stringifyValue(
      this as NameTables,
    );
  }

  @override
  bool operator ==(Object other) {
    return NameTablesMapper.ensureInitialized().equalsValue(
      this as NameTables,
      other,
    );
  }

  @override
  int get hashCode {
    return NameTablesMapper.ensureInitialized().hashValue(this as NameTables);
  }
}

extension NameTablesValueCopy<$R, $Out>
    on ObjectCopyWith<$R, NameTables, $Out> {
  NameTablesCopyWith<$R, NameTables, $Out> get $asNameTables =>
      $base.as((v, t, t2) => _NameTablesCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class NameTablesCopyWith<$R, $In extends NameTables, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, int, String, ObjectCopyWith<$R, String, String>>
  get raceNames;
  MapCopyWith<$R, int, String, ObjectCopyWith<$R, String, String>>
  get classNames;
  MapCopyWith<$R, String, String, ObjectCopyWith<$R, String, String>>
  get kitNames;
  $R call({
    Map<int, String>? raceNames,
    Map<int, String>? classNames,
    Map<String, String>? kitNames,
  });
  NameTablesCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _NameTablesCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, NameTables, $Out>
    implements NameTablesCopyWith<$R, NameTables, $Out> {
  _NameTablesCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<NameTables> $mapper =
      NameTablesMapper.ensureInitialized();
  @override
  MapCopyWith<$R, int, String, ObjectCopyWith<$R, String, String>>
  get raceNames => MapCopyWith(
    $value.raceNames,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(raceNames: v),
  );
  @override
  MapCopyWith<$R, int, String, ObjectCopyWith<$R, String, String>>
  get classNames => MapCopyWith(
    $value.classNames,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(classNames: v),
  );
  @override
  MapCopyWith<$R, String, String, ObjectCopyWith<$R, String, String>>
  get kitNames => MapCopyWith(
    $value.kitNames,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(kitNames: v),
  );
  @override
  $R call({
    Map<int, String>? raceNames,
    Map<int, String>? classNames,
    Map<String, String>? kitNames,
  }) => $apply(
    FieldCopyWithData({
      if (raceNames != null) #raceNames: raceNames,
      if (classNames != null) #classNames: classNames,
      if (kitNames != null) #kitNames: kitNames,
    }),
  );
  @override
  NameTables $make(CopyWithData data) => NameTables(
    raceNames: data.get(#raceNames, or: $value.raceNames),
    classNames: data.get(#classNames, or: $value.classNames),
    kitNames: data.get(#kitNames, or: $value.kitNames),
  );

  @override
  NameTablesCopyWith<$R2, NameTables, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _NameTablesCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

