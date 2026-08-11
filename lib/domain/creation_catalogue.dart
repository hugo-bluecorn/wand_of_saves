// Copyright 2026 hugo-bluecorn
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:dart_mappable/dart_mappable.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/domain/rules/identifiers.g.dart';
import 'package:wand_of_saves/domain/rules/table_columns.dart';
import 'package:wand_of_saves/domain/skill_catalogue.dart';

part 'creation_catalogue.mapper.dart';

/// One of the six abilities a new character rolls.
///
/// **The join between three tables and one record field.** `abracerq.2da`,
/// `abclasrq.2da` and `abracead.2da` all name the same six abilities and each
/// prefixes them differently, so the prefixes are derived here rather than
/// written out three times.
///
/// ⚠️ **The tables spell Charisma `CHR`, not `CHA`.** One letter, and a guess
/// silently loses exactly one ability — the same shape of bug as `HALFORC`
/// against `HALF_ORC`.
enum CreationAbility {
  /// Strength.
  strength('STR', CharacterStat.strength),

  /// Dexterity.
  dexterity('DEX', CharacterStat.dexterity),

  /// Constitution.
  constitution('CON', CharacterStat.constitution),

  /// Intelligence.
  intelligence('INT', CharacterStat.intelligence),

  /// Wisdom.
  wisdom('WIS', CharacterStat.wisdom),

  /// Charisma.
  charisma('CHR', CharacterStat.charisma);

  const CreationAbility(this.key, this.stat);

  /// How the game's own tables abbreviate this ability.
  final String key;

  /// The record field it is stored in, and where its label comes from.
  final CharacterStat stat;

  /// What to call it on screen.
  String get label => stat.label;

  /// `abracerq.2da`'s and `abclasrq.2da`'s floor column.
  String get minimumColumn => 'MIN_$key';

  /// `abracerq.2da`'s ceiling column.
  String get maximumColumn => 'MAX_$key';

  /// `abracead.2da`'s racial adjustment column.
  String get adjustmentColumn => 'MOD_$key';
}

/// One spell a new character may put in their book.
///
/// Its own type rather than a [CreationChoice], because a spell is named by a
/// **resref** and not by a number the record stores — the other three choices
/// all write an integer into a header field, and this one writes eight bytes
/// into a section that has to be created first.
@MappableClass()
class SpellChoice with SpellChoiceMappable {
  /// Records a spell.
  const SpellChoice({
    required this.resref,
    required this.school,
    this.excludedSchools = const {},
    this.nameStrref,
    this.descriptionStrref,
  });

  /// The `SPL` resource, e.g. `SPWI112`.
  final String resref;

  /// The specialist schools this spell is closed to, by `mschool.2da` number.
  ///
  /// ⚠️ **From the `SPL` header's own exclusion bits, not from a table.** No
  /// file in the installation pairs a school with its opposite; each spell
  /// carries the answer for itself.
  final Set<int> excludedSchools;

  /// Its school, as `mschool.2da` numbers them. `0` is no school.
  ///
  /// Carried because a specialist mage's screen outlines their own school's
  /// spells and requires one of them.
  final int school;

  /// Strref of the displayed name, or `null` when the header carries none.
  final int? nameStrref;

  /// Strref of the description the game shows beside it.
  final int? descriptionStrref;
}

/// One thing the player can pick while making a character.
///
/// A race, a class, or a specialisation. All three are the same shape: a number
/// the record stores, the identifier the rules tables key on, and — where the
/// game has one — a strref for the name and another for the description.
@MappableClass()
class CreationChoice with CreationChoiceMappable {
  /// Records a choice.
  const CreationChoice({
    required this.value,
    required this.identifier,
    this.nameStrref,
    this.descriptionStrref,
  });

  /// What the creature record stores for this choice.
  ///
  /// A `RACE.IDS` or `CLASS.IDS` id for the first two. For a specialisation it
  /// is the **whole kit dword**, key already in the high word, so a command can
  /// write it without knowing anything.
  final int value;

  /// The identifier the game's tables key on, e.g. `ELF` or `FERALAN`.
  ///
  /// ⚠️ **Never show this to anyone.** `FERALAN` is displayed as *Archer*;
  /// `HALFORC` as *Half-Orc*. It is a join key, not a name.
  final String identifier;

  /// Strref of the displayed name, or `null` when the rules supply it.
  ///
  /// Only specialisations carry one. Races and classes are named through
  /// `GameRules.raceName` and `GameRules.className`, which since **D13** read
  /// `racetext.2da` and `clastext.2da` themselves rather than deriving from the
  /// IDS identifiers.
  ///
  /// ⚠️ **`clastext`'s `MIXED` holds substitution tokens** — `FIGHTER_MAGE`
  /// reads `<FIGHTERTYPE> / <MAGESCHOOL>` — and those tokens are exactly why a
  /// kit *replaces* the class name on screen.
  final int? nameStrref;

  /// The answer "no specialisation", which most characters give.
  ///
  /// `0x40000000` is `KIT.IDS`'s `TRUECLASS` in the high word — what a
  /// character with no kit carries, and what `CHARBASE` already holds. Offered
  /// as an ordinary choice so "not specialised" and "not yet answered" are not
  /// the same value.
  static const CreationChoice noSpecialisation = CreationChoice(
    value: 0x40000000,
    identifier: 'TRUECLASS',
  );

  /// Strref of the description the game shows beside the choice, or `null`.
  ///
  /// ⚠️ **The text carries pronoun tokens** — `<PRO_MANWOMAN>`, `<PRO_HISHER>`
  /// — which the engine substitutes from the character's gender. Anything
  /// displaying this has to substitute them too, or it prints markup.
  final int? descriptionStrref;
}

/// What the player's own installation says a new character may be.
///
/// Six of the game's `2DA` files, projected into the five questions a creation
/// flow asks. **Nothing here is a rule this project invented**: which classes
/// an elf may take, which alignments a Kensai may hold and what an elf trades
/// for its Dexterity are all read off the tables BG:EE ships.
///
/// Names and descriptions stay **strrefs**, exactly as `ProficiencyCatalogue`
/// leaves them: resolving one needs the talk table, which is a different
/// repository, and repositories must never be aware of each other. The merge
/// happens upstream in the ViewModel.
@MappableClass()
class CreationCatalogue with CreationCatalogueMappable {
  /// Wraps tables already projected.
  const CreationCatalogue({
    required this.races,
    required this.classesByRace,
    required this.kitsByClass,
    required this.alignmentsByRow,
    required this.adjustmentsByRace,
    this.proficiencySlotsByClass = const {},
    this.proficiencyRankCapsByClass = const {},
    this.abilityMinimaByRow = const {},
    this.abilityMinimaByRace = const {},
    this.abilityMaximaByRace = const {},
    this.wizardSpells = const [],
    this.wizardSpellsMemorisable = 0,
    this.sorcererSpellsMemorisable = 0,
    this.sorcererSpellsKnown = 0,
    this.bardSpellsMemorisable = 0,
    this.proficiencies = ProficiencyCatalogue.empty,
    this.skills = SkillCatalogue.empty,
    this.thiefSkillPointsByClass = const {},
    this.schoolByKit = const {},
    this.textByStrref = const {},
  });

  /// Nothing known — no installation, or files that would not parse.
  static const CreationCatalogue empty = CreationCatalogue(
    races: [],
    classesByRace: {},
    kitsByClass: {},
    alignmentsByRow: {},
    adjustmentsByRace: {},
  );

  /// How many first-level wizard spells a new character may learn.
  ///
  /// ⚠️ **A measurement, not a lookup, and the distinction is the point of
  /// D13.** The engine's own screen says "You may choose 2 spells to put in
  /// your spellbook" (`docs/findings/screens/char-create/20-…`). Tables checked
  /// and rejected: `mxsplwiz.2da` is the *memorise* count; `splsrckn.2da` is
  /// the sorcerer's, whose rules differ; `spells.2da` is a flat cap of 50 per
  /// level; `speldesc.2da` is a partial description list. `intmod.2da` does
  /// carry `MAX_SPELLS_PER_LEVEL` and it is **not** this — Aurel rolled
  /// Intelligence 17, which that table gives 14, and the screen still offered
  /// two.
  static const int wizardSpellsLearnable = 2;

  /// Every playable race, in the order `clsrcreq.2da` lists its columns.
  final List<CreationChoice> races;

  /// Classes by `RACE.IDS` id.
  final Map<int, List<CreationChoice>> classesByRace;

  /// Specialisations by `CLASS.IDS` id. Absent for a class that has none.
  final Map<int, List<CreationChoice>> kitsByClass;

  /// Allowed alignments by `alignmnt.2da` row — a class *or* a kit.
  final Map<String, List<int>> alignmentsByRow;

  /// Racial ability adjustments by `RACE.IDS` id, zeroes dropped.
  ///
  /// Keyed by `abracead.2da`'s own column names — `MOD_DEX` and the rest. See
  /// [CreationAbility.adjustmentColumn], which is where that spelling comes
  /// from now that three tables share the vocabulary.
  final Map<int, Map<String, int>> adjustmentsByRace;

  /// Proficiency slots at first level, by class identifier. `profs.2da`.
  ///
  /// ⚠️ **Not `profsmax.2da`.** One letter apart and a different question: this
  /// is how many pips there are to spend, that is how many may go into any one
  /// proficiency. MAGE 1, FIGHTER 4, CLERIC 2, THIEF 2.
  final Map<String, int> proficiencySlotsByClass;

  /// The most ranks one proficiency may hold at first level. `profsmax.2da`.
  final Map<String, int> proficiencyRankCapsByClass;

  /// Ability minima by class **or kit** row, keyed by [CreationAbility.key].
  ///
  /// `abclasrq.2da`. A kit raises the bar where it has a row: an Abjurer needs
  /// Wisdom 15 where a plain Mage needs none.
  final Map<String, Map<String, int>> abilityMinimaByRow;

  /// Ability minima by `RACE.IDS` id, before racial adjustments. `abracerq`.
  final Map<int, Map<String, int>> abilityMinimaByRace;

  /// Ability maxima by `RACE.IDS` id, before racial adjustments. `abracerq`.
  final Map<int, Map<String, int>> abilityMaximaByRace;

  /// Every first-level wizard spell this installation ships.
  ///
  /// Read from the `SPL` resources themselves; see
  /// `ResourceRepository.wizardSpells` for why no table answers this.
  final List<SpellChoice> wizardSpells;

  /// How many first-level wizard spells a first-level caster may memorise.
  ///
  /// `mxsplwiz.2da`, row 1, column 1 — **one**, which is exactly what the
  /// engine's own screen offers. The count that is *not* here is how many may
  /// be learned; see [wizardSpellsLearnable].
  final int wizardSpellsMemorisable;

  /// The same for a sorcerer. `mxsplsrc.2da` — **three**, not one.
  final int sorcererSpellsMemorisable;

  /// How many spells a first-level sorcerer knows. `splsrckn.2da`.
  ///
  /// ⚠️ **The only casting class whose learn count is in a table**, which is
  /// why [wizardSpellsLearnable] has to be a measurement rather than a lookup.
  final int sorcererSpellsKnown;

  /// The same for a bard. `mxsplbrd.2da`, which **has no row 1** — a bard casts
  /// nothing until second level, and the table is what says so.
  final int bardSpellsMemorisable;

  /// Every proficiency the player's `weapprof.2da` names, with its per-class
  /// ceilings.
  ///
  /// Carried here rather than watched from `rulesCataloguesProvider` so the
  /// flow reads **one** query: a second would give the creation state a second
  /// thing to arrive late, and the notifier is shaped around not being rebuilt.
  /// Its names are strrefs like everything else here, resolved by the same
  /// pass — see [textFor].
  final ProficiencyCatalogue proficiencies;

  /// Which thief skills each class and kit may allocate points to.
  ///
  /// `thiefscl.2da`, carried here for the same reason [proficiencies] is: the
  /// flow reads one query, and a second would give the creation state a second
  /// thing to arrive late.
  final SkillCatalogue skills;

  /// How many thief-skill points each class starts with. `thiefskl.2da`.
  ///
  /// ⚠️ **Not `thiefscl.2da`, which is the field above.** One letter apart and
  /// a different question: this is how many points there are to spend, that is
  /// which skills they may go into. A class with no row here has none to spend
  /// — a fighter is absent rather than zero.
  final Map<String, int> thiefSkillPointsByClass;

  /// Each specialisation's school number, by `kitlist.2da` row name.
  ///
  /// ⚠️ **From `mschool.2da`'s row *order*, which is the numbering itself** —
  /// no column carries it. `ABJURER` is 1 through `TRANSMUTER` at 8, and a
  /// spell's `SPL` header stores the same numbers in its own school field and
  /// in its exclusion bits.
  final Map<String, int> schoolByKit;

  /// Text from the talk table, by strref. Empty until it has been resolved.
  ///
  /// Merged in rather than read here, because reaching the talk table means
  /// reaching a second repository and repositories must never be aware of each
  /// other — `loadCreationCatalogue` is where the two meet.
  final Map<int, String> textByStrref;

  /// The text for [strref], or `null` — for no strref, or no talk table.
  ///
  /// `null` is an ordinary answer. On a machine with no game installed there
  /// is no text at all, and a choice with no description is better than a
  /// screen that will not draw.
  String? textFor(int? strref) => strref == null ? null : textByStrref[strref];

  /// What the game calls alignment [id], or `null` with no talk table.
  ///
  /// ⚠️ **Read, never derived.** `ALIGNMEN.IDS` calls true neutral `NEUTRAL`
  /// and the game calls it **"True Neutral"**, so prettifying the identifier
  /// gives our wording rather than the engine's — and only in English. See
  /// [alignmentNameStrrefs] for why the pairing is written out.
  ///
  /// `null` is an ordinary answer on a machine with no game installed, and the
  /// caller falls back to the derived name.
  String? alignmentName(int id) => textFor(alignmentNameStrrefs[id]);

  /// Alignment [id] as a choice, so the step can be drawn like its neighbours.
  ///
  /// ⚠️ **The alignment step was the only one with no description**, where
  /// race, class and specialisation all show the game's own paragraph beside
  /// the list. Expressing an alignment as a [CreationChoice] is what lets it
  /// use the same widget rather than a second, thinner one.
  ///
  /// The identifier comes from `ALIGNMEN.IDS` and is a join key, never shown —
  /// it calls true neutral `NEUTRAL` where the game says "True Neutral".
  CreationChoice alignmentChoice(int id) => CreationChoice(
    value: id,
    identifier: alignmentIdentifiers[id] ?? '$id',
    nameStrref: alignmentNameStrrefs[id],
    descriptionStrref: alignmentDescriptionStrrefs[id],
  );

  /// This catalogue with [text] resolved against it.
  CreationCatalogue withText(Map<int, String> text) =>
      copyWith(textByStrref: text);

  /// The classes [raceId] may take, or empty if nothing was read.
  List<CreationChoice> classesFor(int raceId) =>
      classesByRace[raceId] ?? const [];

  /// The specialisations [classId] offers, or empty — which is the answer for
  /// every multi-class.
  List<CreationChoice> kitsFor(int classId) => kitsByClass[classId] ?? const [];

  /// The alignments this character may hold.
  ///
  /// ⚠️ **A kit governs where it has a row, not its class.** A Fighter may be
  /// any alignment and a Kensai may not be chaotic, so asking before the
  /// specialisation is chosen gives the wrong answer — which is why that step
  /// comes first.
  List<int> alignmentsFor({
    required CreationChoice characterClass,
    CreationChoice? kit,
  }) =>
      alignmentsByRow[kit?.identifier] ??
      alignmentsByRow[characterClass.identifier] ??
      const [];

  /// What [raceId] adds to and takes from the ability scores, zeroes dropped.
  Map<String, int> abilityAdjustmentsFor(int raceId) =>
      adjustmentsByRace[raceId] ?? const {};

  /// How many proficiency pips [characterClass] has to spend at first level.
  ///
  /// `0` when the table names no such class, which is the honest answer on a
  /// machine with no installation — and better than a plausible default that
  /// silently gives a Mage a Fighter's four.
  ///
  /// Takes the identifier rather than a [CreationChoice] because the
  /// identifier **is** the table's key; a caller holding a choice passes
  /// `choice.identifier`.
  ///
  /// ⚠️ **Kits are absent from `profs.2da`**, so a Kensai gets its Fighter
  /// row. That is the table's own shape, not a fallback this code invented.
  /// How many thief-skill points [characterClass] has to spend, or `0`.
  int thiefSkillPointsFor(String characterClass) =>
      thiefSkillPointsByClass[characterClass] ?? 0;

  /// The thief skills [characterClass] may put them into, in table order.
  ///
  /// Empty for a class the table gives nothing, which is what makes the step
  /// disappear rather than draw an empty screen.
  List<String> thiefSkillsFor(String characterClass) => [
    for (final row in skills.allowanceByRow.keys)
      if ((skills.allowanceFor(row, characterClass) ?? 0) > 0) row,
  ];

  /// How many proficiency pips [characterClass] has to spend. `profs.2da`.
  int proficiencySlotsFor(String characterClass) =>
      proficiencySlotsByClass[characterClass] ?? 0;

  /// The most pips [characterClass] may put in any one proficiency.
  int proficiencyRankCapFor(String characterClass) =>
      proficiencyRankCapsByClass[characterClass] ?? 0;

  /// How many first-level wizard spells [characterClass] may memorise.
  ///
  /// ⚠️ **D13 — the join is a rule in code, and it had to be.** `hpclass.2da`
  /// names the hit-die table for every class; nothing in the installation does
  /// the same for the ten `mxspl*` progressions. So which table a class uses is
  /// decided here, from its `CLASS.IDS` identifier: `SORCERER` uses
  /// `mxsplsrc`, `BARD` uses `mxsplbrd`, and anything containing `MAGE` uses
  /// `mxsplwiz`.
  ///
  /// `0` for a class that casts none, which includes a **bard** — `mxsplbrd`
  /// has no first-level row at all, so that answer comes from the table rather
  /// than from the rule above.
  int spellsMemorisableFor(String characterClass) => switch (characterClass) {
    _sorcerer => sorcererSpellsMemorisable,
    _bard => bardSpellsMemorisable,
    _ when characterClass.split('_').contains(_mage) => wizardSpellsMemorisable,
    _ => 0,
  };

  /// How many first-level wizard spells [characterClass] may learn.
  ///
  /// A sorcerer's is `splsrckn.2da`; everyone else's is
  /// [wizardSpellsLearnable], which no table carries.
  int spellsLearnableFor(String characterClass) => switch (characterClass) {
    _sorcerer => sorcererSpellsKnown,
    _ when spellsMemorisableFor(characterClass) > 0 => wizardSpellsLearnable,
    _ => 0,
  };

  /// Whether [characterClass] puts spells in a book at first level.
  ///
  /// Asked of the tables rather than of a list of class names: a class casts
  /// spells exactly when a progression says how many, which is what keeps a
  /// bard's empty first level from needing a special case.
  bool castsWizardSpells(String characterClass) =>
      spellsMemorisableFor(characterClass) > 0 &&
      spellsLearnableFor(characterClass) > 0;

  /// The range [ability] may be rolled into for this character.
  ///
  /// Three tables compose, and the composition is exactly what the game prints
  /// beside each ability. An elf's Dexterity is `abracerq`'s 6–18 plus
  /// `abracead`'s +1, which is the **7 to 19** on the engine's own screen; the
  /// floor then rises to whichever of the race's and the class's is higher.
  ///
  /// ⚠️ **[kit] governs where it has a row, not its class** — the same
  /// precedence [alignmentsFor] uses, and for the same reason: an Abjurer's
  /// Wisdom 15 has nothing to do with what a Mage needs.
  ///
  /// With no installation there is no table to read, so this falls back to what
  /// the *field* can hold. A screen that cannot say what the game allows is
  /// better than one that invents it.
  ({int minimum, int maximum}) abilityBoundsFor({
    required int raceId,
    required String characterClass,
    required CreationAbility ability,
    String? kit,
  }) {
    final race = abilityMinimaByRace[raceId];
    if (race == null) {
      return (
        minimum: ability.stat.minimum,
        maximum: ability.stat.maximum,
      );
    }

    final adjustment =
        adjustmentsByRace[raceId]?[ability.adjustmentColumn] ?? 0;
    final fromClass =
        abilityMinimaByRow[kit]?[ability.key] ??
        abilityMinimaByRow[characterClass]?[ability.key] ??
        0;
    // ⚠️ **The adjustment applies to the race's floor and not to the class's**,
    // because a class requirement is stated about the score the character ends
    // up with — which is the adjusted one, and the one the record stores.
    //
    // ⚠️ **Open, and the two readings differ by exactly one character.** Every
    // case the engine's own screens show agrees either way: an elf's Dexterity
    // is 7 and its Intelligence 9 whichever order the maximum and the addition
    // are taken in. **A Gnome Mage separates them** — `abracerq` floors a
    // gnome's Intelligence at 6, `abracead` adds 1 and `abclasrq` asks a Mage
    // for 9, so this says 9 and taking the maximum first would say 10. The
    // reading here is the one that cannot forbid a character the game allows.
    final fromRace = (race[ability.key] ?? 0) + adjustment;

    return (
      minimum: fromRace > fromClass ? fromRace : fromClass,
      maximum: (abilityMaximaByRace[raceId]?[ability.key] ?? 0) + adjustment,
    );
  }
}

/// `alignmnt.2da`'s column headers, as `ALIGNMEN.IDS` numbers.
///
/// ⚠️ **D13 — glue between two vocabularies, which no third table reconciles.**
/// `alignmnt.2da` heads its columns `L_G`…`C_E` and `ALIGNMEN.IDS` numbers
/// `LAWFUL_GOOD`…`CHAOTIC_EVIL`; nothing in the installation joins them.
///
/// ⚠️ **Written out rather than derived, because one entry defeats the rule an
/// initials scheme would use.** Eight of the nine are the first letters of the
/// two words — `LAWFUL_GOOD` is `L_G` — but `ALIGNMEN.IDS` calls true neutral
/// simply `NEUTRAL`, one word, where the column is `N_N`. A clever mapping gets
/// eight right and silently loses the ninth.
const Map<String, int> alignmentByColumn = {
  'L_G': 0x11,
  'L_N': 0x12,
  'L_E': 0x13,
  'N_G': 0x21,
  'N_N': 0x22,
  'N_E': 0x23,
  'C_G': 0x31,
  'C_N': 0x32,
  'C_E': 0x33,
};

/// Each alignment's name in the player's talk table, by `ALIGNMEN.IDS` number.
///
/// ⚠️ **D13 — no table pairs these, and every candidate was opened.** There is
/// exactly one file matching `align` in the installation and it is
/// `alignmnt.2da`, which says which alignments a class may take and carries no
/// names at all. The strings are real and the game ships each of them twice —
/// 1102–1110 and 7183–7191 — so the pairing is written out here rather than
/// looked up.
///
/// ⚠️ **Why not derive the names from the identifiers.** `ALIGNMEN.IDS` calls
/// true neutral simply `NEUTRAL`, and the game calls it **"True Neutral"** —
/// so prettifying an identifier produces our wording rather than the engine's.
/// It is also English-only, where these follow whatever language the player
/// installed.
const Map<int, int> alignmentNameStrrefs = {
  0x11: 1102,
  0x12: 1104,
  0x13: 1103,
  0x21: 1105,
  0x22: 1106,
  0x23: 1107,
  0x31: 1108,
  0x32: 1109,
  0x33: 1110,
};

/// Each alignment's description in the talk table, by `ALIGNMEN.IDS` number.
///
/// The paragraph the game shows beside the list once one is picked — *"NEUTRAL
/// GOOD: These characters believe that a balance of forces is important…"*. See
/// `docs/findings/screens/char-create/12-alignment-neutral-good.png`.
///
/// ⚠️ **Same D13 position as [alignmentNameStrrefs]**: `alignmnt.2da` is the
/// only alignment file in the installation and carries no text at all, so the
/// pairing is written out. Found by scanning the player's own talk table for
/// the nine paragraphs; 9606 matches the engine's screen word for word.
const Map<int, int> alignmentDescriptionStrrefs = {
  0x11: 9603,
  0x12: 9604,
  0x13: 9605,
  0x21: 9606,
  0x22: 9608,
  0x23: 9607,
  0x31: 9609,
  0x32: 9610,
  0x33: 9611,
};

/// Orders alignments the way the game's own screen does.
///
/// **Grouped by the moral axis, then the legal one**: Lawful Good, Neutral
/// Good, Chaotic Good, then the three neutrals, then the three evils. See
/// `docs/findings/screens/char-create/11-alignment-list.png`.
///
/// ⚠️ **D13 — the order is in no table, and this is not an invented one.**
/// `alignmnt.2da`'s columns run `L_G, L_N, L_E, N_G…`, which is the legal axis
/// first and is a data layout rather than a presentation; building the list in
/// that order is what put the wrong sequence on screen. Neither strref block
/// is in display order either — 1102–1110 runs Lawful Good, Lawful *Evil*,
/// Lawful *Neutral*.
///
/// What justifies the decomposition is `ALIGNMEN.IDS` itself, which names both
/// axes: `MASK_GOOD` 0x01, `MASK_GENEUTRAL` 0x02 and `MASK_EVIL` 0x03 are the
/// low nibble, and `MASK_LAWFUL` 0x10, `MASK_LCNEUTRAL` 0x20 and
/// `MASK_CHAOTIC` 0x30 the high one. Sorting by moral-then-legal is the game's
/// own division of its own numbering.
int compareAlignmentsForDisplay(int a, int b) {
  final moral = (a & 0x0F).compareTo(b & 0x0F);
  return moral != 0 ? moral : (a & 0xF0).compareTo(b & 0xF0);
}

/// The `clastext.2da` `KITID` of a row describing a plain class.
///
/// `0x4000`, which is `KIT.IDS`'s `TRUECLASS`. It is the only thing telling a
/// class row from a kit row that shares its `CLASSID` — `KENSAI` and `FIGHTER`
/// are both `CLASSID` 2, and reading the wrong one describes a Fighter as a
/// Kensai.
const int trueClassKitId = 0x4000;

/// Kits whose stored dword this build refuses to write.
///
/// ⚠️ **The encoding is not uniform.** Most kits store `KITIDS` shifted left 16
/// — measured, not derived: Xzar is a Necromancer and his record holds
/// `0x10000000` where `kitlist.2da` gives `NECROMANCER` a `KITIDS` of `0x1000`.
/// But Barbarian is `0x40000000` and Wild Mage `0x80000000`, which cannot be
/// shifted at all, and Barbarian unshifted is **indistinguishable from
/// `TRUECLASS` shifted** — the value a character with no kit carries.
///
/// Rather than guess a byte into someone's save, those two are left out until
/// one is made in the game and the four bytes at `0x244` are read.
const int highestShiftableKitId = 0xFFFF;

/// Projects the game's own tables into what a creation flow may offer.
///
/// Every argument is a `2DA` from the **player's installation**, because a
/// modded game's answers are its own (D11). An unreadable table yields an empty
/// answer rather than an exception: a machine with no game on it can still open
/// the app, it simply cannot make a character.
CreationCatalogue creationCatalogueFrom({
  required Table2da classRaceRequirements,
  required Table2da alignmentRequirements,
  required Table2da kits,
  required Table2da classText,
  required Table2da raceText,
  required Table2da racialAdjustments,
  required Table2da proficiencySlots,
  required Table2da proficiencyRankCaps,
  required Table2da wizardMemorisation,
  required Table2da sorcererMemorisation,
  required Table2da sorcererKnownSpells,
  required Table2da bardMemorisation,
  required Table2da raceAbilityRequirements,
  required Table2da classAbilityRequirements,
  required Table2da thiefSkillPoints,
  required Table2da thiefSkillClasses,
  required Table2da magicSchools,
  required List<SpellChoice> wizardSpells,
  required ProficiencyCatalogue proficiencies,
  required GameRules rules,
}) {
  final descriptionByRaceId = _raceDescriptions(raceText);
  final descriptionByClassId = _classDescriptions(classText);

  // ⚠️ The playable races *are* this table's columns. Hardcoding seven would
  // be a guess about an installation we have not read.
  final races = <CreationChoice>[];
  final raceIdByColumn = <String, int>{};
  for (final column in classRaceRequirements.columns) {
    final id = rules.raceIdFor(column);
    if (id == null) continue;
    raceIdByColumn[column] = id;
    races.add(
      CreationChoice(
        value: id,
        identifier: column,
        descriptionStrref: descriptionByRaceId[id],
      ),
    );
  }

  final classesByRace = <int, List<CreationChoice>>{};
  for (final MapEntry(key: column, value: raceId) in raceIdByColumn.entries) {
    final available = <CreationChoice>[];
    for (final MapEntry(key: row, value: _)
        in classRaceRequirements.rows.entries) {
      // A row that is not in CLASS.IDS is a kit — `clsrcreq` lists 40 of them
      // alongside the classes — and drops out here without being named.
      final classId = rules.classIdFor(row);
      if (classId == null) continue;
      if (classRaceRequirements.number(row, column) != 1) continue;
      available.add(
        CreationChoice(
          value: classId,
          identifier: row,
          descriptionStrref: descriptionByClassId[classId],
        ),
      );
    }
    if (available.isNotEmpty) classesByRace[raceId] = available;
  }

  final kitsByClass = <int, List<CreationChoice>>{};
  for (final row in kits.rows.keys) {
    final name = kits.cell(row, 'ROWNAME');
    final classId = kits.number(row, 'CLASS');
    final stored = _kitDword(kits.cell(row, 'KITIDS'));
    if (name == null || classId == null || stored == null) continue;
    (kitsByClass[classId] ??= <CreationChoice>[]).add(
      CreationChoice(
        value: stored,
        identifier: name,
        nameStrref: kits.number(row, 'MIXED'),
        descriptionStrref: kits.number(row, 'HELP'),
      ),
    );
  }

  final alignmentsByRow = <String, List<int>>{};
  for (final row in alignmentRequirements.rows.keys) {
    // ⚠️ Sorted, because `alignmentByColumn` follows the table's own column
    // order and that is the legal axis first -- a data layout, not the order
    // the game puts on screen. See [compareAlignmentsForDisplay].
    final allowed = [
      for (final MapEntry(key: column, value: id) in alignmentByColumn.entries)
        if (alignmentRequirements.number(row, column) == 1) id,
    ]..sort(compareAlignmentsForDisplay);
    if (allowed.isNotEmpty) alignmentsByRow[row] = allowed;
  }

  final adjustmentsByRace = <int, Map<String, int>>{};
  for (final row in racialAdjustments.rows.keys) {
    final raceId = rules.raceIdFor(row);
    if (raceId == null) continue;
    final adjustments = {
      for (final column in racialAdjustments.columns)
        if ((racialAdjustments.number(row, column) ?? 0) != 0)
          column: racialAdjustments.number(row, column)!,
    };
    if (adjustments.isNotEmpty) adjustmentsByRace[raceId] = adjustments;
  }

  final abilityMinimaByRace = <int, Map<String, int>>{};
  final abilityMaximaByRace = <int, Map<String, int>>{};
  for (final row in raceAbilityRequirements.rows.keys) {
    final raceId = rules.raceIdFor(row);
    if (raceId == null) continue;
    abilityMinimaByRace[raceId] = _abilityColumn(
      raceAbilityRequirements,
      row,
      (a) => a.minimumColumn,
    );
    abilityMaximaByRace[raceId] = _abilityColumn(
      raceAbilityRequirements,
      row,
      (a) => a.maximumColumn,
    );
  }

  return CreationCatalogue(
    races: races,
    classesByRace: classesByRace,
    kitsByClass: kitsByClass,
    alignmentsByRow: alignmentsByRow,
    adjustmentsByRace: adjustmentsByRace,
    proficiencySlotsByClass: _firstLevelColumn(proficiencySlots),
    proficiencyRankCapsByClass: _firstLevelColumn(proficiencyRankCaps),
    abilityMinimaByRow: {
      for (final row in classAbilityRequirements.rows.keys)
        row: _abilityColumn(
          classAbilityRequirements,
          row,
          (a) => a.minimumColumn,
        ),
    },
    abilityMinimaByRace: abilityMinimaByRace,
    abilityMaximaByRace: abilityMaximaByRace,
    wizardSpells: wizardSpells,
    // Row 1, column 1: a first-level caster and a first-level spell. The rest
    // of the table is levelling, which creation never reaches.
    //
    // ⚠️ **A bard's `mxsplbrd.2da` has no row 1**, so this reads `null` and
    // becomes zero — which is the table saying a first-level bard casts
    // nothing, not a lookup that failed.
    wizardSpellsMemorisable: wizardMemorisation.number('1', '1') ?? 0,
    sorcererSpellsMemorisable: sorcererMemorisation.number('1', '1') ?? 0,
    sorcererSpellsKnown: sorcererKnownSpells.number('1', '1') ?? 0,
    bardSpellsMemorisable: bardMemorisation.number('1', '1') ?? 0,
    proficiencies: proficiencies,
    skills: thiefSkillsFrom(thiefSkillClasses),
    // The row's index is the school number. `rows` is insertion-ordered, so
    // walking it in file order is what makes the position meaningful.
    schoolByKit: {
      for (final (index, row) in magicSchools.rows.keys.indexed)
        if (index > 0) row.toUpperCase(): index,
    },
    // ⚠️ `START_POINTS`, not `LEVEL_POINTS`. The second column is what each
    // level after the first grants, and creation never reaches it.
    thiefSkillPointsByClass: {
      for (final row in thiefSkillPoints.rows.keys)
        if (thiefSkillPoints.number(row, TableColumn.startPoints.header)
            case final int points)
          if (points > 0) row: points,
    },
  );
}

/// `CLASS.IDS` identifiers the spell progressions are keyed on.
///
/// Written out because no table joins a class to its `mxspl*` file — see
/// [CreationCatalogue.spellsMemorisableFor].
const String _mage = 'MAGE';
const String _sorcerer = 'SORCERER';
const String _bard = 'BARD';

/// `FIRST_LEVEL` of every row of [table], as a map by row label.
///
/// Serves `profs.2da` and `profsmax.2da`, which share the column and answer
/// different questions with it — slots in one, a rank cap in the other.
Map<String, int> _firstLevelColumn(Table2da table) => {
  for (final row in table.rows.keys)
    if (table.number(row, TableColumn.firstLevel.header) case final int value)
      row: value,
};

/// One column family of [row], keyed by [CreationAbility.key].
///
/// [column] picks which of the three spellings the table uses — `MIN_STR`,
/// `MAX_STR` or `MOD_STR` — from the ability itself, so the six names are
/// never written out.
Map<String, int> _abilityColumn(
  Table2da table,
  String row,
  String Function(CreationAbility) column,
) => {
  for (final ability in CreationAbility.values)
    if (table.number(row, column(ability)) case final int value)
      ability.key: value,
};

/// Description strrefs by `RACE.IDS` id.
///
/// ⚠️ **Keyed on the table's own `ID` column, never on its row label.**
/// `racetext.2da` labels the seventh race `HALF_ORC` where `RACE.IDS` — and
/// `clsrcreq.2da`'s column, and `abracead.2da`'s row — all say `HALFORC`. A
/// label join silently loses exactly one race, which is the shape of bug
/// `weapprof.2da` already produced once.
Map<int, int> _raceDescriptions(Table2da raceText) => {
  for (final row in raceText.rows.keys)
    if (raceText.number(row, 'ID') case final int id)
      if (raceText.number(row, 'DESCSTR') case final int strref)
        if (strref >= 0) id: strref,
};

/// Description strrefs by `CLASS.IDS` id, taking only the plain-class rows.
Map<int, int> _classDescriptions(Table2da classText) => {
  for (final row in classText.rows.keys)
    // The same FALLEN filter the names need — see `nameStrrefs`.
    if (classText.number(row, TableColumn.fallen.header) != fallenClass)
      if (classText.number(row, 'KITID') == trueClassKitId)
        if (classText.number(row, 'CLASSID') case final int id)
          if (classText.number(row, 'DESCSTR') case final int strref)
            if (strref >= 0) id: strref,
};

/// The dword a kit is stored as, or `null` if this build will not write it.
int? _kitDword(String? kitIds) {
  if (kitIds == null || !kitIds.startsWith('0x')) return null;
  final key = int.tryParse(kitIds.substring(2), radix: 16);
  if (key == null || key == 0 || key > highestShiftableKitId) return null;
  return key << 16;
}
