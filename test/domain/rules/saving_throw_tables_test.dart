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

/// The saving-throw tables, and how a multi-class composes them.
///
/// Every number here is copied out of the player's own `savewar.2da` and
/// `savewiz.2da` — dumped with `tool/dev/dump_table.dart` — so the expectations
/// are the game's data rather than this project's arithmetic.
///
/// ⚠️ **The composition rule is a hypothesis in this file and a measurement in
/// `saving_throw_oracle_test.dart`.** Aurel, the character BG:EE itself built,
/// cannot separate "best of each class" from "the caster's table wins": at
/// level 1 the warrior table is worse in all five categories, so every
/// multi-class holding a fighter gives the other table's row either way.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/domain/rules/game_tables.dart';
import 'package:wand_of_saves/domain/rules/saving_throw_tables.dart';

void main() {
  // Level 1 through 3 of each, verbatim from the installation.
  const tables = SavingThrowTables(
    rowsByTable: {
      'SAVEWAR': {
        'DEATH': [14, 14, 13],
        'WANDS': [16, 16, 15],
        'POLY': [15, 15, 14],
        'BREATH': [17, 17, 16],
        'SPELL': [17, 17, 16],
      },
      'SAVEWIZ': {
        'DEATH': [14, 14, 14],
        'WANDS': [11, 11, 11],
        'POLY': [13, 13, 13],
        'BREATH': [15, 15, 15],
        'SPELL': [12, 12, 12],
      },
      'SAVEPRS': {
        'DEATH': [10, 10, 10],
        'WANDS': [14, 14, 14],
        'POLY': [13, 13, 13],
        'BREATH': [16, 16, 16],
        'SPELL': [15, 15, 15],
      },
      'SAVEROG': {
        'DEATH': [13, 13, 13],
        'WANDS': [14, 14, 14],
        'POLY': [12, 12, 12],
        'BREATH': [16, 16, 16],
        'SPELL': [15, 15, 15],
      },
      // ⚠️ The racial Constitution bonuses, keyed by Constitution rather than
      // by level. Columns 11, 12 and 16 of the installation's own files.
      'SAVECNDH': {
        'DEATH': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 4, 4, 4],
        'WANDS': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 4, 4, 4],
        'POLY': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        'BREATH': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        'SPELL': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 4, 4, 4],
      },
      // ⚠️ The gnome's DEATH row is **all zeros**, where the dwarf and halfling
      // get the bonus there too. That difference is the whole reason there are
      // two tables, and it is what Quayle's record proves.
      'SAVECNG': {
        'DEATH': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        'WANDS': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 4, 4, 4],
        'POLY': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        'BREATH': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        'SPELL': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 4, 4, 4],
      },
    },
  );

  const rules = GeneratedGameRules(savingThrows: tables);

  group('SavingThrowTables', () {
    test('reads one table at one level', () {
      final row = tables.at(table: GameTable.savesWizard, level: 1);

      expect(row?.death, 14);
      expect(row?.wands, 11);
      expect(row?.polymorph, 13);
      expect(row?.breath, 15);
      expect(row?.spells, 12);
    });

    test('a level past the end of the table takes the last row', () {
      // The engine's own tables run to 40 and repeat their tail; a character
      // beyond the rows is not a reason to answer nothing.
      expect(tables.at(table: GameTable.savesWarrior, level: 99)?.death, 13);
    });

    test('a level below one has no answer rather than a made-up one', () {
      expect(tables.at(table: GameTable.savesWarrior, level: 0), isNull);
    });

    test('a table that was never read has no answer', () {
      // ⚠️ **This used to say "an unknown table", spelled `SAVEBARD`.** Naming
      // a table that does not exist stopped being possible when the lookup
      // took a [GameTable] instead of a string — which is the whole point of
      // the change. What is still worth asserting, and is what this always
      // really covered, is the ordinary case behind it: a real table the
      // installation did not supply answers `null` rather than a zero.
      // `savemonk` is the one this fixture deliberately leaves out.
      expect(tables.at(table: GameTable.savesMonk, level: 1), isNull);
    });
  });

  group('which table a class uses', () {
    test('the four groups map to their own tables', () {
      expect(rules.savingThrowTableFor('FIGHTER'), GameTable.savesWarrior);
      expect(rules.savingThrowTableFor('PALADIN'), GameTable.savesWarrior);
      expect(rules.savingThrowTableFor('RANGER'), GameTable.savesWarrior);
      expect(rules.savingThrowTableFor('MAGE'), GameTable.savesWizard);
      expect(rules.savingThrowTableFor('SORCERER'), GameTable.savesWizard);
      expect(rules.savingThrowTableFor('CLERIC'), GameTable.savesPriest);
      expect(rules.savingThrowTableFor('DRUID'), GameTable.savesPriest);
      expect(rules.savingThrowTableFor('THIEF'), GameTable.savesRogue);
      expect(rules.savingThrowTableFor('BARD'), GameTable.savesRogue);
      expect(rules.savingThrowTableFor('MONK'), GameTable.savesMonk);
    });

    test('a class nothing names has no table', () {
      expect(rules.savingThrowTableFor('ANKHEG'), isNull);
    });
  });

  group('savingThrowsFor', () {
    test('a single class is its own table, verbatim', () {
      // Aurel's five, as BG:EE wrote them for a level-1 mage.
      final saves = rules.savingThrowsFor(
        classIdentifier: 'MAGE',
        levels: const [1],
      );

      expect(saves?.death, 14);
      expect(saves?.wands, 11);
      expect(saves?.polymorph, 13);
      expect(saves?.breath, 15);
      expect(saves?.spells, 12);
    });

    test('a fighter/mage at 1/1 is the wizard row — and that is ambiguous', () {
      // ⚠️ The measurement this project has. It is consistent with best-of-each
      // *and* with the caster's table winning, because savewar is worse in all
      // five at level 1. See saving_throw_oracle_test.dart.
      final saves = rules.savingThrowsFor(
        classIdentifier: 'FIGHTER_MAGE',
        levels: const [1, 1],
      );

      expect(saves?.death, 14);
      expect(saves?.wands, 11);
      expect(saves?.polymorph, 13);
      expect(saves?.breath, 15);
      expect(saves?.spells, 12);
    });

    test('a cleric/mage takes the better of each column, from both tables', () {
      // The separating case, and the reason it matters: this row exists in
      // neither table. Death comes from the priest, the other four from the
      // wizard.
      final saves = rules.savingThrowsFor(
        classIdentifier: 'CLERIC_MAGE',
        levels: const [1, 1],
      );

      expect(saves?.death, 10, reason: 'saveprs beats savewiz');
      expect(saves?.wands, 11, reason: 'savewiz beats saveprs');
      expect(saves?.polymorph, 13, reason: 'the two agree');
      expect(saves?.breath, 15, reason: 'savewiz beats saveprs');
      expect(saves?.spells, 12, reason: 'savewiz beats saveprs');
    });

    test('each class is read at its own level, not at the highest', () {
      // A Fighter 3 / Mage 1 asks savewar for level 3 and savewiz for level 1.
      // Only DEATH can show it: savewar drops to 13 there and savewiz stays 14.
      final saves = rules.savingThrowsFor(
        classIdentifier: 'FIGHTER_MAGE',
        levels: const [3, 1],
      );

      expect(saves?.death, 13);
    });

    test('a class the tables cannot name has no answer', () {
      expect(
        rules.savingThrowsFor(classIdentifier: 'ANKHEG', levels: const [1]),
        isNull,
      );
    });

    test('a name and a level count that disagree have no answer', () {
      // The same refusal maximumRolledHitPoints already makes: inventing a
      // level for a class the record does not carry one for is worse than
      // saying nothing.
      expect(
        rules.savingThrowsFor(
          classIdentifier: 'FIGHTER_MAGE',
          levels: const [1],
        ),
        isNull,
      );
    });

    test('a dwarf or halfling improves death, wands and spells', () {
      // ⚠️ Measured against KAGAIN and ALORA, the game's own records. A
      // derivation without this is up to five points too high on three of the
      // five saves for every dwarf, gnome and halfling in the game.
      final saves = rules.savingThrowsFor(
        classIdentifier: 'THIEF',
        levels: const [1],
        raceIdentifier: 'HALFLING',
        constitution: 12,
      );

      expect(saves?.death, 10, reason: '13 less the table’s 3');
      expect(saves?.wands, 11, reason: '14 less 3');
      expect(saves?.polymorph, 12, reason: 'no polymorph bonus in the table');
      expect(saves?.breath, 16, reason: 'nor any breath bonus');
      expect(saves?.spells, 12, reason: '15 less 3');
    });

    test('a gnome improves wands and spells but NOT death', () {
      // Quayle's record is what separates the two tables. A gnome takes the
      // priest's death save unmodified where a halfling would improve it.
      final saves = rules.savingThrowsFor(
        classIdentifier: 'CLERIC_MAGE',
        levels: const [2, 2],
        raceIdentifier: 'GNOME',
        constitution: 11,
      );

      expect(saves?.death, 10, reason: 'savecng’s DEATH row is all zeros');
      expect(saves?.wands, 8, reason: '11 less 3');
      expect(saves?.spells, 9, reason: '12 less 3');
    });

    test('a race with no table of its own takes no bonus', () {
      final human = rules.savingThrowsFor(
        classIdentifier: 'THIEF',
        levels: const [1],
        raceIdentifier: 'HUMAN',
        constitution: 25,
      );

      expect(human?.death, 13);
      expect(human?.wands, 14);
    });

    test('a bonus past the end of the table takes the last column', () {
      // The tables stop at Constitution 25, which is also where the field
      // does; a character beyond it is not a reason to lose the bonus.
      final saves = rules.savingThrowsFor(
        classIdentifier: 'THIEF',
        levels: const [1],
        raceIdentifier: 'DWARF',
        constitution: 99,
      );

      expect(saves?.death, 9, reason: '13 less the last column’s 4');
    });

    test('with no installation there is no answer at all', () {
      // No written-out fallback, unlike the hit dice. Five tables of forty
      // levels transcribed by hand is exactly the kind of copy that goes stale
      // and wrong, and a sheet that shows nothing is honest.
      const bare = GeneratedGameRules();

      expect(
        bare.savingThrowsFor(classIdentifier: 'MAGE', levels: const [1]),
        isNull,
      );
    });
  });
}
