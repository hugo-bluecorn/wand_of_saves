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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/data/repositories/character_file_repository.dart';
import 'package:wand_of_saves/domain/document_ref.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/ui/saves/save_browser_viewmodel.dart';

import '../../support/fakes.dart';

void main() {
  // ProviderContainer.test disposes itself via addTearDown; disposing a plain
  // container by hand raced the in-flight build and hung the error test.
  late FakeRecycleService recycler;

  ProviderContainer containerWith(
    FakeSaveGameRepository repository, {
    FakeCharacterFileRepository? characters,
  }) {
    recycler = FakeRecycleService();
    return ProviderContainer.test(
      overrides: [
        saveGameRepositoryProvider.overrideWithValue(repository),
        characterFileRepositoryProvider.overrideWithValue(
          characters ?? FakeCharacterFileRepository(),
        ),
        recycleServiceProvider.overrideWithValue(recycler),
      ],
    );
  }

  test('exposes the slots the repository returns', () async {
    final container = containerWith(
      FakeSaveGameRepository(slots: [fakeSlot('last'), fakeSlot('start')]),
    );

    final state = await container.read(saveBrowserProvider.future);

    expect(state.saves.map((s) => s.label), ['last', 'start']);
  });

  test('exposes the characters beside them, as a section of its own', () async {
    // The two are peers: a character file is a document in its own right, not
    // something found inside a savegame.
    final container = containerWith(
      FakeSaveGameRepository(slots: [fakeSlot('last')]),
      characters: FakeCharacterFileRepository(
        files: [
          fakeCharacterFile(fileName: 'aurel.chr', name: 'Aurel'),
          fakeCharacterFile(),
        ],
      ),
    );

    final state = await container.read(saveBrowserProvider.future);

    expect(state.characters.map((c) => c.character.name), ['Aurel', 'Aard']);
    expect(state.saves, hasLength(1));
  });

  test('has no slots when the save directory is empty', () async {
    final container = containerWith(FakeSaveGameRepository());

    expect((await container.read(saveBrowserProvider.future)).saves, isEmpty);
  });

  test('is empty only when both sections are', () async {
    // What the "nothing here" message keys on. A player with characters and no
    // saves must not be told there is nothing.
    final container = containerWith(
      FakeSaveGameRepository(),
      characters: FakeCharacterFileRepository(files: [fakeCharacterFile()]),
    );

    final state = await container.read(saveBrowserProvider.future);

    expect(state.saves, isEmpty);
    expect(state.isEmpty, isFalse);
  });

  test('surfaces a load failure as an error state, not a crash', () async {
    // A missing or unreadable save directory is an ordinary situation on a
    // machine where the game is not installed, and the screen has to say so
    // rather than throwing into the widget tree.
    final container = containerWith(
      FakeSaveGameRepository(failure: const FileSystemException('nope')),
    );

    // Read directly rather than through `.future`: that completes normally on
    // success but never settles when build() throws. The claim under test is
    // only that the failure lands in the state instead of escaping.
    final subscription = container.listen(saveBrowserProvider, (_, _) {});
    addTearDown(subscription.close);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final state = subscription.read();

    expect(
      state.hasError,
      isTrue,
      reason: 'the failure escaped instead of landing in the state',
    );

    expect(
      container.read(saveBrowserProvider).error,
      isA<FileSystemException>(),
    );
  });

  test('refresh re-reads both directories', () async {
    // The game is very likely running while this app is open, so the first
    // read cannot be assumed to stay true -- and it exports characters too.
    final repository = FakeSaveGameRepository(slots: [fakeSlot('last')]);
    final characters = FakeCharacterFileRepository();
    final container = containerWith(repository, characters: characters);
    await container.read(saveBrowserProvider.future);

    repository.slots = [fakeSlot('last'), fakeSlot('newer')];
    characters.files = [fakeCharacterFile()];
    await container.read(saveBrowserProvider.notifier).refresh();

    expect(repository.listCalls, 2);
    expect(characters.listCalls, 2);
    expect(container.read(saveBrowserProvider).value?.saves, hasLength(2));
    expect(container.read(saveBrowserProvider).value?.characters, hasLength(1));
  });

  group('selecting and deleting', () {
    ProviderContainer populated() => containerWith(
      FakeSaveGameRepository(slots: [fakeSlot('last'), fakeSlot('start')]),
      characters: FakeCharacterFileRepository(
        files: [fakeCharacterFile(fileName: 'aurel.chr')],
      ),
    );

    test('starts with selection off and nothing ticked', () async {
      final state = await populated().read(saveBrowserProvider.future);

      expect(state.isSelecting, isFalse);
      expect(state.selected, isEmpty);
    });

    test('ticking spans both sections', () async {
      // One selection, so clearing out stale saves and old characters is a
      // single pass rather than two.
      final container = populated();
      await container.read(saveBrowserProvider.future);
      final notifier = container.read(saveBrowserProvider.notifier)
        ..startSelecting()
        ..toggle(const SaveRef('000000022-last'))
        ..toggle(const CharacterRef('aurel.chr'));

      final state = container.read(saveBrowserProvider).value!;

      expect(state.isSelecting, isTrue);
      expect(state.selectedSaveLabels, ['last']);
      expect(state.selectedCharacterNames, ['aurel.chr']);
      expect(notifier, isNotNull);
    });

    test('ticking twice unticks', () async {
      final container = populated();
      await container.read(saveBrowserProvider.future);
      container.read(saveBrowserProvider.notifier)
        ..startSelecting()
        ..toggle(const SaveRef('000000022-last'))
        ..toggle(const SaveRef('000000022-last'));

      expect(container.read(saveBrowserProvider).value?.selected, isEmpty);
    });

    test('selection mode survives unticking the last card', () async {
      // A mode that vanished when the count hit zero would be unusable: the
      // player has to be able to change their mind about one card.
      final container = populated();
      await container.read(saveBrowserProvider.future);
      container.read(saveBrowserProvider.notifier)
        ..startSelecting()
        ..toggle(const SaveRef('000000022-last'))
        ..toggle(const SaveRef('000000022-last'));

      expect(container.read(saveBrowserProvider).value?.isSelecting, isTrue);
    });

    test('cancelling moves nothing and clears the ticks', () async {
      final container = populated();
      await container.read(saveBrowserProvider.future);
      container.read(saveBrowserProvider.notifier)
        ..startSelecting()
        ..toggle(const SaveRef('000000022-last'))
        ..cancelSelection();

      final state = container.read(saveBrowserProvider).value!;

      expect(state.isSelecting, isFalse);
      expect(state.selected, isEmpty);
      expect(recycler.recycledSaves, isEmpty);
      expect(recycler.recycledCharacters, isEmpty);
    });

    test('confirming moves each selected document and re-reads', () async {
      final container = populated();
      await container.read(saveBrowserProvider.future);
      final notifier = container.read(saveBrowserProvider.notifier)
        ..startSelecting()
        ..toggle(const SaveRef('000000022-last'))
        ..toggle(const CharacterRef('aurel.chr'));

      await notifier.deleteSelected();

      expect(recycler.recycledSaves, ['/tmp/last']);
      expect(recycler.recycledCharacters, ['/tmp/characters/aurel.chr']);
      expect(container.read(saveBrowserProvider).value?.isSelecting, isFalse);
      expect(container.read(saveBrowserProvider).value?.selected, isEmpty);
    });

    test('deleting nothing does nothing', () async {
      final container = populated();
      await container.read(saveBrowserProvider.future);
      final notifier = container.read(saveBrowserProvider.notifier)
        ..startSelecting();

      await notifier.deleteSelected();

      expect(recycler.recycledSaves, isEmpty);
    });

    test('emptying is a separate command from deleting', () async {
      // The only irreversible operation in the app, so it is never something
      // that happens as a side effect of a delete.
      final container = populated();
      await container.read(saveBrowserProvider.future);
      final notifier = container.read(saveBrowserProvider.notifier)
        ..startSelecting()
        ..toggle(const SaveRef('000000022-last'));

      await notifier.deleteSelected();

      expect(recycler.emptied, isFalse);

      await notifier.emptyDeleted();

      expect(recycler.emptied, isTrue);
    });

    test('reports whether there is anything to empty', () async {
      final container = populated();
      recycler.hasRecycled = true;

      expect(
        (await container.read(saveBrowserProvider.future)).hasDeleted,
        isTrue,
      );
    });
  });

  group('creating a character', () {
    Uint8List template() =>
        Uint8List(CreHeaderField.headerSize)
          ..setRange(0, 8, latin1.encode('CRE V1.0'));

    ProviderContainer withTemplate({
      Map<String, Uint8List>? creatures,
      FakeCharacterFileRepository? characters,
    }) {
      recycler = FakeRecycleService();
      return ProviderContainer.test(
        overrides: [
          saveGameRepositoryProvider.overrideWithValue(
            FakeSaveGameRepository(),
          ),
          characterFileRepositoryProvider.overrideWithValue(
            characters ?? FakeCharacterFileRepository(),
          ),
          recycleServiceProvider.overrideWithValue(recycler),
          resourceRepositoryProvider.overrideWithValue(
            FakeResourceRepository(
              ProficiencyCatalogue.empty,
              creatures: creatures ?? {'CHARBASE': template()},
            ),
          ),
        ],
      );
    }

    test('builds the record from the game’s own CHARBASE', () async {
      // ⚠️ Never synthesised. The engine's template is what every protagonist
      // is built from, which is why their resref reads *HARBASE.
      final characters = FakeCharacterFileRepository();
      final container = withTemplate(characters: characters);
      await container.read(saveBrowserProvider.future);

      await container
          .read(saveBrowserProvider.notifier)
          .createCharacter(
            name: 'Aurel',
            fileName: 'aurel.chr',
            portraitName: 'AJANTIS',
          );

      final written = characters.created.single.$2;
      expect(written.name, 'Aurel');
      expect(written.creBytes.sublist(0, 8), template().sublist(0, 8));
    });

    test('writes the chosen portrait into the record', () async {
      final characters = FakeCharacterFileRepository();
      final container = withTemplate(characters: characters);
      await container.read(saveBrowserProvider.future);

      await container
          .read(saveBrowserProvider.notifier)
          .createCharacter(
            name: 'Aurel',
            fileName: 'aurel.chr',
            portraitName: 'AJANTIS',
          );

      final cre = CreCodec.decode(characters.created.single.$2.creBytes);
      expect(cre.portraitMedium, 'AJANTISM');
      expect(cre.portraitLarge, 'AJANTISL');
    });

    test('the new character shows in the lineup afterwards', () async {
      final container = withTemplate();
      await container.read(saveBrowserProvider.future);

      await container
          .read(saveBrowserProvider.notifier)
          .createCharacter(
            name: 'Aurel',
            fileName: 'aurel.chr',
            portraitName: 'AJANTIS',
          );

      expect(
        container.read(saveBrowserProvider).value?.characters,
        hasLength(1),
      );
    });

    test('says so when the game is not installed', () async {
      // No installation means no CHARBASE, and nothing the player types will
      // help -- which is why this is a different failure from a name clash.
      final container = withTemplate(creatures: const {});
      await container.read(saveBrowserProvider.future);

      await expectLater(
        container
            .read(saveBrowserProvider.notifier)
            .createCharacter(
              name: 'Aurel',
              fileName: 'aurel.chr',
              portraitName: 'AJANTIS',
            ),
        throwsA(isA<NoCharacterTemplateException>()),
      );
    });

    test('refuses a name that is already taken', () async {
      final characters = FakeCharacterFileRepository()..taken = {'aurel.chr'};
      final container = withTemplate(characters: characters);
      await container.read(saveBrowserProvider.future);

      await expectLater(
        container
            .read(saveBrowserProvider.notifier)
            .createCharacter(
              name: 'Aurel',
              fileName: 'aurel.chr',
              portraitName: 'AJANTIS',
            ),
        throwsA(isA<CharacterFileExistsException>()),
      );
    });
  });
}
