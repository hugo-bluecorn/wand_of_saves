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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/carried_item.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/item_catalogue.dart';
import 'package:wand_of_saves/ui/inventory/inventory_screen.dart';

import '../../support/fakes.dart';

/// ⚠️ Shaped like the installation: `BOOT01`'s name does NOT contain "Boots of
/// Speed" — the game calls it "The Paws of the Cheetah" — and the phrase lives
/// only in its description. That is the whole reason the third tier exists.
const _catalogue = ItemCatalogue({
  'BOOT01': ItemEntry(
    resref: 'BOOT01',
    itemType: 4,
    identifiedName: 'The Paws of the Cheetah',
    unidentifiedName: 'Boots',
    description: 'The fabled Boots of Speed double the wearer’s movement.',
  ),
  'RING01': ItemEntry(
    resref: 'RING01',
    itemType: 10,
    identifiedName: 'Ring of Protection +1',
  ),
});

Character characterWith(List<CarriedItem> items) => fakeCharacter(items: items);

Future<void> pump(
  WidgetTester tester, {
  required Character character,
  required void Function(String, CreItemSlot) onAdd,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itemCatalogueProvider.overrideWith((ref) async => _catalogue),
      ],
      child: MaterialApp(
        home: InventoryScreen(character: () => character, onAdd: onAdd),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mounts and names whose inventory it is', (tester) async {
    // ⚠️ The cheapest guard against the defect that shipped once already: a
    // clean analyze and a green suite are compatible with a screen that throws
    // on its first frame.
    await pump(tester, character: characterWith(const []), onAdd: (_, _) {});
    expect(find.text('Aard · Inventory'), findsOneWidget);
    expect(find.text('Nothing yet.'), findsOneWidget);
  });

  testWidgets('lists what the character carries', (tester) async {
    await pump(
      tester,
      character: characterWith(const [
        CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
        CarriedItem(
          resref: 'BELT16',
          index: 1,
          slotIndex: 22,
          isIdentified: false,
        ),
      ]),
      onAdd: (_, _) {},
    );
    expect(find.text('BOOT01'), findsOneWidget);
    expect(find.text('BELT16'), findsOneWidget);
    // ⚠️ Stated, because the game will draw the plain name for it.
    expect(find.text('unidentified'), findsOneWidget);
  });

  testWidgets('⚠️ finds "Boots of Speed" and labels it a description match', (
    tester,
  ) async {
    // The ask, end to end. Searching names for this returns nothing in BG:EE.
    await pump(tester, character: characterWith(const []), onAdd: (_, _) {});

    await tester.enterText(find.byType(TextField), 'boots of speed');
    await tester.pumpAndSettle();

    expect(find.text('Only in the description'), findsOneWidget);
    expect(find.text('The Paws of the Cheetah'), findsOneWidget);
  });

  testWidgets('finds an item by resref', (tester) async {
    await pump(tester, character: characterWith(const []), onAdd: (_, _) {});
    await tester.enterText(find.byType(TextField), 'RING01');
    await tester.pumpAndSettle();

    expect(find.text('That resref'), findsOneWidget);
    expect(find.text('Ring of Protection +1'), findsOneWidget);
  });

  testWidgets('adding hands back the resref and the first free pack slot', (
    tester,
  ) async {
    final added = <(String, CreItemSlot)>[];
    await pump(
      tester,
      character: characterWith(const []),
      onAdd: (resref, slot) => added.add((resref, slot)),
    );

    await tester.enterText(find.byType(TextField), 'RING01');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(added, [('RING01', CreItemSlot.pack1)]);
  });

  testWidgets('⚠️ scans past a hole rather than counting items', (
    tester,
  ) async {
    // Packs 1 and 3 are taken, 2 is free. Counting items would answer pack 3
    // and overwrite what is already there — the shape a real character has.
    final added = <(String, CreItemSlot)>[];
    await pump(
      tester,
      character: characterWith(const [
        CarriedItem(resref: 'A', index: 0, slotIndex: 21),
        CarriedItem(resref: 'B', index: 1, slotIndex: 23),
      ]),
      onAdd: (resref, slot) => added.add((resref, slot)),
    );

    await tester.enterText(find.byType(TextField), 'RING01');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(added.single.$2, CreItemSlot.pack2);
  });

  testWidgets('says so when the inventory is full, rather than failing', (
    tester,
  ) async {
    await pump(
      tester,
      character: characterWith([
        for (var i = 0; i < 16; i++)
          CarriedItem(
            resref: 'ITEM$i',
            index: i,
            slotIndex: CreItemSlot.pack[i].index,
          ),
      ]),
      onAdd: (_, _) {},
    );
    expect(find.textContaining('inventory is full'), findsOneWidget);
  });

  testWidgets('an empty query shows no results panel at all', (tester) async {
    await pump(tester, character: characterWith(const []), onAdd: (_, _) {});
    expect(find.text('By name'), findsNothing);
    expect(find.text('Found nothing'), findsNothing);
  });
}
