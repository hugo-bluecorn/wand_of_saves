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
    ProficiencyCatalogue proficiencies = ProficiencyCatalogue.empty,
    // ⚠️ A catalogue's names come from the talk table, not from the 2DA, so a
    // fixture that sets `name:` and no string is a shape the app never sees —
    // `withNames` overwrites it with null.
    Map<int, String> strings = const {},
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
        stringRepositoryProvider.overrideWithValue(
          FakeStringRepository(strings),
        ),
        // ⚠️ Not optional. Left to the real one this reads the machine's own
        // chitin.key and a 30 MB archive, and pumpAndSettle does not await real
        // file I/O -- the widget never settles and the whole file times out.
        resourceRepositoryProvider.overrideWithValue(
          FakeResourceRepository(proficiencies),
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

  /// Opens the side sheet on the row labelled [label] and types [value].
  ///
  /// ⚠️ **The sheet's rows are read-only summaries.** Editing goes through the
  /// side sheet, which is what makes a value carry its own verdict where it is
  /// typed rather than in a snackbar somewhere else.
  Future<void> editField(
    WidgetTester tester,
    String label,
    String value,
  ) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, value);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
  }

  testWidgets('grants a proficiency the record does not have yet', (
    tester,
  ) async {
    // ⚠️ **The `.chr` is the document that CAN grow, and this screen refused
    // anyway.** Raising a proficiency from zero appends a 264-byte opcode 233
    // effect: thirty-nine pointers inside a savegame, and **one** in a
    // character file. So a savegame is right to refuse; this screen was not.
    // Reported
    // as "I deselected all proficiencies but I cannot add pip to other
    // proficiencies": the pips were at zero with their effects intact, so every
    // *other* row was inert.
    await showCharacter(
      tester,
      proficiencies: const ProficiencyCatalogue({
        104: ProficiencyEntry(
          id: 104,
          identifier: 'LONGBOW',
          nameStrref: 25016,
          maximumByColumn: {'FIGHTER_MAGE': 2},
        ),
      }),
      strings: const {25016: 'Long Bow'},
    );

    // The row exists and the record holds no effect for it.
    expect(find.text('Long Bow'), findsOneWidget);

    await tester.tap(find.text('Long Bow'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(
      find.text('$fileName •'),
      findsOneWidget,
      reason: 'granting a pip is an edit and marks the document dirty',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final written = CreCodec.decode(files.written.single.creBytes);
    final granted = written.effects.where(
      (e) => e.isProficiency && e.parameter2 == 104,
    );
    expect(granted, hasLength(1), reason: 'one opcode 233 effect appended');
    expect(granted.single.parameter1, 1, reason: 'at one pip');
  });

  testWidgets('names the file in the bar and the character on the sheet', (
    tester,
  ) async {
    // ⚠️ Two names, and they really do differ on disk: Aard1.chr holds Aard.
    // The bar names the document; the sheet names the person. Saying the same
    // name twice would lose the other fact — and for one revision the sheet
    // named nobody at all, which is why this asserts both.
    await showCharacter(tester);

    expect(find.text(fileName), findsOneWidget);
    expect(find.text('Aurel'), findsOneWidget);
  });

  testWidgets('shows every group at once, with no tabs to open', (
    tester,
  ) async {
    // ⚠️ **The point of the single column.** The four headings used to be tabs,
    // so three quarters of the record was always one click away — and a finding
    // marked on a hidden field is a mark nobody can see.
    await showCharacter(tester);

    for (final heading in ['Character', 'Abilities', 'Skills', 'Combat']) {
      expect(find.text(heading), findsWidgets, reason: heading);
    }
    expect(find.byType(Tab), findsNothing);
    expect(find.byType(TabBar), findsNothing);
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

    await editField(tester, 'Strength', '18');

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

    await editField(tester, 'Strength', '18');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(files.written, hasLength(1));
    expect(CreCodec.decode(files.written.single.creBytes).strength, 18);
  });
}
