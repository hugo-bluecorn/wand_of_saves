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

/// THAC0, Lore, thief skill points and the two fixed skill progressions.
///
/// The numbers are the player's own tables, dumped with
/// `tool/dev/dump_table.dart`; the expectations are checked against the game's
/// own NPC records in `derived_stats_oracle_test.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/domain/rules/rules_tables.dart';

void main() {
  const tables = RulesTables(
    byName: {
      // ⚠️ `thac0.2da` enumerates the multi-classes outright, so nothing here
      // is composed — a FIGHTER_MAGE has its own row.
      'THAC0': {
        'MAGE': {'1': 20, '2': 20, '3': 20, '4': 19},
        'FIGHTER': {'1': 20, '2': 19, '3': 18, '4': 17},
        'THIEF': {'1': 20, '2': 20, '3': 19, '4': 19},
        'BARD': {'1': 20, '2': 20, '3': 19, '4': 19},
        'RANGER': {'1': 20, '2': 19, '3': 18, '4': 17},
        'FIGHTER_THIEF': {'1': 20, '2': 19, '3': 18, '4': 17},
        'CLERIC_MAGE': {'1': 20, '2': 20, '3': 20, '4': 18},
      },
      'LORE': {
        'MAGE': {'RATE': 3},
        'FIGHTER': {'RATE': 1},
        'CLERIC': {'RATE': 1},
        'THIEF': {'RATE': 3},
        'BARD': {'RATE': 10},
      },
      'THIEFSKL': {
        'THIEF': {'START_POINTS': 40, 'LEVEL_POINTS': 25},
        'SHADOWDANCER': {'START_POINTS': 30, 'LEVEL_POINTS': 20},
        'FIGHTER_THIEF': {'START_POINTS': 40, 'LEVEL_POINTS': 25},
      },
      'SKILLBRD': {
        '1': {'PICK_POCKETS': 25},
        '2': {'PICK_POCKETS': 30},
        '3': {'PICK_POCKETS': 35},
      },
      'SKILLRNG': {
        '1': {'MOVE_SILENTLY': 15},
        '2': {'MOVE_SILENTLY': 21},
      },
    },
  );

  const rules = GeneratedGameRules(rulesTables: tables);

  group('thac0For', () {
    test('a single class reads its own row at its own level', () {
      expect(rules.thac0For(classIdentifier: 'FIGHTER', levels: [3]), 18);
      expect(rules.thac0For(classIdentifier: 'MAGE', levels: [4]), 19);
    });

    test('a multi-class has a row of its own, and is not composed', () {
      // Coran, a Fighter/Thief 3/3, stores 18 — the FIGHTER_THIEF row, which
      // is the warrior progression rather than anything derived from two.
      expect(
        rules.thac0For(classIdentifier: 'FIGHTER_THIEF', levels: [3, 3]),
        18,
      );
    });

    test('a level past the table takes the last column it has', () {
      expect(rules.thac0For(classIdentifier: 'FIGHTER', levels: [40]), 17);
    });

    test('an unknown class has no answer rather than 20', () {
      // 20 is the level-1 value for everyone, so defaulting to it would look
      // right and be a guess.
      expect(rules.thac0For(classIdentifier: 'ANKHEG', levels: [1]), isNull);
    });

    test('with no tables read there is no answer', () {
      const bare = GeneratedGameRules();

      expect(bare.thac0For(classIdentifier: 'FIGHTER', levels: [1]), isNull);
    });
  });

  group('loreFor', () {
    test('a single class is its rate times its level', () {
      // Garrick, a Bard 1, stores 10; Eldoth at 3 stores 30; Xan, a Mage 2,
      // stores 6.
      expect(rules.loreFor(classIdentifier: 'BARD', levels: [1]), 10);
      expect(rules.loreFor(classIdentifier: 'BARD', levels: [3]), 30);
      expect(rules.loreFor(classIdentifier: 'MAGE', levels: [2]), 6);
      expect(rules.loreFor(classIdentifier: 'FIGHTER', levels: [1]), 1);
    });

    test('a multi-class takes the highest of its classes, not the sum', () {
      // ⚠️ **Unsettled, and the two readings disagree here.** The engine's own
      // recomputation on import stored **3** for a Fighter/Mage/Thief at
      // 1/1/1, where a sum gives 7 — so the engine says highest. The shipped
      // NPC records read like sums (Coran 12, Tiax 8, Quayle 8), but those
      // files also hold a Fighter 1 with Lore 4 and a Mage 1 with Lore 0,
      // which no rule produces, so they are hand-authored and cannot referee
      // it. Engine outranks table outranks file.
      expect(
        rules.loreFor(classIdentifier: 'CLERIC_MAGE', levels: [2, 2]),
        6,
        reason: 'MAGE 3 × 2 beats CLERIC 1 × 2; the sum would be 8',
      );
    });

    test('a class with no row has no lore rate', () {
      expect(rules.loreFor(classIdentifier: 'PALADIN', levels: [1]), isNull);
    });
  });

  group('thiefSkillPointsFor', () {
    test('a thief has forty points to spend at first level', () {
      expect(rules.thiefSkillPointsFor('THIEF'), 40);
    });

    test('a kit is its own row and need not follow its class', () {
      expect(rules.thiefSkillPointsFor('SHADOWDANCER'), 30);
    });

    test('a multi-class has its own row too, and nothing is summed', () {
      expect(rules.thiefSkillPointsFor('FIGHTER_THIEF'), 40);
    });

    test('a class with no row gets none, which is not the same as zero', () {
      // ⚠️ `null` rather than 0: a fighter has no row because the question does
      // not apply, and a creation step that read 0 as "spend nothing" would be
      // right by accident and wrong the moment a table gains a row.
      expect(rules.thiefSkillPointsFor('FIGHTER'), isNull);
    });
  });

  group('fixedThiefSkillsFor', () {
    test('a ranger gets ONE number applied to both stealth skills', () {
      // ⚠️ Measured on Minsc (Ranger 1) and Kivan (Ranger 2): the record holds
      // the same value in Move Silently and Hide in Shadows, and `skillrng`
      // only has a MOVE_SILENTLY column. One number, written twice.
      expect(
        rules.fixedThiefSkillsFor(classIdentifier: 'RANGER', levels: [1]),
        {
          'MOVE_SILENTLY': 15,
          'HIDE_IN_SHADOWS': 15,
        },
      );
      expect(
        rules.fixedThiefSkillsFor(classIdentifier: 'RANGER', levels: [2]),
        {
          'MOVE_SILENTLY': 21,
          'HIDE_IN_SHADOWS': 21,
        },
      );
    });

    test('a bard gets pick pockets and nothing else', () {
      expect(rules.fixedThiefSkillsFor(classIdentifier: 'BARD', levels: [1]), {
        'PICK_POCKETS': 25,
      });
      expect(rules.fixedThiefSkillsFor(classIdentifier: 'BARD', levels: [3]), {
        'PICK_POCKETS': 35,
      });
    });

    test('a thief gets none of these — theirs are allocated, not fixed', () {
      expect(
        rules.fixedThiefSkillsFor(classIdentifier: 'THIEF', levels: [1]),
        isEmpty,
      );
    });

    test('a multi-class ranger or bard is read at that class’s own level', () {
      // FIGHTER_RANGER is not a class, but a multi-class holding one would be
      // read at the ranger's level rather than at the highest.
      expect(
        rules.fixedThiefSkillsFor(
          classIdentifier: 'FIGHTER_THIEF',
          levels: [3, 3],
        ),
        isEmpty,
      );
    });
  });
}
