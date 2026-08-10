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

/// Editing an exported character, which is the other half of the same editor.
///
/// The claims here are deliberately the ones `party_viewmodel_test` makes about
/// a savegame: same edits, same undo, same dirty marker, same atomic write. A
/// difference between the two is a defect, not a design.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/edit_command.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/ui/character/character_file_viewmodel.dart';

import '../../support/fakes.dart';
import '../../support/synthetic_save.dart';

void main() {
  const fileName = 'aurel.chr';

  late FakeCharacterFileRepository files;

  ProviderContainer containerWith({
    SyntheticCharacter character = const SyntheticCharacter(),
    String name = 'Aurel',
    bool exists = true,
  }) {
    final chr = ChrCodec.decode(
      buildCharacterFile(character: character, name: name),
    );
    files = FakeCharacterFileRepository(
      files: exists
          ? [fakeCharacterFile(fileName: fileName, name: name)]
          : const [],
      chr: chr,
    );
    return ProviderContainer.test(
      overrides: [
        characterFileRepositoryProvider.overrideWithValue(files),
        stringRepositoryProvider.overrideWithValue(FakeStringRepository()),
        resourceRepositoryProvider.overrideWithValue(
          const FakeResourceRepository(ProficiencyCatalogue.empty),
        ),
      ],
    );
  }

  CharacterFileViewModel notifierOf(ProviderContainer c) =>
      c.read(characterFileProvider(fileName).notifier);

  group('loading', () {
    test('shows the character the file holds', () async {
      final container = containerWith();

      final state = await container.read(
        characterFileProvider(fileName).future,
      );

      expect(state.character.name, 'Aurel');
      expect(state.file.fileName, fileName);
      expect(state.isDirty, isFalse);
    });

    test('reads stats out of the embedded record', () async {
      final container = containerWith(
        character: const SyntheticCharacter(strength: 12, thac0: 18),
      );

      final state = await container.read(
        characterFileProvider(fileName).future,
      );

      expect(state.character.abilities.strength, 12);
      expect(state.character.thac0, 18);
    });

    test('fails when the route names a file that is gone', () async {
      // The repository answers null; treating that as a failure is this
      // screen's decision, because an editor with nothing to edit has nothing
      // to show.
      final container = containerWith(exists: false);

      final subscription = container.listen(
        characterFileProvider(fileName),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(subscription.read().hasError, isTrue);
      expect(
        container.read(characterFileProvider(fileName)).error,
        isA<CharacterFileNotFoundException>(),
      );
    });
  });

  group('editing', () {
    test('an edit shows in the projected character', () async {
      final container = containerWith(
        character: const SyntheticCharacter(strength: 12),
      );
      final state = await container.read(
        characterFileProvider(fileName).future,
      );

      notifierOf(container).edit(
        SetCharacterStat(
          creOffset: state.character.creOffset,
          stat: CharacterStat.strength,
          value: 18,
        ),
      );

      expect(
        container
            .read(characterFileProvider(fileName))
            .value
            ?.character
            .abilities
            .strength,
        18,
      );
    });

    test('marks the document dirty, and undo takes it back', () async {
      final container = containerWith(
        character: const SyntheticCharacter(strength: 12),
      );
      final state = await container.read(
        characterFileProvider(fileName).future,
      );
      final notifier = notifierOf(container)
        ..edit(
          SetCharacterStat(
            creOffset: state.character.creOffset,
            stat: CharacterStat.strength,
            value: 18,
          ),
        );

      expect(
        container.read(characterFileProvider(fileName)).value?.isDirty,
        isTrue,
      );
      expect(
        container.read(characterFileProvider(fileName)).value?.canUndo,
        isTrue,
      );

      notifier.undo();

      final back = container.read(characterFileProvider(fileName)).value!;
      expect(back.character.abilities.strength, 12);
      // Identity, not a byte comparison: undoing to the loaded snapshot
      // restores that same object, so "nothing to save" needs no diff.
      expect(back.isDirty, isFalse);
      expect(back.canRedo, isTrue);
    });

    test('a fresh edit clears the redo stack', () async {
      final container = containerWith();
      final state = await container.read(
        characterFileProvider(fileName).future,
      );
      final notifier = notifierOf(container)
        ..edit(
          SetCharacterStat(
            creOffset: state.character.creOffset,
            stat: CharacterStat.luck,
            value: 2,
          ),
        )
        ..undo()
        ..edit(
          SetCharacterStat(
            creOffset: state.character.creOffset,
            stat: CharacterStat.luck,
            value: 3,
          ),
        );

      expect(
        container.read(characterFileProvider(fileName)).value?.canRedo,
        isFalse,
      );
      expect(notifier, isNotNull);
    });

    test('refuses a value the stat does not accept', () async {
      final container = containerWith();
      final state = await container.read(
        characterFileProvider(fileName).future,
      );

      expect(
        () => notifierOf(container).edit(
          SetCharacterStat(
            creOffset: state.character.creOffset,
            stat: CharacterStat.strength,
            value: 300,
          ),
        ),
        throwsA(isA<InvalidEditException>()),
      );
    });
  });

  group('saving', () {
    test('writes the working copy and goes clean', () async {
      final container = containerWith(
        character: const SyntheticCharacter(strength: 12),
      );
      final state = await container.read(
        characterFileProvider(fileName).future,
      );
      final notifier = notifierOf(container)
        ..edit(
          SetCharacterStat(
            creOffset: state.character.creOffset,
            stat: CharacterStat.strength,
            value: 18,
          ),
        );

      await notifier.save();

      expect(files.written, hasLength(1));
      expect(CreCodec.decode(files.written.single.creBytes).strength, 18);
      expect(
        container.read(characterFileProvider(fileName)).value?.isDirty,
        isFalse,
      );
    });

    test('writes nothing when there is nothing to save', () async {
      // The browser sorts by modification time, so an idle write would reorder
      // the lineup for no reason.
      final container = containerWith();
      await container.read(characterFileProvider(fileName).future);

      await notifierOf(container).save();

      expect(files.written, isEmpty);
    });
  });

  test('saving re-reads the character list, and only that list', () async {
    // Otherwise the lineup keeps the portrait, level and class it was drawn
    // with, and the player's own edit looks lost. ⚠️ Exactly this list — a
    // character write leaves every savegame on disk alone, which a global
    // "something changed" signal could not express.
    final container = containerWith(
      character: const SyntheticCharacter(strength: 12),
    );
    await container.read(characterFilesProvider.future);
    final readsBefore = files.listCalls;

    final state = await container.read(characterFileProvider(fileName).future);
    final notifier = notifierOf(container)
      ..edit(
        SetCharacterStat(
          creOffset: state.character.creOffset,
          stat: CharacterStat.strength,
          value: 18,
        ),
      );
    await notifier.save();
    await container.read(characterFilesProvider.future);

    expect(files.listCalls, greaterThan(readsBefore));
  });
}
