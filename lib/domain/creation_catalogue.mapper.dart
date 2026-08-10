// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'creation_catalogue.dart';

class CreationChoiceMapper extends ClassMapperBase<CreationChoice> {
  CreationChoiceMapper._();

  static CreationChoiceMapper? _instance;
  static CreationChoiceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CreationChoiceMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'CreationChoice';

  static int _$value(CreationChoice v) => v.value;
  static const Field<CreationChoice, int> _f$value = Field('value', _$value);
  static String _$identifier(CreationChoice v) => v.identifier;
  static const Field<CreationChoice, String> _f$identifier = Field(
    'identifier',
    _$identifier,
  );
  static int? _$nameStrref(CreationChoice v) => v.nameStrref;
  static const Field<CreationChoice, int> _f$nameStrref = Field(
    'nameStrref',
    _$nameStrref,
    opt: true,
  );
  static int? _$descriptionStrref(CreationChoice v) => v.descriptionStrref;
  static const Field<CreationChoice, int> _f$descriptionStrref = Field(
    'descriptionStrref',
    _$descriptionStrref,
    opt: true,
  );

  @override
  final MappableFields<CreationChoice> fields = const {
    #value: _f$value,
    #identifier: _f$identifier,
    #nameStrref: _f$nameStrref,
    #descriptionStrref: _f$descriptionStrref,
  };

  static CreationChoice _instantiate(DecodingData data) {
    return CreationChoice(
      value: data.dec(_f$value),
      identifier: data.dec(_f$identifier),
      nameStrref: data.dec(_f$nameStrref),
      descriptionStrref: data.dec(_f$descriptionStrref),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CreationChoice fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CreationChoice>(map);
  }

  static CreationChoice fromJson(String json) {
    return ensureInitialized().decodeJson<CreationChoice>(json);
  }
}

mixin CreationChoiceMappable {
  String toJson() {
    return CreationChoiceMapper.ensureInitialized().encodeJson<CreationChoice>(
      this as CreationChoice,
    );
  }

  Map<String, dynamic> toMap() {
    return CreationChoiceMapper.ensureInitialized().encodeMap<CreationChoice>(
      this as CreationChoice,
    );
  }

  CreationChoiceCopyWith<CreationChoice, CreationChoice, CreationChoice>
  get copyWith => _CreationChoiceCopyWithImpl<CreationChoice, CreationChoice>(
    this as CreationChoice,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return CreationChoiceMapper.ensureInitialized().stringifyValue(
      this as CreationChoice,
    );
  }

  @override
  bool operator ==(Object other) {
    return CreationChoiceMapper.ensureInitialized().equalsValue(
      this as CreationChoice,
      other,
    );
  }

  @override
  int get hashCode {
    return CreationChoiceMapper.ensureInitialized().hashValue(
      this as CreationChoice,
    );
  }
}

extension CreationChoiceValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CreationChoice, $Out> {
  CreationChoiceCopyWith<$R, CreationChoice, $Out> get $asCreationChoice =>
      $base.as((v, t, t2) => _CreationChoiceCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CreationChoiceCopyWith<$R, $In extends CreationChoice, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    int? value,
    String? identifier,
    int? nameStrref,
    int? descriptionStrref,
  });
  CreationChoiceCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CreationChoiceCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CreationChoice, $Out>
    implements CreationChoiceCopyWith<$R, CreationChoice, $Out> {
  _CreationChoiceCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CreationChoice> $mapper =
      CreationChoiceMapper.ensureInitialized();
  @override
  $R call({
    int? value,
    String? identifier,
    Object? nameStrref = $none,
    Object? descriptionStrref = $none,
  }) => $apply(
    FieldCopyWithData({
      if (value != null) #value: value,
      if (identifier != null) #identifier: identifier,
      if (nameStrref != $none) #nameStrref: nameStrref,
      if (descriptionStrref != $none) #descriptionStrref: descriptionStrref,
    }),
  );
  @override
  CreationChoice $make(CopyWithData data) => CreationChoice(
    value: data.get(#value, or: $value.value),
    identifier: data.get(#identifier, or: $value.identifier),
    nameStrref: data.get(#nameStrref, or: $value.nameStrref),
    descriptionStrref: data.get(
      #descriptionStrref,
      or: $value.descriptionStrref,
    ),
  );

  @override
  CreationChoiceCopyWith<$R2, CreationChoice, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CreationChoiceCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CreationCatalogueMapper extends ClassMapperBase<CreationCatalogue> {
  CreationCatalogueMapper._();

  static CreationCatalogueMapper? _instance;
  static CreationCatalogueMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CreationCatalogueMapper._());
      CreationChoiceMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CreationCatalogue';

  static List<CreationChoice> _$races(CreationCatalogue v) => v.races;
  static const Field<CreationCatalogue, List<CreationChoice>> _f$races = Field(
    'races',
    _$races,
  );
  static Map<int, List<CreationChoice>> _$classesByRace(CreationCatalogue v) =>
      v.classesByRace;
  static const Field<CreationCatalogue, Map<int, List<CreationChoice>>>
  _f$classesByRace = Field('classesByRace', _$classesByRace);
  static Map<int, List<CreationChoice>> _$kitsByClass(CreationCatalogue v) =>
      v.kitsByClass;
  static const Field<CreationCatalogue, Map<int, List<CreationChoice>>>
  _f$kitsByClass = Field('kitsByClass', _$kitsByClass);
  static Map<String, List<int>> _$alignmentsByRow(CreationCatalogue v) =>
      v.alignmentsByRow;
  static const Field<CreationCatalogue, Map<String, List<int>>>
  _f$alignmentsByRow = Field('alignmentsByRow', _$alignmentsByRow);
  static Map<int, Map<String, int>> _$adjustmentsByRace(CreationCatalogue v) =>
      v.adjustmentsByRace;
  static const Field<CreationCatalogue, Map<int, Map<String, int>>>
  _f$adjustmentsByRace = Field('adjustmentsByRace', _$adjustmentsByRace);
  static Map<int, String> _$textByStrref(CreationCatalogue v) => v.textByStrref;
  static const Field<CreationCatalogue, Map<int, String>> _f$textByStrref =
      Field('textByStrref', _$textByStrref, opt: true, def: const {});

  @override
  final MappableFields<CreationCatalogue> fields = const {
    #races: _f$races,
    #classesByRace: _f$classesByRace,
    #kitsByClass: _f$kitsByClass,
    #alignmentsByRow: _f$alignmentsByRow,
    #adjustmentsByRace: _f$adjustmentsByRace,
    #textByStrref: _f$textByStrref,
  };

  static CreationCatalogue _instantiate(DecodingData data) {
    return CreationCatalogue(
      races: data.dec(_f$races),
      classesByRace: data.dec(_f$classesByRace),
      kitsByClass: data.dec(_f$kitsByClass),
      alignmentsByRow: data.dec(_f$alignmentsByRow),
      adjustmentsByRace: data.dec(_f$adjustmentsByRace),
      textByStrref: data.dec(_f$textByStrref),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CreationCatalogue fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CreationCatalogue>(map);
  }

  static CreationCatalogue fromJson(String json) {
    return ensureInitialized().decodeJson<CreationCatalogue>(json);
  }
}

mixin CreationCatalogueMappable {
  String toJson() {
    return CreationCatalogueMapper.ensureInitialized()
        .encodeJson<CreationCatalogue>(this as CreationCatalogue);
  }

  Map<String, dynamic> toMap() {
    return CreationCatalogueMapper.ensureInitialized()
        .encodeMap<CreationCatalogue>(this as CreationCatalogue);
  }

  CreationCatalogueCopyWith<
    CreationCatalogue,
    CreationCatalogue,
    CreationCatalogue
  >
  get copyWith =>
      _CreationCatalogueCopyWithImpl<CreationCatalogue, CreationCatalogue>(
        this as CreationCatalogue,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CreationCatalogueMapper.ensureInitialized().stringifyValue(
      this as CreationCatalogue,
    );
  }

  @override
  bool operator ==(Object other) {
    return CreationCatalogueMapper.ensureInitialized().equalsValue(
      this as CreationCatalogue,
      other,
    );
  }

  @override
  int get hashCode {
    return CreationCatalogueMapper.ensureInitialized().hashValue(
      this as CreationCatalogue,
    );
  }
}

extension CreationCatalogueValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CreationCatalogue, $Out> {
  CreationCatalogueCopyWith<$R, CreationCatalogue, $Out>
  get $asCreationCatalogue => $base.as(
    (v, t, t2) => _CreationCatalogueCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class CreationCatalogueCopyWith<
  $R,
  $In extends CreationCatalogue,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    CreationChoice,
    CreationChoiceCopyWith<$R, CreationChoice, CreationChoice>
  >
  get races;
  MapCopyWith<
    $R,
    int,
    List<CreationChoice>,
    ObjectCopyWith<$R, List<CreationChoice>, List<CreationChoice>>
  >
  get classesByRace;
  MapCopyWith<
    $R,
    int,
    List<CreationChoice>,
    ObjectCopyWith<$R, List<CreationChoice>, List<CreationChoice>>
  >
  get kitsByClass;
  MapCopyWith<$R, String, List<int>, ObjectCopyWith<$R, List<int>, List<int>>>
  get alignmentsByRow;
  MapCopyWith<
    $R,
    int,
    Map<String, int>,
    ObjectCopyWith<$R, Map<String, int>, Map<String, int>>
  >
  get adjustmentsByRace;
  MapCopyWith<$R, int, String, ObjectCopyWith<$R, String, String>>
  get textByStrref;
  $R call({
    List<CreationChoice>? races,
    Map<int, List<CreationChoice>>? classesByRace,
    Map<int, List<CreationChoice>>? kitsByClass,
    Map<String, List<int>>? alignmentsByRow,
    Map<int, Map<String, int>>? adjustmentsByRace,
    Map<int, String>? textByStrref,
  });
  CreationCatalogueCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CreationCatalogueCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CreationCatalogue, $Out>
    implements CreationCatalogueCopyWith<$R, CreationCatalogue, $Out> {
  _CreationCatalogueCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CreationCatalogue> $mapper =
      CreationCatalogueMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    CreationChoice,
    CreationChoiceCopyWith<$R, CreationChoice, CreationChoice>
  >
  get races => ListCopyWith(
    $value.races,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(races: v),
  );
  @override
  MapCopyWith<
    $R,
    int,
    List<CreationChoice>,
    ObjectCopyWith<$R, List<CreationChoice>, List<CreationChoice>>
  >
  get classesByRace => MapCopyWith(
    $value.classesByRace,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(classesByRace: v),
  );
  @override
  MapCopyWith<
    $R,
    int,
    List<CreationChoice>,
    ObjectCopyWith<$R, List<CreationChoice>, List<CreationChoice>>
  >
  get kitsByClass => MapCopyWith(
    $value.kitsByClass,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(kitsByClass: v),
  );
  @override
  MapCopyWith<$R, String, List<int>, ObjectCopyWith<$R, List<int>, List<int>>>
  get alignmentsByRow => MapCopyWith(
    $value.alignmentsByRow,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(alignmentsByRow: v),
  );
  @override
  MapCopyWith<
    $R,
    int,
    Map<String, int>,
    ObjectCopyWith<$R, Map<String, int>, Map<String, int>>
  >
  get adjustmentsByRace => MapCopyWith(
    $value.adjustmentsByRace,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(adjustmentsByRace: v),
  );
  @override
  MapCopyWith<$R, int, String, ObjectCopyWith<$R, String, String>>
  get textByStrref => MapCopyWith(
    $value.textByStrref,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(textByStrref: v),
  );
  @override
  $R call({
    List<CreationChoice>? races,
    Map<int, List<CreationChoice>>? classesByRace,
    Map<int, List<CreationChoice>>? kitsByClass,
    Map<String, List<int>>? alignmentsByRow,
    Map<int, Map<String, int>>? adjustmentsByRace,
    Map<int, String>? textByStrref,
  }) => $apply(
    FieldCopyWithData({
      if (races != null) #races: races,
      if (classesByRace != null) #classesByRace: classesByRace,
      if (kitsByClass != null) #kitsByClass: kitsByClass,
      if (alignmentsByRow != null) #alignmentsByRow: alignmentsByRow,
      if (adjustmentsByRace != null) #adjustmentsByRace: adjustmentsByRace,
      if (textByStrref != null) #textByStrref: textByStrref,
    }),
  );
  @override
  CreationCatalogue $make(CopyWithData data) => CreationCatalogue(
    races: data.get(#races, or: $value.races),
    classesByRace: data.get(#classesByRace, or: $value.classesByRace),
    kitsByClass: data.get(#kitsByClass, or: $value.kitsByClass),
    alignmentsByRow: data.get(#alignmentsByRow, or: $value.alignmentsByRow),
    adjustmentsByRace: data.get(
      #adjustmentsByRace,
      or: $value.adjustmentsByRace,
    ),
    textByStrref: data.get(#textByStrref, or: $value.textByStrref),
  );

  @override
  CreationCatalogueCopyWith<$R2, CreationCatalogue, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CreationCatalogueCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

