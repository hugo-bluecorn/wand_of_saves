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

/// The shared sheet, driven by the other document.
///
/// **What matters here is sameness.** The sheet is one widget serving two
/// ViewModels, so these assert that a `.chr` gets the same editable fields the
/// savegame does — and that the two things a character file genuinely lacks are
/// absent rather than blank.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/ui/character/character_file_view.dart';

import '../../support/fakes.dart';
import '../../support/synthetic_save.dart';

void main() {
  const fileName = 'aurel.chr';
  late FakeCharacterFileRepository files;

  Future<void> showCharacter(
    WidgetTester tester, {
    SyntheticCharacter character = const SyntheticCharacter(),
  }) async {
    tester.view
      ..physicalSize = const Size(1600, 2200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    files = FakeCharacterFileRepository(
      files: [fakeCharacterFile(fileName: fileName, name: 'Aurel')],
      chr: ChrCodec.decode(
        buildCharacterFile(character: character, name: 'Aurel'),
      ),
    );
    final container = ProviderContainer.test(
      overrides: [
        characterFileRepositoryProvider.overrideWithValue(files),
        stringRepositoryProvider.overrideWithValue(FakeStringRepository()),
        // ⚠️ Not optional. Left to the real one this reads the machine's own
        // chitin.key and a 30 MB archive, and pumpAndSettle does not await real
        // file I/O -- the widget never settles and the whole file times out.
        resourceRepositoryProvider.overrideWithValue(
          const FakeResourceRepository(ProficiencyCatalogue.empty),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CharacterFileView(fileName: fileName)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String heading) async {
    await tester.tap(find.widgetWithText(Tab, heading));
    await tester.pumpAndSettle();
  }

  testWidgets('names the file in the bar and the character in the panel', (
    tester,
  ) async {
    // ⚠️ Two names, and they really do differ on disk: Aard1.chr holds Aard.
    // The bar names the document, as the party shell's does; the panel names
    // the person. Saying the same name twice would lose the other fact.
    await showCharacter(tester);

    expect(find.text(fileName), findsOneWidget);
    expect(find.text('Aurel'), findsOneWidget);
  });

  testWidgets('has the same four tabs the party shell does', (tester) async {
    await showCharacter(tester);

    for (final heading in ['Character', 'Abilities', 'Skills', 'Combat']) {
      expect(find.widgetWithText(Tab, heading), findsOneWidget);
    }
  });

  testWidgets('has no portrait rail — there is nothing to rail between', (
    tester,
  ) async {
    await showCharacter(tester);

    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('does not show a party reputation it does not have', (
    tester,
  ) async {
    // ⚠️ Absent rather than blank. The record carries a reputation byte of its
    // own and the engine ignores it; showing that number would be showing
    // something the game never prints.
    await showCharacter(tester);

    expect(find.text('Reputation (party)'), findsNothing);
  });

  testWidgets('editing a stat marks the document dirty and enables Save', (
    tester,
  ) async {
    await showCharacter(
      tester,
      character: const SyntheticCharacter(strength: 12),
    );

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
      reason: 'nothing is unsaved yet',
    );

    await openTab(tester, 'Abilities');
    await tester.enterText(find.widgetWithText(TextField, '12'), '18');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('$fileName •'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Save writes the edited character', (tester) async {
    await showCharacter(
      tester,
      character: const SyntheticCharacter(strength: 12),
    );

    await openTab(tester, 'Abilities');
    await tester.enterText(find.widgetWithText(TextField, '12'), '18');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(files.written, hasLength(1));
    expect(CreCodec.decode(files.written.single.creBytes).strength, 18);
  });
}
