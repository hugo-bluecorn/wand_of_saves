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
  });
}
