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

/// The projection from a record to the sheet the Workbench draws.
///
/// ⚠️ **Every expectation here is a projected value, not a shape.** A test that
/// only counted sections would pass against a projection that filled every row
/// with zeroes — this project has been bitten by a vacuous test six times in
/// one day. So the numbers are Aard's own, read through tables cut down to the
/// rows the assertions name, and the two cases the whole design exists for are
/// asserted directly: a value the class cannot have staying editable, and a
/// rules ceiling that is not the game's.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/domain/rules/character_sheet.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/domain/rules/rules_tables.dart';
import 'package:wand_of_saves/domain/skill_catalogue.dart';
import 'package:wand_of_saves/ui/character/sheet_projection.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';

import '../../support/fakes.dart';

// The rows Aard's own values need, in the style character_sheet_display_test
// established: a table cut to what the tests ask about, so a row that is not
// here answers null and the projection has to say nothing rather than a number.
const _tables = RulesTables(
  byName: {
    'LOREBON': {
      '18': {'VALUE': 3},
      '9': {'VALUE': 0},
    },
    'INTMOD': {
      '18': {'LEARN_SPELL': 85},
    },
    'STRMOD': {
      '18': {'TO_HIT': 1, 'DAMAGE': 2},
    },
    'STRMODEX': {
      '100': {'TO_HIT': 3, 'DAMAGE': 6},
    },
    'SKILLDEX': {
      '17': {'OPEN_LOCKS': 10},
    },
    'SKILLRAC': {
      'ELF': {'OPEN_LOCKS': 5},
    },
  },
);

const _rules = GeneratedGameRules(rulesTables: _tables);

// `thiefscl.2da`, cut to the two classes these tests use. A Fighter/Mage has
// none of the seven; a Thief has all of them.
const _skills = SkillCatalogue({
  'OPEN_LOCKS': {'THIEF': 100, 'FIGHTER_MAGE': 0},
  'FIND_TRAPS': {'THIEF': 100, 'FIGHTER_MAGE': 0},
  'PICK_POCKETS': {'THIEF': 100, 'FIGHTER_MAGE': 0},
  'MOVE_SILENTLY': {'THIEF': 100, 'FIGHTER_MAGE': 0},
  'HIDE_IN_SHADOWS': {'THIEF': 100, 'FIGHTER_MAGE': 0},
  'DETECT_ILLUSION': {'THIEF': 100, 'FIGHTER_MAGE': 0},
  'SET_TRAPS': {'THIEF': 100, 'FIGHTER_MAGE': 0},
});

/// Three rows of `weapprof.2da`: one Aard has and may have, one he has and may
/// have more of, and one his class caps at nothing.
///
/// ⚠️ **Every entry carries its `nameStrref`, because a real one always does.**
/// `ResourceRepository` reads the strref out of `weapprof.2da` and only then
/// resolves it against the talk table, so a `name` without a `nameStrref` is a
/// shape the installation never produces — and a fixture missing it hid that a
/// row naming nothing is not a proficiency. These are the real strrefs:
/// 25023, 25012, 25014.
const _catalogue = ProficiencyCatalogue({
  114: ProficiencyEntry(
    id: 114,
    identifier: '2WEAPON',
    nameStrref: 25023,
    name: 'Two-Weapon Style',
    maximumByColumn: {'FIGHTER_MAGE': 3, 'THIEF': 1},
  ),
  100: ProficiencyEntry(
    id: 100,
    identifier: 'FLAILMORNINGSTAR',
    nameStrref: 25012,
    name: 'Flail / Morning Star',
    maximumByColumn: {'FIGHTER_MAGE': 5},
  ),
  102: ProficiencyEntry(
    id: 102,
    identifier: 'QUARTERSTAFF',
    nameStrref: 25014,
    name: 'Quarterstaff',
    maximumByColumn: {'FIGHTER_MAGE': 0},
  ),
});

void main() {
  /// Aard, the fixture protagonist: a Fighter/Mage 1/1 elf, Constitution 16,
  /// Dexterity 17, 6/7 hit points, THAC0 20, armour class 10, Lore 3.
  SheetCharacter projected({
    int classId = 7,
    int strength = 18,
    int strengthBonus = 100,
    int constitution = 16,
    int lockpicking = 0,
    SkillCatalogue skills = _skills,
    ProficiencyCatalogue proficiencies = ProficiencyCatalogue.empty,
    GameRules rules = _rules,
  }) {
    final base = fakeCharacter(
      classId: classId,
      strength: strength,
      strengthBonus: strengthBonus,
      constitution: constitution,
    );
    final character = base.copyWith(
      thiefSkills: base.thiefSkills.copyWith(lockpicking: lockpicking),
    );

    return sheetCharacterFrom(
      character: character,
      sheet: CharacterSheet(
        character: character,
        rules: rules,
        proficiencies: proficiencies,
        skills: skills,
      ),
      fileName: '000000100-Party',
    );
  }

  SheetField fieldNamed(SheetCharacter sheet, String label) =>
      sheet.fields.firstWhere((field) => field.label == label);

  group('the heading', () {
    test('names the character, the document and the level as the engine '
        'writes it', () {
      final sheet = projected();

      expect(sheet.name, 'Aard');
      expect(sheet.fileName, '000000100-Party');
      expect(sheet.levelLine, 'Level 1/1');
      expect(sheet.creOffset, 532);
    });

    test('keeps identity as four facts rather than one sentence', () {
      expect(projected().identity, [
        'Male',
        'Elf',
        'Fighter / Mage',
        'Neutral Good',
      ]);
    });

    test('leaves out what the tables cannot name', () {
      // 173 is a genuine gap in CLASS.IDS. Three facts, not a raw number.
      expect(projected(classId: 173).identity, ['Male', 'Elf', 'Neutral Good']);
    });

    test('reports the experience the record holds, and no more', () {
      // ⚠️ The record screen prints `Next Level` beside this, and that needs
      // `xplevel.2da`, which nothing here reads.
      expect(projected().experienceLine, '325 XP');
    });
  });

  group('the sheet the game itself is divided into', () {
    test('is four sections, in the order creation walks them', () {
      expect(projected().sections.map((section) => section.title), [
        'Character',
        'Abilities',
        'Skills',
        'Combat',
      ]);
    });

    test('groups them the way the record screen groups them', () {
      final groups = [
        for (final section in projected().sections)
          for (final group in section.groups) group.title,
      ];

      expect(groups, [
        'Character',
        'Condition',
        'Abilities',
        'Skills',
        'Combat',
        'Resistances',
      ]);
    });

    test('has no separate group of what the game shows', () {
      // It held a second `Lore`, and the same label twice on one sheet is the
      // duplication the UI review found. Every row now carries both.
      final sheet = projected();

      expect(
        sheet.sections.expand((section) => section.groups).map((g) => g.title),
        isNot(contains('What the game shows')),
      );
      expect(
        sheet.fields.where((field) => field.label == 'Lore'),
        hasLength(1),
      );
    });

    test('never shows one label twice', () {
      // An edit is addressed by its stat, but a reader is not: two rows with
      // one label has already shipped once.
      final labels = projected().fields.map((field) => field.label).toList();

      expect(labels.toSet(), hasLength(labels.length));
    });

    test('carries the stat on every row an edit command can reach', () {
      // ⚠️ The whole reason `SheetField.stat` exists: a label is not an
      // identity. Only the computed row has none.
      final withoutStat = [
        for (final field in projected().fields)
          if (field.stat == null) field.label,
      ];

      expect(withoutStat, ['Chance to learn a spell']);
    });
  });

  group('stored beside what the engine draws', () {
    test(
      'maximum hit points show the Constitution bonus and its arithmetic',
      () {
        final field = fieldNamed(projected(), 'Maximum hit points');

        expect(field.stored, '7');
        expect(field.inGame, '9');
        expect(field.differsInGame, isTrue);
        expect(field.arithmetic, 'stored 7, +2/level from Constitution 16');
      },
    );

    test(
      'current hit points say they are clamped, because the engine clamps',
      () {
        final field = fieldNamed(projected(), 'Current hit points');

        expect(field.stored, '6');
        expect(field.inGame, '8');
        expect(field.caveat, contains('Clamped'));
      },
    );

    test('THAC0 is signed as the change it makes, not as the bonus', () {
      // Strength 18/100 gives STRMODEX 3, and the engine prints
      // `Strength Modification: -3` against a base of 20.
      final field = fieldNamed(projected(), 'THAC0 (base)');

      expect(field.stored, '20');
      expect(field.inGame, '17');
      expect(field.arithmetic, 'stored 20, −3 from Strength 18');
    });

    test('armour class reads the effective field, which is the one the engine '
        'reads', () {
      final field = fieldNamed(projected(), 'Armour class (effective)');

      expect(field.stored, '10');
      expect(field.inGame, '7');
      expect(field.arithmetic, 'stored 10, −3 from Dexterity 17');
    });

    test('percentile strength is read out as the game writes it', () {
      expect(fieldNamed(projected(), 'Strength').inGame, '18/00');
    });

    test('attacks per round says nothing new when the byte is a count', () {
      final field = fieldNamed(projected(), 'Attacks per round');

      expect(field.stored, '1');
      expect(field.differsInGame, isFalse);
      expect(field.arithmetic, contains('6 to 10 are halves'));
    });

    test('Lore takes both abilities, and the stored value is the base', () {
      final field = fieldNamed(projected(), 'Lore');

      expect(field.stored, '3');
      expect(field.inGame, '6');
      expect(field.arithmetic, 'stored 3, + Intelligence + Wisdom');
    });

    test('the chance to learn a spell sits beside the score it comes from', () {
      final field = fieldNamed(projected(), 'Chance to learn a spell');

      expect(field.stored, '85');
      expect(field.unit, '%');
      expect(field.editable, isFalse);
      expect(field.source, FieldSource.derived);
      expect(
        fieldNamed(projected(), 'Intelligence').arithmetic,
        '85% chance to learn a spell',
      );
    });
  });

  group('a rule nobody has read shows nothing rather than a number', () {
    // A machine with no game installed: the generated IESDP tables still
    // answer, and everything read from the player's own installation does not.
    const bare = GeneratedGameRules();

    test('no THAC0 in game, and no arithmetic claiming a sum', () {
      final field = fieldNamed(projected(rules: bare), 'THAC0 (base)');

      expect(field.inGame, isNull);
      expect(field.arithmetic, isNull);
    });

    test('no Lore in game', () {
      final field = fieldNamed(projected(rules: bare), 'Lore');

      expect(field.inGame, isNull);
      expect(field.arithmetic, isNull);
    });

    test('the chance to learn a spell is absent, not zero', () {
      final labels = projected(rules: bare).fields.map((f) => f.label);

      expect(labels, isNot(contains('Chance to learn a spell')));
    });

    test('hit points still answer, being generated from IESDP', () {
      expect(
        fieldNamed(projected(rules: bare), 'Maximum hit points').inGame,
        '9',
      );
    });
  });

  group('D14 — who owns the value', () {
    test('the engine’s own fields are marked derived and stay editable', () {
      // ⚠️ **`derived` does NOT mean read-only, and reading it that way would
      // regress a capability proven in game.** D14 measured the *import*
      // boundary: gold and fatigue are reset when a `.chr` is taken into a new
      // game. Editing gold in a running savegame works — confirmed in BG:EE on
      // 2026-08-07, the first end-to-end write this project made. So the mark
      // says the edit is provisional; it does not take the field away.
      for (final label in ['Gold (carried)', 'Fatigue']) {
        final field = fieldNamed(projected(), label);

        expect(field.source, FieldSource.derived, reason: label);
        expect(field.editable, isTrue, reason: label);
        expect(field.enabledUnder(rulesBind: true), isTrue, reason: label);
      }
    });

    test('and they say so, rather than leaving it to the colour', () {
      for (final label in ['Gold (carried)', 'Fatigue']) {
        expect(
          fieldNamed(projected(), label).caveat,
          contains('imported'),
          reason: label,
        );
      }
    });

    test('everything else is the player’s', () {
      final field = fieldNamed(projected(), 'Strength');

      expect(field.editable, isTrue);
      expect(field.source, FieldSource.authored);
    });
  });

  group('D16 — the rules ceiling is not the game’s', () {
    test('a maximum the dice could not roll is beyond the rules and still '
        'playable', () {
      // A Fighter 1 / Mage 1 rolls 10 + 4, split between two classes: 7. The
      // field is a word, so the engine takes 40 without complaint — and did.
      final field = fieldNamed(projected(), 'Maximum hit points');

      expect(field.rulesMaximum, 7);
      expect(field.gameMaximum, 65535);
      expect(field.beyondRules('40'), isTrue);
      expect(field.impossible('40'), isFalse);
      expect(field.impossible('70000'), isTrue);
    });

    test('no rules ceiling is drawn where the rules do not set one', () {
      // ⚠️ Creation cannot roll past 18, but nothing in `CharacterSheet` bounds
      // Strength below the field's own 25, so the row says nothing rather than
      // inventing the tighter limit.
      final field = fieldNamed(projected(), 'Strength');

      expect(field.rulesMaximum, isNull);
      expect(field.gameMaximum, 25);
      expect(field.impossible('26'), isTrue);
    });
  });

  group('a value the class cannot have stays editable', () {
    test('an inherited thief skill is flagged and still accepts input', () {
      // ⚠️ The case the whole verdict exists for. `thiefscl.2da` gives
      // FIGHTER_MAGE 0% of Open Locks, so the rules ceiling is zero and the
      // stored 40 is already past it — and the row must not be locked, because
      // an anomaly you cannot touch is one you cannot correct.
      final sheet = projected(lockpicking: 40);
      final field = fieldNamed(sheet, 'Open Locks');

      expect(field.available, isFalse);
      expect(field.anomalous, isTrue);
      expect(field.enabled, isTrue);
      expect(field.rulesMaximum, 0);
      expect(field.gameMaximum, 255);
      expect(field.beyondRules('40'), isTrue);
      expect(field.impossible('40'), isFalse);
      expect(sheet.anomalies.map((f) => f.label), ['Open Locks']);
    });

    test('the same skill at zero is greyed, and the mode releases it', () {
      final field = fieldNamed(projected(), 'Open Locks');

      expect(field.available, isFalse);
      expect(field.anomalous, isFalse);
      expect(field.enabled, isFalse);
      expect(field.enabledUnder(rulesBind: false), isTrue);
    });

    test('a class that has the skill is not held back', () {
      final field = fieldNamed(projected(classId: 4), 'Open Locks');

      expect(field.available, isTrue);
      expect(field.enabled, isTrue);
      expect(field.rulesMaximum, isNull);
    });

    test('and it says nothing about what the game draws', () {
      // ⚠️ **The engine draws NOTHING for a skill the class cannot allocate**,
      // so claiming a number here is the sheet asserting something false about
      // the one thing it speaks for the engine on. Measured 2026-08-10: a
      // stored 25 and 100 on a Fighter/Mage/Thief both survived the record and
      // the Skills tab showed neither, so the display is class-gated and a
      // stored value alone grants nothing.
      //
      // It rendered `stored 0` beside `in game 25` — 0 + Dexterity + race,
      // computed without asking whether the row is shown at all.
      final greyed = fieldNamed(projected(), 'Open Locks');

      expect(greyed.available, isFalse);
      expect(greyed.inGame, isNull, reason: 'the engine draws no such row');
      expect(greyed.arithmetic, isNull, reason: 'nothing to add up');

      // ⚠️ And an anomaly says nothing either — whether the engine draws a
      // *stored* value on a gated row is not established, so absent rather
      // than invented.
      final anomalous = fieldNamed(projected(lockpicking: 40), 'Open Locks');

      expect(anomalous.anomalous, isTrue);
      expect(anomalous.inGame, isNull);

      // The class that does have it is unaffected, which is what makes this
      // test able to fail rather than pass vacuously.
      final allowed = fieldNamed(projected(classId: 4), 'Open Locks');

      expect(allowed.available, isTrue);
      expect(allowed.inGame, isNotNull);
      expect(allowed.arithmetic, isNotNull);
    });

    test('the group says once what the greyed rows have in common', () {
      expect(
        projected().sections[2].groups.single.note,
        'Fighter / Mage has no thief skills — the greyed rows are what the '
        'class cannot allocate.',
      );
      expect(projected(classId: 4).sections[2].groups.single.note, isNull);
    });

    test('a percentile beside anything but an 18 is an anomaly', () {
      // Measured: a character stored 19/100 and arrived as 19/0. It is junk the
      // engine discards, and junk the record really holds — so it is shown, and
      // it can be zeroed.
      final wrong = fieldNamed(projected(strength: 17), 'Exceptional strength');

      expect(wrong.available, isFalse);
      expect(wrong.anomalous, isTrue);
      expect(wrong.enabled, isTrue);
      expect(
        fieldNamed(projected(), 'Exceptional strength').available,
        isTrue,
      );
    });

    test('the fields with no governing table stay allowed', () {
      // Turn Undead and Tracking have no table anywhere found, so `allows`
      // answers true and the row carries the measured caveat instead.
      for (final label in ['Turn Undead', 'Tracking']) {
        final field = fieldNamed(projected(), label);

        expect(field.available, isTrue, reason: label);
        expect(field.caveat, contains('alone grants nothing'), reason: label);
      }
    });
  });

  group('proficiencies — all of them, not only the ones with pips', () {
    test('every row the catalogue names, in the table’s own order', () {
      final proficiencies = projected(proficiencies: _catalogue).proficiencies;

      expect(proficiencies.map((p) => p.id), [114, 100, 102]);
      expect(proficiencies.map((p) => p.name), [
        'Two-Weapon Style',
        'Flail / Morning Star',
        'Quarterstaff',
      ]);
      // Two the record holds at two pips, and one it does not hold at all.
      expect(proficiencies.map((p) => p.pips), [2, 2, 0]);
      expect(proficiencies.map((p) => p.maximum), [3, 5, 0]);
      // ⚠️ `null` means raising it from zero would append an effect, which
      // resizes the record — so a savegame cannot take it and a `.chr` can.
      expect(proficiencies.map((p) => p.effectOffset), [1340, 1604, null]);
      expect(proficiencies.every((p) => !p.over), isTrue);
    });

    test('more pips than the column allows reads as over its ceiling', () {
      // A Thief caps Two-Weapon Style at 1 in this table and Aard holds 2.
      final proficiency = projected(
        classId: 4,
        proficiencies: _catalogue,
      ).proficiencies.firstWhere((p) => p.id == 114);

      expect(proficiency.maximum, 1);
      expect(proficiency.over, isTrue);
    });

    test('no installation still shows what the record holds', () {
      // ⚠️ An empty catalogue must not erase the pips a character has, and the
      // ceiling must not become zero: that would refuse every edit on the
      // screen and look broken rather than degraded.
      final proficiencies = projected().proficiencies;

      expect(proficiencies.map((p) => p.id), [114, 100]);
      expect(proficiencies.map((p) => p.name), [
        'Proficiency 114',
        'Proficiency 100',
      ]);
      expect(proficiencies.map((p) => p.pips), [2, 2]);
      expect(proficiencies.map((p) => p.maximum), [5, 5]);
    });

    test('a row that names nothing is not a proficiency', () {
      // ⚠️ **Measured, not assumed.** BG:EE's `weapprof.2da` ends with fourteen
      // padding rows labelled `EXTRA2`…`EXTRA15`, IDs 116–129, whose `NAME_REF`
      // is 4294967296 — 2^32, beyond any talk table — and whose every class
      // column is zero. `ResourceRepository` already rejects an out-of-range
      // strref, so they arrive with `nameStrref: null`.
      //
      // They were being offered as fourteen proficiencies, each labelled with
      // its row label — the `FLAILMORNINGSTAR` defect class — and each reading
      // `0/0` with an `at ceiling` tag.
      //
      // ⚠️ The test gates on `nameStrref`, not on `name`: a machine with no
      // game installed resolves no names at all, and must not lose every row.
      final sheet = projected(
        proficiencies: const ProficiencyCatalogue({
          114: ProficiencyEntry(
            id: 114,
            identifier: '2WEAPON',
            nameStrref: 25023,
            name: 'Two-Weapon Style',
            maximumByColumn: {'FIGHTER_MAGE': 3},
          ),
          116: ProficiencyEntry(
            id: 116,
            identifier: 'EXTRA2',
            maximumByColumn: {'FIGHTER_MAGE': 0},
          ),
        }),
      );

      expect(sheet.proficiencies.map((p) => p.id), isNot(contains(116)));
      expect(sheet.proficiencies.map((p) => p.name), isNot(contains('EXTRA2')));
      // The named one survives, so this cannot pass by filtering everything.
      expect(sheet.proficiencies.map((p) => p.id), contains(114));
    });

    test(
      'a proficiency the record holds outside the catalogue is not lost',
      () {
        final sheet = projected(
          proficiencies: const ProficiencyCatalogue({
            102: ProficiencyEntry(
              id: 102,
              identifier: 'QUARTERSTAFF',
              nameStrref: 25014,
              name: 'Quarterstaff',
              maximumByColumn: {'FIGHTER_MAGE': 0},
            ),
          }),
        );

        expect(sheet.proficiencies.map((p) => p.id), [102, 114, 100]);
      },
    );
  });
}
