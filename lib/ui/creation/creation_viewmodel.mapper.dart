// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'creation_viewmodel.dart';

class CreationStateMapper extends ClassMapperBase<CreationState> {
  CreationStateMapper._();

  static CreationStateMapper? _instance;
  static CreationStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CreationStateMapper._());
      CreationCatalogueMapper.ensureInitialized();
      CreationChoiceMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CreationState';

  static CreationCatalogue _$catalogue(CreationState v) => v.catalogue;
  static const Field<CreationState, CreationCatalogue> _f$catalogue = Field(
    'catalogue',
    _$catalogue,
    opt: true,
    def: CreationCatalogue.empty,
  );
  static CreationStep _$step(CreationState v) => v.step;
  static const Field<CreationState, CreationStep> _f$step = Field(
    'step',
    _$step,
    opt: true,
    def: CreationStep.gender,
  );
  static int? _$genderId(CreationState v) => v.genderId;
  static const Field<CreationState, int> _f$genderId = Field(
    'genderId',
    _$genderId,
    opt: true,
  );
  static String? _$portraitName(CreationState v) => v.portraitName;
  static const Field<CreationState, String> _f$portraitName = Field(
    'portraitName',
    _$portraitName,
    opt: true,
  );
  static CreationChoice? _$race(CreationState v) => v.race;
  static const Field<CreationState, CreationChoice> _f$race = Field(
    'race',
    _$race,
    opt: true,
  );
  static CreationChoice? _$characterClass(CreationState v) => v.characterClass;
  static const Field<CreationState, CreationChoice> _f$characterClass = Field(
    'characterClass',
    _$characterClass,
    opt: true,
  );
  static CreationChoice? _$specialisation(CreationState v) => v.specialisation;
  static const Field<CreationState, CreationChoice> _f$specialisation = Field(
    'specialisation',
    _$specialisation,
    opt: true,
  );
  static int? _$alignmentId(CreationState v) => v.alignmentId;
  static const Field<CreationState, int> _f$alignmentId = Field(
    'alignmentId',
    _$alignmentId,
    opt: true,
  );
  static String _$name(CreationState v) => v.name;
  static const Field<CreationState, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
    def: '',
  );

  @override
  final MappableFields<CreationState> fields = const {
    #catalogue: _f$catalogue,
    #step: _f$step,
    #genderId: _f$genderId,
    #portraitName: _f$portraitName,
    #race: _f$race,
    #characterClass: _f$characterClass,
    #specialisation: _f$specialisation,
    #alignmentId: _f$alignmentId,
    #name: _f$name,
  };

  static CreationState _instantiate(DecodingData data) {
    return CreationState(
      catalogue: data.dec(_f$catalogue),
      step: data.dec(_f$step),
      genderId: data.dec(_f$genderId),
      portraitName: data.dec(_f$portraitName),
      race: data.dec(_f$race),
      characterClass: data.dec(_f$characterClass),
      specialisation: data.dec(_f$specialisation),
      alignmentId: data.dec(_f$alignmentId),
      name: data.dec(_f$name),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CreationState fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CreationState>(map);
  }

  static CreationState fromJson(String json) {
    return ensureInitialized().decodeJson<CreationState>(json);
  }
}

mixin CreationStateMappable {
  String toJson() {
    return CreationStateMapper.ensureInitialized().encodeJson<CreationState>(
      this as CreationState,
    );
  }

  Map<String, dynamic> toMap() {
    return CreationStateMapper.ensureInitialized().encodeMap<CreationState>(
      this as CreationState,
    );
  }

  CreationStateCopyWith<CreationState, CreationState, CreationState>
  get copyWith => _CreationStateCopyWithImpl<CreationState, CreationState>(
    this as CreationState,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return CreationStateMapper.ensureInitialized().stringifyValue(
      this as CreationState,
    );
  }

  @override
  bool operator ==(Object other) {
    return CreationStateMapper.ensureInitialized().equalsValue(
      this as CreationState,
      other,
    );
  }

  @override
  int get hashCode {
    return CreationStateMapper.ensureInitialized().hashValue(
      this as CreationState,
    );
  }
}

extension CreationStateValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CreationState, $Out> {
  CreationStateCopyWith<$R, CreationState, $Out> get $asCreationState =>
      $base.as((v, t, t2) => _CreationStateCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CreationStateCopyWith<$R, $In extends CreationState, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  CreationCatalogueCopyWith<$R, CreationCatalogue, CreationCatalogue>
  get catalogue;
  CreationChoiceCopyWith<$R, CreationChoice, CreationChoice>? get race;
  CreationChoiceCopyWith<$R, CreationChoice, CreationChoice>?
  get characterClass;
  CreationChoiceCopyWith<$R, CreationChoice, CreationChoice>?
  get specialisation;
  $R call({
    CreationCatalogue? catalogue,
    CreationStep? step,
    int? genderId,
    String? portraitName,
    CreationChoice? race,
    CreationChoice? characterClass,
    CreationChoice? specialisation,
    int? alignmentId,
    String? name,
  });
  CreationStateCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CreationStateCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CreationState, $Out>
    implements CreationStateCopyWith<$R, CreationState, $Out> {
  _CreationStateCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CreationState> $mapper =
      CreationStateMapper.ensureInitialized();
  @override
  CreationCatalogueCopyWith<$R, CreationCatalogue, CreationCatalogue>
  get catalogue => $value.catalogue.copyWith.$chain((v) => call(catalogue: v));
  @override
  CreationChoiceCopyWith<$R, CreationChoice, CreationChoice>? get race =>
      $value.race?.copyWith.$chain((v) => call(race: v));
  @override
  CreationChoiceCopyWith<$R, CreationChoice, CreationChoice>?
  get characterClass =>
      $value.characterClass?.copyWith.$chain((v) => call(characterClass: v));
  @override
  CreationChoiceCopyWith<$R, CreationChoice, CreationChoice>?
  get specialisation =>
      $value.specialisation?.copyWith.$chain((v) => call(specialisation: v));
  @override
  $R call({
    CreationCatalogue? catalogue,
    CreationStep? step,
    Object? genderId = $none,
    Object? portraitName = $none,
    Object? race = $none,
    Object? characterClass = $none,
    Object? specialisation = $none,
    Object? alignmentId = $none,
    String? name,
  }) => $apply(
    FieldCopyWithData({
      if (catalogue != null) #catalogue: catalogue,
      if (step != null) #step: step,
      if (genderId != $none) #genderId: genderId,
      if (portraitName != $none) #portraitName: portraitName,
      if (race != $none) #race: race,
      if (characterClass != $none) #characterClass: characterClass,
      if (specialisation != $none) #specialisation: specialisation,
      if (alignmentId != $none) #alignmentId: alignmentId,
      if (name != null) #name: name,
    }),
  );
  @override
  CreationState $make(CopyWithData data) => CreationState(
    catalogue: data.get(#catalogue, or: $value.catalogue),
    step: data.get(#step, or: $value.step),
    genderId: data.get(#genderId, or: $value.genderId),
    portraitName: data.get(#portraitName, or: $value.portraitName),
    race: data.get(#race, or: $value.race),
    characterClass: data.get(#characterClass, or: $value.characterClass),
    specialisation: data.get(#specialisation, or: $value.specialisation),
    alignmentId: data.get(#alignmentId, or: $value.alignmentId),
    name: data.get(#name, or: $value.name),
  );

  @override
  CreationStateCopyWith<$R2, CreationState, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CreationStateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

