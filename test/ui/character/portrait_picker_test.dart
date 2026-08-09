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

/// Choosing a portrait — the first step of making a character, and the way to
/// change one on a character that already exists.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/ui/character/portrait_picker.dart';

import '../../support/fakes.dart';

void main() {
  /// Portrait bytes keyed by resref, as the resource repository answers them.
  Map<String, Uint8List> portraits(List<String> bases) => {
    for (final base in bases) '${base}M': Uint8List.fromList([0x42, 0x4d]),
  };

  Future<String?> showPicker(
    WidgetTester tester, {
    List<String> available = const ['AJANTIS', 'IMOEN', 'XZAR'],
    String? selected,
  }) async {
    tester.view
      ..physicalSize = const Size(1200, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    String? chosen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resourceRepositoryProvider.overrideWithValue(
            FakeResourceRepository(
              ProficiencyCatalogue.empty,
              portraits: portraits(available),
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async => chosen = await PortraitPicker.show(
                  context,
                  selected: selected,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return chosen;
  }

  testWidgets('offers every portrait the game and the player have', (
    tester,
  ) async {
    await showPicker(tester);

    // ⚠️ The name is *drawn* on the tile, not hidden in a tooltip. The picker
    // has a search box, which means names are how a portrait is found — and on
    // a machine with no game installed every tile is the same placeholder, so
    // an unlabelled grid would say nothing at all.
    for (final name in ['AJANTIS', 'IMOEN', 'XZAR']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('cannot be confirmed until something is chosen', (tester) async {
    await showPicker(tester);

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use this portrait'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('IMOEN'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use this portrait'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('starts on the portrait already in use', (tester) async {
    await showPicker(tester, selected: 'XZAR');

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use this portrait'),
          )
          .onPressed,
      isNotNull,
      reason: 'the character already has one, so there is something to confirm',
    );
  });

  testWidgets('narrows the list as the player types', (tester) async {
    await showPicker(tester);

    await tester.enterText(find.byType(TextField), 'imo');
    await tester.pumpAndSettle();

    expect(find.text('IMOEN'), findsOneWidget);
    expect(find.text('AJANTIS'), findsNothing);
  });

  testWidgets('offers to add one of the player’s own', (tester) async {
    // ⚠️ The same thing the game's own CUSTOM button does. Its absence would
    // leave the player able to choose only from what BioWare shipped.
    await showPicker(tester);

    expect(find.text('Add a portrait…'), findsOneWidget);
  });

  testWidgets('says so plainly when there are no portraits at all', (
    tester,
  ) async {
    // A machine with no Baldur's Gate installed. The picker still opens, and
    // "Add a portrait…" is still there — that path needs no game data.
    await showPicker(tester, available: const []);

    expect(find.textContaining('No portraits found'), findsOneWidget);
    expect(find.text('Add a portrait…'), findsOneWidget);
  });
}
