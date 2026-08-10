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
import 'package:wand_of_saves/domain/rules/game_rules.dart';

part 'creation_catalogue.mapper.dart';

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

  /// Every playable race, in the order `clsrcreq.2da` lists its columns.
  final List<CreationChoice> races;

  /// Classes by `RACE.IDS` id.
  final Map<int, List<CreationChoice>> classesByRace;

  /// Specialisations by `CLASS.IDS` id. Absent for a class that has none.
  final Map<int, List<CreationChoice>> kitsByClass;

  /// Allowed alignments by `alignmnt.2da` row — a class *or* a kit.
  final Map<String, List<int>> alignmentsByRow;

  /// Racial ability adjustments by `RACE.IDS` id, zeroes dropped.
  final Map<int, Map<String, int>> adjustmentsByRace;

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
    final allowed = [
      for (final MapEntry(key: column, value: id) in alignmentByColumn.entries)
        if (alignmentRequirements.number(row, column) == 1) id,
    ];
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

  return CreationCatalogue(
    races: races,
    classesByRace: classesByRace,
    kitsByClass: kitsByClass,
    alignmentsByRow: alignmentsByRow,
    adjustmentsByRace: adjustmentsByRace,
  );
}

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
