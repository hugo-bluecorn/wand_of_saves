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
      // has Constitution 16. Both columns read 2 there, which is exactly why
      // this fixture cannot settle the warrior question.
      expect(rules.hitPointBonusPerLevel(constitution: 16, warrior: false), 2);
      expect(rules.hitPointBonusPerLevel(constitution: 16, warrior: true), 2);
    });

    test('the columns diverge from 17 up', () {
      expect(rules.hitPointBonusPerLevel(constitution: 17, warrior: false), 2);
      expect(rules.hitPointBonusPerLevel(constitution: 17, warrior: true), 3);
      expect(rules.hitPointBonusPerLevel(constitution: 18, warrior: true), 4);
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
    // From the walkthrough's ability chapter: "the bonus for warriors
    // (Fighters, Paladins, Rangers, and their kits)". Applied by CLASS.IDS
    // name so the rule reads in the engine's own vocabulary.
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
