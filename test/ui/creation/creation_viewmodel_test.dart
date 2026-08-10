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

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/ui/creation/creation_viewmodel.dart';

void main() {
  const human = 1;
  const elf = 2;
  const fighter = 2;
  const mage = 1;
  const paladin = 6;
  const ranger = 12;
  const fighterMage = 7;
  const lawfulGood = 0x11;
  const chaoticGood = 0x31;

  // `weapprof.2da` ids, as the player's own file numbers them.
  const quarterstaff = 102;
  const dagger = 90;
  const twoHandedSword = 105;

  const fighterChoice = CreationChoice(value: fighter, identifier: 'FIGHTER');
  const paladinChoice = CreationChoice(value: paladin, identifier: 'PALADIN');
  const rangerChoice = CreationChoice(value: ranger, identifier: 'RANGER');
  const multiChoice = CreationChoice(
    value: fighterMage,
    identifier: 'FIGHTER_MAGE',
  );
  const mageChoice = CreationChoice(value: mage, identifier: 'MAGE');
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

  /// The same catalogue with every table the last three steps read.
  ///
  /// Numbers copied from the player's own installation: `profs.2da` gives a
  /// mage one slot and a Fighter / Mage four, `profsmax.2da` caps any one at
  /// two, `mxsplwiz.2da` memorises one, and `weapprof.2da` gives a mage `0` in
  /// Two-Handed Sword — which is that table's way of saying "not this class".
  const fullCatalogue = CreationCatalogue(
    races: [
      CreationChoice(value: human, identifier: 'HUMAN'),
      CreationChoice(value: elf, identifier: 'ELF'),
    ],
    classesByRace: {
      human: [fighterChoice, mageChoice, multiChoice],
      elf: [fighterChoice, mageChoice, multiChoice],
    },
    kitsByClass: {
      fighter: [kensai],
    },
    alignmentsByRow: {
      'FIGHTER': [lawfulGood, chaoticGood],
      'MAGE': [lawfulGood, chaoticGood],
      'FIGHTER_MAGE': [lawfulGood, chaoticGood],
      'KENSAI': [lawfulGood],
    },
    adjustmentsByRace: {
      elf: {'MOD_DEX': 1, 'MOD_CON': -1},
    },
    proficiencySlotsByClass: {'MAGE': 1, 'FIGHTER': 4, 'FIGHTER_MAGE': 4},
    proficiencyRankCapsByClass: {
      'MAGE': 2,
      'FIGHTER': 2,
      'FIGHTER_MAGE': 2,
    },
    abilityMinimaByRow: {
      'MAGE': {'INT': 9},
      'FIGHTER': {'STR': 9},
      'FIGHTER_MAGE': {'STR': 9, 'INT': 9},
    },
    abilityMinimaByRace: {
      elf: {'STR': 3, 'DEX': 6, 'CON': 7, 'INT': 8, 'WIS': 3, 'CHR': 8},
      human: {'STR': 3, 'DEX': 3, 'CON': 3, 'INT': 3, 'WIS': 3, 'CHR': 3},
    },
    abilityMaximaByRace: {
      elf: {'STR': 18, 'DEX': 18, 'CON': 18, 'INT': 18, 'WIS': 18, 'CHR': 18},
      human: {
        'STR': 18,
        'DEX': 18,
        'CON': 18,
        'INT': 18,
        'WIS': 18,
        'CHR': 18,
      },
    },
    wizardSpells: [
      SpellChoice(resref: 'SPWI101', school: 2),
      SpellChoice(resref: 'SPWI112', school: 6),
      SpellChoice(resref: 'SPWI114', school: 6),
    ],
    wizardSpellsMemorisable: 1,
    proficiencies: ProficiencyCatalogue({
      quarterstaff: ProficiencyEntry(
        id: quarterstaff,
        identifier: 'QUARTERSTAFF',
        maximumByColumn: {'MAGE': 2, 'FIGHTER': 5, 'FIGHTER_MAGE': 2},
      ),
      dagger: ProficiencyEntry(
        id: dagger,
        identifier: 'DAGGER',
        maximumByColumn: {'MAGE': 2, 'FIGHTER': 5, 'FIGHTER_MAGE': 2},
      ),
      twoHandedSword: ProficiencyEntry(
        id: twoHandedSword,
        identifier: 'TWOHANDEDSWORD',
        maximumByColumn: {'MAGE': 0, 'FIGHTER': 5, 'FIGHTER_MAGE': 2},
      ),
    }),
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
      // ⚠️ **The flow grew, so this walk did too.** `catalogue` gives no
      // proficiency slots and no spell progression, so those two steps are not
      // in this character's list at all — abilities is the one that is, and it
      // needs a roll.
      final container = await upToClass();
      expect(stateIn(container).isComplete, isFalse);

      viewModelIn(container)
        ..chooseClass(multiChoice)
        ..next()
        ..chooseAlignment(lawfulGood)
        ..next()
        ..roll()
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
        ..roll()
        ..next()
        ..rename('   ');

      expect(stateIn(container).isComplete, isFalse);
    });
  });

  group('rolling abilities', () {
    /// The flow sitting on the abilities step, class already chosen.
    Future<ProviderContainer> upToAbilities({
      CreationCatalogue tables = fullCatalogue,
      CreationChoice characterClass = mageChoice,
      int seed = 7,
    }) async {
      final container = ProviderContainer.test(
        overrides: [
          creationCatalogueProvider.overrideWith((ref) async => tables),
          abilityDiceProvider.overrideWithValue(Random(seed)),
        ],
      );
      viewModelIn(container);
      await container.read(creationCatalogueProvider.future);
      final elves = stateIn(
        container,
      ).catalogue.races.singleWhere((r) => r.value == elf);
      viewModelIn(container)
        ..chooseGender(1)
        ..next()
        ..choosePortrait('AJANTIS')
        ..next()
        ..chooseRace(elves)
        ..next()
        ..chooseClass(characterClass)
        ..next()
        ..chooseAlignment(lawfulGood)
        ..next();
      return container;
    }

    test('the step is not answered until something has been rolled', () async {
      final container = await upToAbilities();

      expect(stateIn(container).step, CreationStep.abilities);
      expect(stateIn(container).isCurrentStepAnswered, isFalse);
    });

    test('a roll lands every ability inside what the tables allow', () async {
      final container = await upToAbilities();
      viewModelIn(container).roll();
      final state = stateIn(container);

      for (final ability in CreationAbility.values) {
        final bounds = state.boundsFor(ability);
        expect(
          state.abilities[ability],
          inInclusiveRange(bounds.minimum, bounds.maximum),
          reason: ability.label,
        );
      }
      expect(state.isCurrentStepAnswered, isTrue);
    });

    test('an elf’s Dexterity can never be rolled below seven', () async {
      // The bound the engine prints. Rolled a hundred times rather than once,
      // because a floor that holds on one seed is not a floor.
      final container = await upToAbilities();
      for (var i = 0; i < 100; i++) {
        viewModelIn(container).roll();
        expect(
          stateIn(container).abilities[CreationAbility.dexterity],
          inInclusiveRange(7, 19),
        );
      }
    });

    test('the same seed rolls the same character', () async {
      // What injecting the dice buys: a flow that can be tested at all.
      final first = await upToAbilities();
      final second = await upToAbilities();
      viewModelIn(first).roll();
      viewModelIn(second).roll();

      expect(stateIn(first).abilities, stateIn(second).abilities);
    });

    test('a fresh roll spends everything, so nothing is left over', () async {
      final container = await upToAbilities();
      viewModelIn(container).roll();

      expect(stateIn(container).abilityPointsRemaining, 0);
    });

    test('lowering one ability frees a point for another', () async {
      final container = await upToAbilities();
      viewModelIn(container).roll();
      final before = stateIn(container).abilities[CreationAbility.wisdom]!;

      viewModelIn(container).lowerAbility(CreationAbility.wisdom);

      expect(stateIn(container).abilities[CreationAbility.wisdom], before - 1);
      expect(stateIn(container).abilityPointsRemaining, 1);
    });

    test('a point cannot be spent that was not freed first', () async {
      final container = await upToAbilities();
      viewModelIn(container).roll();
      final before = stateIn(container).abilities[CreationAbility.strength]!;

      viewModelIn(container).raiseAbility(CreationAbility.strength);

      expect(stateIn(container).abilities[CreationAbility.strength], before);
    });

    test('neither button may leave an ability outside its bounds', () async {
      final container = await upToAbilities();
      viewModelIn(container).roll();
      final model = viewModelIn(container);
      final bounds = stateIn(container).boundsFor(CreationAbility.charisma);

      // Free plenty, then push at the ceiling and at the floor.
      for (final ability in CreationAbility.values) {
        for (var i = 0; i < 20; i++) {
          model.lowerAbility(ability);
        }
      }
      for (var i = 0; i < 40; i++) {
        model.raiseAbility(CreationAbility.charisma);
      }

      expect(
        stateIn(container).abilities[CreationAbility.charisma],
        bounds.maximum,
      );
      expect(
        stateIn(container).abilities[CreationAbility.strength],
        stateIn(container).boundsFor(CreationAbility.strength).minimum,
      );
    });

    test('a step with points left over is not answered', () async {
      final container = await upToAbilities();
      viewModelIn(container)
        ..roll()
        ..lowerAbility(CreationAbility.wisdom);

      expect(stateIn(container).isCurrentStepAnswered, isFalse);
    });

    test('store and recall put back the roll that was kept', () async {
      final container = await upToAbilities();
      viewModelIn(container).roll();
      final kept = Map.of(stateIn(container).abilities);

      viewModelIn(container)
        ..storeRoll()
        ..roll()
        ..roll()
        ..recallRoll();

      expect(stateIn(container).abilities, kept);
    });

    test('recall does nothing until something has been stored', () async {
      final container = await upToAbilities();
      viewModelIn(container).roll();
      final rolled = Map.of(stateIn(container).abilities);

      viewModelIn(container).recallRoll();

      expect(stateIn(container).abilities, rolled);
      expect(stateIn(container).hasStoredRoll, isFalse);
    });
  });

  group('spending proficiency pips', () {
    Future<ProviderContainer> upToProficiencies({
      CreationChoice characterClass = mageChoice,
    }) async {
      final container = ProviderContainer.test(
        overrides: [
          creationCatalogueProvider.overrideWith((ref) async => fullCatalogue),
          abilityDiceProvider.overrideWithValue(Random(1)),
        ],
      );
      viewModelIn(container);
      await container.read(creationCatalogueProvider.future);
      final elves = stateIn(
        container,
      ).catalogue.races.singleWhere((r) => r.value == elf);
      viewModelIn(container)
        ..chooseGender(1)
        ..next()
        ..choosePortrait('AJANTIS')
        ..next()
        ..chooseRace(elves)
        ..next()
        ..chooseClass(characterClass)
        ..next()
        ..chooseAlignment(lawfulGood)
        ..next()
        ..roll()
        ..next();
      return container;
    }

    test('a mage gets the one slot profs.2da gives, not a default', () async {
      final container = await upToProficiencies();

      expect(stateIn(container).step, CreationStep.proficiencies);
      expect(stateIn(container).proficiencySlots, 1);
      expect(stateIn(container).proficiencyPipsRemaining, 1);
    });

    test('a Fighter / Mage gets four, which is what Aurel spent', () async {
      final container = await upToProficiencies(characterClass: multiChoice);

      expect(stateIn(container).proficiencySlots, 4);
    });

    test('spending a pip leaves one fewer', () async {
      final container = await upToProficiencies(characterClass: multiChoice);
      viewModelIn(container).raiseProficiency(quarterstaff);

      expect(stateIn(container).proficiencies[quarterstaff], 1);
      expect(stateIn(container).proficiencyPipsRemaining, 3);
    });

    test('⚠️ no more pips than profsmax allows in any one', () async {
      // The cap and the slot count are different tables and different numbers:
      // four to spend, at most two in one proficiency.
      final container = await upToProficiencies(characterClass: multiChoice);
      final model = viewModelIn(container);
      for (var i = 0; i < 5; i++) {
        model.raiseProficiency(quarterstaff);
      }

      expect(stateIn(container).proficiencies[quarterstaff], 2);
      expect(stateIn(container).proficiencyPipsRemaining, 2);
    });

    test('no more pips than there are slots, across all of them', () async {
      final container = await upToProficiencies();
      viewModelIn(container)
        ..raiseProficiency(quarterstaff)
        ..raiseProficiency(dagger);

      expect(stateIn(container).proficiencies[dagger], isNull);
      expect(stateIn(container).proficiencyPipsRemaining, 0);
    });

    test('lowering one gives its pip back', () async {
      final container = await upToProficiencies();
      viewModelIn(container)
        ..raiseProficiency(quarterstaff)
        ..lowerProficiency(quarterstaff);

      expect(stateIn(container).proficiencies[quarterstaff], isNull);
      expect(stateIn(container).proficiencyPipsRemaining, 1);
    });

    test('⚠️ only what the class may actually take is offered', () async {
      // `weapprof.2da` gives a mage 0 in Two-Handed Sword — that column is how
      // the table says "not this class", and offering it would be a control
      // the game does not have.
      final container = await upToProficiencies();
      final offered = stateIn(container).proficienciesAvailable;

      expect(offered.map((p) => p.id), contains(quarterstaff));
      expect(offered.map((p) => p.id), isNot(contains(twoHandedSword)));
    });

    test('a kit’s column governs where it has one', () async {
      // The same precedence a kit's alignments use: the specialisation
      // replaces the class rather than adding to it.
      final container = await upToProficiencies(characterClass: fighterChoice);
      viewModelIn(container);

      expect(stateIn(container).proficiencyColumn, 'FIGHTER');
    });

    test('the step is answered only when every pip is spent', () async {
      final container = await upToProficiencies();
      expect(stateIn(container).isCurrentStepAnswered, isFalse);

      viewModelIn(container).raiseProficiency(quarterstaff);

      expect(stateIn(container).isCurrentStepAnswered, isTrue);
    });
  });

  group('choosing spells', () {
    Future<ProviderContainer> upToSpells({
      CreationChoice characterClass = mageChoice,
    }) async {
      final container = ProviderContainer.test(
        overrides: [
          creationCatalogueProvider.overrideWith((ref) async => fullCatalogue),
          abilityDiceProvider.overrideWithValue(Random(1)),
        ],
      );
      viewModelIn(container);
      await container.read(creationCatalogueProvider.future);
      final elves = stateIn(
        container,
      ).catalogue.races.singleWhere((r) => r.value == elf);
      final model = viewModelIn(container)
        ..chooseGender(1)
        ..next()
        ..choosePortrait('AJANTIS')
        ..next()
        ..chooseRace(elves)
        ..next()
        ..chooseClass(characterClass)
        ..next();
      // A Fighter has kits, so the flow stops to ask; a Mage does not.
      if (stateIn(container).step == CreationStep.kit) {
        model
          ..chooseSpecialisation(CreationChoice.noSpecialisation)
          ..next();
      }
      model
        ..chooseAlignment(lawfulGood)
        ..next()
        ..roll()
        ..next();
      for (var i = 0; i < stateIn(container).proficiencySlots; i++) {
        model
          ..raiseProficiency(quarterstaff)
          ..raiseProficiency(dagger);
      }
      model.next();
      return container;
    }

    test('a mage learns two and memorises one, as the screens say', () async {
      final container = await upToSpells();

      expect(stateIn(container).step, CreationStep.spells);
      expect(stateIn(container).spellsLearnable, 2);
      expect(stateIn(container).spellsMemorisable, 1);
    });

    test('⚠️ a fighter never sees the step at all', () async {
      final container = await upToSpells(characterClass: fighterChoice);

      expect(stateIn(container).steps, isNot(contains(CreationStep.spells)));
      expect(stateIn(container).step, CreationStep.name);
    });

    test('learning a third is refused rather than replacing one', () async {
      final container = await upToSpells();
      viewModelIn(container)
        ..learnSpell('SPWI112')
        ..learnSpell('SPWI114')
        ..learnSpell('SPWI101');

      expect(stateIn(container).knownSpells, ['SPWI112', 'SPWI114']);
    });

    test('a spell may be unlearned by choosing it again', () async {
      final container = await upToSpells();
      viewModelIn(container)
        ..learnSpell('SPWI112')
        ..learnSpell('SPWI112');

      expect(stateIn(container).knownSpells, isEmpty);
    });

    test('⚠️ only a spell in the book may be memorised', () async {
      // The engine's own memorise screen lists the two that were learned and
      // nothing else.
      final container = await upToSpells();
      viewModelIn(container).memoriseSpell('SPWI112');

      expect(stateIn(container).memorisedSpells, isEmpty);
    });

    test('unlearning a spell forgets it was memorised too', () async {
      final container = await upToSpells();
      viewModelIn(container)
        ..learnSpell('SPWI112')
        ..memoriseSpell('SPWI112')
        ..learnSpell('SPWI112');

      expect(stateIn(container).knownSpells, isEmpty);
      expect(stateIn(container).memorisedSpells, isEmpty);
    });

    test('the step is answered only when both counts are met', () async {
      final container = await upToSpells();
      final model = viewModelIn(container)
        ..learnSpell('SPWI112')
        ..learnSpell('SPWI114');
      expect(stateIn(container).isCurrentStepAnswered, isFalse);

      model.memoriseSpell('SPWI114');

      expect(stateIn(container).isCurrentStepAnswered, isTrue);
    });
  });
}
