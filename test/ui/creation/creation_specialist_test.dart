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

/// A specialist mage's own school, and the one they are closed out of.
///
/// ⚠️ **The exclusion is in each spell, not in any table.** Checked and
/// rejected first: `mschool.2da` is the text shown when magic is dispelled,
/// `kitlist.2da` has no such column, and nothing in the installation pairs a
/// school with its opposite. The `SPL` header carries a bit per specialist at
/// `0x1E`, and `spl_exclusion_oracle_test.dart` measures that the eight bits
/// line up with the eight opposed pairs the game plays by.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/ui/creation/creation_viewmodel.dart';

void main() {
  const mage = 1;
  const mageChoice = CreationChoice(value: mage, identifier: 'MAGE');
  const abjurer = CreationChoice(value: 0x40090000, identifier: 'ABJURER');
  const transmuter = CreationChoice(
    value: 0x40100000,
    identifier: 'TRANSMUTER',
  );

  // `mschool.2da`: Abjurer is 1 and Transmuter is 8, and the two are opposed.
  const schools = {'ABJURER': 1, 'TRANSMUTER': 8};

  const catalogue = CreationCatalogue(
    races: [CreationChoice(value: 1, identifier: 'HUMAN')],
    classesByRace: {
      1: [mageChoice],
    },
    kitsByClass: {
      mage: [abjurer, transmuter],
    },
    alignmentsByRow: {
      'MAGE': [0x11],
      'ABJURER': [0x11],
      'TRANSMUTER': [0x11],
    },
    adjustmentsByRace: {},
    schoolByKit: schools,
    wizardSpellsMemorisable: 1,
    wizardSpells: [
      // Armour: an Abjuration spell, which a Transmuter may not learn.
      SpellChoice(resref: 'SPWI103', school: 1, excludedSchools: {8}),
      // Chromatic Orb: Alteration, which an Abjurer may not learn.
      SpellChoice(resref: 'SPWI108', school: 8, excludedSchools: {1}),
      // Magic Missile: Invocation, closed to neither of them.
      SpellChoice(resref: 'SPWI112', school: 6, excludedSchools: {4}),
    ],
  );

  ProviderContainer containerWith() => ProviderContainer.test(
    overrides: [
      creationCatalogueProvider.overrideWith((ref) async => catalogue),
    ],
  );

  Future<CreationViewModel> aMage(
    ProviderContainer container, {
    CreationChoice? kit,
  }) async {
    final model = container.read(creationProvider.notifier);
    await container.read(creationCatalogueProvider.future);
    model
      ..chooseRace(const CreationChoice(value: 1, identifier: 'HUMAN'))
      ..chooseClass(mageChoice);
    if (kit != null) model.chooseSpecialisation(kit);
    return model;
  }

  group('which spells are offered', () {
    test('a plain mage is offered every spell there is', () async {
      final container = containerWith();
      await aMage(container, kit: CreationChoice.noSpecialisation);

      expect(container.read(creationProvider).spellsAvailable, hasLength(3));
    });

    test('an abjurer is not offered the alteration spell', () async {
      final container = containerWith();
      await aMage(container, kit: abjurer);

      expect(
        container.read(creationProvider).spellsAvailable.map((s) => s.resref),
        ['SPWI103', 'SPWI112'],
      );
    });

    test('a transmuter is closed out of the other one', () async {
      // The pair, from the opposite side — which is what makes this the
      // spell's own fact rather than a rule about abjurers.
      final container = containerWith();
      await aMage(container, kit: transmuter);

      expect(
        container.read(creationProvider).spellsAvailable.map((s) => s.resref),
        ['SPWI108', 'SPWI112'],
      );
    });
  });

  group('the spell of their own school', () {
    test('a specialist has not answered until they take one', () async {
      // ⚠️ The game's own spellbook screen requires it, and the flow used to
      // let a specialist finish with none.
      final container = containerWith();
      final model = await aMage(container, kit: abjurer);
      model.learnSpell('SPWI112');

      expect(container.read(creationProvider).hasOwnSchoolSpell, isFalse);

      model.learnSpell('SPWI103');
      expect(container.read(creationProvider).hasOwnSchoolSpell, isTrue);
    });

    test('a plain mage is never held to it', () async {
      final container = containerWith();
      await aMage(container, kit: CreationChoice.noSpecialisation);

      expect(container.read(creationProvider).hasOwnSchoolSpell, isTrue);
    });
  });
}
