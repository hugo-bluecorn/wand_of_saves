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
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/repositories/string_repository.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/edit_command.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/ui/party/party_viewmodel.dart';

import '../../support/fakes.dart';
import '../../support/synthetic_save.dart';

void main() {
  const slotName = '000000022-last';

  /// A container over a savegame built from [party].
  ///
  /// Real bytes rather than a canned list of characters: the ViewModel loads a
  /// savegame and projects it, so a fake that skipped the bytes would not be
  /// testing the path the app takes.
  ProviderContainer containerWith({
    List<SyntheticCharacter> party = const [],
    Map<int, String> strings = const {},
    StringRepository? stringRepository,
    ResourceRepository? resourceRepository,
    int partyReputationTimesTen = 110,
    bool slotExists = true,
  }) => ProviderContainer.test(
    overrides: [
      saveGameRepositoryProvider.overrideWithValue(
        FakeSaveGameRepository(
          slots: slotExists ? [fakeSlot('last')] : const [],
          gam: GamCodec.decode(
            buildSave(
              party: party,
              partyReputationTimesTen: partyReputationTimesTen,
            ),
          ),
        ),
      ),
      stringRepositoryProvider.overrideWithValue(
        stringRepository ?? FakeStringRepository(strings),
      ),
      resourceRepositoryProvider.overrideWithValue(
        resourceRepository ??
            const FakeResourceRepository(ProficiencyCatalogue.empty),
      ),
    ],
  );

  group('loading', () {
    test('exposes the party behind the slot', () async {
      final container = containerWith(
        party: const [
          SyntheticCharacter(),
          SyntheticCharacter(
            resref: '*IMOEN',
            displayName: 'Imoen',
            partyOrder: 1,
          ),
        ],
      );

      final state = await container.read(partyProvider(slotName).future);

      expect(state.members.map((m) => m.name), ['Aard', 'Imoen']);
      expect(state.slot.label, 'last');
    });

    test('selects the first member so the screen is never blank', () async {
      final container = containerWith(party: const [SyntheticCharacter()]);

      final state = await container.read(partyProvider(slotName).future);

      expect(state.selectedIndex, 0);
      expect(state.selected?.name, 'Aard');
    });

    test('has no selection when the party is empty', () async {
      final container = containerWith();

      final state = await container.read(partyProvider(slotName).future);

      expect(state.members, isEmpty);
      expect(state.selected, isNull);
    });

    test('a slot that is not there lands in the error state', () async {
      // Read the state directly: `.future` completes normally on success but
      // never settles when build() throws.
      final container = containerWith(slotExists: false);

      final subscription = container.listen(partyProvider(slotName), (_, _) {});
      addTearDown(subscription.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(subscription.read().hasError, isTrue);
      expect(
        container.read(partyProvider(slotName)).error,
        isA<SaveNotFoundException>(),
      );
    });
  });

  group('names', () {
    test('uses the name the savegame carries', () async {
      // The protagonist typed their own name, so it cannot be in a file that
      // shipped with the game.
      final strings = FakeStringRepository({9501: 'Minsc'});
      final container = containerWith(
        party: const [SyntheticCharacter()],
        stringRepository: strings,
      );

      final state = await container.read(partyProvider(slotName).future);

      expect(state.members.single.name, 'Aard');
      expect(
        strings.lookups,
        isEmpty,
        reason: 'a name already in the savegame needs no talk table',
      );
    });

    test('resolves an empty name through the talk table', () async {
      // How all 36 recruitable companions are stored: no name in the GAM, a
      // valid strref in the creature record.
      final container = containerWith(
        party: const [
          SyntheticCharacter(
            resref: '*INSC',
            displayName: '',
            nameStrref: 9501,
          ),
        ],
        strings: {9501: 'Minsc'},
      );

      final state = await container.read(partyProvider(slotName).future);

      expect(state.members.single.name, 'Minsc');
    });

    test(
      'falls back to the resref when the strref resolves to nothing',
      () async {
        final container = containerWith(
          party: const [
            SyntheticCharacter(
              resref: '*INSC',
              displayName: '',
              nameStrref: 9501,
            ),
          ],
        );

        final state = await container.read(partyProvider(slotName).future);

        expect(
          state.members.single.name,
          '*INSC',
          reason: 'a resref is information; invented placeholder text is not',
        );
      },
    );

    test(
      'falls back to the resref when there is no talk table at all',
      () async {
        // A machine with saves but no game installed.
        final container = containerWith(
          party: const [
            SyntheticCharacter(
              resref: '*INSC',
              displayName: '',
              nameStrref: 9501,
            ),
          ],
          stringRepository: const AbsentStringRepository(),
        );

        final state = await container.read(partyProvider(slotName).future);

        expect(state.members.single.name, '*INSC');
      },
    );
  });

  group('reputation', () {
    test('comes from the party, not from the creature record', () async {
      // ⚠️ **Measured in game 2026-08-08, and it falsified what the panel
      // said.** In the real four-member save the GAM holds 11.0 and BG:EE
      // prints "Reputation: Average (11)" on Xzar's record screen — while
      // Xzar's own creature record holds 10.0, as do Montaron's and Imoen's.
      // Only the protagonist's copy agreed.
      //
      // So the creature's copy is not what the engine displays, and the panel
      // was showing 10.0 against a game showing 11 with a tooltip asserting
      // the two matched.
      // The party's 11.0 is `buildSave`'s default, because it is the
      // fixture's; only the creature's stale 10.0 needs stating.
      final container = containerWith(
        party: const [
          SyntheticCharacter(reputationTimesTen: 100),
        ],
      );

      final state = await container.read(partyProvider(slotName).future);

      expect(state.reputation, 11.0);
      expect(
        state.members.single.reputation,
        10.0,
        reason: 'the stale copy is still read, it is just not what is shown',
      );
    });
  });

  group('proficiencies', () {
    /// A catalogue answering with the two rows the fixture party needs.
    ///
    /// Strrefs, not names — that is what the resource repository produces,
    /// and resolving them is the merge this group is about.
    ResourceRepository catalogue() => const FakeResourceRepository(
      ProficiencyCatalogue({
        114: ProficiencyEntry(
          id: 114,
          identifier: '2WEAPON',
          nameStrref: 25023,
          maximumByColumn: {'FIGHTER_MAGE': 3},
        ),
        100: ProficiencyEntry(
          id: 100,
          identifier: 'FLAILMORNINGSTAR',
          nameStrref: 25012,
          maximumByColumn: {'FIGHTER_MAGE': 2},
        ),
      }),
    );

    test('names come from the talk table, not from the table of rules', () {
      // Two repositories, merged above both of them: `weapprof.2da` gives the
      // strref and `dialog.tlk` gives the text. A repository reaching sideways
      // for the other is what the layering forbids.
      //
      // ⚠️ 25023 is the *player's* strref. IESDP's copy of this table says
      // 31138, which in a BG:EE talk table is a paragraph about temples.
      final container = containerWith(
        party: const [
          SyntheticCharacter(proficiencies: {114: 2, 100: 2}),
        ],
        strings: const {
          25023: 'Two-Weapon Style',
          25012: 'Flail / Morning Star',
        },
        resourceRepository: catalogue(),
      );

      expect(
        container.read(partyProvider(slotName).future),
        completion(
          isA<PartyState>()
              .having(
                (s) => s.proficiencies[114]?.name,
                '114',
                'Two-Weapon Style',
              )
              .having(
                (s) => s.proficiencies[100]?.name,
                '100',
                'Flail / Morning Star',
              ),
        ),
      );
    });

    test('keeps the per-class ceilings the game states', () async {
      final container = containerWith(
        party: const [
          SyntheticCharacter(proficiencies: {114: 2}),
        ],
        strings: const {25023: 'Two-Weapon Style'},
        resourceRepository: catalogue(),
      );

      final state = await container.read(partyProvider(slotName).future);

      expect(state.proficiencies[114]?.maximumFor('FIGHTER_MAGE'), 3);
    });

    test('a machine with no game installed still loads the party', () async {
      // The panel then shows pip counts with no names and no ceilings, which
      // is a degradation rather than a failure — the app exists to open saves,
      // and it must not need the game to do it.
      final container = containerWith(
        party: const [
          SyntheticCharacter(proficiencies: {114: 2}),
        ],
      );

      final state = await container.read(partyProvider(slotName).future);

      expect(state.proficiencies.entries, isEmpty);
      expect(state.members.single.proficiencies, hasLength(1));
      expect(state.members.single.proficiencies.single.pips, 2);
    });

    test('survives a talk table that cannot answer', () async {
      final container = containerWith(
        party: const [
          SyntheticCharacter(proficiencies: {114: 2}),
        ],
        stringRepository: const AbsentStringRepository(),
        resourceRepository: catalogue(),
      );

      final state = await container.read(partyProvider(slotName).future);

      // The identifier survives, so the panel has something to label the tile
      // with other than a number.
      expect(state.proficiencies[114]?.name, isNull);
      expect(state.proficiencies[114]?.identifier, '2WEAPON');
    });
  });

  group('editing', () {
    /// A container over a real two-member savegame, so an edit is visible in
    /// what comes back rather than being asserted against a canned list.
    (ProviderContainer, FakeSaveGameRepository) editable() {
      final repository = FakeSaveGameRepository(
        slots: [fakeSlot('last')],
        gam: GamCodec.decode(
          buildSave(
            party: const [
              SyntheticCharacter(),
              SyntheticCharacter(
                resref: '*IMOEN',
                displayName: 'Imoen',
                partyOrder: 1,
                strength: 9,
              ),
            ],
          ),
        ),
      );
      return (
        ProviderContainer.test(
          overrides: [
            saveGameRepositoryProvider.overrideWithValue(repository),
            stringRepositoryProvider.overrideWithValue(FakeStringRepository()),
          ],
        ),
        repository,
      );
    }

    PartyViewModel notifierOf(ProviderContainer c) =>
        c.read(partyProvider(slotName).notifier);
    PartyState stateOf(ProviderContainer c) =>
        c.read(partyProvider(slotName)).value!;

    SetCharacterStat strengthOf(PartyState state, int index, int value) =>
        SetCharacterStat(
          creOffset: state.members[index].creOffset,
          stat: CharacterStat.strength,
          value: value,
        );

    test('an edit shows up in the character it changed', () async {
      final (container, _) = editable();
      await container.read(partyProvider(slotName).future);

      notifierOf(container).edit(strengthOf(stateOf(container), 0, 19));

      expect(stateOf(container).members[0].abilities.strength, 19);
      expect(
        stateOf(container).members[1].abilities.strength,
        9,
        reason: 'the other party member must not move',
      );
    });

    test('an edit marks the save dirty', () async {
      final (container, _) = editable();
      await container.read(partyProvider(slotName).future);
      expect(stateOf(container).isDirty, isFalse);

      notifierOf(container).edit(strengthOf(stateOf(container), 0, 19));

      expect(stateOf(container).isDirty, isTrue);
    });

    test('an edit leaves the selection where it was', () async {
      // The reason the savegame lives on this notifier rather than behind a
      // second one: a chained provider rebuilds on every edit, and the
      // selection would snap back to the first character mid-typing.
      final (container, _) = editable();
      await container.read(partyProvider(slotName).future);
      notifierOf(container).select(1);

      notifierOf(container).edit(strengthOf(stateOf(container), 1, 12));

      expect(stateOf(container).selectedIndex, 1);
      expect(stateOf(container).selected?.abilities.strength, 12);
    });

    test('undo puts the old value back and the save becomes clean', () async {
      final (container, _) = editable();
      await container.read(partyProvider(slotName).future);
      notifierOf(container).edit(strengthOf(stateOf(container), 0, 19));

      notifierOf(container).undo();

      expect(stateOf(container).members[0].abilities.strength, 18);
      expect(
        stateOf(container).isDirty,
        isFalse,
        reason: 'undone back to what was loaded means nothing to save',
      );
    });

    test('redo puts the edit back', () async {
      final (container, _) = editable();
      await container.read(partyProvider(slotName).future);
      notifierOf(container).edit(strengthOf(stateOf(container), 0, 19));
      notifierOf(container).undo();

      notifierOf(container).redo();

      expect(stateOf(container).members[0].abilities.strength, 19);
      expect(stateOf(container).isDirty, isTrue);
    });

    test('a fresh edit abandons the redo stack', () async {
      // Anything else lets redo reapply an edit onto a history it was never
      // taken from.
      final (container, _) = editable();
      await container.read(partyProvider(slotName).future);
      notifierOf(container).edit(strengthOf(stateOf(container), 0, 19));
      notifierOf(container).undo();

      notifierOf(container).edit(strengthOf(stateOf(container), 0, 14));

      expect(stateOf(container).canRedo, isFalse);
      expect(stateOf(container).members[0].abilities.strength, 14);
    });

    test('reports what undo and redo can do', () async {
      final (container, _) = editable();
      await container.read(partyProvider(slotName).future);
      expect(stateOf(container).canUndo, isFalse);
      expect(stateOf(container).canRedo, isFalse);

      notifierOf(container).edit(strengthOf(stateOf(container), 0, 19));
      expect(stateOf(container).canUndo, isTrue);
      expect(stateOf(container).canRedo, isFalse);

      notifierOf(container).undo();
      expect(stateOf(container).canUndo, isFalse);
      expect(stateOf(container).canRedo, isTrue);
    });

    test('undo and redo do nothing when there is nothing to do', () async {
      final (container, _) = editable();
      await container.read(partyProvider(slotName).future);

      notifierOf(container)
        ..undo()
        ..redo();

      expect(stateOf(container).members[0].abilities.strength, 18);
      expect(stateOf(container).isDirty, isFalse);
    });

    test(
      'save writes the edited savegame and the save becomes clean',
      () async {
        final (container, repository) = editable();
        await container.read(partyProvider(slotName).future);
        notifierOf(container).edit(strengthOf(stateOf(container), 0, 19));

        await notifierOf(container).save();

        expect(repository.written, hasLength(1));
        expect(
          CreCodec.decode(
            repository.written.single.partyMembers.first.creBytes,
          ).strength,
          19,
        );
        expect(stateOf(container).isDirty, isFalse);
      },
    );

    test('saving with nothing changed writes nothing', () async {
      // The file's timestamp is what the browser sorts by, so an idle save
      // would reorder the grid for no reason.
      final (container, repository) = editable();
      await container.read(partyProvider(slotName).future);

      await notifierOf(container).save();

      expect(repository.written, isEmpty);
    });
  });

  group('select', () {
    test('moves the selection', () async {
      final container = containerWith(
        party: const [
          SyntheticCharacter(),
          SyntheticCharacter(displayName: 'Imoen', partyOrder: 1),
        ],
      );
      await container.read(partyProvider(slotName).future);

      container.read(partyProvider(slotName).notifier).select(1);

      expect(
        container.read(partyProvider(slotName)).value?.selected?.name,
        'Imoen',
      );
    });

    test('ignores an index outside the party', () async {
      final container = containerWith(party: const [SyntheticCharacter()]);
      await container.read(partyProvider(slotName).future);

      container.read(partyProvider(slotName).notifier).select(7);

      expect(
        container.read(partyProvider(slotName)).value?.selectedIndex,
        0,
        reason: 'the selection must stay on something that exists',
      );
    });
  });
}
