// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'proficiency_catalogue.dart';

class ProficiencyEntryMapper extends ClassMapperBase<ProficiencyEntry> {
  ProficiencyEntryMapper._();

  static ProficiencyEntryMapper? _instance;
  static ProficiencyEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProficiencyEntryMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ProficiencyEntry';

  static int _$id(ProficiencyEntry v) => v.id;
  static const Field<ProficiencyEntry, int> _f$id = Field('id', _$id);
  static String _$identifier(ProficiencyEntry v) => v.identifier;
  static const Field<ProficiencyEntry, String> _f$identifier = Field(
    'identifier',
    _$identifier,
  );
  static Map<String, int> _$maximumByColumn(ProficiencyEntry v) =>
      v.maximumByColumn;
  static const Field<ProficiencyEntry, Map<String, int>> _f$maximumByColumn =
      Field('maximumByColumn', _$maximumByColumn);
  static int? _$nameStrref(ProficiencyEntry v) => v.nameStrref;
  static const Field<ProficiencyEntry, int> _f$nameStrref = Field(
    'nameStrref',
    _$nameStrref,
    opt: true,
  );
  static String? _$name(ProficiencyEntry v) => v.name;
  static const Field<ProficiencyEntry, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
  );

  @override
  final MappableFields<ProficiencyEntry> fields = const {
    #id: _f$id,
    #identifier: _f$identifier,
    #maximumByColumn: _f$maximumByColumn,
    #nameStrref: _f$nameStrref,
    #name: _f$name,
  };

  static ProficiencyEntry _instantiate(DecodingData data) {
    return ProficiencyEntry(
      id: data.dec(_f$id),
      identifier: data.dec(_f$identifier),
      maximumByColumn: data.dec(_f$maximumByColumn),
      nameStrref: data.dec(_f$nameStrref),
      name: data.dec(_f$name),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ProficiencyEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProficiencyEntry>(map);
  }

  static ProficiencyEntry fromJson(String json) {
    return ensureInitialized().decodeJson<ProficiencyEntry>(json);
  }
}

mixin ProficiencyEntryMappable {
  String toJson() {
    return ProficiencyEntryMapper.ensureInitialized()
        .encodeJson<ProficiencyEntry>(this as ProficiencyEntry);
  }

  Map<String, dynamic> toMap() {
    return ProficiencyEntryMapper.ensureInitialized()
        .encodeMap<ProficiencyEntry>(this as ProficiencyEntry);
  }

  ProficiencyEntryCopyWith<ProficiencyEntry, ProficiencyEntry, ProficiencyEntry>
  get copyWith =>
      _ProficiencyEntryCopyWithImpl<ProficiencyEntry, ProficiencyEntry>(
        this as ProficiencyEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ProficiencyEntryMapper.ensureInitialized().stringifyValue(
      this as ProficiencyEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProficiencyEntryMapper.ensureInitialized().equalsValue(
      this as ProficiencyEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return ProficiencyEntryMapper.ensureInitialized().hashValue(
      this as ProficiencyEntry,
    );
  }
}

extension ProficiencyEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProficiencyEntry, $Out> {
  ProficiencyEntryCopyWith<$R, ProficiencyEntry, $Out>
  get $asProficiencyEntry =>
      $base.as((v, t, t2) => _ProficiencyEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ProficiencyEntryCopyWith<$R, $In extends ProficiencyEntry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, int, ObjectCopyWith<$R, int, int>>
  get maximumByColumn;
  $R call({
    int? id,
    String? identifier,
    Map<String, int>? maximumByColumn,
    int? nameStrref,
    String? name,
  });
  ProficiencyEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProficiencyEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProficiencyEntry, $Out>
    implements ProficiencyEntryCopyWith<$R, ProficiencyEntry, $Out> {
  _ProficiencyEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProficiencyEntry> $mapper =
      ProficiencyEntryMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, int, ObjectCopyWith<$R, int, int>>
  get maximumByColumn => MapCopyWith(
    $value.maximumByColumn,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(maximumByColumn: v),
  );
  @override
  $R call({
    int? id,
    String? identifier,
    Map<String, int>? maximumByColumn,
    Object? nameStrref = $none,
    Object? name = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (identifier != null) #identifier: identifier,
      if (maximumByColumn != null) #maximumByColumn: maximumByColumn,
      if (nameStrref != $none) #nameStrref: nameStrref,
      if (name != $none) #name: name,
    }),
  );
  @override
  ProficiencyEntry $make(CopyWithData data) => ProficiencyEntry(
    id: data.get(#id, or: $value.id),
    identifier: data.get(#identifier, or: $value.identifier),
    maximumByColumn: data.get(#maximumByColumn, or: $value.maximumByColumn),
    nameStrref: data.get(#nameStrref, or: $value.nameStrref),
    name: data.get(#name, or: $value.name),
  );

  @override
  ProficiencyEntryCopyWith<$R2, ProficiencyEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ProficiencyEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ProficiencyCatalogueMapper extends ClassMapperBase<ProficiencyCatalogue> {
  ProficiencyCatalogueMapper._();

  static ProficiencyCatalogueMapper? _instance;
  static ProficiencyCatalogueMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProficiencyCatalogueMapper._());
      ProficiencyEntryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ProficiencyCatalogue';

  static Map<int, ProficiencyEntry> _$entries(ProficiencyCatalogue v) =>
      v.entries;
  static const Field<ProficiencyCatalogue, Map<int, ProficiencyEntry>>
  _f$entries = Field('entries', _$entries);

  @override
  final MappableFields<ProficiencyCatalogue> fields = const {
    #entries: _f$entries,
  };

  static ProficiencyCatalogue _instantiate(DecodingData data) {
    return ProficiencyCatalogue(data.dec(_f$entries));
  }

  @override
  final Function instantiate = _instantiate;

  static ProficiencyCatalogue fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProficiencyCatalogue>(map);
  }

  static ProficiencyCatalogue fromJson(String json) {
    return ensureInitialized().decodeJson<ProficiencyCatalogue>(json);
  }
}

mixin ProficiencyCatalogueMappable {
  String toJson() {
    return ProficiencyCatalogueMapper.ensureInitialized()
        .encodeJson<ProficiencyCatalogue>(this as ProficiencyCatalogue);
  }

  Map<String, dynamic> toMap() {
    return ProficiencyCatalogueMapper.ensureInitialized()
        .encodeMap<ProficiencyCatalogue>(this as ProficiencyCatalogue);
  }

  ProficiencyCatalogueCopyWith<
    ProficiencyCatalogue,
    ProficiencyCatalogue,
    ProficiencyCatalogue
  >
  get copyWith =>
      _ProficiencyCatalogueCopyWithImpl<
        ProficiencyCatalogue,
        ProficiencyCatalogue
      >(this as ProficiencyCatalogue, $identity, $identity);
  @override
  String toString() {
    return ProficiencyCatalogueMapper.ensureInitialized().stringifyValue(
      this as ProficiencyCatalogue,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProficiencyCatalogueMapper.ensureInitialized().equalsValue(
      this as ProficiencyCatalogue,
      other,
    );
  }

  @override
  int get hashCode {
    return ProficiencyCatalogueMapper.ensureInitialized().hashValue(
      this as ProficiencyCatalogue,
    );
  }
}

extension ProficiencyCatalogueValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProficiencyCatalogue, $Out> {
  ProficiencyCatalogueCopyWith<$R, ProficiencyCatalogue, $Out>
  get $asProficiencyCatalogue => $base.as(
    (v, t, t2) => _ProficiencyCatalogueCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ProficiencyCatalogueCopyWith<
  $R,
  $In extends ProficiencyCatalogue,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<
    $R,
    int,
    ProficiencyEntry,
    ProficiencyEntryCopyWith<$R, ProficiencyEntry, ProficiencyEntry>
  >
  get entries;
  $R call({Map<int, ProficiencyEntry>? entries});
  ProficiencyCatalogueCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProficiencyCatalogueCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProficiencyCatalogue, $Out>
    implements ProficiencyCatalogueCopyWith<$R, ProficiencyCatalogue, $Out> {
  _ProficiencyCatalogueCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProficiencyCatalogue> $mapper =
      ProficiencyCatalogueMapper.ensureInitialized();
  @override
  MapCopyWith<
    $R,
    int,
    ProficiencyEntry,
    ProficiencyEntryCopyWith<$R, ProficiencyEntry, ProficiencyEntry>
  >
  get entries => MapCopyWith(
    $value.entries,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(entries: v),
  );
  @override
  $R call({Map<int, ProficiencyEntry>? entries}) =>
      $apply(FieldCopyWithData({if (entries != null) #entries: entries}));
  @override
  ProficiencyCatalogue $make(CopyWithData data) =>
      ProficiencyCatalogue(data.get(#entries, or: $value.entries));

  @override
  ProficiencyCatalogueCopyWith<$R2, ProficiencyCatalogue, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ProficiencyCatalogueCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

