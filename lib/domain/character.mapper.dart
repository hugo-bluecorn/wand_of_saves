// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'character.dart';

class CharacterMapper extends ClassMapperBase<Character> {
  CharacterMapper._();

  static CharacterMapper? _instance;
  static CharacterMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CharacterMapper._());
      AbilityScoresMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Character';

  static String _$name(Character v) => v.name;
  static const Field<Character, String> _f$name = Field('name', _$name);
  static int _$nameStrref(Character v) => v.nameStrref;
  static const Field<Character, int> _f$nameStrref = Field(
    'nameStrref',
    _$nameStrref,
  );
  static String _$creResref(Character v) => v.creResref;
  static const Field<Character, String> _f$creResref = Field(
    'creResref',
    _$creResref,
  );
  static int _$partyOrder(Character v) => v.partyOrder;
  static const Field<Character, int> _f$partyOrder = Field(
    'partyOrder',
    _$partyOrder,
  );
  static int _$structOffset(Character v) => v.structOffset;
  static const Field<Character, int> _f$structOffset = Field(
    'structOffset',
    _$structOffset,
  );
  static int _$creOffset(Character v) => v.creOffset;
  static const Field<Character, int> _f$creOffset = Field(
    'creOffset',
    _$creOffset,
  );
  static int _$creLength(Character v) => v.creLength;
  static const Field<Character, int> _f$creLength = Field(
    'creLength',
    _$creLength,
  );
  static int _$currentHitPoints(Character v) => v.currentHitPoints;
  static const Field<Character, int> _f$currentHitPoints = Field(
    'currentHitPoints',
    _$currentHitPoints,
  );
  static int _$maximumHitPoints(Character v) => v.maximumHitPoints;
  static const Field<Character, int> _f$maximumHitPoints = Field(
    'maximumHitPoints',
    _$maximumHitPoints,
  );
  static int _$experience(Character v) => v.experience;
  static const Field<Character, int> _f$experience = Field(
    'experience',
    _$experience,
  );
  static int _$gold(Character v) => v.gold;
  static const Field<Character, int> _f$gold = Field('gold', _$gold);
  static int _$thac0(Character v) => v.thac0;
  static const Field<Character, int> _f$thac0 = Field('thac0', _$thac0);
  static int _$armorClass(Character v) => v.armorClass;
  static const Field<Character, int> _f$armorClass = Field(
    'armorClass',
    _$armorClass,
  );
  static int _$armorClassNatural(Character v) => v.armorClassNatural;
  static const Field<Character, int> _f$armorClassNatural = Field(
    'armorClassNatural',
    _$armorClassNatural,
  );
  static int _$levelFirstClass(Character v) => v.levelFirstClass;
  static const Field<Character, int> _f$levelFirstClass = Field(
    'levelFirstClass',
    _$levelFirstClass,
  );
  static int _$levelSecondClass(Character v) => v.levelSecondClass;
  static const Field<Character, int> _f$levelSecondClass = Field(
    'levelSecondClass',
    _$levelSecondClass,
  );
  static int _$levelThirdClass(Character v) => v.levelThirdClass;
  static const Field<Character, int> _f$levelThirdClass = Field(
    'levelThirdClass',
    _$levelThirdClass,
  );
  static double _$reputation(Character v) => v.reputation;
  static const Field<Character, double> _f$reputation = Field(
    'reputation',
    _$reputation,
  );
  static int _$classId(Character v) => v.classId;
  static const Field<Character, int> _f$classId = Field('classId', _$classId);
  static int _$raceId(Character v) => v.raceId;
  static const Field<Character, int> _f$raceId = Field('raceId', _$raceId);
  static int _$alignmentId(Character v) => v.alignmentId;
  static const Field<Character, int> _f$alignmentId = Field(
    'alignmentId',
    _$alignmentId,
  );
  static int _$genderId(Character v) => v.genderId;
  static const Field<Character, int> _f$genderId = Field(
    'genderId',
    _$genderId,
  );
  static int _$kitId(Character v) => v.kitId;
  static const Field<Character, int> _f$kitId = Field('kitId', _$kitId);
  static AbilityScores _$abilities(Character v) => v.abilities;
  static const Field<Character, AbilityScores> _f$abilities = Field(
    'abilities',
    _$abilities,
  );
  static String? _$portraitPath(Character v) => v.portraitPath;
  static const Field<Character, String> _f$portraitPath = Field(
    'portraitPath',
    _$portraitPath,
    opt: true,
  );

  @override
  final MappableFields<Character> fields = const {
    #name: _f$name,
    #nameStrref: _f$nameStrref,
    #creResref: _f$creResref,
    #partyOrder: _f$partyOrder,
    #structOffset: _f$structOffset,
    #creOffset: _f$creOffset,
    #creLength: _f$creLength,
    #currentHitPoints: _f$currentHitPoints,
    #maximumHitPoints: _f$maximumHitPoints,
    #experience: _f$experience,
    #gold: _f$gold,
    #thac0: _f$thac0,
    #armorClass: _f$armorClass,
    #armorClassNatural: _f$armorClassNatural,
    #levelFirstClass: _f$levelFirstClass,
    #levelSecondClass: _f$levelSecondClass,
    #levelThirdClass: _f$levelThirdClass,
    #reputation: _f$reputation,
    #classId: _f$classId,
    #raceId: _f$raceId,
    #alignmentId: _f$alignmentId,
    #genderId: _f$genderId,
    #kitId: _f$kitId,
    #abilities: _f$abilities,
    #portraitPath: _f$portraitPath,
  };

  static Character _instantiate(DecodingData data) {
    return Character(
      name: data.dec(_f$name),
      nameStrref: data.dec(_f$nameStrref),
      creResref: data.dec(_f$creResref),
      partyOrder: data.dec(_f$partyOrder),
      structOffset: data.dec(_f$structOffset),
      creOffset: data.dec(_f$creOffset),
      creLength: data.dec(_f$creLength),
      currentHitPoints: data.dec(_f$currentHitPoints),
      maximumHitPoints: data.dec(_f$maximumHitPoints),
      experience: data.dec(_f$experience),
      gold: data.dec(_f$gold),
      thac0: data.dec(_f$thac0),
      armorClass: data.dec(_f$armorClass),
      armorClassNatural: data.dec(_f$armorClassNatural),
      levelFirstClass: data.dec(_f$levelFirstClass),
      levelSecondClass: data.dec(_f$levelSecondClass),
      levelThirdClass: data.dec(_f$levelThirdClass),
      reputation: data.dec(_f$reputation),
      classId: data.dec(_f$classId),
      raceId: data.dec(_f$raceId),
      alignmentId: data.dec(_f$alignmentId),
      genderId: data.dec(_f$genderId),
      kitId: data.dec(_f$kitId),
      abilities: data.dec(_f$abilities),
      portraitPath: data.dec(_f$portraitPath),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Character fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Character>(map);
  }

  static Character fromJson(String json) {
    return ensureInitialized().decodeJson<Character>(json);
  }
}

mixin CharacterMappable {
  String toJson() {
    return CharacterMapper.ensureInitialized().encodeJson<Character>(
      this as Character,
    );
  }

  Map<String, dynamic> toMap() {
    return CharacterMapper.ensureInitialized().encodeMap<Character>(
      this as Character,
    );
  }

  CharacterCopyWith<Character, Character, Character> get copyWith =>
      _CharacterCopyWithImpl<Character, Character>(
        this as Character,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CharacterMapper.ensureInitialized().stringifyValue(
      this as Character,
    );
  }

  @override
  bool operator ==(Object other) {
    return CharacterMapper.ensureInitialized().equalsValue(
      this as Character,
      other,
    );
  }

  @override
  int get hashCode {
    return CharacterMapper.ensureInitialized().hashValue(this as Character);
  }
}

extension CharacterValueCopy<$R, $Out> on ObjectCopyWith<$R, Character, $Out> {
  CharacterCopyWith<$R, Character, $Out> get $asCharacter =>
      $base.as((v, t, t2) => _CharacterCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CharacterCopyWith<$R, $In extends Character, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  AbilityScoresCopyWith<$R, AbilityScores, AbilityScores> get abilities;
  $R call({
    String? name,
    int? nameStrref,
    String? creResref,
    int? partyOrder,
    int? structOffset,
    int? creOffset,
    int? creLength,
    int? currentHitPoints,
    int? maximumHitPoints,
    int? experience,
    int? gold,
    int? thac0,
    int? armorClass,
    int? armorClassNatural,
    int? levelFirstClass,
    int? levelSecondClass,
    int? levelThirdClass,
    double? reputation,
    int? classId,
    int? raceId,
    int? alignmentId,
    int? genderId,
    int? kitId,
    AbilityScores? abilities,
    String? portraitPath,
  });
  CharacterCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CharacterCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Character, $Out>
    implements CharacterCopyWith<$R, Character, $Out> {
  _CharacterCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Character> $mapper =
      CharacterMapper.ensureInitialized();
  @override
  AbilityScoresCopyWith<$R, AbilityScores, AbilityScores> get abilities =>
      $value.abilities.copyWith.$chain((v) => call(abilities: v));
  @override
  $R call({
    String? name,
    int? nameStrref,
    String? creResref,
    int? partyOrder,
    int? structOffset,
    int? creOffset,
    int? creLength,
    int? currentHitPoints,
    int? maximumHitPoints,
    int? experience,
    int? gold,
    int? thac0,
    int? armorClass,
    int? armorClassNatural,
    int? levelFirstClass,
    int? levelSecondClass,
    int? levelThirdClass,
    double? reputation,
    int? classId,
    int? raceId,
    int? alignmentId,
    int? genderId,
    int? kitId,
    AbilityScores? abilities,
    Object? portraitPath = $none,
  }) => $apply(
    FieldCopyWithData({
      if (name != null) #name: name,
      if (nameStrref != null) #nameStrref: nameStrref,
      if (creResref != null) #creResref: creResref,
      if (partyOrder != null) #partyOrder: partyOrder,
      if (structOffset != null) #structOffset: structOffset,
      if (creOffset != null) #creOffset: creOffset,
      if (creLength != null) #creLength: creLength,
      if (currentHitPoints != null) #currentHitPoints: currentHitPoints,
      if (maximumHitPoints != null) #maximumHitPoints: maximumHitPoints,
      if (experience != null) #experience: experience,
      if (gold != null) #gold: gold,
      if (thac0 != null) #thac0: thac0,
      if (armorClass != null) #armorClass: armorClass,
      if (armorClassNatural != null) #armorClassNatural: armorClassNatural,
      if (levelFirstClass != null) #levelFirstClass: levelFirstClass,
      if (levelSecondClass != null) #levelSecondClass: levelSecondClass,
      if (levelThirdClass != null) #levelThirdClass: levelThirdClass,
      if (reputation != null) #reputation: reputation,
      if (classId != null) #classId: classId,
      if (raceId != null) #raceId: raceId,
      if (alignmentId != null) #alignmentId: alignmentId,
      if (genderId != null) #genderId: genderId,
      if (kitId != null) #kitId: kitId,
      if (abilities != null) #abilities: abilities,
      if (portraitPath != $none) #portraitPath: portraitPath,
    }),
  );
  @override
  Character $make(CopyWithData data) => Character(
    name: data.get(#name, or: $value.name),
    nameStrref: data.get(#nameStrref, or: $value.nameStrref),
    creResref: data.get(#creResref, or: $value.creResref),
    partyOrder: data.get(#partyOrder, or: $value.partyOrder),
    structOffset: data.get(#structOffset, or: $value.structOffset),
    creOffset: data.get(#creOffset, or: $value.creOffset),
    creLength: data.get(#creLength, or: $value.creLength),
    currentHitPoints: data.get(#currentHitPoints, or: $value.currentHitPoints),
    maximumHitPoints: data.get(#maximumHitPoints, or: $value.maximumHitPoints),
    experience: data.get(#experience, or: $value.experience),
    gold: data.get(#gold, or: $value.gold),
    thac0: data.get(#thac0, or: $value.thac0),
    armorClass: data.get(#armorClass, or: $value.armorClass),
    armorClassNatural: data.get(
      #armorClassNatural,
      or: $value.armorClassNatural,
    ),
    levelFirstClass: data.get(#levelFirstClass, or: $value.levelFirstClass),
    levelSecondClass: data.get(#levelSecondClass, or: $value.levelSecondClass),
    levelThirdClass: data.get(#levelThirdClass, or: $value.levelThirdClass),
    reputation: data.get(#reputation, or: $value.reputation),
    classId: data.get(#classId, or: $value.classId),
    raceId: data.get(#raceId, or: $value.raceId),
    alignmentId: data.get(#alignmentId, or: $value.alignmentId),
    genderId: data.get(#genderId, or: $value.genderId),
    kitId: data.get(#kitId, or: $value.kitId),
    abilities: data.get(#abilities, or: $value.abilities),
    portraitPath: data.get(#portraitPath, or: $value.portraitPath),
  );

  @override
  CharacterCopyWith<$R2, Character, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CharacterCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

