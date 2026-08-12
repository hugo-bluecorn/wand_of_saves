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

/// How many pips may go into one proficiency, and whose column decides.
///
/// ⚠️ **Engine-confirmed, 2026-08-11.** A thief in BG:EE's own creation flow
/// was refused a second pip in Short Sword with a slot still unspent. The cap
/// is the **lower** of `profsmax.2da`'s `FIRST_LEVEL` -- which is `2` for every
/// row in the file -- and the `weapprof.2da` class column, which gives a cleric
/// or a thief `1`.
///
/// ⚠️ **And the column is not simply the kit's.** Both halves were measured:
/// `SWASHBUCKLER` is 2 where `THIEF` is 1, so a single-class kit's column
/// governs; but `ILLUSIONIST` is **0** for War Hammer where `CLERIC_MAGE` is 1,
/// and the engine gave a Gnome Cleric/Illusionist a hammer and a flail.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/ui/creation/creation_viewmodel.dart';

void main() {
  const warHammer = 97;
  const shortSword = 91;

  const thief = CreationChoice(value: 4, identifier: 'THIEF');
  const swashbuckler = CreationChoice(
    value: 0x40130000,
    identifier: 'SWASHBUCKLER',
  );
  const clericMage = CreationChoice(value: 14, identifier: 'CLERIC_MAGE');
  const illusionist = CreationChoice(
    value: 0x04000000,
    identifier: 'ILLUSIONIST',
  );

  // The numbers are this installation's own, dumped from weapprof.2da.
  const catalogue = CreationCatalogue(
    races: [],
    classesByRace: {},
    kitsByClass: {},
    alignmentsByRow: {},
    adjustmentsByRace: {},
    proficiencySlotsByClass: {'THIEF': 2, 'CLERIC_MAGE': 2},
    // profsmax gives every row 2. That is the trap: alone it says a thief may
    // specialise, and the engine refuses.
    proficiencyRankCapsByClass: {
      'THIEF': 2,
      'CLERIC_MAGE': 2,
      'SWASHBUCKLER': 2,
      'ILLUSIONIST': 2,
    },
    proficiencies: ProficiencyCatalogue({
      shortSword: ProficiencyEntry(
        id: shortSword,
        identifier: 'SHORTSWORD',
        nameStrref: 25002,
        maximumByColumn: {
          'THIEF': 1,
          'SWASHBUCKLER': 2,
          'CLERIC_MAGE': 0,
          'ILLUSIONIST': 0,
        },
      ),
      warHammer: ProficiencyEntry(
        id: warHammer,
        identifier: 'WARHAMMER',
        nameStrref: 25008,
        maximumByColumn: {
          'THIEF': 0,
          'SWASHBUCKLER': 0,
          'CLERIC_MAGE': 1,
          'ILLUSIONIST': 0,
        },
      ),
    }),
  );

  CreationState stateFor({
    required CreationChoice characterClass,
    CreationChoice? kit,
  }) => CreationState(
    catalogue: catalogue,
    characterClass: characterClass,
    specialisation: kit,
  );

  group('the cap on one proficiency', () {
    test('a thief may only become Proficient, not Specialised', () {
      // The defect exactly as the engine showed it: profsmax says 2, weapprof
      // says 1, and the game refuses the second pip.
      final state = stateFor(characterClass: thief);

      expect(state.rankCapFor(shortSword), 1);
    });

    test('a Swashbuckler may specialise where a plain Thief may not', () {
      // ⚠️ The kit's column genuinely wins when the kit *is* the whole class,
      // which is why "always use the class column" would be wrong.
      final state = stateFor(characterClass: thief, kit: swashbuckler);

      expect(state.rankCapFor(shortSword), 2);
    });

    test('a multi-class takes its class column, not its school’s', () {
      // ⚠️ The other half. `ILLUSIONIST` forbids a war hammer outright; the
      // engine gave the gnome one, on the `CLERIC_MAGE` column.
      final state = stateFor(characterClass: clericMage, kit: illusionist);

      expect(state.rankCapFor(warHammer), 1);
      expect(
        state.proficienciesAvailable.map((e) => e.id),
        contains(warHammer),
      );
    });

    test('never exceeds the level cap, however generous the column', () {
      // profsmax is the *level* ceiling and weapprof the *class* one; the
      // answer is the lower. A fighter's 5 is Grand Mastery, not a level-1
      // entitlement.
      final state = stateFor(characterClass: thief, kit: swashbuckler);

      expect(state.rankCapFor(shortSword), lessThanOrEqualTo(2));
    });
  });
}
