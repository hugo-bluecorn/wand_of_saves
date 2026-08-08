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
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/domain/rules/character_sheet.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/domain/skill_catalogue.dart';

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
    test('a kit REPLACES the class name — the game showed exactly this', () {
      // Xzar, party[3] of the Party fixture: a MAGE storing 0x10000000, which
      // shifted right 16 is 0x1000 = MAGESCHOOL_NECROMANCER.
      //
      // 2026-08-08, BG:EE's record screen for him:
      //
      //   Necromancer: Level 1        <- not "Mage"
      //   Next Level: 2500            <- still the mage progression
      //   Male / Human / Necromancer / Chaotic Evil
      //
      // So the class byte stays MAGE and only the *name* changes. An earlier
      // pass rendered "Mage (Necromancer)", which was our invention: nothing
      // in the game writes the base class beside the kit.
      final xzar = sheetOf(classId: 1, kitId: 0x10000000);

      expect(xzar.kitName, 'Necromancer');
      expect(xzar.identity, 'Male · Elf · Necromancer · Neutral Good');
    });

    test('a character with no kit shows none, on either encoding', () {
      // Aard and Montaron store 0x40000000 (TRUECLASS); Imoen stores 0. All
      // three have no kit and the game shows none for any of them.
      expect(sheetOf().kitName, isNull);
      expect(sheetOf(kitId: 0).kitName, isNull);
      expect(sheetOf().identity, 'Male · Elf · Fighter / Mage · Neutral Good');
    });

    test('a known kit stands in for a class the tables cannot name', () {
      // Since the kit replaces the class outright there is nothing for it to
      // attach to, so an unnameable class is no reason to drop a name we do
      // have. 173 is a genuine gap in CLASS.IDS.
      expect(
        sheetOf(classId: 173, kitId: 0x10000000).identity,
        'Male · Elf · Necromancer · Neutral Good',
      );
    });

    test('an unnameable class with no kit still shows nothing', () {
      expect(sheetOf(classId: 173).identity, 'Male · Elf · Neutral Good');
    });
  });

  group('proficiencies', () {
    test('a plain character is governed by their class column', () {
      // weapprof.2da's columns are CLASS.IDS identifiers, so this is a
      // lookup and not a rendering — 'Fighter / Mage' would find nothing.
      expect(sheetOf().classColumn, 'FIGHTER_MAGE');
      expect(sheetOf(classId: 4).classColumn, 'THIEF');
    });

    test('a kit replaces the class column, as it replaces the name', () {
      // The same rule the record screen follows: a Necromancer is a
      // Necromancer, not a Mage who is also a Necromancer. Kits exist in this
      // table precisely because their ceilings differ from the base class's.
      expect(sheetOf(kitId: 0x10000000).classColumn, 'NECROMANCER');
    });

    test('both spellings of "no kit" fall back to the class', () {
      // 0x40000000 is KIT.IDS's TRUECLASS and plain 0 is the other encoding.
      // Neither is a column, and reading either as one would look up
      // 'TRUECLASS' and cap every proficiency at nothing.
      expect(sheetOf().classColumn, 'FIGHTER_MAGE');
      expect(sheetOf(kitId: 0).classColumn, 'FIGHTER_MAGE');
    });

    test('a class the tables cannot name has no column', () {
      expect(sheetOf(classId: 173).classColumn, isNull);
    });

    test('the ceiling comes from the table, for this character', () {
      // A Fighter/Mage caps at 3 in Two-Weapon Style where a Fighter caps at
      // 3 and a Mage at 0. Aard is the first, has 2, and so has one pip left
      // — which is exactly the edit the in-game run makes.
      final sheet = CharacterSheet(
        character: fakeCharacter(),
        rules: const GeneratedGameRules(),
        proficiencies: const ProficiencyCatalogue({
          114: ProficiencyEntry(
            id: 114,
            identifier: '2WEAPON',
            name: 'Two-Weapon Style',
            maximumByColumn: {'FIGHTER_MAGE': 3, 'FIGHTER': 3, 'MAGE': 0},
          ),
        }),
      );

      expect(sheet.maximumPipsFor(114), 3);
    });

    test('no catalogue means no ceiling, not a ceiling of zero', () {
      // A machine with no game installed. Capping at zero would silently
      // refuse every proficiency edit and look like a broken field.
      expect(sheetOf().maximumPipsFor(114), isNull);
    });

    test('names what the catalogue names, and numbers what it does not', () {
      final sheet = CharacterSheet(
        character: fakeCharacter(),
        rules: const GeneratedGameRules(),
        proficiencies: const ProficiencyCatalogue({
          114: ProficiencyEntry(
            id: 114,
            identifier: '2WEAPON',
            name: 'Two-Weapon Style',
            maximumByColumn: {},
          ),
          100: ProficiencyEntry(
            id: 100,
            identifier: 'FLAILMORNINGSTAR',
            maximumByColumn: {},
          ),
        }),
      );

      expect(sheet.proficiencyLabel(114), 'Two-Weapon Style');
      // No talk table, so the table's own row label — which is information,
      // where invented text would not be.
      expect(sheet.proficiencyLabel(100), 'FLAILMORNINGSTAR');
      // Nothing at all known: the number, rather than a blank tile.
      expect(sheet.proficiencyLabel(96), 'Proficiency 96');
    });
  });

  group('what a class may actually allocate', () {
    /// `thiefscl.2da`, cut to the classes these tests use.
    const skills = SkillCatalogue({
      'OPEN_LOCKS': {
        'THIEF': 100,
        'FIGHTER_MAGE': 0,
        'BARD': 0,
        'SHADOWDANCER': 100,
      },
      'PICK_POCKETS': {
        'THIEF': 100,
        'FIGHTER_MAGE': 0,
        'BARD': 100,
        'SHADOWDANCER': 100,
      },
      'SET_TRAPS': {
        'THIEF': 100,
        'FIGHTER_MAGE': 0,
        'BARD': 0,
        'SHADOWDANCER': 0,
      },
    });

    CharacterSheet sheetFor({
      int classId = 7,
      int kitId = 0x40000000,
      int lockpicking = 0,
    }) => CharacterSheet(
      character: fakeCharacter().copyWith(
        classId: classId,
        kitId: kitId,
        thiefSkills: fakeCharacter().thiefSkills.copyWith(
          lockpicking: lockpicking,
        ),
      ),
      rules: const GeneratedGameRules(),
      skills: skills,
    );

    test('a thief may allocate a thief skill and a fighter/mage may not', () {
      // The defect in one line. Aard is a Fighter/Mage and the panel was
      // offering him Open Locks.
      expect(sheetFor(classId: 4).allows(CharacterStat.lockpicking), isTrue);
      expect(sheetFor().allows(CharacterStat.lockpicking), isFalse);
    });

    test('a class gets a subset, not all or nothing', () {
      // A bard picks pockets and cannot open locks — which is what makes this
      // a table lookup rather than "is this character a thief".
      final bard = sheetFor(classId: 5);

      expect(bard.allows(CharacterStat.pickPockets), isTrue);
      expect(bard.allows(CharacterStat.lockpicking), isFalse);
    });

    test('a kit answers for itself, through its own column', () {
      // A Shadowdancer is a thief who cannot set traps, which no rule about
      // the base class would get right. KIT.IDS numbers it 16417, and the
      // record stores that key in the dword's high word.
      final shadowdancer = sheetFor(classId: 4);
      final byKit = CharacterSheet(
        character: fakeCharacter().copyWith(classId: 4, kitId: 0x40210000),
        rules: const GeneratedGameRules(),
        skills: skills,
      );

      expect(shadowdancer.allows(CharacterStat.setTraps), isTrue);
      expect(
        byKit.classColumn,
        'SHADOWDANCER',
        reason: 'the kit column, not the class column',
      );
      expect(byKit.allows(CharacterStat.setTraps), isFalse);
    });

    test('Lore is allowed for everyone, having no row at all', () {
      // Confirmed in game: a Necromancer's record screen prints Lore 15.
      expect(sheetFor().allows(CharacterStat.lore), isTrue);
      expect(sheetFor(classId: 4).allows(CharacterStat.lore), isTrue);
    });

    test('the fields with no table stay allowed rather than guessed at', () {
      // Turn Undead and Tracking have no governing table anywhere found —
      // tracking.2da is per-area prose. Inventing a class rule is exactly the
      // sort of plausible-and-unchecked claim this project keeps retracting.
      expect(sheetFor().allows(CharacterStat.turnUndeadLevel), isTrue);
      expect(sheetFor().allows(CharacterStat.trackingSkill), isTrue);
    });

    test('everything universal stays allowed', () {
      final aard = sheetFor();

      for (final stat in [
        CharacterStat.strength,
        CharacterStat.saveVersusSpells,
        CharacterStat.resistFire,
        CharacterStat.numberOfAttacks,
        CharacterStat.fatigue,
      ]) {
        expect(aard.allows(stat), isTrue, reason: '$stat');
      }
    });

    test('no catalogue allows everything, rather than forbidding it', () {
      // A machine with no game installed. Forbidding every skill would look
      // like a broken screen; the `null` that SkillCatalogue returns for an
      // unknown column exists precisely to keep those two apart.
      final blind = CharacterSheet(
        character: fakeCharacter(),
        rules: const GeneratedGameRules(),
      );

      expect(blind.allows(CharacterStat.lockpicking), isTrue);
    });

    test('a proficiency the class cannot use is not allowed', () {
      final aard = CharacterSheet(
        character: fakeCharacter(),
        rules: const GeneratedGameRules(),
        proficiencies: const ProficiencyCatalogue({
          114: ProficiencyEntry(
            id: 114,
            identifier: '2WEAPON',
            maximumByColumn: {'FIGHTER_MAGE': 3},
          ),
          102: ProficiencyEntry(
            id: 102,
            identifier: 'QUARTERSTAFF',
            maximumByColumn: {'FIGHTER_MAGE': 0},
          ),
        }),
      );

      expect(aard.allowsProficiency(114), isTrue);
      expect(aard.allowsProficiency(102), isFalse);
      expect(
        aard.allowsProficiency(96),
        isTrue,
        reason: 'unknown to the table is not the same as forbidden',
      );
    });

    test('says why, so the tooltip does not have to guess', () {
      expect(
        sheetFor().unavailableReason(CharacterStat.lockpicking),
        allOf(contains('Fighter / Mage'), contains('Open Locks')),
      );
      expect(
        sheetFor(classId: 4).unavailableReason(CharacterStat.lockpicking),
        isNull,
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
