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

/// The inventory layer against a real character, not a synthetic one.
///
/// ⚠️ **The synthetic tests prove the code runs; this proves it is right.** The
/// shapes that matter here were authored by BioWare and by the engine — a hole
/// in the backpack, an unidentified item, a slot table that comes *before* the
/// items section — and every one of them is something a fixture author would
/// have laid out more tidily.
library;

import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  final path = fixtureChr('Aard1');
  final skip = path == null
      ? 'no fixtures: run `fvm dart run tool/dev/sync_fixtures.dart`'
      : null;

  group('Aard1.chr, read through the inventory layer', () {
    late Cre cre;

    setUp(() {
      if (path == null) return;
      final chr = ChrCodec.decode(
        File(path).readAsBytesSync(),
        source: 'Aard1',
      );
      cre = CreCodec.decode(chr.creatureAt(chr.creOffset));
    });

    test('reads all eleven items', () {
      expect(cre.items, hasLength(11));
      expect(
        cre.items.map((i) => i.resref).take(3),
        ['BLUN03', 'BOOT01', 'AX1H03'],
      );
    });

    test(
      '⚠️ BELT16 is NOT identified, which changes the name the game draws',
      () {
        // The engine shows "Belt", not "Belt of Antipode". A sheet that
        // resolves the identified name regardless states something the engine
        // does not — this project's sharpest recurring fault.
        final belt = cre.items.firstWhere((i) => i.resref == 'BELT16');
        expect(belt.isIdentified, isFalse);
        expect(belt.flags, isEmpty);
      },
    );

    test('SCRL3Z carries two flags, not one', () {
      final scroll = cre.items.firstWhere((i) => i.resref == 'SCRL3Z');
      expect(scroll.flags, {
        CreItemFlag.identified,
        CreItemFlag.unstealable,
      });
    });

    test('reads the equipped slots the engine wrote', () {
      // BLUN03 (Flail +1) is in the OFF-HAND, which IESDP calls the shield
      // slot — the naming trap that makes this worth asserting.
      expect(cre.itemIndexAt(CreItemSlot.shield), 0);
      expect(cre.items[0].resref, 'BLUN03');
      expect(cre.itemIndexAt(CreItemSlot.boots), 1);
      expect(cre.items[1].resref, 'BOOT01');
      expect(cre.itemIndexAt(CreItemSlot.weapon1), 2);
      expect(cre.items[2].resref, 'AX1H03');
    });

    test('⚠️ the backpack has a HOLE, and the API scans past it', () {
      // Packs 1-7 and 9 are filled; pack 8 is empty. A "first free slot" that
      // counted items rather than scanning would answer pack 9 and overwrite
      // the quarterstaff sitting there.
      expect(cre.itemIndexAt(CreItemSlot.pack7), isNotNull);
      expect(cre.itemIndexAt(CreItemSlot.pack8), isNull);
      expect(cre.itemIndexAt(CreItemSlot.pack9), isNotNull);
      expect(cre.firstFreePackSlot, CreItemSlot.pack8);
    });

    test('⚠️ every item is referenced by a slot — no orphans', () {
      // The finding that says an added item MUST get a slot word: the engine
      // keeps the table tight, so an unreferenced item is behaviour nothing
      // has been observed to tolerate.
      expect(cre.orphanedItems, isEmpty);
      expect(cre.itemSlots.values.toSet(), hasLength(cre.items.length));
    });

    test('the slot table sits BEFORE the items section on real data', () {
      // Which is why `withEntryInserted`'s relocation branch never fired in a
      // test until one was written for the other order.
      expect(
        cre.readField(CreHeaderField.itemSlotsOffset),
        lessThan(cre.readField(CreHeaderField.itemsOffset)),
      );
    });

    test('⚠️ adding an item changes exactly one item entry and one slot', () {
      final grown = cre
          .withEntryAppended(
            section: CreSection.items,
            entry: itemEntry(resref: 'RING01'),
          )
          .withItemSlot(CreItemSlot.pack8, 11);

      expect(grown.bytes, hasLength(cre.bytes.length + creItemLength));
      expect(grown.items, hasLength(12));
      expect(grown.items.last.resref, 'RING01');
      expect(grown.itemIndexAt(CreItemSlot.pack8), 11);
      expect(grown.orphanedItems, isEmpty);
      // Everything that was already there still reads the same.
      expect(
        grown.items.take(11).map((i) => i.resref),
        cre.items.map((i) => i.resref),
      );
      expect(grown.itemSlots..remove(CreItemSlot.pack8), cre.itemSlots);
    });

    test('⚠️ removing an item renumbers the slots on real data', () {
      // Item 1 is BOOT01 in the boots slot; everything above it shifts down.
      final after = cre.withItemRemoved(1);
      expect(after.items, hasLength(10));
      expect(after.items.map((i) => i.resref), isNot(contains('BOOT01')));
      expect(after.itemIndexAt(CreItemSlot.boots), isNull);
      // AX1H03 was index 2 and is now 1, and weapon 1 must follow it.
      expect(after.itemIndexAt(CreItemSlot.weapon1), 1);
      expect(after.items[1].resref, 'AX1H03');
      expect(after.orphanedItems, isEmpty);
    });

    test('the section chain still closes after both edits', () {
      // The strongest single check on a CRE: one comparison reconciles every
      // section pointer, every entry size and the effect-version flag.
      final grown = cre
          .withEntryAppended(
            section: CreSection.items,
            entry: itemEntry(resref: 'RING01'),
          )
          .withItemSlot(CreItemSlot.pack8, 11);
      expect(grown.contentEnd, grown.bytes.length);
      expect(
        cre.withItemRemoved(1).contentEnd,
        cre.bytes.length - creItemLength,
      );
    });
  }, skip: skip);
}
