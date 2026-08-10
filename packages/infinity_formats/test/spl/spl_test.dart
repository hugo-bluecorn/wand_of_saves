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

/// The `SPL` header — enough of it to list the spells a character may learn.
///
/// ⚠️ **Read because no table answers.** The installation ships `spells.2da`,
/// `speldesc.2da`, `mschool.2da`, `splsrckn.2da` and ten `mxspl*` tables, and
/// not one of them lists which spells exist at a level. The spells themselves
/// do, in their own headers.
library;

import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/layout.dart';

void main() {
  /// An `SPL V1` header with the five fields this project reads.
  Uint8List header({
    int type = 1,
    int level = 1,
    int school = 6,
    int nameStrref = 12052,
    int descriptionStrref = 12053,
    String signature = 'SPL ',
  }) {
    final out = Uint8List(splHeaderLength)
      ..setRange(0, 4, signature.codeUnits)
      ..setRange(4, 8, 'V1  '.codeUnits);
    ByteData.sublistView(out)
      ..setInt32(SplHeaderField.name.offset, nameStrref, Endian.little)
      ..setUint16(SplHeaderField.spellType.offset, type, Endian.little)
      ..setUint32(SplHeaderField.level.offset, level, Endian.little)
      ..setInt32(
        SplHeaderField.description.offset,
        descriptionStrref,
        Endian.little,
      );
    out[SplHeaderField.school.offset] = school;
    return out;
  }

  group('the layout', () {
    test('is sound, with the gaps a verified subset is allowed', () {
      // No struct size: this table is the handful of fields that have been
      // checked, not all 114 bytes the format defines.
      expect(layoutProblems(SplHeaderField.values), isEmpty);
    });

    test('every field lies inside the header', () {
      for (final field in SplHeaderField.values) {
        expect(
          field.offset + field.length,
          lessThanOrEqualTo(splHeaderLength),
          reason: '$field',
        );
      }
    });
  });

  group('reading one', () {
    test('reports the level a player counts, with nothing subtracted', () {
      // ⚠️ **Unlike the creature record's own spell entries**, which store the
      // level less one. Two structures, one word apart in meaning.
      expect(SplCodec.decode(header(level: 3)).level, 3);
    });

    test('reports the strrefs that name and describe it', () {
      final spell = SplCodec.decode(header());

      expect(spell.nameStrref, 12052);
      expect(spell.descriptionStrref, 12053);
    });

    test('a header with no name reports null rather than -1', () {
      // 86 of the 108 SPL files claiming first-level wizard carry `-1` here.
      // They are the engine's internals, not spells anyone learns.
      expect(SplCodec.decode(header(nameStrref: -1)).nameStrref, isNull);
    });

    test('⚠️ its type numbering is not the creature record’s', () {
      // An SPL header says 1 wizard, 2 priest, 4 innate; a creature's known
      // spell says 0 priest, 1 wizard, 2 innate. The two agree on exactly one
      // value, which is the worst possible overlap.
      expect(SplType.wizard.stored, 1);
      expect(SplType.priest.stored, 2);
      expect(SplType.innate.stored, 4);
      expect(SplCodec.decode(header(type: 2)).type, SplType.priest);
    });

    test('a type the format does not define reads as null, not a crash', () {
      expect(SplCodec.decode(header(type: 99)).type, isNull);
    });

    test('reports the school, which a specialist’s screen outlines', () {
      expect(SplCodec.decode(header(school: 3)).school, 3);
    });
  });

  group('refusals', () {
    test('something that is not a spell is refused by signature', () {
      expect(
        () => SplCodec.decode(header(signature: 'ITM ')),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('a file too short to hold a header is refused', () {
      expect(
        () => SplCodec.decode(Uint8List(16)),
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });
}
