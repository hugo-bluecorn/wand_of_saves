// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'rules_tables.dart';

class RulesTablesMapper extends ClassMapperBase<RulesTables> {
  RulesTablesMapper._();

  static RulesTablesMapper? _instance;
  static RulesTablesMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RulesTablesMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'RulesTables';

  static Map<String, Map<String, Map<String, int>>> _$byName(RulesTables v) =>
      v.byName;
  static const Field<RulesTables, Map<String, Map<String, Map<String, int>>>>
  _f$byName = Field('byName', _$byName, opt: true, def: const {});

  @override
  final MappableFields<RulesTables> fields = const {#byName: _f$byName};

  static RulesTables _instantiate(DecodingData data) {
    return RulesTables(byName: data.dec(_f$byName));
  }

  @override
  final Function instantiate = _instantiate;

  static RulesTables fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RulesTables>(map);
  }

  static RulesTables fromJson(String json) {
    return ensureInitialized().decodeJson<RulesTables>(json);
  }
}

mixin RulesTablesMappable {
  String toJson() {
    return RulesTablesMapper.ensureInitialized().encodeJson<RulesTables>(
      this as RulesTables,
    );
  }

  Map<String, dynamic> toMap() {
    return RulesTablesMapper.ensureInitialized().encodeMap<RulesTables>(
      this as RulesTables,
    );
  }

  RulesTablesCopyWith<RulesTables, RulesTables, RulesTables> get copyWith =>
      _RulesTablesCopyWithImpl<RulesTables, RulesTables>(
        this as RulesTables,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RulesTablesMapper.ensureInitialized().stringifyValue(
      this as RulesTables,
    );
  }

  @override
  bool operator ==(Object other) {
    return RulesTablesMapper.ensureInitialized().equalsValue(
      this as RulesTables,
      other,
    );
  }

  @override
  int get hashCode {
    return RulesTablesMapper.ensureInitialized().hashValue(this as RulesTables);
  }
}

extension RulesTablesValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RulesTables, $Out> {
  RulesTablesCopyWith<$R, RulesTables, $Out> get $asRulesTables =>
      $base.as((v, t, t2) => _RulesTablesCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RulesTablesCopyWith<$R, $In extends RulesTables, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<
    $R,
    String,
    Map<String, Map<String, int>>,
    ObjectCopyWith<
      $R,
      Map<String, Map<String, int>>,
      Map<String, Map<String, int>>
    >
  >
  get byName;
  $R call({Map<String, Map<String, Map<String, int>>>? byName});
  RulesTablesCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RulesTablesCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RulesTables, $Out>
    implements RulesTablesCopyWith<$R, RulesTables, $Out> {
  _RulesTablesCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RulesTables> $mapper =
      RulesTablesMapper.ensureInitialized();
  @override
  MapCopyWith<
    $R,
    String,
    Map<String, Map<String, int>>,
    ObjectCopyWith<
      $R,
      Map<String, Map<String, int>>,
      Map<String, Map<String, int>>
    >
  >
  get byName => MapCopyWith(
    $value.byName,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(byName: v),
  );
  @override
  $R call({Map<String, Map<String, Map<String, int>>>? byName}) =>
      $apply(FieldCopyWithData({if (byName != null) #byName: byName}));
  @override
  RulesTables $make(CopyWithData data) =>
      RulesTables(byName: data.get(#byName, or: $value.byName));

  @override
  RulesTablesCopyWith<$R2, RulesTables, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RulesTablesCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

