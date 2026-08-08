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

import 'dart:io';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/synthetic_gam.dart';

void main() {
  const gold = GamHeaderField.partyGold;

  group('round trip', () {
    test('re-encoding an unedited save is byte-identical', () {
      final source = buildGam();

      expect(GamCodec.encode(GamCodec.decode(source)), orderedEquals(source));
    });

    test('byte identity alone proves nothing — see the next group', () {
      // Deliberately recorded as a test name. A writer implemented as
      // `return input` passes the test above perfectly. The assertion that
      // actually constrains a writer is the one below.
      expect(GamCodec.encode(GamCodec.decode(buildGam())), isNotEmpty);
    });
  });

  group('withPartyGold', () {
    test('changes nothing outside the four bytes backing the field', () {
      final source = buildGam(partyGold: 500);
      final edited = GamCodec.encode(
        GamCodec.decode(source).withPartyGold(999),
      );

      expect(edited, hasLength(source.length));
      for (var i = 0; i < source.length; i++) {
        if (i >= gold.offset && i < gold.offset + gold.length) continue;
        expect(
          edited[i],
          source[i],
          reason:
              'byte $i changed, outside partyGold '
              '[${gold.offset}, ${gold.offset + gold.length})',
        );
      }
    });

    test('actually writes the new value', () {
      final edited = GamCodec.encode(
        GamCodec.decode(buildGam(partyGold: 500)).withPartyGold(999),
      );

      expect(GamCodec.decode(edited).partyGold, 999);
    });

    test('preserves the trailer beyond the header verbatim', () {
      // The bytes this codec does not understand are the ones most likely to
      // be silently destroyed by a writer that regenerates instead of patches.
      final source = buildGam();
      final edited = GamCodec.encode(
        GamCodec.decode(source).withPartyGold(7),
      );
      final from = syntheticGamTrailerOffset;

      expect(
        edited.sublist(from),
        orderedEquals(source.sublist(from)),
      );
    });

    test('leaves the original Gam untouched', () {
      final original = GamCodec.decode(buildGam(partyGold: 500));

      final edited = original.withPartyGold(999);

      expect(original.partyGold, 500, reason: 'the original was mutated');
      expect(edited.partyGold, 999);
    });

    test('returns a Gam whose bytes are also unmodifiable', () {
      final edited = GamCodec.decode(buildGam()).withPartyGold(5);

      expect(() => edited.bytes[0] = 0, throwsUnsupportedError);
    });
  });

  group('withCreatureField', () {
    /// A save whose single party member carries a full, decodable CRE header.
    Uint8List saveWithCreature() => buildGam(
      party: const [
        SyntheticNpc(
          resref: '*HARBASE',
          displayName: 'Aard',
          creLength: CreHeaderField.headerSize,
        ),
      ],
    );

    int creOffsetOf(Uint8List bytes) =>
        GamCodec.decode(bytes).partyMembers.single.creOffset;

    test('writes a value into the embedded creature record', () {
      final source = saveWithCreature();
      final gam = GamCodec.decode(source);

      final edited = gam.withCreatureField(
        creOffset: creOffsetOf(source),
        field: CreHeaderField.strength,
        value: 19,
      );

      expect(
        CreCodec.decode(edited.partyMembers.single.creBytes).strength,
        19,
      );
    });

    test('changes nothing outside the bytes backing the field', () {
      // The assertion that actually constrains a writer. Byte identity on an
      // unedited file proves nothing -- `return input` passes that.
      const field = CreHeaderField.strength;
      final source = saveWithCreature();
      final creOffset = creOffsetOf(source);
      final edited = GamCodec.encode(
        GamCodec.decode(source).withCreatureField(
          creOffset: creOffset,
          field: field,
          value: 19,
        ),
      );

      expect(edited, hasLength(source.length));
      for (var i = 0; i < source.length; i++) {
        if (i >= creOffset + field.offset &&
            i < creOffset + field.offset + field.length) {
          continue;
        }
        expect(edited[i], source[i], reason: 'byte $i changed');
      }
    });

    test('round-trips a negative value through a signed field', () {
      // Plate and shield. The field is declared signed in the layout table, so
      // the writer and the reader take it from the same place.
      final source = saveWithCreature();
      final edited = GamCodec.decode(source).withCreatureField(
        creOffset: creOffsetOf(source),
        field: CreHeaderField.armorClassNatural,
        value: -2,
      );

      expect(
        CreCodec.decode(edited.partyMembers.single.creBytes).armorClassNatural,
        -2,
      );
    });

    test('refuses a value too large for the field rather than truncating', () {
      // 256 in a one-byte field would wrap to 0. A wrapped number written into
      // a savegame is silent corruption.
      final source = saveWithCreature();
      final gam = GamCodec.decode(source);

      expect(
        () => gam.withCreatureField(
          creOffset: creOffsetOf(source),
          field: CreHeaderField.strength,
          value: 256,
        ),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('refuses a negative value in an unsigned field', () {
      final source = saveWithCreature();
      final gam = GamCodec.decode(source);

      expect(
        () => gam.withCreatureField(
          creOffset: creOffsetOf(source),
          field: CreHeaderField.strength,
          value: -1,
        ),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('refuses to write past the end of the file', () {
      final gam = GamCodec.decode(saveWithCreature());

      expect(
        () => gam.withCreatureField(
          creOffset: gam.bytes.length - 4,
          field: CreHeaderField.strength,
          value: 18,
        ),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('leaves the original Gam untouched', () {
      final source = saveWithCreature();
      final original = GamCodec.decode(source);

      final edited = original.withCreatureField(
        creOffset: creOffsetOf(source),
        field: CreHeaderField.strength,
        value: 19,
      );

      expect(
        CreCodec.decode(edited.partyMembers.single.creBytes).strength,
        19,
      );
      expect(
        CreCodec.decode(original.partyMembers.single.creBytes).strength,
        0,
        reason: 'the original was mutated',
      );
    });
  });

  group('the real fixture', () {
    final path = fixtureGam('000000022-last');

    test(
      'edits gold without disturbing any other byte of a real save',
      () {
        // The whole point of the slice: a 95,968-byte file, one field changed,
        // everything else provably identical.
        final source = File(path!).readAsBytesSync();
        final edited = GamCodec.encode(
          GamCodec.decode(source).withPartyGold(12345),
        );

        expect(edited, hasLength(source.length));
        var changed = 0;
        for (var i = 0; i < source.length; i++) {
          if (source[i] != edited[i]) changed++;
        }
        expect(changed, lessThanOrEqualTo(gold.length));
        for (var i = 0; i < source.length; i++) {
          if (i >= gold.offset && i < gold.offset + gold.length) continue;
          expect(edited[i], source[i], reason: 'byte $i changed');
        }
        expect(GamCodec.decode(edited).partyGold, 12345);
      },
      skip: path == null
          ? 'no fixtures: run `fvm dart run tool/dev/sync_fixtures.dart` '
                'from the repository root'
          : null,
    );

    test(
      "edits a stat inside a real character's creature record",
      () {
        // The Phase 2 gate, in test form: a 95,968-byte save, one *nested*
        // field changed, everything else provably identical. Party gold sits
        // in the header at a fixed offset; this one is inside an embedded CRE
        // located through the party array, which is the harder claim.
        const field = CreHeaderField.strength;
        final source = File(path!).readAsBytesSync();
        final gam = GamCodec.decode(source);
        final creOffset = gam.partyMembers.single.creOffset;

        final edited = GamCodec.encode(
          gam.withCreatureField(
            creOffset: creOffset,
            field: field,
            value: 19,
          ),
        );

        expect(edited, hasLength(source.length));
        final changed = [
          for (var i = 0; i < source.length; i++)
            if (source[i] != edited[i]) i,
        ];
        expect(
          changed,
          [creOffset + field.offset],
          reason: 'exactly the one byte backing Strength should differ',
        );
        expect(
          CreCodec.decode(
            GamCodec.decode(edited).partyMembers.single.creBytes,
          ).strength,
          19,
        );
      },
      skip: path == null
          ? 'no fixtures: run `fvm dart run tool/dev/sync_fixtures.dart` '
                'from the repository root'
          : null,
    );
  });
}
