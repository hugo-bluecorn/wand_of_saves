// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'skill_catalogue.dart';

class SkillCatalogueMapper extends ClassMapperBase<SkillCatalogue> {
  SkillCatalogueMapper._();

  static SkillCatalogueMapper? _instance;
  static SkillCatalogueMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SkillCatalogueMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'SkillCatalogue';

  static Map<String, Map<String, int>> _$allowanceByRow(SkillCatalogue v) =>
      v.allowanceByRow;
  static const Field<SkillCatalogue, Map<String, Map<String, int>>>
  _f$allowanceByRow = Field('allowanceByRow', _$allowanceByRow);

  @override
  final MappableFields<SkillCatalogue> fields = const {
    #allowanceByRow: _f$allowanceByRow,
  };

  static SkillCatalogue _instantiate(DecodingData data) {
    return SkillCatalogue(data.dec(_f$allowanceByRow));
  }

  @override
  final Function instantiate = _instantiate;

  static SkillCatalogue fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SkillCatalogue>(map);
  }

  static SkillCatalogue fromJson(String json) {
    return ensureInitialized().decodeJson<SkillCatalogue>(json);
  }
}

mixin SkillCatalogueMappable {
  String toJson() {
    return SkillCatalogueMapper.ensureInitialized().encodeJson<SkillCatalogue>(
      this as SkillCatalogue,
    );
  }

  Map<String, dynamic> toMap() {
    return SkillCatalogueMapper.ensureInitialized().encodeMap<SkillCatalogue>(
      this as SkillCatalogue,
    );
  }

  SkillCatalogueCopyWith<SkillCatalogue, SkillCatalogue, SkillCatalogue>
  get copyWith => _SkillCatalogueCopyWithImpl<SkillCatalogue, SkillCatalogue>(
    this as SkillCatalogue,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return SkillCatalogueMapper.ensureInitialized().stringifyValue(
      this as SkillCatalogue,
    );
  }

  @override
  bool operator ==(Object other) {
    return SkillCatalogueMapper.ensureInitialized().equalsValue(
      this as SkillCatalogue,
      other,
    );
  }

  @override
  int get hashCode {
    return SkillCatalogueMapper.ensureInitialized().hashValue(
      this as SkillCatalogue,
    );
  }
}

extension SkillCatalogueValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SkillCatalogue, $Out> {
  SkillCatalogueCopyWith<$R, SkillCatalogue, $Out> get $asSkillCatalogue =>
      $base.as((v, t, t2) => _SkillCatalogueCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SkillCatalogueCopyWith<$R, $In extends SkillCatalogue, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<
    $R,
    String,
    Map<String, int>,
    ObjectCopyWith<$R, Map<String, int>, Map<String, int>>
  >
  get allowanceByRow;
  $R call({Map<String, Map<String, int>>? allowanceByRow});
  SkillCatalogueCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SkillCatalogueCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SkillCatalogue, $Out>
    implements SkillCatalogueCopyWith<$R, SkillCatalogue, $Out> {
  _SkillCatalogueCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SkillCatalogue> $mapper =
      SkillCatalogueMapper.ensureInitialized();
  @override
  MapCopyWith<
    $R,
    String,
    Map<String, int>,
    ObjectCopyWith<$R, Map<String, int>, Map<String, int>>
  >
  get allowanceByRow => MapCopyWith(
    $value.allowanceByRow,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(allowanceByRow: v),
  );
  @override
  $R call({Map<String, Map<String, int>>? allowanceByRow}) => $apply(
    FieldCopyWithData({
      if (allowanceByRow != null) #allowanceByRow: allowanceByRow,
    }),
  );
  @override
  SkillCatalogue $make(CopyWithData data) =>
      SkillCatalogue(data.get(#allowanceByRow, or: $value.allowanceByRow));

  @override
  SkillCatalogueCopyWith<$R2, SkillCatalogue, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SkillCatalogueCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

