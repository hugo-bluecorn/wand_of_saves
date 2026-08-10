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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/ui/creation/creation_viewmodel.dart';

void main() {
  const human = 1;
  const elf = 2;
  const fighter = 2;
  const paladin = 6;
  const ranger = 12;
  const fighterMage = 7;
  const lawfulGood = 0x11;
  const chaoticGood = 0x31;

  const fighterChoice = CreationChoice(value: fighter, identifier: 'FIGHTER');
  const paladinChoice = CreationChoice(value: paladin, identifier: 'PALADIN');
  const rangerChoice = CreationChoice(value: ranger, identifier: 'RANGER');
  const multiChoice = CreationChoice(
    value: fighterMage,
    identifier: 'FIGHTER_MAGE',
  );
  const kensai = CreationChoice(value: 0x40030000, identifier: 'KENSAI');
  const archer = CreationChoice(value: 0x40070000, identifier: 'FERALAN');

  /// A catalogue shaped like the real one, small enough to reason about.
  const catalogue = CreationCatalogue(
    races: [
      CreationChoice(value: human, identifier: 'HUMAN'),
      CreationChoice(value: elf, identifier: 'ELF'),
    ],
    classesByRace: {
      human: [fighterChoice, paladinChoice, rangerChoice, multiChoice],
      elf: [fighterChoice, rangerChoice, multiChoice],
    },
    kitsByClass: {
      fighter: [kensai],
      ranger: [archer],
    },
    alignmentsByRow: {
      'FIGHTER': [lawfulGood, chaoticGood],
      'PALADIN': [lawfulGood],
      'RANGER': [lawfulGood, chaoticGood],
      'FIGHTER_MAGE': [lawfulGood, chaoticGood],
      // ⚠️ A Kensai may not be chaotic where a plain Fighter may. This is why
      // the specialisation step comes before alignment.
      'KENSAI': [lawfulGood],
    },
    adjustmentsByRace: {},
  );

  ProviderContainer containerWith([
    CreationCatalogue tables = catalogue,
  ]) => ProviderContainer.test(
    overrides: [
      creationCatalogueProvider.overrideWith((ref) async => tables),
    ],
  );

  CreationViewModel viewModelIn(ProviderContainer c) =>
      c.read(creationProvider.notifier);
  CreationState stateIn(ProviderContainer c) => c.read(creationProvider);

  /// Walks the flow so it is sitting **on** the class step, answered so far.
  Future<ProviderContainer> upToClass({int race = human}) async {
    final container = containerWith();
    // Reading the provider starts it; the catalogue arrives asynchronously.
    viewModelIn(container);
    await container.read(creationCatalogueProvider.future);

    final chosen = stateIn(container).catalogue.races.singleWhere(
      (r) => r.value == race,
    );
    viewModelIn(container)
      ..chooseGender(1)
      ..next()
      ..choosePortrait('AJANTIS')
      ..next()
      ..chooseRace(chosen)
      ..next();
    return container;
  }

  group('where it starts', () {
    test('on gender, with nothing chosen and no way forward', () {
      final container = containerWith();

      expect(stateIn(container).step, CreationStep.gender);
      expect(stateIn(container).isCurrentStepAnswered, isFalse);
    });

    test('opens on a catalogue that has already been read', () async {
      // ⚠️ **The regression test for a crash a golden test found.** Seeding the
      // draft with `ref.listen(fireImmediately: true)` fires the callback
      // *during* `build()`, before `state` exists — so the moment the query had
      // already resolved, opening the flow threw `Bad state: Tried to read the
      // state of an uninitialized provider`.
      //
      // Every other test here overrides the query with something that starts
      // life loading, so the null guard skipped the write and the bug could not
      // appear. Resolving it *first* is what reproduces it — and that is the
      // ordinary case, because `isAutoDispose` throws this notifier away on
      // leaving while the query outlives it.
      final container = containerWith();
      await container.read(creationCatalogueProvider.future);

      expect(stateIn(container).catalogue.races, isNotEmpty);
      expect(stateIn(container).step, CreationStep.gender);
    });

    test('the catalogue arrives without the draft passing through a load', () {
      // ⚠️ A *synchronous* notifier on purpose. An AsyncNotifier would make
      // every Back and Next a rebuild through a loading state — the trap
      // `CharacterFileViewModel` already documents for its edit session.
      final container = containerWith();

      expect(stateIn(container), isA<CreationState>());
      expect(stateIn(container).catalogue.races, isEmpty);
    });
  });

  group('moving between steps', () {
    test('refuses to advance until the step is answered', () {
      final container = containerWith();

      viewModelIn(container).next();

      expect(stateIn(container).step, CreationStep.gender);
    });

    test('advances once answered, and back returns', () {
      final container = containerWith();
      final model = viewModelIn(container)
        ..chooseGender(1)
        ..next();
      expect(stateIn(container).step, CreationStep.portrait);

      model.back();
      expect(stateIn(container).step, CreationStep.gender);
    });

    test('the specialisation step is skipped when a class has none', () async {
      final container = await upToClass();
      final model = viewModelIn(container)..chooseClass(multiChoice);

      expect(stateIn(container).steps, isNot(contains(CreationStep.kit)));

      model.next();
      expect(stateIn(container).step, CreationStep.alignment);
    });

    test('the specialisation step is offered when a class has kits', () async {
      final container = await upToClass();
      viewModelIn(container)
        ..chooseClass(fighterChoice)
        ..next();

      expect(stateIn(container).step, CreationStep.kit);
    });
  });

  group('a change upstream invalidates what depended on it', () {
    test('changing race drops a class that race cannot take', () async {
      final container = await upToClass();
      final model = viewModelIn(container)..chooseClass(paladinChoice);

      expect(stateIn(container).characterClass, paladinChoice);

      // An elf may not be a paladin. The choice cannot survive the change.
      model.chooseRace(
        stateIn(container).catalogue.races.singleWhere((r) => r.value == elf),
      );

      expect(stateIn(container).characterClass, isNull);
    });

    test('changing race keeps a class that race can also take', () async {
      final container = await upToClass();
      final elves = stateIn(container).catalogue.races.singleWhere(
        (r) => r.value == elf,
      );
      viewModelIn(container)
        ..chooseClass(fighterChoice)
        ..chooseRace(elves);

      expect(stateIn(container).characterClass, fighterChoice);
    });

    test(
      'changing class drops a specialisation that class does not have',
      () async {
        final container = await upToClass();
        final model = viewModelIn(container)
          ..chooseClass(fighterChoice)
          ..next()
          ..chooseSpecialisation(kensai);

        expect(stateIn(container).specialisation, kensai);

        model.chooseClass(rangerChoice);

        expect(stateIn(container).specialisation, isNull);
      },
    );

    test('choosing a specialisation drops an alignment it forbids', () async {
      final container = await upToClass();
      final model = viewModelIn(container)
        ..chooseClass(fighterChoice)
        ..next()
        ..chooseSpecialisation(CreationChoice.noSpecialisation)
        ..next()
        ..chooseAlignment(chaoticGood);

      expect(stateIn(container).alignmentId, chaoticGood);

      // A Kensai may not be chaotic. The alignment cannot survive.
      model.chooseSpecialisation(kensai);

      expect(stateIn(container).alignmentId, isNull);
      expect(stateIn(container).alignmentsAvailable, [lawfulGood]);
    });
  });

  group('the draft survives things that are none of its business', () {
    test('an invalidated query does not wipe what was chosen', () async {
      // ⚠️ **The regression test for a bug this design was changed to avoid.**
      // Riverpod destroys a provider's state whenever it recomputes, and the
      // portrait step's `Add a portrait…` invalidates a query. Had this
      // ViewModel *watched* the catalogue, importing a picture at step two
      // would have thrown the player back to step one with nothing chosen.
      final container = await upToClass();
      viewModelIn(container).chooseClass(fighterChoice);

      container.invalidate(creationCatalogueProvider);
      await container.read(creationCatalogueProvider.future);

      expect(stateIn(container).characterClass, fighterChoice);
      expect(stateIn(container).step, CreationStep.characterClass);
      expect(stateIn(container).catalogue.races, isNotEmpty);
    });
  });

  group('what it hands to the writer', () {
    test('is incomplete until every step is answered', () async {
      final container = await upToClass();
      expect(stateIn(container).isComplete, isFalse);

      viewModelIn(container)
        ..chooseClass(multiChoice)
        ..next()
        ..chooseAlignment(lawfulGood)
        ..next()
        ..rename('Aurel');

      expect(stateIn(container).isComplete, isTrue);
    });

    test('a name of spaces is not a name', () async {
      final container = await upToClass();
      viewModelIn(container)
        ..chooseClass(multiChoice)
        ..next()
        ..chooseAlignment(lawfulGood)
        ..next()
        ..rename('   ');

      expect(stateIn(container).isComplete, isFalse);
    });
  });
}
