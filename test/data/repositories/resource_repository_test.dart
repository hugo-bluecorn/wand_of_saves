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
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/domain/rules/game_tables.dart';
import 'package:wand_of_saves/domain/skill_catalogue.dart';

void main() {
  /// The shape of BG:EE's own `weapprof.2da`, cut to the rows that matter.
  ///
  /// Copied structurally, not verbatim — the real file has 62 columns. It
  /// keeps the two things that make this table awkward: the `ID` column is
  /// the key rather than the row label, and **two rows share a label**.
  const weapprof = '''
2DA V1.0
0
                 ID   NAME_REF DESC_REF MAGE FIGHTER FIGHTER_MAGE NECROMANCER
SPEAR            3    0        0        0    0       0            0
AXE              6    0        0        0    0       0            0
LONGSWORD        90   25001    34147    0    5       2            0
AXE              92   25003    34149    0    5       2            0
SPEAR            98   25010    34157    0    5       2            0
2WEAPON          114  25023    34176    0    3       3            0
CLUB             115  25009    35442    1    5       2            1
EXTRA2           116  4294967296 4294967296 0 0      0            0
''';

  group('proficienciesFrom', () {
    test('keys on the ID column, not on the row label', () {
      // The `ID` column is what opcode 233 stores in parameter 2, and the
      // label is not unique: BG:EE labels two rows AXE and two SPEAR. Keying
      // on the label would put the obsolete BG1 proficiency 6 in the map and
      // leave 92 — the one the engine actually uses — out of it.
      final catalogue = proficienciesFrom(Table2da.parse(weapprof));

      expect(catalogue[92]?.identifier, 'AXE');
      expect(catalogue[6]?.identifier, 'AXE');
      expect(catalogue[98]?.identifier, 'SPEAR');
      expect(catalogue[3]?.identifier, 'SPEAR');
    });

    test('carries the strref rather than a name', () {
      // Resolving it needs the talk table, which is a different repository —
      // and repositories must never be aware of each other.
      final catalogue = proficienciesFrom(Table2da.parse(weapprof));

      expect(catalogue[114]?.nameStrref, 25023);
      expect(catalogue[114]?.name, isNull);
    });

    test('drops a strref no talk table could hold', () {
      // The unused rows carry 4294967296, which is 2^32 — larger than any
      // strref and not a mistake to pass on to a lookup.
      final catalogue = proficienciesFrom(Table2da.parse(weapprof));

      expect(catalogue[116]?.nameStrref, isNull);
    });

    test('carries the per-class pip ceiling the table itself states', () {
      // The game's own answer to "how many pips may this character have",
      // which is the only source for it — IESDP states no range for opcode
      // 233's Amount. A Fighter/Mage caps at 3 in Two-Weapon Style, and Aard
      // is a Fighter/Mage with 2, so the run that raises him to 3 is legal
      // and 4 would not be.
      final catalogue = proficienciesFrom(Table2da.parse(weapprof));

      expect(catalogue[114]?.maximumFor('FIGHTER_MAGE'), 3);
      expect(catalogue[114]?.maximumFor('FIGHTER'), 3);
      expect(catalogue[90]?.maximumFor('FIGHTER'), 5);
      expect(catalogue[90]?.maximumFor('FIGHTER_MAGE'), 2);
      expect(catalogue[90]?.maximumFor('MAGE'), 0);
    });

    test('answers nothing for a column the table does not have', () {
      // A kit the player's file does not list must produce no ceiling rather
      // than a zero, because zero would silently refuse every edit.
      final catalogue = proficienciesFrom(Table2da.parse(weapprof));

      expect(catalogue[114]?.maximumFor('DWARVEN_DEFENDER'), isNull);
      expect(catalogue[114]?.maximumFor(null), isNull);
    });

    test('is empty for a table that is not one', () {
      expect(proficienciesFrom(Table2da.parse('not a 2da')).entries, isEmpty);
    });
  });

  group('withNames', () {
    test('fills in the names the talk table resolved', () {
      final catalogue = proficienciesFrom(
        Table2da.parse(weapprof),
      ).withNames({25023: 'Two-Weapon Style', 25001: 'Long Sword'});

      expect(catalogue[114]?.name, 'Two-Weapon Style');
      expect(catalogue[90]?.name, 'Long Sword');
      // Unresolved stays unresolved rather than becoming an empty string.
      expect(catalogue[3]?.name, isNull);
    });

    test('keeps the identifiers and the ceilings', () {
      final catalogue = proficienciesFrom(
        Table2da.parse(weapprof),
      ).withNames({25023: 'Two-Weapon Style'});

      expect(catalogue[114]?.identifier, '2WEAPON');
      expect(catalogue[114]?.maximumFor('FIGHTER_MAGE'), 3);
    });
  });

  /// The shape of BG:EE's `thiefscl.2da`, cut to the columns that matter.
  ///
  /// Rows are the thief skills, columns are the **same** `CLASS.IDS`-and-kit
  /// vocabulary `weapprof.2da` uses, and the cell is the percentage of skill
  /// points that class may put into that skill. `0` means the class does not
  /// have the skill at all.
  ///
  /// `STEALTH` is in the real file and is zero for every class; it has no
  /// creature-record field and nothing reads it.
  const thiefscl = '''
2DA V1.0
0
                MAGE FIGHTER THIEF BARD RANGER FIGHTER_MAGE BLADE SHADOWDANCER
PICK_POCKETS    0    0       100   100  0      0            50    100
OPEN_LOCKS      0    0       100   0    0      0            0     100
FIND_TRAPS      0    0       100   0    0      0            0     100
MOVE_SILENTLY   0    0       100   0    100    0            0     100
HIDE_IN_SHADOWS 0    0       100   0    100    0            0     100
DETECT_ILLUSION 0    0       100   0    0      0            0     100
SET_TRAPS       0    0       100   0    0      0            0     0
STEALTH         0    0       0     0    0      0            0     0
''';

  group('thiefSkillsFrom', () {
    test('a thief may allocate every skill', () {
      final skills = thiefSkillsFrom(Table2da.parse(thiefscl));

      for (final row in [
        'PICK_POCKETS',
        'OPEN_LOCKS',
        'FIND_TRAPS',
        'MOVE_SILENTLY',
        'HIDE_IN_SHADOWS',
        'DETECT_ILLUSION',
        'SET_TRAPS',
      ]) {
        expect(skills.allowanceFor(row, 'THIEF'), 100, reason: row);
      }
    });

    test('a fighter/mage may allocate none of them', () {
      // The defect this whole slice exists for: the panel was offering all
      // seven to Aard, who cannot have any.
      final skills = thiefSkillsFrom(Table2da.parse(thiefscl));

      for (final row in ['OPEN_LOCKS', 'FIND_TRAPS', 'PICK_POCKETS']) {
        expect(skills.allowanceFor(row, 'FIGHTER_MAGE'), 0, reason: row);
      }
    });

    test('other classes get a subset, not all or nothing', () {
      // What makes this a table rather than a boolean. A bard picks pockets
      // and nothing else; a ranger sneaks and does not pick locks.
      final skills = thiefSkillsFrom(Table2da.parse(thiefscl));

      expect(skills.allowanceFor('PICK_POCKETS', 'BARD'), 100);
      expect(skills.allowanceFor('OPEN_LOCKS', 'BARD'), 0);
      expect(skills.allowanceFor('MOVE_SILENTLY', 'RANGER'), 100);
      expect(skills.allowanceFor('OPEN_LOCKS', 'RANGER'), 0);
    });

    test('a kit is a column of its own, and may differ from its class', () {
      // A Blade is a bard who picks pockets at half rate; a Shadowdancer is a
      // thief who cannot set traps. Neither is derivable from the base class.
      final skills = thiefSkillsFrom(Table2da.parse(thiefscl));

      expect(skills.allowanceFor('PICK_POCKETS', 'BLADE'), 50);
      expect(skills.allowanceFor('SET_TRAPS', 'SHADOWDANCER'), 0);
      expect(skills.allowanceFor('OPEN_LOCKS', 'SHADOWDANCER'), 100);
    });

    test('an unknown column answers null, never zero', () {
      // The distinction that keeps a missing table from silently forbidding
      // every edit — the same one ProficiencyEntry.maximumFor makes.
      final skills = thiefSkillsFrom(Table2da.parse(thiefscl));

      expect(skills.allowanceFor('OPEN_LOCKS', 'DWARVEN_DEFENDER'), isNull);
      expect(skills.allowanceFor('OPEN_LOCKS', null), isNull);
      expect(skills.allowanceFor(null, 'THIEF'), isNull);
    });

    test('is empty for a table that is not one', () {
      expect(thiefSkillsFrom(Table2da.parse('nope')).allowanceByRow, isEmpty);
    });
  });

  group('ResourceRepository', () {
    // Resolved here rather than in `setUpAll`, because `skip:` is read when
    // the test is *registered* and every setUp has yet to run.
    final game = const GameProfileService().findGameDirectory();

    test(
      "reads the player's own weapprof.2da",
      () {
        // ⚠️ **The reason D11 exists.** IESDP ships the BG2:EE copy of this
        // file, whose NAME_REF for Two-Weapon Style is 31138 — which in the
        // player's talk table reads "While in temples, talk to the priests as
        // you would an innkeeper...". The player's own file says 25023.
        //
        // Nothing about that is visible in the data: both files parse, both
        // have a NAME_REF column, both give a plausible integer.
        final catalogue = ResourceRepository(
          const GameProfileService(),
        ).proficiencies();

        expect(
          catalogue,
          completion(
            isA<ProficiencyCatalogue>()
                .having((c) => c[114]?.identifier, '114', '2WEAPON')
                .having((c) => c[114]?.nameStrref, 'strref', 25023)
                .having((c) => c[114]?.maximumFor('FIGHTER_MAGE'), 'cap', 3),
          ),
        );
      },
      skip: game == null ? 'no BG:EE installation on this machine' : false,
    );

    test(
      "reads the player's own thiefscl.2da",
      () {
        // The two readings that make this a measurement rather than a parse:
        // a Fighter/Mage has none of the seven, and a Thief has all of them.
        // Anything that got the column vocabulary wrong would answer null for
        // both, and anything that got the rows wrong would answer neither.
        final skills = ResourceRepository(
          const GameProfileService(),
        ).thiefSkills();

        expect(
          skills,
          completion(
            isA<SkillCatalogue>()
                .having(
                  (s) => [
                    for (final row in [
                      'PICK_POCKETS',
                      'OPEN_LOCKS',
                      'FIND_TRAPS',
                      'MOVE_SILENTLY',
                      'HIDE_IN_SHADOWS',
                      'DETECT_ILLUSION',
                      'SET_TRAPS',
                    ])
                      s.allowanceFor(row, 'FIGHTER_MAGE'),
                  ],
                  'every skill for a fighter/mage',
                  everyElement(0),
                )
                .having(
                  (s) => s.allowanceFor('OPEN_LOCKS', 'THIEF'),
                  'open locks for a thief',
                  100,
                )
                .having(
                  (s) => s.allowanceFor('PICK_POCKETS', 'BARD'),
                  'pick pockets for a bard',
                  100,
                ),
          ),
        );
      },
      skip: game == null ? 'no BG:EE installation on this machine' : false,
    );

    test('degrades to empty when the installation is not there', () {
      // The app opens saves on machines with no game installed. That is an
      // ordinary state, not an error — the panel shows pip counts and skips
      // the names.
      final catalogue = ResourceRepository(
        const GameProfileService(gameCandidates: ['/nowhere'], environment: {}),
      );

      expect(
        catalogue.proficiencies(),
        completion(
          isA<ProficiencyCatalogue>().having(
            (c) => c.entries,
            'entries',
            isEmpty,
          ),
        ),
      );
      expect(
        catalogue.thiefSkills(),
        completion(
          isA<SkillCatalogue>().having(
            (s) => s.allowanceByRow,
            'rows',
            isEmpty,
          ),
        ),
      );
    });
  });

  group('savingThrowTablesFrom', () {
    /// `savewar.2da`'s first three levels, in the real file's own shape.
    const savewar = '''
2DA V1.0
0
                        1   2   3
DEATH                   14  14  13
WANDS                   16  16  15
POLY                    15  15  14
BREATH                  17  17  16
SPELL                   17  17  16
''';

    /// `savewiz.2da`'s, which differ in every category but DEATH.
    const savewiz = '''
2DA V1.0
0
       1      2      3
DEATH  14     14     14
WANDS  11     11     11
POLY   13     13     13
BREATH 15     15     15
SPELL  12     12     12
''';

    test('a table becomes one list per category, level 1 first', () {
      final tables = savingThrowTablesFrom({
        'savewar': Table2da.parse(savewar),
      });

      expect(tables.rowsByTable['SAVEWAR']?['DEATH'], [14, 14, 13]);
      expect(tables.rowsByTable['SAVEWAR']?['SPELL'], [17, 17, 16]);
    });

    test('the levels come back in column order, not in file order', () {
      // The columns are numbered, and a map's iteration order is not a
      // promise. Reading them as `1`, `2`, `3` is what makes the list index
      // the level.
      final tables = savingThrowTablesFrom({
        'savewiz': Table2da.parse(savewiz),
      });

      expect(tables.at(table: GameTable.savesWizard, level: 1)?.wands, 11);
      expect(tables.at(table: GameTable.savesWizard, level: 3)?.spells, 12);
    });

    test('the table name is uppercased, whatever the resref was', () {
      final tables = savingThrowTablesFrom({
        'savewar': Table2da.parse(savewar),
      });

      expect(tables.rowsByTable.keys, contains('SAVEWAR'));
    });

    test('a table that would not parse is left out rather than half-read', () {
      final tables = savingThrowTablesFrom({
        'savewar': Table2da.parse(savewar),
        'savewiz': Table2da.parse('not a 2da'),
      });

      expect(tables.rowsByTable.keys, ['SAVEWAR']);
    });

    test('nothing read is empty, not an exception', () {
      expect(savingThrowTablesFrom(const {}).isEmpty, isTrue);
    });
  });
}
