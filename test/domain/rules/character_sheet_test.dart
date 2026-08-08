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
    // All three slots at once, because what these tests are about is the
    // shape of the slots -- 1/1/1 against 1/1/0 -- not one field at a time.
    List<int> levels = const [1, 1, 0],
    int kitId = 0x40000000,
  }) => CharacterSheet(
    character: fakeCharacter().copyWith(
      classId: classId,
      kitId: kitId,
      levelFirstClass: levels[0],
      levelSecondClass: levels[1],
      levelThirdClass: levels[2],
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

  group('class levels — a savegame does not zero its unused slots', () {
    // Measured on the four-member Party fixture. Aard, the player's own
    // character, stores 01 01 00; every recruited NPC stores 01 01 01,
    // single-class Imoen and Xzar included. Reading "how many classes" off
    // the bytes therefore prints "Level 1/1/1" for a plain Thief, which is
    // what the character panel was doing.
    test('a single class shows one level however many slots are filled', () {
      final imoen = sheetOf(classId: 4, levels: const [1, 1, 1]);

      expect(imoen.classLevels, [1]);
      expect(imoen.levelLabel, '1');
    });

    test('a two-class name shows two, dropping the junk third', () {
      final montaron = sheetOf(classId: 9, levels: const [1, 1, 1]);

      expect(montaron.levelLabel, '1/1');
    });

    test('the player character was already right, and stays right', () {
      // Aard: FIGHTER_MAGE storing 01 01 00. The old drop-zeroes rule and the
      // class-driven one agree here, which is precisely why the bug survived.
      expect(sheetOf().levelLabel, '1/1');
    });

    test('a triple multi-class shows all three', () {
      expect(
        sheetOf(classId: 10, levels: const [7, 8, 9]).levelLabel,
        '7/8/9',
      );
    });

    test('an unknown class falls back to the slots that are filled', () {
      // Nothing better is available, and showing nothing would be worse than
      // showing the bytes.
      final unknown = sheetOf(classId: 173, levels: const [3, 2, 0]);

      expect(unknown.classLevels, [3, 2]);
      expect(unknown.levelLabel, '3/2');
    });

    test('a record with no levels at all says so', () {
      expect(
        sheetOf(classId: 173, levels: const [0, 0, 0]).levelLabel,
        '—',
      );
    });

    test('the hit-point bonus ignores a junk slot', () {
      // A single-class Thief at level 5 storing 05 01 01: the bonus multiplies
      // by 5, and would still do so if the junk slots ever exceeded it.
      expect(
        sheetOf(classId: 4, levels: const [5, 1, 1]).maximumHitPointsInGame,
        7 + 2 * 5,
      );
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
        sheetOf(levels: const [5, 3, 0]).maximumHitPointsInGame,
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

    test('reproduces the whole Constitution 18 run, number for number', () {
      // The 2026-08-08 in-game run, and the strongest single check in this
      // suite: every figure below was read off BG:EE's own inventory screen
      // for a character whose savegame held 37/40 at Constitution 18.
      //
      //   Class Hit Points/Level: +7
      //   Bonus Hit Points/Level: +4      <- the warrior column
      //   globe: 41/44
      //
      // The rival hypothesis was not a rounding error away: the other column
      // gives 2, so it predicted 39/42.
      final aard = CharacterSheet(
        character: fakeCharacter().copyWith(
          currentHitPoints: 37,
          maximumHitPoints: 40,
          abilities: fakeCharacter().abilities.copyWith(constitution: 18),
        ),
        rules: const GeneratedGameRules(),
      );

      expect(aard.hitPointBonusPerLevel, 4);
      expect(aard.currentHitPointsInGame, 41);
      expect(aard.maximumHitPointsInGame, 44);
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

  group('kit', () {
    test('a specialist mage is named, and joins the identity line', () {
      // Xzar, party[3] of the Party fixture: a MAGE storing 0x10000000, which
      // shifted right 16 is 0x1000 = MAGESCHOOL_NECROMANCER. He is a
      // Necromancer, which is what makes the shift a measurement.
      final xzar = sheetOf(classId: 1, kitId: 0x10000000);

      expect(xzar.kitName, 'Necromancer');
      expect(
        xzar.identity,
        'Male · Elf · Mage (Necromancer) · Neutral Good',
        reason: 'the kit qualifies the class rather than standing beside it',
      );
    });

    test('a character with no kit shows none, on either encoding', () {
      // Aard and Montaron store 0x40000000 (TRUECLASS); Imoen stores 0. All
      // three have no kit and the game shows none for any of them.
      expect(sheetOf().kitName, isNull);
      expect(sheetOf(kitId: 0).kitName, isNull);
      expect(sheetOf().identity, 'Male · Elf · Fighter / Mage · Neutral Good');
    });

    test('an unnamed class cannot carry a kit into the identity line', () {
      // The parenthesis has nothing to attach to, so the kit drops with it
      // rather than appearing on its own.
      expect(
        sheetOf(classId: 173, kitId: 0x10000000).identity,
        'Male · Elf · Neutral Good',
      );
    });
  });

  group('what the tables cannot answer', () {
    test('no maximum hit points are suggested', () {
      // What the maximum *should* be needs the per-class dice tables
      // (hpwar.2da and friends). IESDP ships only a template for them, so the
      // rules-based cap is not computable from what we have — it waits for
      // Phase 3 reading the player's own files.
      expect(sheetOf().maximumHitPointsAllowed, isNull);
    });
  });
}
