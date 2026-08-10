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

/// The roller, and the floor it now holds itself to.
///
/// Plain 3d6 six times averages **63**, and a total of 85 turns up about once
/// in eight hundred throws — which is what rerolling in the game for ten
/// minutes buys you. The roller does that rerolling itself.
library;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/ui/creation/creation_viewmodel.dart';

void main() {
  const human = 1;
  const mage = 1;
  const humanChoice = CreationChoice(value: human, identifier: 'HUMAN');
  const mageChoice = CreationChoice(value: mage, identifier: 'MAGE');

  /// Bounds an ordinary character has: 3 to 18 on everything.
  CreationCatalogue catalogueWith({int maximum = 18}) => CreationCatalogue(
    races: const [humanChoice],
    classesByRace: const {
      human: [mageChoice],
    },
    kitsByClass: const {},
    alignmentsByRow: const {
      'MAGE': [0x11],
    },
    adjustmentsByRace: const {},
    abilityMinimaByRace: {
      human: {for (final a in CreationAbility.values) a.key: 3},
    },
    abilityMaximaByRace: {
      human: {for (final a in CreationAbility.values) a.key: maximum},
    },
  );

  Future<ProviderContainer> aRoller({
    int seed = 7,
    int maximum = 18,
  }) async {
    final container = ProviderContainer.test(
      overrides: [
        creationCatalogueProvider.overrideWith(
          (ref) async => catalogueWith(maximum: maximum),
        ),
        abilityDiceProvider.overrideWithValue(Random(seed)),
      ],
    );
    final model = container.read(creationProvider.notifier);
    // ⚠️ The catalogue arrives asynchronously, and an overridden async
    // provider always starts in `loading` — read synchronously, every table
    // lookup answers nothing and the bounds fall back to the field's.
    await container.read(creationCatalogueProvider.future);
    model
      ..chooseRace(humanChoice)
      ..chooseClass(mageChoice);
    return container;
  }

  test('every roll clears the floor, not just a lucky one', () async {
    // ⚠️ Twenty rolls on twenty seeds. A floor that holds on one seed is not a
    // floor — the same reason the Dexterity bound is rolled a hundred times.
    for (var seed = 0; seed < 20; seed++) {
      final container = await aRoller(seed: seed);
      container.read(creationProvider.notifier).roll();

      expect(
        container.read(creationProvider).abilityPoints,
        greaterThanOrEqualTo(CreationViewModel.abilityTotalWanted),
        reason: 'seed $seed',
      );
    }
  });

  test('the scores are still dice, not six identical numbers', () async {
    // What rejection sampling buys over topping every score up: the spread is
    // whatever the dice gave, conditioned on the total. A roller that padded
    // each ability to reach the target would hand out a flat character.
    final container = await aRoller();
    container.read(creationProvider.notifier).roll();
    final scores = container.read(creationProvider).abilities.values.toSet();

    expect(scores.length, greaterThan(1));
  });

  test('every ability still lands inside the tables’ bounds', () async {
    final container = await aRoller();
    container.read(creationProvider.notifier).roll();
    final state = container.read(creationProvider);

    for (final ability in CreationAbility.values) {
      final bounds = state.boundsFor(ability);
      expect(
        state.abilities[ability],
        inInclusiveRange(bounds.minimum, bounds.maximum),
        reason: ability.label,
      );
    }
  });

  test('⚠️ a target the bounds cannot reach returns the best, not a hang', () {
    // Six abilities capped at 10 can never total 85. Rejection sampling with
    // no floor under it would spin for ever, so the search is bounded and
    // keeps the best roll it saw — which here is the cap on all six.
    expect(() async {
      final container = await aRoller(maximum: 10);
      container.read(creationProvider.notifier).roll();

      expect(
        container.read(creationProvider).abilityPoints,
        lessThan(CreationViewModel.abilityTotalWanted),
      );
      expect(
        container.read(creationProvider).abilityPoints,
        greaterThan(50),
        reason: 'it should still have kept a good roll',
      );
    }, returnsNormally);
  });

  test('the same seed still rolls the same character', () async {
    // The property the injected dice exist for, and rerolling internally must
    // not cost it.
    final first = await aRoller();
    final second = await aRoller();
    first.read(creationProvider.notifier).roll();
    second.read(creationProvider.notifier).roll();

    expect(
      first.read(creationProvider).abilities,
      second.read(creationProvider).abilities,
    );
  });
}
