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
import 'package:wand_of_saves/ui/inventory/item_drag.dart';

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
  bool isDirty = false,
  VoidCallback? onSave,
  Widget? rail,
  int partyPosition = 0,
  bool draggable = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itemCatalogueProvider.overrideWith((ref) async => _catalogue),
      ],
      child: MaterialApp(
        home: InventoryScreen(
          character: () => character,
          onAdd: onAdd,
          isDirty: isDirty,
          onSave: onSave,
          rail: rail,
          partyPosition: draggable ? partyPosition : null,
        ),
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

  group('the editor shell, supplied by the caller', () {
    testWidgets('no Save button when the caller supplies none', (tester) async {
      // The shape a character file gets today, and it must keep working: this
      // screen serves both documents and neither is the less capable surface.
      await pump(tester, character: characterWith(const []), onAdd: (_, _) {});
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    });

    testWidgets('Save is drawn but disabled while nothing is dirty', (
      tester,
    ) async {
      await pump(
        tester,
        character: characterWith(const []),
        onAdd: (_, _) {},
        onSave: () {},
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(button.onPressed, isNull, reason: 'nothing to save yet');
    });

    testWidgets('Save saves once when there are edits', (tester) async {
      var saved = 0;
      await pump(
        tester,
        character: characterWith(const []),
        onAdd: (_, _) {},
        isDirty: true,
        onSave: () => saved++,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(saved, 1);
    });

    testWidgets('the title marks unsaved edits, as both editors do', (
      tester,
    ) async {
      await pump(
        tester,
        character: characterWith(const []),
        onAdd: (_, _) {},
        isDirty: true,
        onSave: () {},
      );
      expect(find.textContaining('\u2022'), findsOneWidget);
    });

    testWidgets('no rail when the caller supplies none', (tester) async {
      // ⚠️ A character file has NO party, so there is nothing for a rail to
      // show. A one-member rail there would be decoration.
      await pump(tester, character: characterWith(const []), onAdd: (_, _) {});
      expect(find.byKey(const Key('inventory-rail')), findsNothing);
    });

    testWidgets('the rail is drawn beside the inventory when supplied', (
      tester,
    ) async {
      await pump(
        tester,
        character: characterWith(const []),
        onAdd: (_, _) {},
        rail: const SizedBox(
          key: Key('inventory-rail'),
          width: 80,
          child: Text('Imoen'),
        ),
      );
      expect(find.byKey(const Key('inventory-rail')), findsOneWidget);
      expect(find.text('Imoen'), findsOneWidget);
      // Still the inventory, not a rail that replaced it.
      expect(find.textContaining('Inventory'), findsWidgets);
    });
  });

  group('dragging an item out of the backpack', () {
    testWidgets('a backpack row is draggable when the caller allows it', (
      tester,
    ) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
        draggable: true,
      );
      expect(find.byType(Draggable<ItemDrag>), findsOneWidget);
    });

    testWidgets('⚠️ an EQUIPPED row is not draggable', (tester) async {
      // Equipment is not modelled, and unequipping would change a stored
      // armour class the engine reads rather than recomputes. Slot 8 is boots.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 8),
        ]),
        onAdd: (_, _) {},
        draggable: true,
      );
      expect(find.byType(Draggable<ItemDrag>), findsNothing);
      expect(find.text('BOOT01'), findsOneWidget, reason: 'still listed');
    });

    testWidgets('nothing is draggable on a document with no party', (
      tester,
    ) async {
      // A `.chr` has nobody to hand an item to.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
      );
      expect(find.byType(Draggable<ItemDrag>), findsNothing);
    });

    testWidgets('⚠️ a VERTICAL pull scrolls the list, it does not drag', (
      tester,
    ) async {
      // ⚠️ **The hazard the research found.** Flutter's own `affinity` doc: a
      // draggable with null or vertical affinity "will out-compete the
      // Scrollable for vertical gestures" — which would make the inventory
      // unscrollable. Horizontal affinity is what keeps both gestures alive,
      // and it matches the geometry: the portraits are to the LEFT.
      await pump(
        tester,
        character: characterWith([
          for (var i = 0; i < 16; i++)
            CarriedItem(resref: 'ITEM$i', index: i, slotIndex: 21 + i),
        ]),
        onAdd: (_, _) {},
        draggable: true,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('ITEM0')),
      );
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();

      expect(
        find.byType(ItemDragFeedback),
        findsNothing,
        reason: 'a vertical pull must not have started a drag',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a HORIZONTAL pull starts the drag', (tester) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
        draggable: true,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('BOOT01')),
      );
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();

      expect(find.byType(ItemDragFeedback), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('what is carried and what is worn are different things', () {
    testWidgets('a pack item sits under Inventory, a worn one under Equipped', (
      tester,
    ) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'RING01', index: 0, slotIndex: 21),
          CarriedItem(resref: 'BOOT01', index: 1, slotIndex: 8),
        ]),
        onAdd: (_, _) {},
      );

      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Equipped'), findsOneWidget);
      expect(find.text('RING01'), findsOneWidget);
      expect(find.text('BOOT01'), findsOneWidget);
    });

    testWidgets('no Equipped panel when nothing is worn', (tester) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'RING01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
      );
      expect(find.text('Equipped'), findsNothing);
      expect(find.text('Inventory'), findsOneWidget);
    });

    testWidgets('⚠️ an item in NO slot is still shown', (tester) async {
      // ⚠️ Legal and observed: 618 items across 220 shipped creature records
      // are referenced by no slot. Rendering only the first two groups would
      // make those rows silently vanish from a screen whose whole job is to
      // show the record.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'GHOST1', index: 0, slotIndex: -1),
        ]),
        onAdd: (_, _) {},
      );
      expect(find.text('GHOST1'), findsOneWidget);
      expect(find.textContaining('will not'), findsOneWidget);
    });

    testWidgets('⚠️ no enum identifier reaches the screen', (tester) async {
      // `slot.name` used to be printed straight out, so a real character's
      // inventory said `leftRing` and `quickItem` at them.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 8),
          CarriedItem(resref: 'RING02', index: 1, slotIndex: 4),
          CarriedItem(resref: 'SW1H06', index: 2, slotIndex: 9),
        ]),
        onAdd: (_, _) {},
      );

      for (final leaked in ['boots', 'leftRing', 'weapon1', 'quickItem']) {
        expect(find.text(leaked), findsNothing, reason: leaked);
      }
      expect(find.text('Boots'), findsOneWidget);
      expect(find.text('Ring'), findsOneWidget);
      expect(find.text('Weapon 1'), findsOneWidget);
    });

    testWidgets('⚠️ the word "backpack" appears nowhere', (tester) async {
      // The game says Inventory — strrefs 6671, 11292 and 24358 — and
      // "Backpack" is in none of its 34,000 strings. The word was ours.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'RING01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
      );
      expect(find.textContaining('backpack'), findsNothing);
      expect(find.textContaining('Backpack'), findsNothing);
    });

    testWidgets('each panel counts its own section', (tester) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'A', index: 0, slotIndex: 21),
          CarriedItem(resref: 'B', index: 1, slotIndex: 22),
          CarriedItem(resref: 'C', index: 2, slotIndex: 8),
        ]),
        onAdd: (_, _) {},
      );
      // Two carried, one worn — not three and three.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });
  });
}
