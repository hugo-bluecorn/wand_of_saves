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
import 'package:wand_of_saves/data/repositories/string_repository.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/ui/party/party_viewmodel.dart';

import '../../support/fakes.dart';

void main() {
  const slotName = '000000022-last';

  ProviderContainer containerWith({
    List<Character> party = const [],
    Map<int, String> strings = const {},
    StringRepository? stringRepository,
    bool slotExists = true,
  }) => ProviderContainer.test(
    overrides: [
      saveGameRepositoryProvider.overrideWithValue(
        FakeSaveGameRepository(
          slots: slotExists ? [fakeSlot('last')] : const [],
          parties: {slotName: party},
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
        party: [
          fakeCharacter(),
          fakeCharacter(name: 'Imoen', creResref: '*IMOEN', partyOrder: 1),
        ],
      );

      final state = await container.read(partyProvider(slotName).future);

      expect(state.members.map((m) => m.name), ['Aard', 'Imoen']);
      expect(state.slot.label, 'last');
    });

    test('selects the first member so the screen is never blank', () async {
      final container = containerWith(party: [fakeCharacter()]);

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
        party: [fakeCharacter()],
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
        party: [
          fakeCharacter(name: '', nameStrref: 9501, creResref: '*INSC'),
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
          party: [
            fakeCharacter(name: '', nameStrref: 9501, creResref: '*INSC'),
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
          party: [
            fakeCharacter(name: '', nameStrref: 9501, creResref: '*INSC'),
          ],
          stringRepository: const AbsentStringRepository(),
        );

        final state = await container.read(partyProvider(slotName).future);

        expect(state.members.single.name, '*INSC');
      },
    );
  });

  group('select', () {
    test('moves the selection', () async {
      final container = containerWith(
        party: [
          fakeCharacter(),
          fakeCharacter(name: 'Imoen', partyOrder: 1),
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
      final container = containerWith(party: [fakeCharacter()]);
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
