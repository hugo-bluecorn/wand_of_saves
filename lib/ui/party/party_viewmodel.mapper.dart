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
  static int _$selectedIndex(PartyState v) => v.selectedIndex;
  static const Field<PartyState, int> _f$selectedIndex = Field(
    'selectedIndex',
    _$selectedIndex,
    opt: true,
    def: 0,
  );

  @override
  final MappableFields<PartyState> fields = const {
    #slot: _f$slot,
    #members: _f$members,
    #selectedIndex: _f$selectedIndex,
  };

  static PartyState _instantiate(DecodingData data) {
    return PartyState(
      slot: data.dec(_f$slot),
      members: data.dec(_f$members),
      selectedIndex: data.dec(_f$selectedIndex),
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
  $R call({SaveSlot? slot, List<Character>? members, int? selectedIndex});
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
  $R call({SaveSlot? slot, List<Character>? members, int? selectedIndex}) =>
      $apply(
        FieldCopyWithData({
          if (slot != null) #slot: slot,
          if (members != null) #members: members,
          if (selectedIndex != null) #selectedIndex: selectedIndex,
        }),
      );
  @override
  PartyState $make(CopyWithData data) => PartyState(
    slot: data.get(#slot, or: $value.slot),
    members: data.get(#members, or: $value.members),
    selectedIndex: data.get(#selectedIndex, or: $value.selectedIndex),
  );

  @override
  PartyStateCopyWith<$R2, PartyState, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PartyStateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

