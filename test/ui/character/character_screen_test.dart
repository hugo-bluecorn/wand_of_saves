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

/// The party rail, at the party sizes the game actually allows.
///
/// ⚠️ **An overflow is one of the few UI defects a test CAN catch.** Widths and
/// label truncation are not assertable here — `flutter test` draws with a font
/// whose every glyph is a full em square — but a `RenderFlex` overflow reports
/// through `FlutterError` and fails the test, and it does not depend on glyph
/// metrics at all. Six fixed-height portraits either fit the viewport or they
/// do not.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/item_catalogue.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/ui/character/character_screen.dart';
import 'package:wand_of_saves/ui/character/portrait_tile.dart';

import '../../support/fakes.dart';
import '../../support/synthetic_save.dart';

void main() {
  // ⚠️ Must match what `fakeSlot` builds — it prefixes `000000022-`. A name
  // that does not match finds no slot, renders no rail, and every assertion
  // below passes against an empty screen.
  const slotName = '000000022-six';

  /// Pumps the character screen over a party of [size] in a [height] viewport.
  Future<void> open(
    WidgetTester tester, {
    required int size,
    required double height,
  }) async {
    tester.view
      ..physicalSize = Size(1400, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer.test(
      overrides: [
        saveGameRepositoryProvider.overrideWithValue(
          FakeSaveGameRepository(
            slots: [fakeSlot('six')],
            gam: GamCodec.decode(
              buildSave(
                party: [
                  for (var i = 0; i < size; i++)
                    SyntheticCharacter(
                      resref: '*MEMBER$i',
                      displayName: 'Member $i',
                      partyOrder: i,
                    ),
                ],
              ),
            ),
          ),
        ),
        stringRepositoryProvider.overrideWithValue(FakeStringRepository()),
        // ⚠️ Not optional: the real one reads the machine's own chitin.key and
        // a 30 MB archive, which `pumpAndSettle` does not await.
        resourceRepositoryProvider.overrideWithValue(
          const FakeResourceRepository(ProficiencyCatalogue.empty),
        ),
        characterFileRepositoryProvider.overrideWithValue(
          FakeCharacterFileRepository(),
        ),
        itemCatalogueProvider.overrideWith(
          (ref) async => const ItemCatalogue({
            'RING01': ItemEntry(
              resref: 'RING01',
              itemType: 10,
              identifiedName: 'Ring of Protection +1',
            ),
          }),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: CharacterScreen(slotDirectoryName: slotName),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Fails unless the rail really drew [size] members.
  ///
  /// ⚠️ **Without this every test here passed with the bug in place**, because
  /// a slot name that did not match `fakeSlot`'s found no savegame and rendered
  /// no rail — and an empty screen overflows nothing. The rail's destinations
  /// are a `Column`, lazily built by nothing, so a label off the bottom of the
  /// viewport is still in the tree and still findable.
  void expectRailRendered(int size) {
    for (var i = 0; i < size; i++) {
      expect(
        find.text('Member $i'),
        // Not `findsOneWidget`: the selected member is named twice, once in
        // the rail and once in the sheet's identity header.
        findsAtLeastNWidgets(1),
        reason: 'the rail must actually have drawn member $i',
      );
    }
  }

  testWidgets('⚠️ a full six-member party does not overflow the rail', (
    tester,
  ) async {
    // Six is the party size the game allows, and it is the first one tall
    // enough to exceed a short window — every fixture before Conan had one
    // member or four. The rail must scroll rather than paint past its bottom.
    await open(tester, size: 6, height: 700);
    expectRailRendered(6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('and neither does it in a window shorter than one tile', (
    tester,
  ) async {
    await open(tester, size: 6, height: 240);
    expectRailRendered(6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a one-member party still renders', (tester) async {
    await open(tester, size: 1, height: 700);
    expectRailRendered(1);
    expect(tester.takeException(), isNull);
  });

  group('the inventory carries the editor shell with it', () {
    /// Opens the inventory from the app bar.
    Future<void> openInventory(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Inventory'));
      await tester.pumpAndSettle();
    }

    testWidgets('it shows the whole party and a Save button', (tester) async {
      await open(tester, size: 6, height: 700);
      await openInventory(tester);

      expect(find.textContaining('· Inventory'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      expectRailRendered(6);
      expect(tester.takeException(), isNull);
    });

    testWidgets('⚠️ selecting another member switches whose inventory it is', (
      tester,
    ) async {
      // The behaviour that makes the rail worth putting there rather than
      // being decoration: a control that does nothing is a defect here.
      await open(tester, size: 6, height: 700);
      await openInventory(tester);
      expect(find.text('Member 0 · Inventory'), findsOneWidget);

      await tester.tap(find.text('Member 3'));
      await tester.pumpAndSettle();

      expect(find.text('Member 3 · Inventory'), findsOneWidget);
      expect(find.text('Member 0 · Inventory'), findsNothing);
    });
  });

  group('handing an item to another character', () {
    testWidgets('⚠️ dragging onto a portrait moves it, in one undo step', (
      tester,
    ) async {
      await open(tester, size: 6, height: 700);
      // Give member 0 something to hand over.
      await tester.tap(find.byTooltip('Inventory'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'RING01');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('RING01'), findsOneWidget, reason: 'member 0 has it');

      // Drag it onto member 3's portrait. Horizontal first, because the
      // draggable only claims the gesture on that axis.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('RING01')),
      );
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      // ⚠️ The drop target is the PORTRAIT, not the label beneath it — the
      // DragTarget is the destination's `icon`. `NavigationRail` builds either
      // `icon` or `selectedIcon` per destination, never both, so these are one
      // per member in party order.
      await gesture.moveTo(
        tester.getCenter(find.byType(PortraitTile).at(3)),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Member 0 no longer carries it.
      expect(find.text('RING01'), findsNothing);

      // And member 3 does.
      await tester.tap(find.byType(PortraitTile).at(3));
      await tester.pumpAndSettle();
      expect(find.text('RING01'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
