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
import 'package:wand_of_saves/data/repositories/string_repository.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/edit_command.dart';
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
    bool slotExists = true,
  }) => ProviderContainer.test(
    overrides: [
      saveGameRepositoryProvider.overrideWithValue(
        FakeSaveGameRepository(
          slots: slotExists ? [fakeSlot('last')] : const [],
          gam: GamCodec.decode(buildSave(party: party)),
        ),
      ),
      stringRepositoryProvider.overrideWithValue(
        stringRepository ?? FakeStringRepository(strings),
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
