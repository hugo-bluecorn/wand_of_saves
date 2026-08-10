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

/// The three spell sections, read through their own field tables.
///
/// ⚠️ **The middle one is the reason these are tables rather than literals.** A
/// memorisation-info entry holds an *index into another section*, so six fields
/// have to agree with each other and with the memorised array. Written inline,
/// that is six chances to transpose a number; as a layout it is one table the
/// reader and the writer share (D6).
///
/// Offsets come from `../iesdp/file_formats/ie_formats/cre_v1.htm`, read rather
/// than recalled, and are confirmed against a character the engine made.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/layout.dart';

void main() {
  group('the layouts account for exactly the entry they describe', () {
    // The assertion the stride bug came from: a table that stops short of its
    // declared size means one of the two numbers is wrong, and reading an
    // array at that stride corrupts everything past the first element.
    test('a known spell is 12 bytes with no gaps', () {
      expect(
        layoutProblems(
          CreKnownSpellField.values,
          structSize: creKnownSpellLength,
        ),
        isEmpty,
      );
    });

    test('a memorisation-info entry is 16 bytes with no gaps', () {
      expect(
        layoutProblems(
          CreMemorizationField.values,
          structSize: creMemorizationInfoLength,
        ),
        isEmpty,
      );
    });

    test('a memorised spell is 12 bytes with no gaps', () {
      expect(
        layoutProblems(
          CreMemorizedSpellField.values,
          structSize: creMemorizedSpellLength,
        ),
        isEmpty,
      );
    });
  });

  group('reading the sections back', () {
    /// A creature with one entry in each of the three spell sections.
    Cre creature() {
      const known = CreHeaderField.headerSize;
      const info = known + creKnownSpellLength;
      const memorized = info + creMemorizationInfoLength;
      const end = memorized + creMemorizedSpellLength;

      final out = Uint8List(end)
        ..setRange(0, 4, 'CRE '.codeUnits)
        ..setRange(4, 8, 'V1.0'.codeUnits)
        ..setRange(known, known + 7, 'SPWI112'.codeUnits)
        ..setRange(memorized, memorized + 7, 'SPWI112'.codeUnits);
      ByteData.sublistView(out)
        ..setUint32(CreHeaderField.knownSpellsOffset.offset, known, _le)
        ..setUint32(CreHeaderField.knownSpellsCount.offset, 1, _le)
        ..setUint32(CreHeaderField.memorizationInfoOffset.offset, info, _le)
        ..setUint32(CreHeaderField.memorizationInfoCount.offset, 1, _le)
        ..setUint32(CreHeaderField.memorizedSpellsOffset.offset, memorized, _le)
        ..setUint32(CreHeaderField.memorizedSpellsCount.offset, 1, _le)
        // The known spell: first level, wizard.
        ..setUint16(known + CreKnownSpellField.levelLessOne.offset, 0, _le)
        ..setUint16(known + CreKnownSpellField.type.offset, 1, _le)
        // The info row: one memorisable, one memorised, starting at index 0.
        ..setUint16(info + CreMemorizationField.levelLessOne.offset, 0, _le)
        ..setUint16(info + CreMemorizationField.memorisable.offset, 1, _le)
        ..setUint16(info + CreMemorizationField.afterEffects.offset, 1, _le)
        ..setUint16(info + CreMemorizationField.type.offset, 1, _le)
        ..setUint32(info + CreMemorizationField.firstIndex.offset, 0, _le)
        ..setUint32(info + CreMemorizationField.count.offset, 1, _le)
        ..setUint32(memorized + CreMemorizedSpellField.flags.offset, 1, _le);
      return CreCodec.decode(out);
    }

    test('a known spell comes back as the level a player counts', () {
      // ⚠️ IESDP calls the field "Spell Level -1", so the reader adds one. A
      // book full of level-0 spells is what happens when it does not.
      final spell = creature().knownSpells.single;

      expect(spell.resref, 'SPWI112');
      expect(spell.level, 1);
      expect(spell.type, 1);
    });

    test('a memorisation row carries its window into the memorised array', () {
      final row = creature().memorizations.single;

      expect(row.level, 1);
      expect(row.memorisable, 1);
      expect(row.afterEffects, 1);
      expect(row.type, 1);
      expect(row.firstIndex, 0);
      expect(row.count, 1);
    });

    test('a memorised spell reports whether it is ready to cast', () {
      final spell = creature().memorizedSpells.single;

      expect(spell.resref, 'SPWI112');
      expect(spell.isMemorized, isTrue);
      expect(spell.isDisabled, isFalse);
    });

    test('a creature with no spell sections reads as three empty lists', () {
      // Two of the 37 creatures in the party fixture carry
      // `knownSpellsOffset == 0`, which means absent rather than "at the top".
      final bare = CreCodec.decode(
        Uint8List(CreHeaderField.headerSize)
          ..setRange(0, 4, 'CRE '.codeUnits)
          ..setRange(4, 8, 'V1.0'.codeUnits),
      );

      expect(bare.knownSpells, isEmpty);
      expect(bare.memorizations, isEmpty);
      expect(bare.memorizedSpells, isEmpty);
    });
  });

  group('against a character the engine itself made', () {
    final path = fixtureChr('aurel');
    const why = 'no aurel.chr fixture (run tool/dev/sync_fixtures.dart)';

    Cre aurel() => CreCodec.decode(
      ChrCodec.decode(File(path!).readAsBytesSync()).creBytes,
    );

    test(
      'knows two first-level wizard spells and has memorised one',
      () {
        // The walkthrough's own numbers: a Mage learns two 1st-level spells at
        // creation and memorises one of them.
        final cre = aurel();

        expect(cre.knownSpells.map((s) => s.resref), ['SPWI114', 'SPWI112']);
        expect(cre.knownSpells.every((s) => s.level == 1), isTrue);
        expect(cre.knownSpells.every((s) => s.type == 1), isTrue);
        expect(cre.memorizedSpells.single.resref, 'SPWI112');
        expect(cre.memorizedSpells.single.isMemorized, isTrue);
      },
      skip: path == null ? why : false,
    );

    test(
      '⚠️ carries a full grid of rows, not only the one it uses',
      () {
        // **The engine writes every (level, type) row whether or not the class
        // can cast it** — seven priest levels and nine wizard levels on a
        // Fighter / Mage who has no priest spells at all. Anything imitating a
        // created character has to know that; a single row would have been the
        // obvious guess and the wrong one.
        final rows = aurel().memorizations;

        expect(rows.where((r) => r.type == 0), hasLength(7));
        expect(rows.where((r) => r.type == 1), hasLength(9));
        expect(rows.singleWhere((r) => r.count > 0).level, 1);
        expect(rows.singleWhere((r) => r.count > 0).type, 1);
      },
      skip: path == null ? why : false,
    );

    test(
      '⚠️ every row’s index is the running total of the ones before',
      () {
        // What "index into the memorised spells array" costs: the rows are a
        // partition of that array in order, so inserting anywhere but the very
        // end rewrites a pointer in a *different* section.
        final rows = aurel().memorizations;

        var running = 0;
        for (final row in rows) {
          expect(
            row.firstIndex,
            running,
            reason: 'row ${row.type}/${row.level}',
          );
          running += row.count;
        }
        expect(running, aurel().memorizedSpellsCount);
      },
      skip: path == null ? why : false,
    );
  });
}

const Endian _le = Endian.little;
