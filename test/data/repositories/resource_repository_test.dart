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

    test('degrades to empty when the installation is not there', () {
      // The app opens saves on machines with no game installed. That is an
      // ordinary state, not an error — the panel shows pip counts and skips
      // the names.
      final catalogue = ResourceRepository(
        const GameProfileService(gameCandidates: ['/nowhere'], environment: {}),
      ).proficiencies();

      expect(
        catalogue,
        completion(
          isA<ProficiencyCatalogue>().having(
            (c) => c.entries,
            'entries',
            isEmpty,
          ),
        ),
      );
    });
  });
}
