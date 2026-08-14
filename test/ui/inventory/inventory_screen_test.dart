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
import 'package:wand_of_saves/ui/core/theme.dart';
import 'package:wand_of_saves/ui/inventory/inventory_screen.dart';
import 'package:wand_of_saves/ui/inventory/item_drag.dart';

import '../../support/fakes.dart';

/// ⚠️ Shaped like the installation: `BOOT01`'s name does NOT contain "Boots of
/// Speed" — the game calls it "The Paws of the Cheetah" — and the phrase lives
/// only in its description. That is the whole reason the third tier exists.
const _catalogue = ItemCatalogue({
  'BOW99': ItemEntry(
    resref: 'BOW99',
    itemType: 15,
    identifiedName: 'Protector of the Dryads +2',
    unidentifiedName: 'Shortbow',
    isMovable: false,
  ),
  'TROLLBOO': ItemEntry(
    resref: 'TROLLBOO',
    itemType: 4,
    identifiedName: 'The Paws of the Cheetah',
    unidentifiedName: 'Boots',
  ),
  'BELT16': ItemEntry(
    resref: 'BELT16',
    itemType: 8,
    identifiedName: 'Belt of Antipode',
    unidentifiedName: 'Belt',
  ),
  'RING06': ItemEntry(
    resref: 'RING06',
    itemType: 10,
    identifiedName: 'Ring of Clumsiness',
    isCursed: true,
  ),
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
  void Function(CarriedItem)? onRemove,
  List<String> party = const [],
  void Function(CarriedItem, int to)? onMoveTo,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itemCatalogueProvider.overrideWith((ref) async => _catalogue),
      ],
      child: MaterialApp(
        theme: theme,
        home: InventoryScreen(
          character: () => character,
          onAdd: onAdd,
          isDirty: isDirty,
          onSave: onSave,
          rail: rail,
          partyPosition: draggable ? partyPosition : null,
          onRemove: onRemove,
          party: party,
          onMoveTo: onMoveTo,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '⚠️ the scrollbar has a position on the platform the app ships on',
    (tester) async {
      // `flutter test` runs as Android, where a vertical scroll view attaches
      // itself to the PrimaryScrollController and the Scrollbar finds it by
      // accident. On desktop neither happens: unless the Scrollbar and the
      // scroll view share one controller, the theme's always-visible thumb
      // has nothing to measure and Flutter 3.47 asserts on the first frame.
      // Pin both conditions, or this is the suite that shipped it.
      await pump(
        tester,
        character: characterWith(const []),
        onAdd: (_, _) {},
        theme: AppTheme.light,
      );

      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('mounts and names whose inventory it is', (tester) async {
    // ⚠️ The cheapest guard against the defect that shipped once already: a
    // clean analyze and a green suite are compatible with a screen that throws
    // on its first frame.
    await pump(tester, character: characterWith(const []), onAdd: (_, _) {});
    expect(find.text('Aard · Inventory'), findsOneWidget);
    // ⚠️ No "Nothing yet." any more, and that is the point of the grid: an
    // empty backpack shows sixteen empty slots, so the capacity is countable
    // rather than merely asserted to be unused.
    expect(find.byType(InventoryCell), findsNWidgets(16));
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
      // ⚠️ Was 'Ring' — both hands shared one label, so a character wearing two
      // could not tell the rows apart.
      expect(find.text('Left Ring'), findsOneWidget);
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
      // ⚠️ No counts anywhere: sixteen cells with two filled IS the count, and
      // the Equipped rows are countable by eye. A badge restating what is drawn
      // is the findings-badge-reading-13 failure.
      expect(find.textContaining('/16'), findsNothing);
      expect(find.text('items'), findsNothing);
    });
  });

  group('⚠️ items the engine will never release', () {
    testWidgets('a search that only matches immovable items says so', (
      tester,
    ) async {
      await pump(tester, character: characterWith(const []), onAdd: (_, _) {});

      await tester.enterText(find.byType(TextField), 'protector');
      await tester.pumpAndSettle();

      expect(find.text('BOW99'), findsNothing, reason: 'never offered');
      expect(find.textContaining('withheld'), findsOneWidget);
      expect(find.textContaining('1'), findsWidgets);
    });

    testWidgets('nothing is said when nothing was withheld', (tester) async {
      await pump(tester, character: characterWith(const []), onAdd: (_, _) {});

      await tester.enterText(find.byType(TextField), 'RING01');
      await tester.pumpAndSettle();

      // ⚠️ Not `find.text('RING01')` — the search box holds that text too.
      expect(find.text('Ring of Protection +1'), findsOneWidget);
      expect(find.textContaining('withheld'), findsNothing);
    });

    testWidgets('a CURSED item is offered, and marked', (tester) async {
      // Cursed means "cannot be unequipped", not "cannot be moved" — so it is
      // added like anything else, with the warning said rather than enforced.
      await pump(tester, character: characterWith(const []), onAdd: (_, _) {});

      await tester.enterText(find.byType(TextField), 'clumsiness');
      await tester.pumpAndSettle();

      expect(find.text('RING06'), findsOneWidget);
      expect(find.text('cursed'), findsOneWidget);
    });

    testWidgets('⚠️ an immovable item ALREADY carried is marked', (
      tester,
    ) async {
      // The row that explains itself: BOW99 sitting in Imoen's pack, unable to
      // be dragged when its neighbours can. Without this the difference in
      // affordance has no visible cause.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOW99', index: 0, slotIndex: 21),
          CarriedItem(resref: 'RING01', index: 1, slotIndex: 22),
        ]),
        onAdd: (_, _) {},
        draggable: true,
      );

      expect(find.text('cannot be moved'), findsOneWidget);
      expect(
        find.byType(Draggable<ItemDrag>),
        findsOneWidget,
        reason: 'only the movable one may be dragged',
      );
    });
  });

  group('the backpack is sixteen cells, not a list', () {
    /// The cells of the Inventory grid, in slot order.
    Finder cells() => find.byType(InventoryCell);

    testWidgets('sixteen cells whatever is carried', (tester) async {
      await pump(tester, character: characterWith(const []), onAdd: (_, _) {});
      expect(cells(), findsNWidgets(16), reason: 'empty pack');

      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
      );
      expect(cells(), findsNWidgets(16), reason: 'one item');
    });

    testWidgets('⚠️ an item in pack10 draws in cell 10, not cell 1', (
      tester,
    ) async {
      // ⚠️ **The test that makes the grid honest.** Holes are ordinary — a real
      // character fills packs 1-7 and 9 — so a grid that packed items leftward
      // would be a prettier lie than the list it replaces. Slot 30 is pack10.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
          CarriedItem(resref: 'RING01', index: 1, slotIndex: 30),
        ]),
        onAdd: (_, _) {},
      );

      final drawn = tester.widgetList<InventoryCell>(cells()).toList();
      expect(drawn[0].item?.resref, 'BOOT01', reason: 'pack1');
      expect(drawn[9].item?.resref, 'RING01', reason: 'pack10');
      for (final between in [1, 2, 3, 4, 5, 6, 7, 8]) {
        expect(drawn[between].item, isNull, reason: 'cell ${between + 1}');
      }
    });

    testWidgets('a cell carries the name AND the code', (tester) async {
      // ⚠️ Both earn their place: four items resolve to "The Paws of the
      // Cheetah", so the code is the only thing telling them apart — and one
      // of the four is the immovable one.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
          CarriedItem(resref: 'TROLLBOO', index: 1, slotIndex: 22),
        ]),
        onAdd: (_, _) {},
      );

      expect(find.text('The Paws of the Cheetah'), findsNWidgets(2));
      expect(find.text('BOOT01'), findsOneWidget);
      expect(find.text('TROLLBOO'), findsOneWidget);
    });

    testWidgets('⚠️ an unidentified item shows the name the GAME draws', (
      tester,
    ) async {
      // With the flag clear the engine shows "Belt", not "Belt of Antipode" —
      // `Aard1.chr` carries exactly that case. Showing the identified name
      // would be this app stating something the game does not.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(
            resref: 'BELT16',
            index: 0,
            slotIndex: 21,
            isIdentified: false,
          ),
          CarriedItem(resref: 'BOOT01', index: 1, slotIndex: 22),
        ]),
        onAdd: (_, _) {},
      );

      expect(find.text('Belt'), findsOneWidget);
      expect(find.text('Belt of Antipode'), findsNothing);
      // And the identified neighbour is unaffected.
      expect(find.text('The Paws of the Cheetah'), findsOneWidget);
    });

    testWidgets('falls back to the code when there is no catalogue', (
      tester,
    ) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'XYZZY01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
      );
      expect(find.text('XYZZY01'), findsWidgets);
    });

    testWidgets('an empty cell and an immovable one are not draggable', (
      tester,
    ) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOW99', index: 0, slotIndex: 21),
          CarriedItem(resref: 'BOOT01', index: 1, slotIndex: 22),
        ]),
        onAdd: (_, _) {},
        draggable: true,
      );
      expect(
        find.byType(Draggable<ItemDrag>),
        findsOneWidget,
        reason: 'BOOT01 only — fourteen empties and BOW99 must not drag',
      );
    });
  });

  group('an equipped row describes an item the way a cell does', () {
    testWidgets('⚠️ name as title, code as subtitle, slot as a leading tag', (
      tester,
    ) async {
      // The defect a screenshot of Xzar exposed: the grid said "The Paws of the
      // Cheetah / BOOT01" while the Equipped list said "BOOT01 / Boots" — the
      // same item, the same screen, two descriptions.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 8),
        ]),
        onAdd: (_, _) {},
      );

      expect(find.text('The Paws of the Cheetah'), findsOneWidget);
      expect(find.text('BOOT01'), findsOneWidget);
      expect(find.text('Boots'), findsOneWidget, reason: 'the slot tag');
    });

    testWidgets('⚠️ the identified rule reaches the row, not just the cell', (
      tester,
    ) async {
      // Mutating `nameWhen` must redden this AND the cell's test — the proof
      // the rule is shared rather than copied into each surface.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(
            resref: 'BELT16',
            index: 0,
            slotIndex: 7,
            isIdentified: false,
          ),
        ]),
        onAdd: (_, _) {},
      );

      // ⚠️ Twice, and that is not a defect: an unidentified BELT16 is called
      // "Belt" and it sits in the slot the game also calls "Belt", so the title
      // and the slot tag read the same. The claim under test is the absence of
      // the identified name.
      expect(find.text('Belt'), findsNWidgets(2));
      expect(find.text('Belt of Antipode'), findsNothing);
    });

    testWidgets('⚠️ two rings are tellable apart', (tester) async {
      // Both slots mapped to "Ring", so a character wearing two could not tell
      // which row was which. Slot 4 is the left ring, slot 5 the right.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'RING01', index: 0, slotIndex: 4),
          CarriedItem(resref: 'RING06', index: 1, slotIndex: 5),
        ]),
        onAdd: (_, _) {},
      );

      expect(find.text('Left Ring'), findsOneWidget);
      expect(find.text('Right Ring'), findsOneWidget);
      expect(find.text('Ring'), findsNothing, reason: 'ambiguous on its own');
    });

    testWidgets('falls back to the code with no catalogue', (tester) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'XYZZY01', index: 0, slotIndex: 8),
        ]),
        onAdd: (_, _) {},
      );
      expect(find.text('XYZZY01'), findsWidgets);
      expect(find.text('Boots'), findsOneWidget);
    });

    testWidgets('the no-slot warning is said once, by the panel', (
      tester,
    ) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: -1),
          CarriedItem(resref: 'RING01', index: 1, slotIndex: -1),
        ]),
        onAdd: (_, _) {},
      );
      // Two rows, one explanation — not the sentence repeated per row.
      expect(find.textContaining('will not'), findsOneWidget);
    });
  });

  group('every item carries a menu', () {
    Future<void> openMenu(WidgetTester tester, {int at = 0}) async {
      // ⚠️ The Equipped panel sits below sixteen grid cells, which puts it off
      // the bottom of an 800x600 test viewport.
      final button = find.byIcon(Icons.more_horiz).at(at);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('an occupied cell has one; an empty cell does not', (
      tester,
    ) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
        onRemove: (_) {},
      );
      // One cell filled out of sixteen, one equipped row: one menu button.
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('no menu at all when the caller offers no actions', (
      tester,
    ) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
      );
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('⚠️ Remove hands back the item it belongs to', (tester) async {
      final removed = <CarriedItem>[];
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
          CarriedItem(resref: 'RING01', index: 1, slotIndex: 22),
        ]),
        onAdd: (_, _) {},
        onRemove: removed.add,
      );

      await openMenu(tester, at: 1);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(removed.single.resref, 'RING01', reason: 'the second cell');
    });

    testWidgets('⚠️ an EQUIPPED row has a menu too, the best case there is', (
      tester,
    ) async {
      // A cursed item already worn is one the game itself can never remove.
      final removed = <CarriedItem>[];
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 8),
        ]),
        onAdd: (_, _) {},
        onRemove: removed.add,
      );

      await openMenu(tester);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(removed.single.resref, 'BOOT01');
    });

    testWidgets('Move to lists the party and excludes the owner', (
      tester,
    ) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
        onRemove: (_) {},
        party: const ['Conan', 'Imoen', 'Xzar'],
        partyPosition: 1,
        draggable: true,
        onMoveTo: (_, _) {},
      );

      await openMenu(tester);
      await tester.tap(find.text('Move to'));
      await tester.pumpAndSettle();

      expect(find.text('Conan'), findsOneWidget);
      expect(find.text('Xzar'), findsOneWidget);
      expect(find.text('Imoen'), findsNothing, reason: 'already has it');
    });

    testWidgets('Move to is absent with no party', (tester) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
        onRemove: (_) {},
      );
      await openMenu(tester);
      expect(find.text('Move to'), findsNothing);
    });

    testWidgets('choosing a member hands back who was chosen', (tester) async {
      final moved = <(String, int)>[];
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
        onRemove: (_) {},
        party: const ['Conan', 'Imoen', 'Xzar'],
        draggable: true,
        onMoveTo: (item, to) => moved.add((item.resref, to)),
      );

      await openMenu(tester);
      await tester.tap(find.text('Move to'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xzar'));
      await tester.pumpAndSettle();

      expect(moved.single, ('BOOT01', 2));
    });
  });

  group('⚠️ an equipped item has nowhere to be moved to', () {
    Future<void> openMenu(WidgetTester tester, {int at = 0}) async {
      final button = find.byIcon(Icons.more_horiz).at(at);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('an EQUIPPED row offers no Move to at all', (tester) async {
      // ⚠️ **The bug this fixes.** The menu offered `Move to → <member>` on
      // every row while `MoveItem` refuses anything outside a backpack slot, so
      // choosing a member for an equipped item threw. The drag path had the
      // rule right; the menu had a second copy of it, wrong.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 8),
        ]),
        onAdd: (_, _) {},
        onRemove: (_) {},
        party: const ['Conan', 'Imoen', 'Xzar'],
        draggable: true,
        onMoveTo: (_, _) {},
      );

      await openMenu(tester);
      expect(find.text('Move to'), findsNothing);
      expect(find.text('Remove'), findsOneWidget, reason: 'still removable');
    });

    testWidgets('a BACKPACK row still offers it', (tester) async {
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
        onRemove: (_) {},
        party: const ['Conan', 'Imoen', 'Xzar'],
        draggable: true,
        onMoveTo: (_, _) {},
      );

      await openMenu(tester);
      expect(find.text('Move to'), findsOneWidget);
    });

    testWidgets('⚠️ an IMMOVABLE backpack item offers no Move to either', (
      tester,
    ) async {
      // The second half of the same bug: handing `BOW99` on would simply
      // strand it on somebody else. The drag already refused it; the menu did
      // not, because it carried its own copy of the rule.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOW99', index: 0, slotIndex: 21),
        ]),
        onAdd: (_, _) {},
        onRemove: (_) {},
        party: const ['Conan', 'Imoen', 'Xzar'],
        draggable: true,
        onMoveTo: (_, _) {},
      );

      await openMenu(tester);
      expect(find.text('Move to'), findsNothing);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('an item in NO slot offers no Move to either', (tester) async {
      // It is not in a backpack slot, so the command would refuse it just the
      // same.
      await pump(
        tester,
        character: characterWith(const [
          CarriedItem(resref: 'BOOT01', index: 0, slotIndex: -1),
        ]),
        onAdd: (_, _) {},
        onRemove: (_) {},
        party: const ['Conan', 'Imoen', 'Xzar'],
        draggable: true,
        onMoveTo: (_, _) {},
      );

      await openMenu(tester);
      expect(find.text('Move to'), findsNothing);
    });
  });
}
