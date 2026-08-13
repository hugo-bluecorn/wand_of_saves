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
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

/// A creature carrying [items] items, with a real slot table.
///
/// ⚠️ **The slot table comes BEFORE the items section**, which is the order
/// every real `.chr` fixture uses — and it is why `withEntryInserted`'s
/// slot-relocation branch had never fired in a test. [slotsAfterItems] builds
/// the other order so that branch can be exercised too.
Cre creature({
  int items = 0,
  Map<CreItemSlot, int> slots = const {},
  bool slotsAfterItems = false,
}) {
  var at = CreHeaderField.headerSize;
  final slotsFirst = !slotsAfterItems;
  final slotsAt = slotsFirst ? at : at + items * creItemLength;
  if (slotsFirst) at += creItemSlotsLength;
  final itemsAt = items > 0 ? at : 0;
  at += items * creItemLength;
  if (!slotsFirst) at += creItemSlotsLength;

  final total = slotsFirst ? at : slotsAt + creItemSlotsLength;
  final out = Uint8List(total)
    ..setRange(0, 4, latin1.encode('CRE '))
    ..setRange(4, 8, latin1.encode('V1.0'));
  final view = ByteData.sublistView(out)
    ..setUint8(CreHeaderField.effectVersion.offset, 1)
    ..setUint32(CreHeaderField.itemSlotsOffset.offset, slotsAt, Endian.little)
    ..setUint32(CreHeaderField.itemsOffset.offset, itemsAt, Endian.little)
    ..setUint32(CreHeaderField.itemsCount.offset, items, Endian.little);

  // Every slot empty, then the ones asked for.
  for (var i = 0; i < 40; i++) {
    view.setUint16(slotsAt + i * 2, CreItemSlot.empty, Endian.little);
  }
  // ⚠️ The two trailing words are selection state, not slots. Zero, as the
  // fixtures hold — and a writer that treats them as items would break this.
  view
    ..setUint16(slotsAt + CreItemSlot.selectedWeaponOffset, 0, Endian.little)
    ..setUint16(
      slotsAt + CreItemSlot.selectedWeaponAbilityOffset,
      0,
      Endian.little,
    );
  slots.forEach((slot, index) {
    view.setUint16(slotsAt + slot.byteOffset, index, Endian.little);
  });

  for (var i = 0; i < items; i++) {
    out.setRange(
      itemsAt + i * creItemLength,
      itemsAt + (i + 1) * creItemLength,
      itemEntry(resref: 'ITEM$i', quantity: i + 1),
    );
  }
  return CreCodec.decode(out);
}

void main() {
  group('Cre.items', () {
    test('reads nothing when the section is absent', () {
      expect(creature().items, isEmpty);
    });

    test('reads every entry, in order', () {
      final cre = creature(items: 3);
      expect(cre.items.map((i) => i.resref), ['ITEM0', 'ITEM1', 'ITEM2']);
      expect(cre.items.map((i) => i.quantity), [1, 2, 3]);
    });

    test('reads the flags back as a set', () {
      final cre = creature(items: 1);
      expect(cre.items.single.flags, {CreItemFlag.identified});
      expect(cre.items.single.isIdentified, isTrue);
    });
  });

  group('Cre.itemSlots', () {
    test('reports only the occupied slots', () {
      final cre = creature(
        items: 2,
        slots: {CreItemSlot.boots: 0, CreItemSlot.pack1: 1},
      );
      expect(cre.itemSlots, {CreItemSlot.boots: 0, CreItemSlot.pack1: 1});
    });

    test('an empty table reports nothing', () {
      expect(creature(items: 1).itemSlots, isEmpty);
    });

    test('⚠️ never reports the two trailing selection words', () {
      // They sit at indices 38 and 39 holding 0, which as an item index would
      // read as "item 0 is equipped here" — twice.
      final cre = creature(items: 1);
      expect(cre.itemSlots, isEmpty);
      expect(cre.itemSlots.keys, everyElement(isA<CreItemSlot>()));
    });

    test('answers for one slot', () {
      final cre = creature(items: 1, slots: {CreItemSlot.boots: 0});
      expect(cre.itemIndexAt(CreItemSlot.boots), 0);
      expect(cre.itemIndexAt(CreItemSlot.helmet), isNull);
    });

    test('finds the first free backpack slot, scanning past holes', () {
      // ⚠️ Holes are legal: `Aard1.chr` uses packs 1-7 and 9, leaving 8 empty.
      // Counting rather than scanning puts the next item on top of pack 9.
      final cre = creature(
        items: 3,
        slots: {CreItemSlot.pack1: 0, CreItemSlot.pack3: 1},
      );
      expect(cre.firstFreePackSlot, CreItemSlot.pack2);
    });

    test('answers null when the backpack is full', () {
      final full = {
        for (var i = 0; i < 16; i++) CreItemSlot.pack[i]: i,
      };
      expect(creature(items: 16, slots: full).firstFreePackSlot, isNull);
    });
  });

  group('Cre.withItemSlot', () {
    test('points a slot at an item', () {
      final cre = creature(items: 1).withItemSlot(CreItemSlot.boots, 0);
      expect(cre.itemIndexAt(CreItemSlot.boots), 0);
      expect(cre.bytes, hasLength(creature(items: 1).bytes.length));
    });

    test('clears a slot', () {
      final cre = creature(
        items: 1,
        slots: {CreItemSlot.boots: 0},
      ).withItemSlot(CreItemSlot.boots, null);
      expect(cre.itemIndexAt(CreItemSlot.boots), isNull);
    });

    test('⚠️ changes exactly two bytes', () {
      final before = creature(items: 2);
      final after = before.withItemSlot(CreItemSlot.pack1, 1);
      final differing = [
        for (var i = 0; i < before.bytes.length; i++)
          if (before.bytes[i] != after.bytes[i]) i,
      ];
      expect(differing, hasLength(2), reason: 'one word, nothing else');
    });

    test('refuses an item index the record does not have', () {
      expect(
        () => creature(items: 1).withItemSlot(CreItemSlot.boots, 5),
        throwsA(isA<RangeError>()),
      );
    });

    test('refuses to write a slot when there is no table', () {
      final noTable = CreCodec.decode(
        Uint8List(CreHeaderField.headerSize)
          ..setRange(0, 4, latin1.encode('CRE '))
          ..setRange(4, 8, latin1.encode('V1.0')),
      );
      expect(
        () => noTable.withItemSlot(CreItemSlot.boots, 0),
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });

  group('Cre.withItemRemoved', () {
    test('drops the entry and shrinks the record', () {
      final before = creature(items: 3, slots: {CreItemSlot.pack1: 1});
      final after = before.withItemRemoved(1);
      expect(after.items.map((i) => i.resref), ['ITEM0', 'ITEM2']);
      expect(after.bytes, hasLength(before.bytes.length - creItemLength));
    });

    test('⚠️ renumbers every slot above the one removed', () {
      // The hazard `withEntryInserted` documents for memorisation windows and
      // never documented for items: slot words are INDICES, so removing item 1
      // leaves anything pointing at 2 pointing at the wrong item.
      final before = creature(
        items: 3,
        slots: {
          CreItemSlot.boots: 0,
          CreItemSlot.pack1: 1,
          CreItemSlot.pack2: 2,
        },
      );
      final after = before.withItemRemoved(1);
      expect(after.itemIndexAt(CreItemSlot.boots), 0, reason: 'below, unmoved');
      expect(after.itemIndexAt(CreItemSlot.pack1), isNull, reason: 'cleared');
      expect(after.itemIndexAt(CreItemSlot.pack2), 1, reason: 'was 2');
      // And it still points at the item it always did.
      expect(
        after.items[after.itemIndexAt(CreItemSlot.pack2)!].resref,
        'ITEM2',
      );
    });

    test('refuses an index that is not there', () {
      expect(
        () => creature(items: 2).withItemRemoved(2),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('adding an item composes from what already exists', () {
    test('append the entry, then point a slot at it', () {
      final before = creature(items: 1, slots: {CreItemSlot.pack1: 0});
      final after = before
          .withEntryAppended(
            section: CreSection.items,
            entry: itemEntry(resref: 'BOOT01'),
          )
          .withItemSlot(CreItemSlot.pack2, 1);

      expect(after.items.map((i) => i.resref), ['ITEM0', 'BOOT01']);
      expect(after.itemIndexAt(CreItemSlot.pack2), 1);
      expect(after.bytes, hasLength(before.bytes.length + creItemLength));
    });

    test('⚠️ an item nothing points at is invisible in game', () {
      // Not a failure this can assert against the engine, but it can assert
      // the shape: every fixture references every item from a slot, so an
      // append without a slot write leaves an orphan.
      final orphaned = creature(items: 1).withEntryAppended(
        section: CreSection.items,
        entry: itemEntry(resref: 'BOOT01'),
      );
      expect(orphaned.items, hasLength(2));
      expect(orphaned.itemSlots, isEmpty);
      expect(orphaned.orphanedItems, [0, 1]);
    });
  });

  group('⚠️ the slot-relocation branch, never exercised until now', () {
    test('the table moves when it sits after the items section', () {
      // `withEntryInserted` shifts `itemSlotsOffset` when the table is at or
      // after the splice. Every real fixture puts the table FIRST, so this
      // branch had no coverage at all — and it is the branch that keeps a
      // grown record's slots readable.
      final before = creature(
        items: 1,
        slots: {CreItemSlot.boots: 0},
        slotsAfterItems: true,
      );
      final slotsBefore = before.readField(CreHeaderField.itemSlotsOffset);

      final after = before.withEntryAppended(
        section: CreSection.items,
        entry: itemEntry(resref: 'BOOT01'),
      );

      expect(
        after.readField(CreHeaderField.itemSlotsOffset),
        slotsBefore + creItemLength,
      );
      // The words themselves survive the move.
      expect(after.itemIndexAt(CreItemSlot.boots), 0);
    });
  });
}
