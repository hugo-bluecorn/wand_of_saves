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

  group('inserting somewhere other than the end', () {
    // ⚠️ **The memorisation rows are why this exists.** Each names a window of
    // the memorised-spells array, so a second spell of a level that already has
    // one goes *inside* the array, not after it — and appending would file it
    // under whichever window happens to come last.
    test('the entry lands at the index asked for', () {
      final before = creature(knownSpells: 3);
      final third = before.bytes.sublist(
        before.knownSpellsOffset + 2 * creKnownSpellLength,
        before.knownSpellsOffset + 3 * creKnownSpellLength,
      );

      final after = before.withEntryInserted(
        section: CreSection.knownSpells,
        at: 1,
        entry: entryOf(creKnownSpellLength, 0x6B),
      );

      final at = after.knownSpellsOffset + creKnownSpellLength;
      expect(
        after.bytes.sublist(at, at + creKnownSpellLength),
        entryOf(creKnownSpellLength, 0x6B),
      );
      expect(after.knownSpellsCount, 4);
      expect(after.contentEnd, after.bytes.length);
      // What was third is now fourth, byte for byte — the check that separates
      // "the count went up" from "the entries after it survived".
      final moved = after.knownSpellsOffset + 3 * creKnownSpellLength;
      expect(after.bytes.sublist(moved, moved + creKnownSpellLength), third);
    });

    test('inserting at zero leaves the section where it started', () {
      final before = creature(knownSpells: 2, items: 1);

      final after = before.withEntryInserted(
        section: CreSection.knownSpells,
        at: 0,
        entry: entryOf(creKnownSpellLength, 0x01),
      );

      expect(after.knownSpellsOffset, before.knownSpellsOffset);
      expect(after.itemsOffset, before.itemsOffset + creKnownSpellLength);
      expect(after.contentEnd, after.bytes.length);
    });

    test('appending is the same call at the end', () {
      final before = creature(knownSpells: 2);
      final entry = entryOf(creKnownSpellLength, 0x2C);

      expect(
        before
            .withEntryInserted(
              section: CreSection.knownSpells,
              at: 2,
              entry: entry,
            )
            .bytes,
        before
            .withEntryAppended(section: CreSection.knownSpells, entry: entry)
            .bytes,
      );
    });

    test('an index past the end is refused rather than clamped', () {
      final before = creature(knownSpells: 2);

      expect(
        () => before.withEntryInserted(
          section: CreSection.knownSpells,
          at: 3,
          entry: entryOf(creKnownSpellLength, 0),
        ),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('patching one field of one entry', () {
    test('writes through the entry’s own layout', () {
      final before = creature(knownSpells: 2);

      final after = before.withEntryField(
        section: CreSection.knownSpells,
        at: 1,
        field: CreKnownSpellField.type,
        value: 2,
      );

      expect(after.knownSpells[1].type, 2);
      expect(after.knownSpells[0].type, before.knownSpells[0].type);
      expect(after.bytes, hasLength(before.bytes.length));
    });

    test('a value the field cannot hold is refused, never truncated', () {
      // A wrapped number written into someone's character is exactly the
      // silent corruption this project is shaped around.
      final before = creature(knownSpells: 1);

      expect(
        () => before.withEntryField(
          section: CreSection.knownSpells,
          at: 0,
          field: CreKnownSpellField.type,
          value: 70000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('an entry index outside the section is refused', () {
      final before = creature(knownSpells: 1);

      expect(
        () => before.withEntryField(
          section: CreSection.knownSpells,
          at: 1,
          field: CreKnownSpellField.type,
          value: 0,
        ),
        throwsA(isA<RangeError>()),
      );
    });

    test('a field from the wrong layout cannot reach the next entry', () {
      // `CreMemorizationField.count` sits at 0x0c+4, which runs past a 12-byte
      // known-spell entry and into its neighbour. Refusing on the stride is
      // what stops one table being used to write through another.
      final before = creature(knownSpells: 2);

      expect(
        () => before.withEntryField(
          section: CreSection.knownSpells,
          at: 0,
          field: CreMemorizationField.count,
          value: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('the effect version, which decides the stride', () {
    // ⚠️ **`CHARBASE` stores 0 and the engine's own finished character stores
    // 1.** So a record arrives from the template claiming 48-byte v1 effects
    // and has to become v2 before a 264-byte proficiency can be appended. The
    // flag is free to change only because the template carries **no effects**;
    // with any present it would reinterpret bytes already written.
    Cre templateShaped() {
      final out = Uint8List(CreHeaderField.headerSize)
        ..setRange(0, 4, latin1.encode('CRE '))
        ..setRange(4, 8, latin1.encode('V1.0'));
      ByteData.sublistView(out)
        ..setUint8(CreHeaderField.effectVersion.offset, 0)
        ..setUint32(
          CreHeaderField.effectsOffset.offset,
          CreHeaderField.headerSize,
          Endian.little,
        );
      return CreCodec.decode(out);
    }

    test('an empty section changes stride and nothing else moves', () {
      final before = templateShaped();
      expect(before.effectLength, creEffectV1Length);

      final after = before.withEffectVersion(1);

      expect(after.effectLength, creEffectV2Length);
      expect(after.bytes, hasLength(before.bytes.length));
      expect(after.contentEnd, after.bytes.length);
    });

    test('a v2 entry then fits where it did not before', () {
      final after = templateShaped()
          .withEffectVersion(1)
          .withEntryAppended(
            section: CreSection.effects,
            entry: entryOf(creEffectV2Length, 0x99),
          );

      expect(after.effectsCount, 1);
      expect(after.contentEnd, after.bytes.length);
    });

    test('⚠️ a record that already holds effects refuses', () {
      // Changing the stride under existing entries does not move a byte and
      // reinterprets every one of them — the quietest possible corruption.
      final populated = creature(effects: 2);

      expect(
        () => populated.withEffectVersion(0),
        throwsA(isA<StateError>()),
      );
    });

    test('asking for the version it already has is not a refusal', () {
      final populated = creature(effects: 2);

      expect(populated.withEffectVersion(1).effectLength, creEffectV2Length);
    });

    test('a version the format does not define is refused', () {
      expect(
        () => templateShaped().withEffectVersion(2),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('reading one field by its table entry', () {
    // The read counterpart of `withCreatureField`, and it exists because two
    // callers wanted it: a golden test comparing six abilities, and the probe
    // tool checking that every value it wrote survived the round trip. Both had
    // been writing the six out by hand.
    test('honours the width and signedness the table declares', () {
      final cre = creature(effects: 1);
      final patched = CreCodec.decode(
        Uint8List.fromList(cre.bytes)
          ..[CreHeaderField.strength.offset] = 18
          ..buffer.asByteData().setInt16(
            CreHeaderField.armorClassEffective.offset,
            -5,
            Endian.little,
          ),
      );

      expect(patched.readField(CreHeaderField.strength), 18);
      // ⚠️ Signed. An unsigned read of −5 is 65531, which is the bug the
      // armour-class field already produced once.
      expect(patched.readField(CreHeaderField.armorClassEffective), -5);
    });

    test('agrees with the accessor written for the same field', () {
      final cre = creature(effects: 1);

      expect(cre.readField(CreHeaderField.thac0), cre.thac0);
      expect(cre.readField(CreHeaderField.effectsCount), cre.effectsCount);
    });

    test('a field it cannot read numerically is refused', () {
      expect(
        () => creature().readField(CreHeaderField.dialogFile),
        throwsA(isA<InfinityFormatException>()),
      );
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
