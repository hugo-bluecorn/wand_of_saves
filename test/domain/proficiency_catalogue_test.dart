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

/// Which rows of `weapprof.2da` are a proficiency a character may be given.
///
/// ⚠️ **The fixture is the real file's shape, not a convenient one.** BG:EE's
/// copy has three bands and two of them are junk, and a fixture holding only
/// live rows would have passed against the code that shipped `Bow` beside
/// `Long Bow` and fourteen rows called `EXTRA*`. The ids, row labels and
/// strrefs below are the installation's own, read with
/// `fvm dart run tool/dev/dump_table.dart weapprof`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';

void main() {
  // One row from each band, with the file's real values.
  const catalogue = ProficiencyCatalogue({
    // Obsolete BG1 generation: a valid name, a valid description, and a
    // non-zero cap — which is why no column separates it from the live band.
    2: ProficiencyEntry(
      id: 2,
      identifier: 'BOW',
      nameStrref: 8733,
      name: 'Bow',
      maximumByColumn: {'FIGHTER_MAGE': 2},
    ),
    // Live EE generation.
    104: ProficiencyEntry(
      id: 104,
      identifier: 'LONGBOW',
      nameStrref: 25016,
      name: 'Long Bow',
      maximumByColumn: {'FIGHTER_MAGE': 2},
    ),
    105: ProficiencyEntry(
      id: 105,
      identifier: 'SHORTBOW',
      nameStrref: 25017,
      name: 'Short Bow',
      maximumByColumn: {'FIGHTER_MAGE': 2},
    ),
    // Padding: `NAME_REF` is 2^32, which ResourceRepository rejects as out of
    // range, so it arrives with no strref at all and every column zero.
    116: ProficiencyEntry(
      id: 116,
      identifier: 'EXTRA2',
      maximumByColumn: {'FIGHTER_MAGE': 0},
    ),
  });

  group('live', () {
    test('keeps the current generation', () {
      expect(catalogue.live.entries.keys, [104, 105]);
      expect(catalogue.live.entries.values.map((e) => e.name), [
        'Long Bow',
        'Short Bow',
      ]);
    });

    test('drops the padding rows, which name nothing', () {
      expect(catalogue.live[116], isNull);
      // ⚠️ Gated on the strref, not the resolved name: a machine with no
      // installation resolves no names and must degrade, not empty.
      expect(catalogue.entries[116]!.nameStrref, isNull);
    });

    test('drops the obsolete generation, which names something real', () {
      // ⚠️ The point of a separate test. `Bow` has a valid name, a valid
      // description and a cap of 2, so neither the name filter nor a
      // zero-column filter touches it — and it was the user-visible complaint.
      final obsolete = catalogue.entries[2]!;

      expect(obsolete.name, 'Bow');
      expect(obsolete.nameStrref, isNotNull);
      expect(obsolete.maximumFor('FIGHTER_MAGE'), 2);
      expect(catalogue.live[2], isNull);
    });

    test('an empty catalogue stays empty rather than throwing', () {
      expect(ProficiencyCatalogue.empty.live.entries, isEmpty);
    });

    test('holds nothing back that the live band contains', () {
      // A guard on the floor itself: 89 is the lowest id the shipped creature
      // records use, so an entry at exactly 89 must survive.
      const boundary = ProficiencyCatalogue({
        89: ProficiencyEntry(
          id: 89,
          identifier: 'BASTARDSWORD',
          nameStrref: 25000,
          name: 'Bastard Sword',
          maximumByColumn: {'FIGHTER_MAGE': 2},
        ),
      });

      expect(boundary.live.entries.keys, [89]);
    });
  });
}
