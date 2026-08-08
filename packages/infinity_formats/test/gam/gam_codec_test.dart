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
  group('header validation', () {
    test('accepts a well-formed GAME V2.0', () {
      expect(GamCodec.decode(buildGam()).partyGold, 161);
    });

    test('rejects a wrong signature, naming what it found', () {
      expect(
        () => GamCodec.decode(buildGam(signature: 'TLK ')),
        throwsA(
          isA<InfinityFormatException>().having(
            (e) => e.message,
            'message',
            contains('TLK'),
          ),
        ),
      );
    });

    test('rejects an unsupported version, naming what it found', () {
      expect(
        () => GamCodec.decode(buildGam(version: 'V2.2')),
        throwsA(
          isA<InfinityFormatException>().having(
            (e) => e.message,
            'message',
            contains('V2.2'),
          ),
        ),
      );
    });

    test('rejects a file too short to hold the documented header', () {
      expect(
        () => GamCodec.decode(buildGam(truncateTo: 32)),
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });

  group('header fields', () {
    test('reads each field at its documented offset', () {
      final gam = GamCodec.decode(
        buildGam(partyGold: 4242, partyNpcOffset: 512, partyNpcCount: 6),
      );

      expect(gam.partyGold, 4242);
      expect(gam.partyNpcOffset, 512);
      expect(gam.partyNpcCount, 6);
    });

    test('reports an absent section as absent, not as offset zero', () {
      // partyInventoryOffset == 0 means the section does not exist. Treating
      // it as a real offset is what produced the spike's stride of -180.
      final gam = GamCodec.decode(buildGam());

      expect(gam.partyInventoryOffset, 0);
      expect(gam.hasPartyInventory, isFalse);
    });
  });

  group('retained bytes', () {
    test('keeps the whole source, byte for byte', () {
      final source = buildGam();

      expect(GamCodec.decode(source).bytes, orderedEquals(source));
    });

    test('exposes them as an unmodifiable view', () {
      // The hard rule is "preserve unknown bytes". Handing out a mutable
      // buffer would make that a matter of discipline; this makes it a type
      // error at runtime.
      final gam = GamCodec.decode(buildGam());

      expect(() => gam.bytes[0] = 0, throwsUnsupportedError);
    });
  });

  group('the real fixture', () {
    final path = fixtureGam('000000022-last');

    test(
      'parses with the values recorded in the findings document',
      () {
        final gam = GamCodec.decode(File(path!).readAsBytesSync());

        expect(gam.partyGold, 161);
        expect(gam.gameTime, 4791);
        expect(gam.currentArea, 'AR2600');
        expect(gam.reputation, 11.0);
        expect(gam.partyNpcOffset, 180);
        expect(gam.partyNpcCount, 1);
        expect(gam.nonPartyNpcCount, 36);
        // The section really is absent on every BG1EE save examined.
        expect(gam.hasPartyInventory, isFalse);
      },
      skip: path == null
          ? 'no fixtures: run `fvm dart run tool/dev/sync_fixtures.dart` '
                'from the repository root'
          : null,
    );
  });
}
