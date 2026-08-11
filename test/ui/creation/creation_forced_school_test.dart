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

/// The school a character is given without being asked.
///
/// ⚠️ **Measured 2026-08-11.** A Gnome Cleric/Illusionist made in BG:EE's own
/// flow gets **no specialisation screen** — the game goes straight from class
/// to alignment — and the record it writes nonetheless holds
/// `kit = 0x04000000`, which is `MAGESCHOOL_ILLUSIONIST`.
///
/// The choice is a lookup, not a rule: `clsrcreq.2da`'s `GNOME` column allows
/// exactly one mage school. Only the *forcing* is a rule, and it is justified
/// by the engine writing a kit nobody asked for.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/ui/creation/creation_viewmodel.dart';

void main() {
  const gnome = 6;
  const elf = 2;
  const mage = 1;

  const clericMage = CreationChoice(value: 14, identifier: 'CLERIC_MAGE');
  const fighterMage = CreationChoice(value: 7, identifier: 'FIGHTER_MAGE');
  const fighterThief = CreationChoice(value: 8, identifier: 'FIGHTER_THIEF');
  const mageClass = CreationChoice(value: mage, identifier: 'MAGE');

  const illusionist = CreationChoice(
    value: 0x04000000,
    identifier: 'ILLUSIONIST',
  );
  const abjurer = CreationChoice(value: 0x00400000, identifier: 'ABJURER');

  const catalogue = CreationCatalogue(
    races: [],
    classesByRace: {},
    kitsByClass: {
      mage: [illusionist, abjurer],
    },
    alignmentsByRow: {},
    adjustmentsByRace: {},
    // `mschool.2da` numbering: what makes a kit a *school* rather than a kit.
    schoolByKit: {'ILLUSIONIST': 5, 'ABJURER': 1},
    // ⚠️ The rows `clsrcreq` holds for kits, which used to be dropped on the
    // floor. A gnome is allowed exactly one school; an elf is allowed both.
    kitsAllowedByRace: {
      gnome: {'ILLUSIONIST'},
      elf: {'ILLUSIONIST', 'ABJURER'},
    },
  );

  CreationState stateFor({
    required int raceId,
    required CreationChoice characterClass,
  }) => CreationState(
    catalogue: catalogue,
    race: CreationChoice(value: raceId, identifier: 'RACE'),
    characterClass: characterClass,
  );

  group('a school given without asking', () {
    test('a gnome Cleric/Mage is an Illusionist', () {
      final state = stateFor(raceId: gnome, characterClass: clericMage);

      expect(state.specialisationToWrite?.identifier, 'ILLUSIONIST');
      expect(state.specialisationToWrite?.value, 0x04000000);
    });

    test('and so is a gnome Fighter/Mage', () {
      final state = stateFor(raceId: gnome, characterClass: fighterMage);

      expect(state.specialisationToWrite?.identifier, 'ILLUSIONIST');
    });

    test('an elf Fighter/Mage is forced into nothing', () {
      // Two schools are open to an elf, so there is no single answer to give
      // unasked — and the engine's own Aurel, an elf Fighter/Mage, stores
      // TRUECLASS.
      final state = stateFor(raceId: elf, characterClass: fighterMage);

      expect(state.specialisationToWrite, isNull);
    });

    test('a multi-class with no mage in it is forced into nothing', () {
      final state = stateFor(raceId: gnome, characterClass: fighterThief);

      expect(state.specialisationToWrite, isNull);
    });

    test('a single-class mage is asked, not told', () {
      // ⚠️ The kit *step* exists for a single-class mage, so forcing would take
      // a choice away. What the race does there is narrow the list.
      final state = stateFor(raceId: gnome, characterClass: mageClass);

      expect(state.specialisationToWrite, isNull);
    });

    test('the chosen specialisation still wins where one was chosen', () {
      const state = CreationState(
        catalogue: catalogue,
        race: CreationChoice(value: gnome, identifier: 'GNOME'),
        characterClass: mageClass,
        specialisation: abjurer,
      );

      expect(state.specialisationToWrite, abjurer);
    });
  });

  group('the kit list a race may pick from', () {
    test('a gnome mage is offered only the school the game allows', () {
      // Currently every school is offered to every race, which is a second way
      // the same table was being ignored.
      final state = stateFor(raceId: gnome, characterClass: mageClass);

      expect(
        state.specialisationsAvailable
            .where((c) => c != CreationChoice.noSpecialisation)
            .map((c) => c.identifier),
        ['ILLUSIONIST'],
      );
    });

    test('an elf mage is offered both', () {
      final state = stateFor(raceId: elf, characterClass: mageClass);

      expect(
        state.specialisationsAvailable
            .where((c) => c != CreationChoice.noSpecialisation)
            .map((c) => c.identifier),
        ['ILLUSIONIST', 'ABJURER'],
      );
    });
  });

  group('against the player’s own installation', () {
    // ⚠️ **The fixture above is synthetic, and that has been the trap all day**
    // — three defects in a row were true of a fixture and false of the real
    // tables. `clsrcreq.2da` is the thing being trusted here, so it is read.
    const profile = GameProfileService();
    final installed = profile.findGameDirectory() != null;
    const why = 'no Baldur’s Gate installation';
    const rules = GeneratedGameRules();
    final resources = ResourceRepository(profile);

    Future<CreationState> real({
      required int raceId,
      required String classIdentifier,
    }) async {
      final catalogue = await resources.creationCatalogue(rules: rules);
      return CreationState(
        catalogue: catalogue,
        race: CreationChoice(value: raceId, identifier: 'RACE'),
        characterClass: CreationChoice(
          value: rules.classIdFor(classIdentifier) ?? 0,
          identifier: classIdentifier,
        ),
      );
    }

    test(
      'a gnome Cleric/Mage is written as an Illusionist, as the engine writes '
      'it',
      () async {
        // The engine's own Gnome Cleric/Illusionist stores 0x04000000, and
        // that fixture is `000000102-Gnome Start`.
        final state = await real(raceId: 6, classIdentifier: 'CLERIC_MAGE');

        expect(state.specialisationToWrite?.identifier, 'ILLUSIONIST');
        expect(state.specialisationToWrite?.value, 0x04000000);
      },
      skip: installed ? false : why,
    );

    test(
      'an elf Fighter/Mage is forced into nothing, as Aurel stores',
      () async {
        // BG:EE's own Aurel is an elf Fighter/Mage holding TRUECLASS, and the
        // golden test asserts we match him. This is that from the other side.
        final state = await real(raceId: 2, classIdentifier: 'FIGHTER_MAGE');

        expect(state.specialisationToWrite, isNull);
      },
      skip: installed ? false : why,
    );
  });
}
