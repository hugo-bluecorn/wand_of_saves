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

/// The column headers this application asks rules tables for.
///
/// The companion to `GameTable`, and the half with the sharper edge. A wrong
/// *table* usually returns nothing; a wrong **column of the right shape**
/// returns a number. `profs.2da` and `profsmax.2da` both carry `FIRST_LEVEL`,
/// which is why reading one where the other was meant produced a proficiency
/// rule that was wrong and silent.
///
/// So each value names the tables it belongs to, and
/// `table_columns_test.dart` checks that claim against the player's own files.
/// Two constants collapse into one value here: `START_POINTS` and `MIXED` were
/// each declared twice, in different layers, with nothing to say they were the
/// same column.
///
/// ⚠️ **The seven thief-skill names are deliberately NOT here**, though they
/// are column headers in `skilldex` and `skillrac`. They are a *skill*
/// vocabulary rather than a column one — the same seven names are **row**
/// labels in `thiefscl` — and they already have a home on
/// `CharacterStat.thiefSkillRow`. Adding them would be a second spelling of a
/// vocabulary that already exists, which is the duplication this file removes.
/// Unifying `GameRules`' three private copies with `CharacterStat`'s is worth
/// doing and is its own change.
library;

import 'package:wand_of_saves/domain/rules/game_tables.dart';

/// A column header, and the tables that carry it.
enum TableColumn {
  /// `FIRST_LEVEL` — what a first-level character gets.
  ///
  /// ⚠️ **In both proficiency tables, meaning different things.** In
  /// [GameTable.proficiencySlots] it is how many pips there are to spend; in
  /// [GameTable.proficiencyRankCap] it is how many may go into any one. That
  /// this column exists in both is exactly why the pair is dangerous.
  firstLevel('FIRST_LEVEL', [
    GameTable.proficiencySlots,
    GameTable.proficiencyRankCap,
  ]),

  /// `RATE` — a per-level rate.
  ///
  /// Lore per level in [GameTable.loreRate]; one further proficiency slot
  /// every so many levels in [GameTable.proficiencySlots].
  rate('RATE', [GameTable.loreRate, GameTable.proficiencySlots]),

  /// `START_POINTS` — the thief-skill points a first-level character spends.
  ///
  /// **Was declared twice**, once in the creation catalogue and once in the
  /// rules, with nothing connecting them.
  startPoints('START_POINTS', [GameTable.thiefSkillPoints]),

  /// `VALUE` — [GameTable.loreBonus]'s only column.
  value('VALUE', [GameTable.loreBonus]),

  /// `TO_HIT` — what Strength takes off THAC0.
  ///
  /// Positive is an improvement, because THAC0 runs downwards.
  toHit('TO_HIT', [
    GameTable.strengthModifiers,
    GameTable.exceptionalStrengthModifiers,
  ]),

  /// `LEARN_SPELL` — the percentage chance Intelligence gives.
  learnSpell('LEARN_SPELL', [GameTable.intelligenceModifiers]),

  /// `TABLE` — the resref of the hit-die table a class uses.
  ///
  /// ⚠️ **Holds a resref, not a number and not a strref.** The tables it names
  /// are data, which is why they are not `GameTable` values.
  hitDieTable('TABLE', [GameTable.hitDieTableByClass]),

  /// `UPPERCASE` — the race name strref the app shows.
  raceName('UPPERCASE', [GameTable.raceText]),

  /// `MIXED` — the mixed-case name strref, for a class and for a kit alike.
  ///
  /// **Was declared twice**, as `classNameColumn` and `kitNameColumn`, with
  /// identical values and no sign they were one column.
  ///
  /// ⚠️ In [GameTable.classText] the string it names is a **template**:
  /// `FIGHTER` resolves to `<FIGHTERTYPE>`.
  mixedCaseName('MIXED', [GameTable.classText, GameTable.kits]),

  /// `FALLEN` — what tells `FALLEN_CLERIC` from `CLERIC`.
  ///
  /// ⚠️ Those two rows share a `CLASSID` and a "no kit" marker, so without this
  /// column a last-wins map puts "Fallen Cleric" on the class screen. It did.
  fallen('FALLEN', [GameTable.classText]),

  /// `ID` — the number opcode 233 stores for a proficiency.
  ///
  /// ⚠️ **The key, in place of the row label**, which is not unique: BG:EE
  /// labels two rows `AXE` and two `SPEAR`.
  proficiencyId('ID', [GameTable.weaponProficiencies]),

  /// `NAME_REF` — a proficiency's name, as a strref.
  proficiencyName('NAME_REF', [GameTable.weaponProficiencies]),

  /// `DESC_REF` — a proficiency's description, as a strref.
  proficiencyDescription('DESC_REF', [GameTable.weaponProficiencies]);

  const TableColumn(this.header, this.inTables);

  /// The header exactly as the file spells it — always uppercase.
  final String header;

  /// Every table this application reads this column from.
  ///
  /// Not every table that happens to have a column of this name: `racetext`
  /// also has an `ID`, and the app does not ask it for one. This records where
  /// the dependency is, so the test checks a claim the code actually makes.
  final List<GameTable> inTables;
}
