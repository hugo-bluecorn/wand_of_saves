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

/// Every assertion here that is marked "the game printed" was read off a
/// screenshot of BG:EE showing the fixture character, taken during the Phase 2
/// write-back run. That makes this suite an oracle comparison that needs no
/// game installed: the engine's own output is quoted in the expectations.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';

void main() {
  const rules = GeneratedGameRules();

  group('identity — confirmed against the record screen', () {
    test('class 7 is a Fighter / Mage', () {
      expect(rules.classIdentifier(7), 'FIGHTER_MAGE');
      expect(rules.className(7), 'Fighter / Mage');
    });

    test('race 2 is an Elf', () {
      expect(rules.raceIdentifier(2), 'ELF');
      expect(rules.raceName(2), 'Elf');
    });

    test('alignment 33 is Neutral Good', () {
      // Stored as 0x21. ALIGNMEN.IDS is written in hex where CLASS.IDS and
      // RACE.IDS are decimal.
      expect(rules.alignmentIdentifier(0x21), 'NEUTRAL_GOOD');
      expect(rules.alignmentName(33), 'Neutral Good');
    });
  });

  group('identity — rendering not confirmed by an oracle', () {
    // The identifiers come from the game's data; turning them into English is
    // ours, so these are our convention rather than measurements.
    test('a single class keeps its one word', () {
      expect(rules.className(2), 'Fighter');
      expect(rules.className(11), 'Druid');
    });

    test('a triple multi-class separates all three', () {
      expect(rules.className(10), 'Fighter / Mage / Thief');
    });

    test('hyphenated races are spelled the way the game spells them', () {
      expect(rules.raceName(3), 'Half-Elf');
      expect(rules.raceName(7), 'Half-Orc');
    });

    test('an unknown id has no name rather than a made-up one', () {
      // 173 is a genuine gap in CLASS.IDS, which runs well past the playable
      // classes -- it also numbers FOOD_CREATURE and LONG_SWORD, because
      // scripts target by it.
      expect(rules.className(173), isNull);
      expect(rules.raceName(200), isNull);
      expect(rules.alignmentName(200), isNull);
    });
  });

  group('kit — settled 2026-08-08 by a four-member party', () {
    // The stored dword carries the KIT.IDS key in its high word. Xzar proves
    // the shift: he stores 0x10000000, which shifted right 16 is 0x1000 =
    // MAGESCHOOL_NECROMANCER, and Xzar is a Necromancer. Montaron proves the
    // TRUECLASS reading: he stores 0x40000000 and is a Fighter/Thief with no
    // mage component, so 0x4000 cannot mean "generalist mage".
    test('the high word is the KIT.IDS key', () {
      expect(rules.kitIdentifier(0x10000000), 'MAGESCHOOL_NECROMANCER');
      expect(rules.kitIdentifier(0x40000000), 'TRUECLASS');
    });

    test('a specialist mage is named by his school', () {
      expect(rules.kitName(0x10000000), 'Necromancer');
    });

    test('TRUECLASS is no kit rather than a kit called TRUECLASS', () {
      expect(rules.kitName(0x40000000), isNull);
    });

    test('zero is the other way a character has no kit', () {
      // Imoen stores 0x00000000 where Aard and Montaron store 0x40000000.
      // Both mean the same thing, so both must render as nothing.
      expect(rules.kitIdentifier(0), isNull);
      expect(rules.kitName(0), isNull);
    });

    test('an unrecognised kit has no name rather than a made-up one', () {
      expect(rules.kitName(0x00990000), isNull);
    });
  });

  group('class count — how many level slots a record actually uses', () {
    // A savegame does NOT zero its unused level slots: every recruited NPC in
    // the Party fixture stores 1/1/1, including single-class Imoen and Xzar.
    // The count has to come from the class, never from the bytes.
    test('a single class uses one slot', () {
      expect(rules.classCount(4), 1, reason: 'THIEF');
      expect(rules.classCount(1), 1, reason: 'MAGE');
    });

    test('a dual name is two slots', () {
      expect(rules.classCount(7), 2, reason: 'FIGHTER_MAGE');
      expect(rules.classCount(9), 2, reason: 'FIGHTER_THIEF');
      expect(rules.classCount(18), 2, reason: 'CLERIC_RANGER');
    });

    test('a triple name is three slots', () {
      expect(rules.classCount(10), 3, reason: 'FIGHTER_MAGE_THIEF');
      expect(rules.classCount(17), 3, reason: 'FIGHTER_MAGE_CLERIC');
    });

    test('an unknown class says so rather than guessing one', () {
      expect(rules.classCount(173), isNull);
    });
  });

  group('armour class from Dexterity', () {
    test('17 gives -3', () {
      // The game printed "Dexterity: -3" beside an armour class of 10, and
      // showed 7 on the shield.
      expect(rules.armourClassFromDexterity(17), -3);
    });

    test('the middle of the range gives nothing', () {
      expect(rules.armourClassFromDexterity(10), 0);
    });

    test('the ends of the table are present', () {
      expect(rules.armourClassFromDexterity(0), 5);
      expect(rules.armourClassFromDexterity(25), -6);
    });

    test('a score outside the table has no modifier', () {
      expect(rules.armourClassFromDexterity(99), isNull);
    });
  });

  group('hit points from Constitution', () {
    test('16 gives +2, whatever the class', () {
      // The game printed "Bonus Hit Points/Level: +2" for this character, who
      // had Constitution 16 at the time. Both columns read 2 there, which is
      // why 16 could never settle the warrior question.
      expect(rules.hitPointBonusPerLevel(constitution: 16, warrior: false), 2);
      expect(rules.hitPointBonusPerLevel(constitution: 16, warrior: true), 2);
    });

    test('the columns diverge from 17 up', () {
      expect(rules.hitPointBonusPerLevel(constitution: 17, warrior: false), 2);
      expect(rules.hitPointBonusPerLevel(constitution: 17, warrior: true), 3);
      expect(rules.hitPointBonusPerLevel(constitution: 18, warrior: true), 4);
    });

    test('18 on a warrior gives +4 — the game printed exactly this', () {
      // 2026-08-08, the run that closed the last unmeasured rule in this
      // file. Aard raised to Constitution 18 and loaded in BG:EE: the
      // inventory screen read "Bonus Hit Points/Level: +4" and the globe
      // read 41/44 against a stored 37/40. The other column reads 2 at 18,
      // which would have shown 39/42 — a different number on the same
      // screen, which is what made the run decisive.
      expect(rules.hitPointBonusPerLevel(constitution: 18, warrior: true), 4);
      expect(rules.hitPointBonusPerLevel(constitution: 18, warrior: false), 2);
    });

    test('a low Constitution is a penalty', () {
      expect(rules.hitPointBonusPerLevel(constitution: 1, warrior: false), -3);
    });

    test('a score outside the table has no bonus', () {
      expect(
        rules.hitPointBonusPerLevel(constitution: 99, warrior: false),
        isNull,
      );
    });
  });

  group('warrior classification', () {
    // The roots come from the walkthrough's ability chapter: "the bonus for
    // warriors (Fighters, Paladins, Rangers, and their kits)". Applied by
    // CLASS.IDS name so the rule reads in the engine's own vocabulary.
    //
    // **Confirmed in game 2026-08-08** for the case that mattered -- a
    // multi-class. A FIGHTER_MAGE at Constitution 18 made the engine print
    // "+4", so containment is right and half a fighter is a warrior.
    test('fighters, paladins and rangers are warriors', () {
      expect(rules.isWarrior(2), isTrue, reason: 'FIGHTER');
      expect(rules.isWarrior(6), isTrue, reason: 'PALADIN');
      expect(rules.isWarrior(12), isTrue, reason: 'RANGER');
    });

    test('a multi-class containing a fighter is a warrior', () {
      expect(rules.isWarrior(7), isTrue, reason: 'FIGHTER_MAGE');
      expect(rules.isWarrior(10), isTrue, reason: 'FIGHTER_MAGE_THIEF');
    });

    test('everyone else is not', () {
      expect(rules.isWarrior(1), isFalse, reason: 'MAGE');
      expect(rules.isWarrior(3), isFalse, reason: 'CLERIC');
      expect(rules.isWarrior(4), isFalse, reason: 'THIEF');
      expect(rules.isWarrior(5), isFalse, reason: 'BARD');
    });

    test('an unknown class is not a warrior', () {
      expect(rules.isWarrior(173), isFalse);
    });
  });

  group('the generated tables are not empty', () {
    test('each one has entries', () {
      // A silently empty rules table would make every derived number quietly
      // wrong, which is the failure this project is shaped around. The
      // generator refuses to emit one; this is the belt to that braces.
      expect(rules.classIdentifier(1), isNotNull);
      expect(rules.raceIdentifier(1), isNotNull);
      expect(rules.alignmentIdentifier(0x11), isNotNull);
      expect(rules.armourClassFromDexterity(18), isNotNull);
      expect(
        rules.hitPointBonusPerLevel(constitution: 10, warrior: false),
        isNotNull,
      );
    });
  });
}
