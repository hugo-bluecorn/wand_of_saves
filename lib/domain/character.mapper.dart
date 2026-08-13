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
      SavingThrowsMapper.ensureInitialized();
      ResistancesMapper.ensureInitialized();
      ThiefSkillsMapper.ensureInitialized();
      ArmorClassModifiersMapper.ensureInitialized();
      ProficiencyMapper.ensureInitialized();
      CarriedItemMapper.ensureInitialized();
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
  static SavingThrows _$savingThrows(Character v) => v.savingThrows;
  static const Field<Character, SavingThrows> _f$savingThrows = Field(
    'savingThrows',
    _$savingThrows,
  );
  static Resistances _$resistances(Character v) => v.resistances;
  static const Field<Character, Resistances> _f$resistances = Field(
    'resistances',
    _$resistances,
  );
  static ThiefSkills _$thiefSkills(Character v) => v.thiefSkills;
  static const Field<Character, ThiefSkills> _f$thiefSkills = Field(
    'thiefSkills',
    _$thiefSkills,
  );
  static ArmorClassModifiers _$armorClassModifiers(Character v) =>
      v.armorClassModifiers;
  static const Field<Character, ArmorClassModifiers> _f$armorClassModifiers =
      Field('armorClassModifiers', _$armorClassModifiers);
  static int _$numberOfAttacks(Character v) => v.numberOfAttacks;
  static const Field<Character, int> _f$numberOfAttacks = Field(
    'numberOfAttacks',
    _$numberOfAttacks,
  );
  static int _$morale(Character v) => v.morale;
  static const Field<Character, int> _f$morale = Field('morale', _$morale);
  static int _$moraleBreak(Character v) => v.moraleBreak;
  static const Field<Character, int> _f$moraleBreak = Field(
    'moraleBreak',
    _$moraleBreak,
  );
  static int _$luck(Character v) => v.luck;
  static const Field<Character, int> _f$luck = Field('luck', _$luck);
  static int _$fatigue(Character v) => v.fatigue;
  static const Field<Character, int> _f$fatigue = Field('fatigue', _$fatigue);
  static int _$intoxication(Character v) => v.intoxication;
  static const Field<Character, int> _f$intoxication = Field(
    'intoxication',
    _$intoxication,
  );
  static int _$turnUndeadLevel(Character v) => v.turnUndeadLevel;
  static const Field<Character, int> _f$turnUndeadLevel = Field(
    'turnUndeadLevel',
    _$turnUndeadLevel,
  );
  static int _$trackingSkill(Character v) => v.trackingSkill;
  static const Field<Character, int> _f$trackingSkill = Field(
    'trackingSkill',
    _$trackingSkill,
  );
  static List<Proficiency> _$proficiencies(Character v) => v.proficiencies;
  static const Field<Character, List<Proficiency>> _f$proficiencies = Field(
    'proficiencies',
    _$proficiencies,
    opt: true,
    def: const [],
  );
  static List<CarriedItem> _$items(Character v) => v.items;
  static const Field<Character, List<CarriedItem>> _f$items = Field(
    'items',
    _$items,
    opt: true,
    def: const [],
  );
  static String? _$portraitPath(Character v) => v.portraitPath;
  static const Field<Character, String> _f$portraitPath = Field(
    'portraitPath',
    _$portraitPath,
    opt: true,
  );
  static String _$portraitBaseName(Character v) => v.portraitBaseName;
  static const Field<Character, String> _f$portraitBaseName = Field(
    'portraitBaseName',
    _$portraitBaseName,
    opt: true,
    def: '',
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
    #savingThrows: _f$savingThrows,
    #resistances: _f$resistances,
    #thiefSkills: _f$thiefSkills,
    #armorClassModifiers: _f$armorClassModifiers,
    #numberOfAttacks: _f$numberOfAttacks,
    #morale: _f$morale,
    #moraleBreak: _f$moraleBreak,
    #luck: _f$luck,
    #fatigue: _f$fatigue,
    #intoxication: _f$intoxication,
    #turnUndeadLevel: _f$turnUndeadLevel,
    #trackingSkill: _f$trackingSkill,
    #proficiencies: _f$proficiencies,
    #items: _f$items,
    #portraitPath: _f$portraitPath,
    #portraitBaseName: _f$portraitBaseName,
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
      savingThrows: data.dec(_f$savingThrows),
      resistances: data.dec(_f$resistances),
      thiefSkills: data.dec(_f$thiefSkills),
      armorClassModifiers: data.dec(_f$armorClassModifiers),
      numberOfAttacks: data.dec(_f$numberOfAttacks),
      morale: data.dec(_f$morale),
      moraleBreak: data.dec(_f$moraleBreak),
      luck: data.dec(_f$luck),
      fatigue: data.dec(_f$fatigue),
      intoxication: data.dec(_f$intoxication),
      turnUndeadLevel: data.dec(_f$turnUndeadLevel),
      trackingSkill: data.dec(_f$trackingSkill),
      proficiencies: data.dec(_f$proficiencies),
      items: data.dec(_f$items),
      portraitPath: data.dec(_f$portraitPath),
      portraitBaseName: data.dec(_f$portraitBaseName),
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
  SavingThrowsCopyWith<$R, SavingThrows, SavingThrows> get savingThrows;
  ResistancesCopyWith<$R, Resistances, Resistances> get resistances;
  ThiefSkillsCopyWith<$R, ThiefSkills, ThiefSkills> get thiefSkills;
  ArmorClassModifiersCopyWith<$R, ArmorClassModifiers, ArmorClassModifiers>
  get armorClassModifiers;
  ListCopyWith<
    $R,
    Proficiency,
    ProficiencyCopyWith<$R, Proficiency, Proficiency>
  >
  get proficiencies;
  ListCopyWith<
    $R,
    CarriedItem,
    CarriedItemCopyWith<$R, CarriedItem, CarriedItem>
  >
  get items;
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
    SavingThrows? savingThrows,
    Resistances? resistances,
    ThiefSkills? thiefSkills,
    ArmorClassModifiers? armorClassModifiers,
    int? numberOfAttacks,
    int? morale,
    int? moraleBreak,
    int? luck,
    int? fatigue,
    int? intoxication,
    int? turnUndeadLevel,
    int? trackingSkill,
    List<Proficiency>? proficiencies,
    List<CarriedItem>? items,
    String? portraitPath,
    String? portraitBaseName,
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
  SavingThrowsCopyWith<$R, SavingThrows, SavingThrows> get savingThrows =>
      $value.savingThrows.copyWith.$chain((v) => call(savingThrows: v));
  @override
  ResistancesCopyWith<$R, Resistances, Resistances> get resistances =>
      $value.resistances.copyWith.$chain((v) => call(resistances: v));
  @override
  ThiefSkillsCopyWith<$R, ThiefSkills, ThiefSkills> get thiefSkills =>
      $value.thiefSkills.copyWith.$chain((v) => call(thiefSkills: v));
  @override
  ArmorClassModifiersCopyWith<$R, ArmorClassModifiers, ArmorClassModifiers>
  get armorClassModifiers => $value.armorClassModifiers.copyWith.$chain(
    (v) => call(armorClassModifiers: v),
  );
  @override
  ListCopyWith<
    $R,
    Proficiency,
    ProficiencyCopyWith<$R, Proficiency, Proficiency>
  >
  get proficiencies => ListCopyWith(
    $value.proficiencies,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(proficiencies: v),
  );
  @override
  ListCopyWith<
    $R,
    CarriedItem,
    CarriedItemCopyWith<$R, CarriedItem, CarriedItem>
  >
  get items => ListCopyWith(
    $value.items,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(items: v),
  );
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
    SavingThrows? savingThrows,
    Resistances? resistances,
    ThiefSkills? thiefSkills,
    ArmorClassModifiers? armorClassModifiers,
    int? numberOfAttacks,
    int? morale,
    int? moraleBreak,
    int? luck,
    int? fatigue,
    int? intoxication,
    int? turnUndeadLevel,
    int? trackingSkill,
    List<Proficiency>? proficiencies,
    List<CarriedItem>? items,
    Object? portraitPath = $none,
    String? portraitBaseName,
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
      if (savingThrows != null) #savingThrows: savingThrows,
      if (resistances != null) #resistances: resistances,
      if (thiefSkills != null) #thiefSkills: thiefSkills,
      if (armorClassModifiers != null)
        #armorClassModifiers: armorClassModifiers,
      if (numberOfAttacks != null) #numberOfAttacks: numberOfAttacks,
      if (morale != null) #morale: morale,
      if (moraleBreak != null) #moraleBreak: moraleBreak,
      if (luck != null) #luck: luck,
      if (fatigue != null) #fatigue: fatigue,
      if (intoxication != null) #intoxication: intoxication,
      if (turnUndeadLevel != null) #turnUndeadLevel: turnUndeadLevel,
      if (trackingSkill != null) #trackingSkill: trackingSkill,
      if (proficiencies != null) #proficiencies: proficiencies,
      if (items != null) #items: items,
      if (portraitPath != $none) #portraitPath: portraitPath,
      if (portraitBaseName != null) #portraitBaseName: portraitBaseName,
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
    savingThrows: data.get(#savingThrows, or: $value.savingThrows),
    resistances: data.get(#resistances, or: $value.resistances),
    thiefSkills: data.get(#thiefSkills, or: $value.thiefSkills),
    armorClassModifiers: data.get(
      #armorClassModifiers,
      or: $value.armorClassModifiers,
    ),
    numberOfAttacks: data.get(#numberOfAttacks, or: $value.numberOfAttacks),
    morale: data.get(#morale, or: $value.morale),
    moraleBreak: data.get(#moraleBreak, or: $value.moraleBreak),
    luck: data.get(#luck, or: $value.luck),
    fatigue: data.get(#fatigue, or: $value.fatigue),
    intoxication: data.get(#intoxication, or: $value.intoxication),
    turnUndeadLevel: data.get(#turnUndeadLevel, or: $value.turnUndeadLevel),
    trackingSkill: data.get(#trackingSkill, or: $value.trackingSkill),
    proficiencies: data.get(#proficiencies, or: $value.proficiencies),
    items: data.get(#items, or: $value.items),
    portraitPath: data.get(#portraitPath, or: $value.portraitPath),
    portraitBaseName: data.get(#portraitBaseName, or: $value.portraitBaseName),
  );

  @override
  CharacterCopyWith<$R2, Character, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CharacterCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

