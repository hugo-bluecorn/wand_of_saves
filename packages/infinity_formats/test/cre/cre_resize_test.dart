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

/// Growing a creature record — the first edit in this project that resizes.
///
/// ⚠️ **Every other writer here patches a fixed-width field in place.** This
/// one moves bytes, so the gate is different: `Cre.contentEnd` reconciles all
/// six section pointers against the file length, and must still do so after.
/// A shifted-but-corrupt section is the failure mode, which is why one test
/// compares a later section byte for byte at its new home.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

void main() {
  /// A creature with the sections asked for, laid out in the file's own order.
  ///
  /// Absent sections carry offset `0`, which is what `CHARBASE` does and what
  /// the shift has to respect.
  Cre creature({int effects = 0, int knownSpells = 0, int items = 0}) {
    const stride = creEffectV2Length;
    var at = CreHeaderField.headerSize;

    final knownAt = knownSpells > 0 ? at : 0;
    at += knownSpells * creKnownSpellLength;
    final itemsAt = items > 0 ? at : 0;
    at += items * creItemLength;
    final effectsAt = effects > 0 ? at : 0;
    at += effects * stride;

    final out = Uint8List(at)
      ..setRange(0, 4, latin1.encode('CRE '))
      ..setRange(4, 8, latin1.encode('V1.0'));
    final view = ByteData.sublistView(out)
      // 1 means the 264-byte v2 effect, which is what BG:EE writes.
      ..setUint8(CreHeaderField.effectVersion.offset, 1)
      ..setUint32(
        CreHeaderField.knownSpellsOffset.offset,
        knownAt,
        Endian.little,
      )
      ..setUint32(
        CreHeaderField.knownSpellsCount.offset,
        knownSpells,
        Endian.little,
      )
      ..setUint32(CreHeaderField.itemsOffset.offset, itemsAt, Endian.little)
      ..setUint32(CreHeaderField.itemsCount.offset, items, Endian.little)
      ..setUint32(CreHeaderField.effectsOffset.offset, effectsAt, Endian.little)
      ..setUint32(CreHeaderField.effectsCount.offset, effects, Endian.little);
    // Something recognisable in each section, so a bad shift is visible.
    for (var i = 0; i < out.length - CreHeaderField.headerSize; i++) {
      out[CreHeaderField.headerSize + i] = (i % 251) + 1;
    }
    // The header must survive the fill above.
    out
      ..setRange(0, 4, latin1.encode('CRE '))
      ..setRange(4, 8, latin1.encode('V1.0'));
    view.setUint8(CreHeaderField.effectVersion.offset, 1);
    return CreCodec.decode(out);
  }

  Uint8List entryOf(int stride, int marker) =>
      Uint8List(stride)..fillRange(0, stride, marker);

  group('appending an entry to a section that already has some', () {
    test('the count goes up and the file grows by exactly one stride', () {
      final before = creature(effects: 2);

      final after = before.withEntryAppended(
        section: CreSection.effects,
        entry: entryOf(before.effectLength, 0xAB),
      );

      expect(after.effectsCount, before.effectsCount + 1);
      expect(after.bytes, hasLength(before.bytes.length + before.effectLength));
    });

    test('the record still reconciles — contentEnd is the file length', () {
      // The strongest single check a CRE has: one comparison covers all six
      // section pointers, every entry size and the effect-version flag.
      final after = creature(effects: 2).withEntryAppended(
        section: CreSection.effects,
        entry: entryOf(264, 0xAB),
      );

      expect(after.contentEnd, after.bytes.length);
    });

    test('the appended bytes are the ones handed in', () {
      final before = creature(effects: 1);
      final entry = entryOf(before.effectLength, 0x5A);

      final after = before.withEntryAppended(
        section: CreSection.effects,
        entry: entry,
      );

      final at = after.effectsOffset + before.effectsCount * after.effectLength;
      expect(after.bytes.sublist(at, at + entry.length), entry);
    });

    test('leaves the creature it was given alone', () {
      final before = creature(effects: 1);
      final length = before.bytes.length;

      before.withEntryAppended(
        section: CreSection.effects,
        entry: entryOf(before.effectLength, 1),
      );

      expect(before.bytes, hasLength(length));
      expect(before.effectsCount, 1);
    });
  });

  group('a section that was not there at all', () {
    test('is created rather than written at offset zero', () {
      // ⚠️ **An offset of `0` means absent.** `CHARBASE` carries no effects at
      // all, so granting a proficiency has to *make* the section — and writing
      // the entry at 0 would land it on the signature.
      final before = creature();
      expect(before.effectsOffset, 0);

      final after = before.withEntryAppended(
        section: CreSection.effects,
        entry: entryOf(before.effectLength, 0x11),
      );

      expect(
        after.effectsOffset,
        greaterThanOrEqualTo(CreHeaderField.headerSize),
      );
      expect(after.effectsCount, 1);
      expect(after.contentEnd, after.bytes.length);
    });
  });

  group('what the shift must not break', () {
    test('a section after the insertion moves and keeps its bytes exactly', () {
      // ⚠️ The real failure mode. Shifting an offset without moving the bytes,
      // or moving them by the wrong amount, still parses — it just reads the
      // wrong thing forever.
      final before = creature(knownSpells: 2, effects: 1, items: 1);
      final itemsBefore = before.bytes.sublist(
        before.itemsOffset,
        before.itemsOffset + before.itemsCount * creItemLength,
      );

      final after = before.withEntryAppended(
        section: CreSection.knownSpells,
        entry: entryOf(creKnownSpellLength, 0x77),
      );

      expect(after.itemsOffset, before.itemsOffset + creKnownSpellLength);
      expect(
        after.bytes.sublist(
          after.itemsOffset,
          after.itemsOffset + after.itemsCount * creItemLength,
        ),
        itemsBefore,
      );
      expect(after.contentEnd, after.bytes.length);
    });

    test('a section before the insertion does not move', () {
      final before = creature(knownSpells: 1, effects: 1);

      final after = before.withEntryAppended(
        section: CreSection.effects,
        entry: entryOf(before.effectLength, 0x22),
      );

      expect(after.knownSpellsOffset, before.knownSpellsOffset);
    });

    test('an absent section keeps its zero rather than being shifted', () {
      // Adding the stride to a `0` would turn "absent" into a real pointer at
      // the stride, which is the −180 mistake in a new costume.
      final before = creature(effects: 1);
      expect(before.itemsOffset, 0);

      final after = before.withEntryAppended(
        section: CreSection.effects,
        entry: entryOf(before.effectLength, 0x33),
      );

      expect(after.itemsOffset, 0);
    });
  });

  group('refusals', () {
    test('an entry of the wrong size is refused rather than written', () {
      final before = creature(effects: 1);

      expect(
        () => before.withEntryAppended(
          section: CreSection.effects,
          entry: entryOf(10, 0),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
