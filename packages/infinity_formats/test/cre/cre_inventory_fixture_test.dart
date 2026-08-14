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

    test('⚠️ adding into the HOLE inserts in slot order, not at the end', () {
      // ⚠️ **This test used to assert the bug.** It appended and expected the
      // entry at index 11, which on this record leaves `pack8=[11] pack9=[10]`
      // — an inversion occurring in none of the 41 engine-written records.
      //
      // pack8 is the hole and pack9 is occupied above it, so the entry belongs
      // at 10: the number of occupied slots that precede pack8 (shield, boots,
      // weapon1, packs 1-7). Everything from 10 up shifts by one.
      final grown = cre.withItemAdded(
        entry: itemEntry(resref: 'RING01'),
        slot: CreItemSlot.pack8,
      );

      expect(grown.bytes, hasLength(cre.bytes.length + creItemLength));
      expect(grown.items, hasLength(12));
      expect(
        grown.itemIndexAt(CreItemSlot.pack8),
        10,
        reason: 'ordered, not 11',
      );
      expect(grown.items[10].resref, 'RING01');
      expect(grown.itemIndexAt(CreItemSlot.pack9), 11, reason: 'was 10');
      expect(
        grown.items[11].resref,
        cre.items[10].resref,
        reason: 'follows it',
      );
      expect(grown.orphanedItems, isEmpty);
      // Everything below the splice is untouched, entries and slots alike.
      expect(
        grown.items.take(10).map((i) => i.resref),
        cre.items.take(10).map((i) => i.resref),
      );
      expect(grown.itemIndexAt(CreItemSlot.shield), 0);
      expect(grown.itemIndexAt(CreItemSlot.pack7), 9);
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
      final grown = cre.withItemAdded(
        entry: itemEntry(resref: 'RING01'),
        slot: CreItemSlot.pack8,
      );
      expect(grown.contentEnd, grown.bytes.length);
      expect(
        cre.withItemRemoved(1).contentEnd,
        cre.bytes.length - creItemLength,
      );
    });
  }, skip: skip);

  group('⚠️ the slot-order invariant, across every engine-written record', () {
    /// Every party member of every fixture save, plus every exported `.chr`.
    ///
    /// Deliberately enumerated rather than named: the set grows whenever a save
    /// is synced, and a gate that only ever sees the records someone typed in
    /// is a gate with a blind spot.
    List<(String, Cre)> engineWritten() {
      final found = <(String, Cre)>[];
      final saves = Directory(defaultFixtureSaveRoot);
      if (saves.existsSync()) {
        for (final dir in saves.listSync().whereType<Directory>()) {
          final slot = dir.path.split(Platform.pathSeparator).last;
          final gam = fixtureGam(slot);
          if (gam == null) continue;
          for (final npc in GamCodec.decode(
            File(gam).readAsBytesSync(),
            source: slot,
          ).partyMembers) {
            found.add((
              '$slot/${npc.creResref}',
              CreCodec.decode(npc.creBytes, source: slot),
            ));
          }
        }
      }
      for (final name in fixtureChrNames()) {
        final chr = ChrCodec.decode(
          File(fixtureChr(name)!).readAsBytesSync(),
          source: name,
        );
        found.add((name, CreCodec.decode(chr.creBytes, source: name)));
      }
      return found;
    }

    test('every record walks 0…n−1 in slot order', () {
      // The measurement that found the append bug, promoted to a gate. Sparse
      // slots, dense indices: holes in the backpack are ordinary and do not put
      // holes in the items array.
      final all = engineWritten();
      expect(all, isNotEmpty, reason: 'no fixtures — the check never ran');
      for (final (where, cre) in all) {
        final walked = [
          for (final slot in CreItemSlot.values)
            if (cre.itemSlots[slot] case final int at) at,
        ];
        expect(
          walked,
          List.generate(walked.length, (i) => i),
          reason: '$where — ascending and dense in slot order',
        );
        expect(cre.orphanedItems, isEmpty, reason: where);
      }
    });

    test('and it survives an add into a hole', () {
      // Adding must not be the one thing that breaks what every record holds.
      for (final (where, cre) in engineWritten()) {
        final free = cre.firstFreePackSlot;
        if (free == null || !cre.hasItemSlots) continue;
        final grown = cre.withItemAdded(
          entry: itemEntry(resref: 'RING01'),
          slot: free,
        );
        final walked = [
          for (final slot in CreItemSlot.values)
            if (grown.itemSlots[slot] case final int at) at,
        ];
        expect(
          walked,
          List.generate(walked.length, (i) => i),
          reason: '$where — after adding into ${free.name}',
        );
        expect(grown.contentEnd, grown.bytes.length, reason: where);
      }
    });
  });

  group('⚠️ the engine as the oracle for where an entry goes', () {
    // `000000022-Conan Full Party` and `000000023-Conan Inventory Move` are one
    // in-game inventory transfer apart, so the second is the answer key for the
    // first. Imoen received three scrolls: SCRL68 into her empty `pack1`, then
    // SCRL77 and SCRL67 into `pack7` and `pack8`.
    final before = fixtureGam('000000022-Conan Full Party');
    final after = fixtureGam('000000023-Conan Inventory Move');

    Cre imoenIn(String? gam) => CreCodec.decode(
      GamCodec.decode(
        File(gam!).readAsBytesSync(),
      ).partyMembers.firstWhere((npc) => npc.creResref == '*MOEN1').creBytes,
    );

    test('filling her empty pack1 lands at index 6, as the engine did', () {
      final start = imoenIn(before);
      expect(
        start.itemIndexAt(CreItemSlot.pack1),
        isNull,
        reason: 'the premise: pack1 is the hole',
      );

      final grown = start.withItemAdded(
        entry: itemEntry(resref: 'SCRL68'),
        slot: CreItemSlot.pack1,
      );
      expect(grown.itemIndexAt(CreItemSlot.pack1), 6);
      expect(
        imoenIn(after).itemIndexAt(CreItemSlot.pack1),
        6,
        reason: 'which is what the engine itself wrote',
      );
    });

    test('⚠️ all three adds reproduce the record the engine wrote', () {
      var built = imoenIn(before);
      for (final (resref, slot) in [
        ('SCRL68', CreItemSlot.pack1),
        ('SCRL77', CreItemSlot.pack7),
        ('SCRL67', CreItemSlot.pack8),
      ]) {
        built = built.withItemAdded(
          entry: itemEntry(resref: resref),
          slot: slot,
        );
      }

      final engine = imoenIn(after);
      expect(built.itemSlots, engine.itemSlots, reason: 'every slot word');
      expect(
        built.items.map((i) => i.resref),
        engine.items.map((i) => i.resref),
        reason: 'every entry, in the engine’s own order',
      );
    });
  }, skip: missingPair());
}

/// Why the oracle group cannot run, or `null` when it can.
String? missingPair() =>
    fixtureGam('000000022-Conan Full Party') == null ||
        fixtureGam('000000023-Conan Inventory Move') == null
    ? 'needs the Conan transfer pair: run tool/dev/sync_fixtures.dart'
    : null;
