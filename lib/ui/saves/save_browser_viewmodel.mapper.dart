// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'save_browser_viewmodel.dart';

class BrowserStateMapper extends ClassMapperBase<BrowserState> {
  BrowserStateMapper._();

  static BrowserStateMapper? _instance;
  static BrowserStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BrowserStateMapper._());
      CharacterFileMapper.ensureInitialized();
      SaveSlotMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'BrowserState';

  static List<CharacterFile> _$characters(BrowserState v) => v.characters;
  static const Field<BrowserState, List<CharacterFile>> _f$characters = Field(
    'characters',
    _$characters,
    opt: true,
    def: const [],
  );
  static List<SaveSlot> _$saves(BrowserState v) => v.saves;
  static const Field<BrowserState, List<SaveSlot>> _f$saves = Field(
    'saves',
    _$saves,
    opt: true,
    def: const [],
  );
  static Set<DocumentRef> _$selected(BrowserState v) => v.selected;
  static const Field<BrowserState, Set<DocumentRef>> _f$selected = Field(
    'selected',
    _$selected,
    opt: true,
    def: const {},
  );
  static bool _$isSelecting(BrowserState v) => v.isSelecting;
  static const Field<BrowserState, bool> _f$isSelecting = Field(
    'isSelecting',
    _$isSelecting,
    opt: true,
    def: false,
  );
  static bool _$hasDeleted(BrowserState v) => v.hasDeleted;
  static const Field<BrowserState, bool> _f$hasDeleted = Field(
    'hasDeleted',
    _$hasDeleted,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<BrowserState> fields = const {
    #characters: _f$characters,
    #saves: _f$saves,
    #selected: _f$selected,
    #isSelecting: _f$isSelecting,
    #hasDeleted: _f$hasDeleted,
  };

  static BrowserState _instantiate(DecodingData data) {
    return BrowserState(
      characters: data.dec(_f$characters),
      saves: data.dec(_f$saves),
      selected: data.dec(_f$selected),
      isSelecting: data.dec(_f$isSelecting),
      hasDeleted: data.dec(_f$hasDeleted),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static BrowserState fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BrowserState>(map);
  }

  static BrowserState fromJson(String json) {
    return ensureInitialized().decodeJson<BrowserState>(json);
  }
}

mixin BrowserStateMappable {
  String toJson() {
    return BrowserStateMapper.ensureInitialized().encodeJson<BrowserState>(
      this as BrowserState,
    );
  }

  Map<String, dynamic> toMap() {
    return BrowserStateMapper.ensureInitialized().encodeMap<BrowserState>(
      this as BrowserState,
    );
  }

  BrowserStateCopyWith<BrowserState, BrowserState, BrowserState> get copyWith =>
      _BrowserStateCopyWithImpl<BrowserState, BrowserState>(
        this as BrowserState,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return BrowserStateMapper.ensureInitialized().stringifyValue(
      this as BrowserState,
    );
  }

  @override
  bool operator ==(Object other) {
    return BrowserStateMapper.ensureInitialized().equalsValue(
      this as BrowserState,
      other,
    );
  }

  @override
  int get hashCode {
    return BrowserStateMapper.ensureInitialized().hashValue(
      this as BrowserState,
    );
  }
}

extension BrowserStateValueCopy<$R, $Out>
    on ObjectCopyWith<$R, BrowserState, $Out> {
  BrowserStateCopyWith<$R, BrowserState, $Out> get $asBrowserState =>
      $base.as((v, t, t2) => _BrowserStateCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class BrowserStateCopyWith<$R, $In extends BrowserState, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    CharacterFile,
    CharacterFileCopyWith<$R, CharacterFile, CharacterFile>
  >
  get characters;
  ListCopyWith<$R, SaveSlot, SaveSlotCopyWith<$R, SaveSlot, SaveSlot>>
  get saves;
  $R call({
    List<CharacterFile>? characters,
    List<SaveSlot>? saves,
    Set<DocumentRef>? selected,
    bool? isSelecting,
    bool? hasDeleted,
  });
  BrowserStateCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _BrowserStateCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BrowserState, $Out>
    implements BrowserStateCopyWith<$R, BrowserState, $Out> {
  _BrowserStateCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BrowserState> $mapper =
      BrowserStateMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    CharacterFile,
    CharacterFileCopyWith<$R, CharacterFile, CharacterFile>
  >
  get characters => ListCopyWith(
    $value.characters,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(characters: v),
  );
  @override
  ListCopyWith<$R, SaveSlot, SaveSlotCopyWith<$R, SaveSlot, SaveSlot>>
  get saves => ListCopyWith(
    $value.saves,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(saves: v),
  );
  @override
  $R call({
    List<CharacterFile>? characters,
    List<SaveSlot>? saves,
    Set<DocumentRef>? selected,
    bool? isSelecting,
    bool? hasDeleted,
  }) => $apply(
    FieldCopyWithData({
      if (characters != null) #characters: characters,
      if (saves != null) #saves: saves,
      if (selected != null) #selected: selected,
      if (isSelecting != null) #isSelecting: isSelecting,
      if (hasDeleted != null) #hasDeleted: hasDeleted,
    }),
  );
  @override
  BrowserState $make(CopyWithData data) => BrowserState(
    characters: data.get(#characters, or: $value.characters),
    saves: data.get(#saves, or: $value.saves),
    selected: data.get(#selected, or: $value.selected),
    isSelecting: data.get(#isSelecting, or: $value.isSelecting),
    hasDeleted: data.get(#hasDeleted, or: $value.hasDeleted),
  );

  @override
  BrowserStateCopyWith<$R2, BrowserState, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _BrowserStateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

