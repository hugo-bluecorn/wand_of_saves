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

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/rules/character_sheet.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';

import '../../support/fakes.dart';

void main() {
  /// The fixture protagonist: Fighter/Mage 1/1, elf, neutral good,
  /// Constitution 16, Dexterity 17, hit points 6/7, armour class 10.
  CharacterSheet sheetOf({
    int classId = 7,
    int constitution = 16,
    int dexterity = 17,
    int levelFirstClass = 1,
    int levelSecondClass = 1,
  }) => CharacterSheet(
    character: fakeCharacter().copyWith(
      classId: classId,
      levelFirstClass: levelFirstClass,
      levelSecondClass: levelSecondClass,
      abilities: fakeCharacter().abilities.copyWith(
        constitution: constitution,
        dexterity: dexterity,
      ),
    ),
    rules: const GeneratedGameRules(),
  );

  group('identity', () {
    test('reads like the record screen, in its order', () {
      // BG:EE's own record screen stacks these as Male, Elf, Fighter / Mage,
      // Neutral Good.
      expect(
        sheetOf().identity,
        'Male · Elf · Fighter / Mage · Neutral Good',
      );
    });

    test('leaves out what it cannot name rather than showing a number', () {
      expect(sheetOf(classId: 173).identity, 'Male · Elf · Neutral Good');
    });
  });

  group('armour class', () {
    test('adds the Dexterity modifier, matching what the game showed', () {
      // Stored 10, Dexterity 17 gives -3, and the game's shield read 7.
      expect(sheetOf().armourClassModifier, -3);
      expect(sheetOf().armourClassInGame, 7);
    });

    test('is the stored value when Dexterity does nothing', () {
      expect(sheetOf(dexterity: 10).armourClassInGame, 10);
    });

    test('has no derived value when Dexterity is off the table', () {
      expect(sheetOf(dexterity: 99).armourClassInGame, isNull);
    });
  });

  group('hit points', () {
    test('adds the Constitution bonus, matching what the game showed', () {
      // The game printed "Bonus Hit Points/Level: +2" and showed 8/9 against
      // a stored 6/7.
      expect(sheetOf().hitPointBonusPerLevel, 2);
      expect(sheetOf().currentHitPointsInGame, 8);
      expect(sheetOf().maximumHitPointsInGame, 9);
    });

    test('multiplies the bonus by the highest class level', () {
      // Confirmed at level 1 and nowhere else -- see the note on the getter.
      expect(
        sheetOf(levelFirstClass: 5, levelSecondClass: 3).maximumHitPointsInGame,
        7 + 2 * 5,
      );
    });

    test('uses the warrior column for a class that has a fighter in it', () {
      // Constitution 17 is the first row where the two columns differ: 2 for
      // everyone else, 3 for warriors.
      expect(
        sheetOf(constitution: 17).hitPointBonusPerLevel,
        3,
        reason: 'FIGHTER_MAGE draws on the warrior column',
      );
      expect(
        sheetOf(classId: 1, constitution: 17).hitPointBonusPerLevel,
        2,
        reason: 'a MAGE does not',
      );
    });

    test('has no derived value when Constitution is off the table', () {
      expect(sheetOf(constitution: 99).maximumHitPointsInGame, isNull);
    });

    test('current hit points are clamped to the maximum, as the game does', () {
      // Measured: a savegame carrying 20 current against a maximum of 7 loaded
      // showing 9/9, not 22/9. The engine clamps on load, so showing an
      // impossible pair would be reporting a state the game never has.
      final overfull = CharacterSheet(
        character: fakeCharacter().copyWith(currentHitPoints: 20),
        rules: const GeneratedGameRules(),
      );

      expect(overfull.maximumHitPointsInGame, 9);
      expect(overfull.currentHitPointsInGame, 9);
    });
  });

  group('bounds that depend on another field', () {
    test('current hit points cannot exceed the maximum', () {
      // The stat's own range is the field's width, 0-65535, which lets an
      // editor offer 20 against a maximum of 7. The engine clamps that away on
      // load, so it is not a state a savegame can actually hold.
      expect(sheetOf().upperBoundFor(CharacterStat.currentHitPoints), 7);
    });

    test('the bound follows the maximum when the maximum changes', () {
      final tougher = CharacterSheet(
        character: fakeCharacter().copyWith(maximumHitPoints: 40),
        rules: const GeneratedGameRules(),
      );

      expect(tougher.upperBoundFor(CharacterStat.currentHitPoints), 40);
    });

    test('every other stat keeps its own range', () {
      expect(
        sheetOf().upperBoundFor(CharacterStat.strength),
        CharacterStat.strength.maximum,
      );
      expect(
        sheetOf().upperBoundFor(CharacterStat.maximumHitPoints),
        CharacterStat.maximumHitPoints.maximum,
      );
    });

    test('a value already in the save can be out of bounds', () {
      // Which is exactly the case worth surfacing: the fixture carries 20
      // current against 7 maximum, left there by an earlier write-back test.
      // The editor should say so rather than presenting it as ordinary.
      final overfull = CharacterSheet(
        character: fakeCharacter().copyWith(currentHitPoints: 20),
        rules: const GeneratedGameRules(),
      );

      expect(
        overfull.isWithinBounds(CharacterStat.currentHitPoints, 20),
        isFalse,
      );
      expect(
        overfull.isWithinBounds(CharacterStat.currentHitPoints, 7),
        isTrue,
      );
      expect(overfull.isWithinBounds(CharacterStat.strength, 19), isTrue);
      expect(overfull.isWithinBounds(CharacterStat.strength, 99), isFalse);
    });
  });

  group('what the tables cannot answer', () {
    test('the kit is reported as unknown rather than guessed at', () {
      // The fixture stores 0x40000000 for "no kit". Shifted right 16 that is
      // 0x4000, which is KIT.IDS's *first* entry, MAGESCHOOL_GENERALIST — so
      // the obvious decoding names a kit for a character who has none. Until
      // the encoding is measured, this stays null rather than wrong.
      expect(sheetOf().kitName, isNull);
    });

    test('no maximum hit points are suggested', () {
      // What the maximum *should* be needs the per-class dice tables
      // (hpwar.2da and friends). IESDP ships only a template for them, so the
      // rules-based cap is not computable from what we have — it waits for
      // Phase 3 reading the player's own files.
      expect(sheetOf().maximumHitPointsAllowed, isNull);
    });
  });
}
