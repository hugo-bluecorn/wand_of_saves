// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'character_file_viewmodel.dart';

class CharacterFileStateMapper extends ClassMapperBase<CharacterFileState> {
  CharacterFileStateMapper._();

  static CharacterFileStateMapper? _instance;
  static CharacterFileStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CharacterFileStateMapper._());
      CharacterFileMapper.ensureInitialized();
      CharacterMapper.ensureInitialized();
      ProficiencyCatalogueMapper.ensureInitialized();
      SkillCatalogueMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CharacterFileState';

  static CharacterFile _$file(CharacterFileState v) => v.file;
  static const Field<CharacterFileState, CharacterFile> _f$file = Field(
    'file',
    _$file,
  );
  static Character _$character(CharacterFileState v) => v.character;
  static const Field<CharacterFileState, Character> _f$character = Field(
    'character',
    _$character,
  );
  static ProficiencyCatalogue _$proficiencies(CharacterFileState v) =>
      v.proficiencies;
  static const Field<CharacterFileState, ProficiencyCatalogue>
  _f$proficiencies = Field(
    'proficiencies',
    _$proficiencies,
    opt: true,
    def: ProficiencyCatalogue.empty,
  );
  static SkillCatalogue _$skills(CharacterFileState v) => v.skills;
  static const Field<CharacterFileState, SkillCatalogue> _f$skills = Field(
    'skills',
    _$skills,
    opt: true,
    def: SkillCatalogue.empty,
  );
  static bool _$isDirty(CharacterFileState v) => v.isDirty;
  static const Field<CharacterFileState, bool> _f$isDirty = Field(
    'isDirty',
    _$isDirty,
    opt: true,
    def: false,
  );
  static bool _$canUndo(CharacterFileState v) => v.canUndo;
  static const Field<CharacterFileState, bool> _f$canUndo = Field(
    'canUndo',
    _$canUndo,
    opt: true,
    def: false,
  );
  static bool _$canRedo(CharacterFileState v) => v.canRedo;
  static const Field<CharacterFileState, bool> _f$canRedo = Field(
    'canRedo',
    _$canRedo,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<CharacterFileState> fields = const {
    #file: _f$file,
    #character: _f$character,
    #proficiencies: _f$proficiencies,
    #skills: _f$skills,
    #isDirty: _f$isDirty,
    #canUndo: _f$canUndo,
    #canRedo: _f$canRedo,
  };

  static CharacterFileState _instantiate(DecodingData data) {
    return CharacterFileState(
      file: data.dec(_f$file),
      character: data.dec(_f$character),
      proficiencies: data.dec(_f$proficiencies),
      skills: data.dec(_f$skills),
      isDirty: data.dec(_f$isDirty),
      canUndo: data.dec(_f$canUndo),
      canRedo: data.dec(_f$canRedo),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CharacterFileState fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CharacterFileState>(map);
  }

  static CharacterFileState fromJson(String json) {
    return ensureInitialized().decodeJson<CharacterFileState>(json);
  }
}

mixin CharacterFileStateMappable {
  String toJson() {
    return CharacterFileStateMapper.ensureInitialized()
        .encodeJson<CharacterFileState>(this as CharacterFileState);
  }

  Map<String, dynamic> toMap() {
    return CharacterFileStateMapper.ensureInitialized()
        .encodeMap<CharacterFileState>(this as CharacterFileState);
  }

  CharacterFileStateCopyWith<
    CharacterFileState,
    CharacterFileState,
    CharacterFileState
  >
  get copyWith =>
      _CharacterFileStateCopyWithImpl<CharacterFileState, CharacterFileState>(
        this as CharacterFileState,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CharacterFileStateMapper.ensureInitialized().stringifyValue(
      this as CharacterFileState,
    );
  }

  @override
  bool operator ==(Object other) {
    return CharacterFileStateMapper.ensureInitialized().equalsValue(
      this as CharacterFileState,
      other,
    );
  }

  @override
  int get hashCode {
    return CharacterFileStateMapper.ensureInitialized().hashValue(
      this as CharacterFileState,
    );
  }
}

extension CharacterFileStateValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CharacterFileState, $Out> {
  CharacterFileStateCopyWith<$R, CharacterFileState, $Out>
  get $asCharacterFileState => $base.as(
    (v, t, t2) => _CharacterFileStateCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class CharacterFileStateCopyWith<
  $R,
  $In extends CharacterFileState,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  CharacterFileCopyWith<$R, CharacterFile, CharacterFile> get file;
  CharacterCopyWith<$R, Character, Character> get character;
  ProficiencyCatalogueCopyWith<$R, ProficiencyCatalogue, ProficiencyCatalogue>
  get proficiencies;
  SkillCatalogueCopyWith<$R, SkillCatalogue, SkillCatalogue> get skills;
  $R call({
    CharacterFile? file,
    Character? character,
    ProficiencyCatalogue? proficiencies,
    SkillCatalogue? skills,
    bool? isDirty,
    bool? canUndo,
    bool? canRedo,
  });
  CharacterFileStateCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CharacterFileStateCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CharacterFileState, $Out>
    implements CharacterFileStateCopyWith<$R, CharacterFileState, $Out> {
  _CharacterFileStateCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CharacterFileState> $mapper =
      CharacterFileStateMapper.ensureInitialized();
  @override
  CharacterFileCopyWith<$R, CharacterFile, CharacterFile> get file =>
      $value.file.copyWith.$chain((v) => call(file: v));
  @override
  CharacterCopyWith<$R, Character, Character> get character =>
      $value.character.copyWith.$chain((v) => call(character: v));
  @override
  ProficiencyCatalogueCopyWith<$R, ProficiencyCatalogue, ProficiencyCatalogue>
  get proficiencies =>
      $value.proficiencies.copyWith.$chain((v) => call(proficiencies: v));
  @override
  SkillCatalogueCopyWith<$R, SkillCatalogue, SkillCatalogue> get skills =>
      $value.skills.copyWith.$chain((v) => call(skills: v));
  @override
  $R call({
    CharacterFile? file,
    Character? character,
    ProficiencyCatalogue? proficiencies,
    SkillCatalogue? skills,
    bool? isDirty,
    bool? canUndo,
    bool? canRedo,
  }) => $apply(
    FieldCopyWithData({
      if (file != null) #file: file,
      if (character != null) #character: character,
      if (proficiencies != null) #proficiencies: proficiencies,
      if (skills != null) #skills: skills,
      if (isDirty != null) #isDirty: isDirty,
      if (canUndo != null) #canUndo: canUndo,
      if (canRedo != null) #canRedo: canRedo,
    }),
  );
  @override
  CharacterFileState $make(CopyWithData data) => CharacterFileState(
    file: data.get(#file, or: $value.file),
    character: data.get(#character, or: $value.character),
    proficiencies: data.get(#proficiencies, or: $value.proficiencies),
    skills: data.get(#skills, or: $value.skills),
    isDirty: data.get(#isDirty, or: $value.isDirty),
    canUndo: data.get(#canUndo, or: $value.canUndo),
    canRedo: data.get(#canRedo, or: $value.canRedo),
  );

  @override
  CharacterFileStateCopyWith<$R2, CharacterFileState, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CharacterFileStateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

