// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'party_viewmodel.dart';

class PartyStateMapper extends ClassMapperBase<PartyState> {
  PartyStateMapper._();

  static PartyStateMapper? _instance;
  static PartyStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PartyStateMapper._());
      SaveSlotMapper.ensureInitialized();
      CharacterMapper.ensureInitialized();
      ProficiencyCatalogueMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PartyState';

  static SaveSlot _$slot(PartyState v) => v.slot;
  static const Field<PartyState, SaveSlot> _f$slot = Field('slot', _$slot);
  static List<Character> _$members(PartyState v) => v.members;
  static const Field<PartyState, List<Character>> _f$members = Field(
    'members',
    _$members,
  );
  static ProficiencyCatalogue _$proficiencies(PartyState v) => v.proficiencies;
  static const Field<PartyState, ProficiencyCatalogue> _f$proficiencies = Field(
    'proficiencies',
    _$proficiencies,
    opt: true,
    def: ProficiencyCatalogue.empty,
  );
  static int _$selectedIndex(PartyState v) => v.selectedIndex;
  static const Field<PartyState, int> _f$selectedIndex = Field(
    'selectedIndex',
    _$selectedIndex,
    opt: true,
    def: 0,
  );
  static bool _$isDirty(PartyState v) => v.isDirty;
  static const Field<PartyState, bool> _f$isDirty = Field(
    'isDirty',
    _$isDirty,
    opt: true,
    def: false,
  );
  static bool _$canUndo(PartyState v) => v.canUndo;
  static const Field<PartyState, bool> _f$canUndo = Field(
    'canUndo',
    _$canUndo,
    opt: true,
    def: false,
  );
  static bool _$canRedo(PartyState v) => v.canRedo;
  static const Field<PartyState, bool> _f$canRedo = Field(
    'canRedo',
    _$canRedo,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<PartyState> fields = const {
    #slot: _f$slot,
    #members: _f$members,
    #proficiencies: _f$proficiencies,
    #selectedIndex: _f$selectedIndex,
    #isDirty: _f$isDirty,
    #canUndo: _f$canUndo,
    #canRedo: _f$canRedo,
  };

  static PartyState _instantiate(DecodingData data) {
    return PartyState(
      slot: data.dec(_f$slot),
      members: data.dec(_f$members),
      proficiencies: data.dec(_f$proficiencies),
      selectedIndex: data.dec(_f$selectedIndex),
      isDirty: data.dec(_f$isDirty),
      canUndo: data.dec(_f$canUndo),
      canRedo: data.dec(_f$canRedo),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PartyState fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PartyState>(map);
  }

  static PartyState fromJson(String json) {
    return ensureInitialized().decodeJson<PartyState>(json);
  }
}

mixin PartyStateMappable {
  String toJson() {
    return PartyStateMapper.ensureInitialized().encodeJson<PartyState>(
      this as PartyState,
    );
  }

  Map<String, dynamic> toMap() {
    return PartyStateMapper.ensureInitialized().encodeMap<PartyState>(
      this as PartyState,
    );
  }

  PartyStateCopyWith<PartyState, PartyState, PartyState> get copyWith =>
      _PartyStateCopyWithImpl<PartyState, PartyState>(
        this as PartyState,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PartyStateMapper.ensureInitialized().stringifyValue(
      this as PartyState,
    );
  }

  @override
  bool operator ==(Object other) {
    return PartyStateMapper.ensureInitialized().equalsValue(
      this as PartyState,
      other,
    );
  }

  @override
  int get hashCode {
    return PartyStateMapper.ensureInitialized().hashValue(this as PartyState);
  }
}

extension PartyStateValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PartyState, $Out> {
  PartyStateCopyWith<$R, PartyState, $Out> get $asPartyState =>
      $base.as((v, t, t2) => _PartyStateCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PartyStateCopyWith<$R, $In extends PartyState, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  SaveSlotCopyWith<$R, SaveSlot, SaveSlot> get slot;
  ListCopyWith<$R, Character, CharacterCopyWith<$R, Character, Character>>
  get members;
  ProficiencyCatalogueCopyWith<$R, ProficiencyCatalogue, ProficiencyCatalogue>
  get proficiencies;
  $R call({
    SaveSlot? slot,
    List<Character>? members,
    ProficiencyCatalogue? proficiencies,
    int? selectedIndex,
    bool? isDirty,
    bool? canUndo,
    bool? canRedo,
  });
  PartyStateCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PartyStateCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PartyState, $Out>
    implements PartyStateCopyWith<$R, PartyState, $Out> {
  _PartyStateCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PartyState> $mapper =
      PartyStateMapper.ensureInitialized();
  @override
  SaveSlotCopyWith<$R, SaveSlot, SaveSlot> get slot =>
      $value.slot.copyWith.$chain((v) => call(slot: v));
  @override
  ListCopyWith<$R, Character, CharacterCopyWith<$R, Character, Character>>
  get members => ListCopyWith(
    $value.members,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(members: v),
  );
  @override
  ProficiencyCatalogueCopyWith<$R, ProficiencyCatalogue, ProficiencyCatalogue>
  get proficiencies =>
      $value.proficiencies.copyWith.$chain((v) => call(proficiencies: v));
  @override
  $R call({
    SaveSlot? slot,
    List<Character>? members,
    ProficiencyCatalogue? proficiencies,
    int? selectedIndex,
    bool? isDirty,
    bool? canUndo,
    bool? canRedo,
  }) => $apply(
    FieldCopyWithData({
      if (slot != null) #slot: slot,
      if (members != null) #members: members,
      if (proficiencies != null) #proficiencies: proficiencies,
      if (selectedIndex != null) #selectedIndex: selectedIndex,
      if (isDirty != null) #isDirty: isDirty,
      if (canUndo != null) #canUndo: canUndo,
      if (canRedo != null) #canRedo: canRedo,
    }),
  );
  @override
  PartyState $make(CopyWithData data) => PartyState(
    slot: data.get(#slot, or: $value.slot),
    members: data.get(#members, or: $value.members),
    proficiencies: data.get(#proficiencies, or: $value.proficiencies),
    selectedIndex: data.get(#selectedIndex, or: $value.selectedIndex),
    isDirty: data.get(#isDirty, or: $value.isDirty),
    canUndo: data.get(#canUndo, or: $value.canUndo),
    canRedo: data.get(#canRedo, or: $value.canRedo),
  );

  @override
  PartyStateCopyWith<$R2, PartyState, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PartyStateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

