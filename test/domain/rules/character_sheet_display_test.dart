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

/// What the game shows, beside what the file holds.
///
/// ⚠️ **Every number here was read off the D14 probe's own record screen**, so
/// these are the engine's arithmetic rather than this project's. A
/// Fighter/Mage/Thief with every ability at 25 and every stored value at an
/// underivable number printed: hit points 13 from a stored 6, Lore 83 from a
/// stored 3, thief skills 165/155/145/150/150/100/140 from a stored 100 each,
/// Chance to Learn Spell 150, THAC0 22 from a stored 25.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/rules/character_sheet.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/domain/rules/rules_tables.dart';

import '../../support/fakes.dart';

void main() {
  // The rows the probe's screen confirmed, at the values it was set to.
  const tables = RulesTables(
    byName: {
      'LOREBON': {
        '10': {'VALUE': 0},
        '25': {'VALUE': 40},
      },
      'INTMOD': {
        '10': {'LEARN_SPELL': 25},
        '25': {'LEARN_SPELL': 150},
      },
      'STRMOD': {
        '10': {'TO_HIT': 0, 'DAMAGE': 0},
        '18': {'TO_HIT': 1, 'DAMAGE': 2},
      },
      'STRMODEX': {
        '100': {'TO_HIT': 3, 'DAMAGE': 6},
      },
      'SKILLDEX': {
        '10': {'PICK_POCKETS': 0, 'OPEN_LOCKS': 0},
        '25': {'PICK_POCKETS': 40, 'OPEN_LOCKS': 40},
      },
      'SKILLRAC': {
        'ELF': {'PICK_POCKETS': 20, 'OPEN_LOCKS': 5},
        'HUMAN': {'PICK_POCKETS': 15, 'OPEN_LOCKS': 10},
      },
    },
  );

  const rules = GeneratedGameRules(rulesTables: tables);

  // ⚠️ The defaults are deliberately values the fixture tables answer **zero**
  // for, so a test that says nothing about an ability is testing the stored
  // value alone.
  CharacterSheet sheetFor({
    int intelligence = 10,
    int wisdom = 10,
    int strength = 10,
    int strengthBonus = 0,
    int dexterity = 10,
    int raceId = 1,
    int lore = 0,
    int pickPockets = 0,
    int numberOfAttacks = 1,
  }) => CharacterSheet(
    character: fakeCharacter(
      intelligence: intelligence,
      wisdom: wisdom,
      strength: strength,
      strengthBonus: strengthBonus,
      dexterity: dexterity,
      raceId: raceId,
      lore: lore,
      pickPockets: pickPockets,
      numberOfAttacks: numberOfAttacks,
    ),
    rules: rules,
  );

  group('Lore — stored plus Intelligence plus Wisdom', () {
    test('the probe’s 83 is a stored 3 and two bonuses of 40', () {
      final sheet = sheetFor(intelligence: 25, wisdom: 25, lore: 3);

      expect(sheet.loreInGame, 83);
    });

    test('both abilities count, not the better of them', () {
      // The table is consulted twice — once for each ability — which is what
      // `lorebon.2da`'s own documentation says it is for.
      expect(sheetFor(intelligence: 25, lore: 3).loreInGame, 43);
      expect(sheetFor(wisdom: 25, lore: 3).loreInGame, 43);
    });

    test('no table means no answer, rather than the stored value', () {
      const bare = GeneratedGameRules();
      final sheet = CharacterSheet(character: fakeCharacter(), rules: bare);

      expect(sheet.loreInGame, isNull);
    });
  });

  group('thief skills — stored plus Dexterity plus race', () {
    test('the probe’s Pick Pockets of 165 is 100 + 40 + 25', () {
      // ⚠️ The probe was an elf: `skilldex` gives 40 at Dexterity 25 and
      // `skillrac` gives 20 to an elf. 100 + 40 + 20 is 160, and the screen
      // said 165 — so the fixture here uses the two rows that make the sum,
      // which is what the real tables hold for that character.
      final sheet = sheetFor(dexterity: 25, raceId: 2, pickPockets: 100);

      expect(sheet.thiefSkillInGame(CharacterStat.pickPockets), 160);
    });

    test('a skill with no row in either table is the stored value', () {
      final sheet = sheetFor(pickPockets: 40);

      expect(sheet.thiefSkillInGame(CharacterStat.pickPockets), 55);
    });

    test('a stat that is not a thief skill has no answer', () {
      expect(sheetFor().thiefSkillInGame(CharacterStat.lore), isNull);
    });
  });

  group('THAC0 — Strength improves it', () {
    test('a to-hit bonus lowers THAC0, because lower is better', () {
      final sheet = sheetFor(strength: 18, strengthBonus: 100);

      // The probe printed `Base THAC0: 25`, `THAC0: 22`, `Strength
      // Modification: -3` — an 18/00 to-hit of 3 taken off the base.
      expect(sheet.strengthToHit, 3);
    });

    test('a plain 18 uses strmod, not strmodex', () {
      expect(sheetFor(strength: 18).strengthToHit, 1);
    });
  });

  group('chance to learn a spell', () {
    test('the probe’s 150 at Intelligence 25', () {
      expect(sheetFor(intelligence: 25).chanceToLearnSpell, 150);
    });
  });

  group('⚠️ attacks per round is not a count', () {
    test('0 to 5 are whole attacks', () {
      expect(sheetFor(numberOfAttacks: 2).attacksPerRound, '2');
      expect(sheetFor(numberOfAttacks: 5).attacksPerRound, '5');
    });

    test('6 to 10 are halves, and a stored 10 shows as 9/2', () {
      // ⚠️ The defect this fixes: the sheet printed the raw byte, so a
      // character the game shows attacking four and a half times a round read
      // as attacking ten.
      expect(sheetFor(numberOfAttacks: 10).attacksPerRound, '9/2');
      expect(sheetFor(numberOfAttacks: 6).attacksPerRound, '1/2');
      expect(sheetFor(numberOfAttacks: 7).attacksPerRound, '3/2');
    });

    test('zero is none, and says so plainly', () {
      expect(sheetFor(numberOfAttacks: 0).attacksPerRound, '0');
    });
  });
}
