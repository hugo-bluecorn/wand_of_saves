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

/// The thief-skills step: forty points, and only the skills the class has.
///
/// ⚠️ **The gap this closes.** The game hands a new Thief 40 points to spread
/// across seven skills and our wizard never asked, so every Thief this
/// application created started with zero in all of them — visible on the first
/// locked door.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/domain/skill_catalogue.dart';
import 'package:wand_of_saves/ui/creation/creation_viewmodel.dart';

void main() {
  const thief = 4;
  const fighter = 2;
  const thiefChoice = CreationChoice(value: thief, identifier: 'THIEF');
  const fighterChoice = CreationChoice(value: fighter, identifier: 'FIGHTER');

  /// `thiefscl.2da`'s shape: a row per skill, a column per class.
  const skills = SkillCatalogue({
    'PICK_POCKETS': {'THIEF': 100, 'FIGHTER': 0, 'BARD': 100},
    'OPEN_LOCKS': {'THIEF': 100, 'FIGHTER': 0, 'BARD': 0},
    'FIND_TRAPS': {'THIEF': 100, 'FIGHTER': 0, 'BARD': 0},
    'MOVE_SILENTLY': {'THIEF': 100, 'FIGHTER': 0, 'BARD': 0},
    'HIDE_IN_SHADOWS': {'THIEF': 100, 'FIGHTER': 0, 'BARD': 0},
    'DETECT_ILLUSION': {'THIEF': 100, 'FIGHTER': 0, 'BARD': 0},
    'SET_TRAPS': {'THIEF': 100, 'FIGHTER': 0, 'BARD': 0},
  });

  const catalogue = CreationCatalogue(
    races: [CreationChoice(value: 1, identifier: 'HUMAN')],
    classesByRace: {
      1: [thiefChoice, fighterChoice],
    },
    kitsByClass: {},
    alignmentsByRow: {
      'THIEF': [0x11],
      'FIGHTER': [0x11],
    },
    adjustmentsByRace: {},
    skills: skills,
    thiefSkillPointsByClass: {'THIEF': 40},
  );

  ProviderContainer containerWith() => ProviderContainer.test(
    overrides: [
      creationCatalogueProvider.overrideWith((ref) async => catalogue),
    ],
  );

  /// Starts the notifier and waits for the catalogue to arrive.
  ///
  /// ⚠️ **The await is not optional.** An overridden async provider always
  /// begins in `loading`, so a flow read synchronously sees the empty
  /// catalogue and every table lookup answers nothing.
  Future<CreationViewModel> viewModelOf(ProviderContainer container) async {
    final model = container.read(creationProvider.notifier);
    await container.read(creationCatalogueProvider.future);
    return model;
  }

  group('who is asked at all', () {
    test('a thief is asked, because the table gives them points', () async {
      final container = containerWith();
      (await viewModelOf(container))
        ..chooseRace(const CreationChoice(value: 1, identifier: 'HUMAN'))
        ..chooseClass(thiefChoice);

      expect(
        container.read(creationProvider).steps,
        contains(CreationStep.thiefSkills),
      );
    });

    test('a fighter is not asked, having no row in the table', () async {
      // ⚠️ Absent, not empty. A step that draws nothing is worse than one that
      // never appears — the same rule the specialisation step already follows.
      final container = containerWith();
      (await viewModelOf(container))
        ..chooseRace(const CreationChoice(value: 1, identifier: 'HUMAN'))
        ..chooseClass(fighterChoice);

      expect(
        container.read(creationProvider).steps,
        isNot(contains(CreationStep.thiefSkills)),
      );
    });
  });

  group('spending the points', () {
    Future<CreationViewModel> aThief(ProviderContainer container) async =>
        (await viewModelOf(container))
          ..chooseRace(const CreationChoice(value: 1, identifier: 'HUMAN'))
          ..chooseClass(thiefChoice);

    test('starts with the table’s points, all unspent', () async {
      final container = containerWith();
      await aThief(container);

      final state = container.read(creationProvider);
      expect(state.thiefSkillPoints, 40);
      expect(state.thiefSkillPointsRemaining, 40);
    });

    test('offers only the skills this class may allocate', () async {
      final container = containerWith();
      await aThief(container);

      expect(
        container.read(creationProvider).thiefSkillsAvailable,
        hasLength(7),
      );
    });

    test('allocating spends from the pool', () async {
      final container = containerWith();
      (await aThief(container)).allocateSkill('OPEN_LOCKS', 25);

      final state = container.read(creationProvider);
      expect(state.thiefSkills['OPEN_LOCKS'], 25);
      expect(state.thiefSkillPointsRemaining, 15);
    });

    test('refuses to spend more than the pool holds', () async {
      final container = containerWith();
      (await aThief(container))
        ..allocateSkill('OPEN_LOCKS', 30)
        ..allocateSkill('FIND_TRAPS', 30);

      final state = container.read(creationProvider);
      expect(state.thiefSkills['FIND_TRAPS'], isNull);
      expect(state.thiefSkillPointsRemaining, 10);
    });

    test('refuses a skill the class does not have', () async {
      final container = containerWith();
      (await viewModelOf(container))
        ..chooseRace(const CreationChoice(value: 1, identifier: 'HUMAN'))
        ..chooseClass(fighterChoice)
        ..allocateSkill('OPEN_LOCKS', 5);

      expect(container.read(creationProvider).thiefSkills, isEmpty);
    });

    test('lowering one frees the points again', () async {
      final container = containerWith();
      (await aThief(container))
        ..allocateSkill('OPEN_LOCKS', 30)
        ..allocateSkill('OPEN_LOCKS', 10);

      expect(container.read(creationProvider).thiefSkillPointsRemaining, 30);
    });

    test('the step is answered only when every point is spent', () async {
      // The same rule the proficiency step follows: the engine will not let a
      // character leave the screen with points in hand.
      final container = containerWith();
      final model = await aThief(container);

      expect(
        container.read(creationProvider).answered(CreationStep.thiefSkills),
        isFalse,
      );
      model.allocateSkill('OPEN_LOCKS', 40);
      expect(
        container.read(creationProvider).answered(CreationStep.thiefSkills),
        isTrue,
      );
    });
  });

  test('what is spent becomes stats to write', () async {
    final container = containerWith();
    (await viewModelOf(container))
      ..chooseRace(const CreationChoice(value: 1, identifier: 'HUMAN'))
      ..chooseClass(thiefChoice)
      ..allocateSkill('OPEN_LOCKS', 25)
      ..allocateSkill('PICK_POCKETS', 15);

    expect(container.read(creationProvider).allocatedSkillStats, {
      CharacterStat.lockpicking: 25,
      CharacterStat.pickPockets: 15,
    });
  });
}
