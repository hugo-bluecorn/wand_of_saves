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
import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/synthetic_gam.dart';

void main() {
  group('a party of several', () {
    // No fixture can cover this: every real save has exactly one party
    // member, so any stride reads it correctly. That is how the spike's
    // stride of -180 survived unnoticed.
    const roster = [
      SyntheticNpc(resref: '*ONE', displayName: 'Aard', creLength: 48),
      SyntheticNpc(resref: '*TWO', displayName: 'Jaheira', creLength: 64),
      SyntheticNpc(resref: '*THREE', displayName: 'Minsc', creLength: 40),
    ];

    test('finds one member per header count', () {
      expect(
        GamCodec.decode(buildGam(party: roster)).partyMembers,
        hasLength(3),
      );
    });

    test('walks the array at a 352-byte stride', () {
      final party = GamCodec.decode(buildGam(party: roster)).partyMembers;

      for (var i = 1; i < party.length; i++) {
        expect(
          party[i].structOffset - party[i - 1].structOffset,
          GamNpcField.structSize,
        );
      }
    });

    test('reads each member distinctly, not the first one repeatedly', () {
      // A stride of 0 would pass a naive "count is right" check while
      // returning the same character three times.
      final party = GamCodec.decode(buildGam(party: roster)).partyMembers;

      expect(party.map((n) => n.displayName), ['Aard', 'Jaheira', 'Minsc']);
      expect(party.map((n) => n.creResref), ['*ONE', '*TWO', '*THREE']);
    });

    test('locates each embedded CRE', () {
      final party = GamCodec.decode(buildGam(party: roster)).partyMembers;

      expect(party.map((n) => n.creLength), [48, 64, 40]);
      for (final npc in party) {
        expect(npc.creBytes, hasLength(npc.creLength));
        expect(ascii.decode(npc.creBytes.sublist(0, 4)), 'CRE ');
      }
    });

    test('retains where each struct lives, for later patching', () {
      // Phase 1 patches a struct in place; it must not have to re-derive the
      // position from the array index and a stride it might get wrong.
      final gam = GamCodec.decode(buildGam(party: roster));
      final first = gam.partyMembers.first;

      expect(first.structOffset, gam.partyNpcOffset);
    });
  });

  group('bounds', () {
    test('rejects an array that runs past the end of the file', () {
      // A corrupt count would otherwise read arbitrary memory as characters.
      final bytes = buildGam(partyNpcCount: 9999);

      expect(
        () => GamCodec.decode(bytes).partyMembers,
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });

  group('the real fixture', () {
    final path = fixtureGam('000000022-last');
    final skip = path == null
        ? 'no fixtures: run `fvm dart run tool/dev/sync_fixtures.dart` '
              'from the repository root'
        : null;

    test(
      'the non-party array ends exactly where the first CRE begins',
      () {
        // 7312 + 36 * 352 == 19984 on this save, and the equivalent holds on
        // the other two. A wrong stride misses by a multiple of 36.
        final gam = GamCodec.decode(File(path!).readAsBytesSync());
        final npcs = gam.nonPartyMembers;

        expect(npcs, hasLength(36));
        expect(
          gam.nonPartyNpcOffset + npcs.length * GamNpcField.structSize,
          npcs.first.creOffset,
        );
      },
      skip: skip,
    );

    test(
      'all 36 embedded CRE blobs chain without a gap',
      () {
        // off[i] + size[i] == off[i+1], a 36-link chain that a wrong stride
        // breaks at the first link.
        final npcs = GamCodec.decode(
          File(path!).readAsBytesSync(),
        ).nonPartyMembers;

        for (var i = 1; i < npcs.length; i++) {
          expect(
            npcs[i].creOffset,
            npcs[i - 1].creOffset + npcs[i - 1].creLength,
            reason:
                'chain breaks between ${npcs[i - 1].creResref} '
                'and ${npcs[i].creResref}',
          );
        }
      },
      skip: skip,
    );

    test(
      'every embedded CRE really is a CRE',
      () {
        final npcs = GamCodec.decode(
          File(path!).readAsBytesSync(),
        ).nonPartyMembers;

        for (final npc in npcs) {
          expect(
            ascii.decode(npc.creBytes.sublist(0, 8)),
            'CRE V1.0',
            reason: '${npc.creResref} at ${npc.creOffset}',
          );
        }
      },
      skip: skip,
    );

    test(
      'the party member is the protagonist recorded in the findings',
      () {
        final gam = GamCodec.decode(File(path!).readAsBytesSync());
        final party = gam.partyMembers;

        expect(party, hasLength(1));
        expect(party.single.creResref, '*HARBASE');
        expect(party.single.displayName, 'Aard');
        expect(party.single.creOffset, 532);
      },
      skip: skip,
    );
  });
}
