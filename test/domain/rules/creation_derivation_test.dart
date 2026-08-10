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

/// What a newly created character's record should hold beyond their choices.
///
/// ⚠️ **D14 is why this exists.** The engine overwrites six fields on import
/// and leaves sixty-seven alone, so a character created with saving throws of
/// zero keeps them for the whole game. Nothing else is going to fill these in.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/rules/creation_derivation.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/domain/rules/hit_die_tables.dart';
import 'package:wand_of_saves/domain/rules/rules_tables.dart';
import 'package:wand_of_saves/domain/rules/saving_throw_tables.dart';

void main() {
  const rules = GeneratedGameRules(
    savingThrows: SavingThrowTables(
      rowsByTable: {
        'SAVEWIZ': {
          'DEATH': [14],
          'WANDS': [11],
          'POLY': [13],
          'BREATH': [15],
          'SPELL': [12],
        },
        'SAVEROG': {
          'DEATH': [13],
          'WANDS': [14],
          'POLY': [12],
          'BREATH': [16],
          'SPELL': [15],
        },
        'SAVECNG': {
          // ⚠️ All zeros, as the real table is — the gnome's bonus does not
          // reach death, which is the only thing distinguishing this table
          // from the dwarf and halfling one.
          'DEATH': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          'WANDS': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3],
          'POLY': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          'BREATH': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          'SPELL': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3],
        },
      },
    ),
    rulesTables: RulesTables(
      byName: {
        'THAC0': {
          'MAGE': {'1': 20},
          'BARD': {'1': 20},
          'RANGER': {'1': 20},
        },
        'LORE': {
          'MAGE': {'RATE': 3},
          'BARD': {'RATE': 10},
          'RANGER': {'RATE': 1},
        },
        'SKILLBRD': {
          '1': {'PICK_POCKETS': 25},
        },
        'SKILLRNG': {
          '1': {'MOVE_SILENTLY': 15},
        },
      },
    ),
    hitDice: HitDieTables(
      tableByClass: {'MAGE': 'HPWIZ', 'BARD': 'HPROG', 'RANGER': 'HPWAR'},
      rowsByTable: {
        'HPWIZ': [(sides: 4, rolls: 1, modifier: 0)],
        'HPROG': [(sides: 6, rolls: 1, modifier: 0)],
        'HPWAR': [(sides: 10, rolls: 1, modifier: 0)],
      },
    ),
  );

  group('a first-level mage', () {
    final derived = derivedStatsFor(
      rules: rules,
      classIdentifier: 'MAGE',
      raceIdentifier: 'HUMAN',
      levels: const [1],
      constitution: 10,
    );

    test('gets the five saving throws its class table gives', () {
      expect(derived[CharacterStat.saveVersusDeath], 14);
      expect(derived[CharacterStat.saveVersusWands], 11);
      expect(derived[CharacterStat.saveVersusPolymorph], 13);
      expect(derived[CharacterStat.saveVersusBreath], 15);
      expect(derived[CharacterStat.saveVersusSpells], 12);
    });

    test('gets a THAC0 and a Lore', () {
      expect(derived[CharacterStat.thac0], 20);
      expect(derived[CharacterStat.lore], 3);
    });

    test('gets hit points, current and maximum alike', () {
      // ⚠️ The **rolled** maximum, without the Constitution bonus: the engine
      // adds that at display and recomputes the stored value on import
      // anyway. Difficulty maximises the roll at Normal and below.
      expect(derived[CharacterStat.maximumHitPoints], 4);
      expect(derived[CharacterStat.currentHitPoints], 4);
    });

    test('gets a morale break of zero, which is what keeps them playable', () {
      // ⚠️ Not cosmetic. A morale break at or above morale panics a character
      // permanently, and the protagonist's own record stores 0.
      expect(derived[CharacterStat.moraleBreak], 0);
    });

    test('gets no thief skills, having none to get', () {
      expect(derived.containsKey(CharacterStat.pickPockets), isFalse);
      expect(derived.containsKey(CharacterStat.moveSilently), isFalse);
    });
  });

  test('a gnome takes the racial bonus on their saves', () {
    final derived = derivedStatsFor(
      rules: rules,
      classIdentifier: 'MAGE',
      raceIdentifier: 'GNOME',
      levels: const [1],
      constitution: 11,
    );

    expect(derived[CharacterStat.saveVersusWands], 8, reason: '11 less 3');
    expect(derived[CharacterStat.saveVersusDeath], 14, reason: 'no bonus');
  });

  test('a bard gets pick pockets without being asked for it', () {
    final derived = derivedStatsFor(
      rules: rules,
      classIdentifier: 'BARD',
      raceIdentifier: 'HUMAN',
      levels: const [1],
      constitution: 10,
    );

    expect(derived[CharacterStat.pickPockets], 25);
  });

  test('a ranger gets the same stealth number in both skills', () {
    final derived = derivedStatsFor(
      rules: rules,
      classIdentifier: 'RANGER',
      raceIdentifier: 'HUMAN',
      levels: const [1],
      constitution: 10,
    );

    expect(derived[CharacterStat.moveSilently], 15);
    expect(derived[CharacterStat.hideInShadows], 15);
  });

  test('a field the tables cannot answer is left out, never guessed at', () {
    // ⚠️ Absent rather than zero. A character created on a machine with no
    // installation keeps the template's values, which are the engine's own —
    // writing zeros over them would be worse than writing nothing.
    const bare = GeneratedGameRules();
    final derived = derivedStatsFor(
      rules: bare,
      classIdentifier: 'MAGE',
      raceIdentifier: 'HUMAN',
      levels: const [1],
      constitution: 10,
    );

    expect(derived.containsKey(CharacterStat.saveVersusDeath), isFalse);
    expect(derived.containsKey(CharacterStat.thac0), isFalse);
    expect(
      derived[CharacterStat.moraleBreak],
      0,
      reason: 'this one needs no table, and a panicking character is a bug',
    );
  });
}
