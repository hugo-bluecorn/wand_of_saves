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

import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/synthetic_gam.dart';

/// A save with two party members and two non-party ones, laid out the way a
/// real one is: party structs, party CREs, non-party structs, non-party CREs,
/// then the three trailing blocks.
///
/// ⚠️ **Two of each is the minimum that can catch anything.** With one party
/// member no later `creOffset` exists to be shifted, which is exactly why the
/// stride bug and the 36 unpatched non-party pointers both went unnoticed.
Gam buildRelocatable() => GamCodec.decode(
  buildGam(
    party: const [
      SyntheticNpc(resref: 'AARD', displayName: 'Aard'),
      SyntheticNpc(resref: 'IMOEN', displayName: 'Imoen'),
    ],
    nonParty: const [
      SyntheticNpc(resref: 'QUAYLE', displayName: 'Quayle'),
      SyntheticNpc(resref: 'TIAX', displayName: 'Tiax'),
    ],
  ),
);

/// The indices at which two buffers differ.
List<int> differences(Uint8List a, Uint8List b) => [
  for (var i = 0; i < (a.length < b.length ? a.length : b.length); i++)
    if (a[i] != b[i]) i,
];

void main() {
  group('Gam.withCreature — the relocation', () {
    test('a same-size record moves nothing at all', () {
      // The fast path. A replacement of equal length is the fixed-width case
      // wearing different clothes, and it must not shift a single pointer.
      final gam = buildRelocatable();
      final first = gam.partyMembers.first;
      final replacement = Uint8List.fromList(first.creBytes)
        ..[8] = 0xAB; // a byte inside the record, nothing structural

      final after = gam.withCreature(
        creOffset: first.creOffset,
        creature: Cre.trusted(replacement),
      );

      expect(after.bytes, hasLength(gam.bytes.length));
      expect(
        differences(gam.bytes, after.bytes),
        [first.creOffset + 8],
        reason: 'only the edited byte should differ',
      );
    });

    test(
      '⚠️ growing the first record patches exactly the pointers after it',
      () {
        final gam = buildRelocatable();
        final before = gam.bytes;
        final first = gam.partyMembers.first;
        final splice = first.creOffset + first.creLength;
        const delta = 20;

        final grown = Uint8List(first.creLength + delta)
          ..setRange(0, first.creLength, first.creBytes);
        final after = gam.withCreature(
          creOffset: first.creOffset,
          creature: Cre.trusted(grown),
        );

        expect(after.bytes, hasLength(before.length + delta));

        // The owning struct's own length field.
        expect(after.partyMembers.first.creLength, first.creLength + delta);
        // ...and its position is unchanged: it starts before the splice.
        expect(after.partyMembers.first.creOffset, first.creOffset);

        // Every creature stored after it moves by exactly delta.
        expect(
          after.partyMembers[1].creOffset,
          gam.partyMembers[1].creOffset + delta,
        );
        for (var i = 0; i < 2; i++) {
          expect(
            after.nonPartyMembers[i].creOffset,
            gam.nonPartyMembers[i].creOffset + delta,
            reason:
                'non-party $i — the 36 pointers nothing recorded until '
                '2026-08-09',
          );
        }

        // The non-party struct ARRAY itself moves, because it sits after the
        // party's creature data.
        expect(after.nonPartyNpcOffset, gam.nonPartyNpcOffset + delta);
        // The party struct array does not: it is before the splice.
        expect(after.partyNpcOffset, gam.partyNpcOffset);

        expect(splice, greaterThan(gam.partyNpcOffset));
      },
    );

    test(
      '⚠️ carries all three trailing offsets, including the unmodelled one',
      () {
        final gam = buildRelocatable();
        final first = gam.partyMembers.first;
        const delta = 20;
        final grown = Uint8List(first.creLength + delta)
          ..setRange(0, first.creLength, first.creBytes);

        final after = gam.withCreature(
          creOffset: first.creOffset,
          creature: Cre.trusted(grown),
        );

        int read(Gam g, GamHeaderField f) =>
            ByteData.sublistView(g.bytes).getUint32(f.offset, Endian.little);

        for (final field in [
          GamHeaderField.globalsOffset,
          GamHeaderField.journalOffset,
          // ⚠️ The one that was invisible to the codec until 2026-08-12, and it
          // is live on every real save. Missing it corrupts silently.
          GamHeaderField.familiarInfoOffset,
        ]) {
          expect(
            read(after, field),
            read(gam, field) + delta,
            reason: '${field.name} sits after the splice and must move',
          );
        }
      },
    );

    test('⚠️ leaves the two absence markers alone', () {
      // The whole reason GamSection exists. `partyInventoryOffset` is 0 on
      // every BG1EE save and `familiarExtraOffset` is all-ones; adding a delta
      // to either invents a pointer into the middle of the file.
      final gam = buildRelocatable();
      final first = gam.partyMembers.first;
      final grown = Uint8List(first.creLength + 20)
        ..setRange(0, first.creLength, first.creBytes);

      final after = gam.withCreature(
        creOffset: first.creOffset,
        creature: Cre.trusted(grown),
      );

      int read(Gam g, GamHeaderField f) =>
          ByteData.sublistView(g.bytes).getUint32(f.offset, Endian.little);

      expect(read(after, GamHeaderField.partyInventoryOffset), 0);
      expect(read(after, GamHeaderField.familiarExtraOffset), 0xFFFFFFFF);
    });

    test('⚠️ keeps the EOF-anchored offsets at the NEW end of file', () {
      // The third encoding, and the one a naive "skip absent sections" rule
      // gets wrong. Stored locations and pocket plane hold the file length
      // with a count of zero; measured across three real saves of different
      // sizes, they track the length every time.
      final gam = buildRelocatable();
      final first = gam.partyMembers.first;
      final grown = Uint8List(first.creLength + 20)
        ..setRange(0, first.creLength, first.creBytes);

      final after = gam.withCreature(
        creOffset: first.creOffset,
        creature: Cre.trusted(grown),
      );

      int read(GamHeaderField f) =>
          ByteData.sublistView(after.bytes).getUint32(f.offset, Endian.little);

      expect(read(GamHeaderField.storedLocationsOffset), after.bytes.length);
      expect(read(GamHeaderField.pocketPlaneOffset), after.bytes.length);
    });

    test('preserves every byte that is not a patched pointer', () {
      // The gate this project uses instead of round-trip identity: the bytes
      // that moved are byte-for-byte the same at their new home, and the ones
      // that did not move are untouched.
      final gam = buildRelocatable();
      final before = gam.bytes;
      final first = gam.partyMembers.first;
      final splice = first.creOffset + first.creLength;
      const delta = 20;
      final grown = Uint8List(first.creLength + delta)
        ..setRange(0, first.creLength, first.creBytes);

      final after = gam
          .withCreature(
            creOffset: first.creOffset,
            creature: Cre.trusted(grown),
          )
          .bytes;

      // The trailer, which lives before the splice, is identical in place.
      final trailerAt = syntheticGamTrailerOffset;
      expect(
        after.sublist(trailerAt, trailerAt + syntheticGamTrailerLength),
        before.sublist(trailerAt, trailerAt + syntheticGamTrailerLength),
      );

      // The three trailing blocks are identical, delta bytes later.
      final sectionsAt = before.length - 3 * syntheticGamSectionLength;
      expect(
        after.sublist(sectionsAt + delta, sectionsAt + delta + 48),
        before.sublist(sectionsAt, sectionsAt + 48),
        reason: 'the moved blocks must arrive intact',
      );

      // The second party member's record survives the move.
      expect(
        after.sublist(splice + delta, splice + delta + 8),
        before.sublist(splice, splice + 8),
      );
    });

    test('refuses a creature nobody in the party owns', () {
      final gam = buildRelocatable();
      expect(
        () => gam.withCreature(
          creOffset: 999999,
          creature: Cre.trusted(Uint8List(32)),
        ),
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });
}
