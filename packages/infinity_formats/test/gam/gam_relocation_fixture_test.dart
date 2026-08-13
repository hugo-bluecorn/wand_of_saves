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

/// Aligns the two buffers around the splice and reports every dword that
/// genuinely changed.
///
/// ⚠️ **A plain byte diff is useless here**, because inserting bytes shifts
/// 95 KB and every one of them "differs". What a relocation must be judged on
/// is whether anything changed *other* than position: so bytes before the
/// splice are compared in place, and bytes at or after it are compared against
/// their new home [delta] later. Whatever still differs is a patched pointer.
List<int> patchedDwords(
  Uint8List before,
  Uint8List after, {
  required int splice,
  required int delta,
  required int skipFrom,
  required int skipTo,
}) {
  final out = <int>[];
  for (var i = 0; i + 4 <= before.length; i += 4) {
    // The replaced record itself is not a pointer patch.
    if (i >= skipFrom && i < skipTo) continue;
    final at = i >= splice ? i + delta : i;
    final a = ByteData.sublistView(before).getUint32(i, Endian.little);
    final b = ByteData.sublistView(after).getUint32(at, Endian.little);
    if (a != b) out.add(i);
  }
  return out;
}

void main() {
  const slot = '000000022-last';
  final path = fixtureGam(slot);
  final skip = path == null
      ? 'no fixtures: run `fvm dart run tool/dev/sync_fixtures.dart`'
      : null;

  group('the relocation gate, on a real save', () {
    late Gam gam;

    setUp(() {
      if (path == null) return;
      gam = GamCodec.decode(File(path).readAsBytesSync(), source: slot);
    });

    test('⚠️ growing the protagonist patches exactly 43 pointers', () {
      // **This is the number the plan was built on, and the number the project
      // had recorded wrongly.** `verified-format-offsets.md` said 39: it
      // counted 36 non-party `creOffset` fields plus the three GAM header
      // offsets the layout table happened to name. Three more sit past the
      // party creature — familiar info, stored locations, pocket plane — and
      // `creLength` makes the forty-third.
      final first = gam.partyMembers.first;
      final splice = first.creOffset + first.creLength;
      const delta = 20;

      final grown = Uint8List(first.creLength + delta)
        ..setRange(0, first.creLength, first.creBytes);
      final after = gam.withCreature(
        creOffset: first.creOffset,
        creature: Cre.trusted(grown),
      );

      expect(after.bytes, hasLength(gam.bytes.length + delta));

      final patched = patchedDwords(
        gam.bytes,
        after.bytes,
        splice: splice,
        delta: delta,
        skipFrom: first.creOffset,
        skipTo: splice,
      );

      expect(
        patched,
        hasLength(43),
        reason:
            '36 non-party creOffsets + 6 header offsets + 1 creLength; '
            'got ${patched.length} at $patched',
      );
    });

    test('the 43 are the fields we expect, by name', () {
      final first = gam.partyMembers.first;
      final splice = first.creOffset + first.creLength;
      const delta = 20;
      final grown = Uint8List(first.creLength + delta)
        ..setRange(0, first.creLength, first.creBytes);
      final after = gam.withCreature(
        creOffset: first.creOffset,
        creature: Cre.trusted(grown),
      );

      final patched = patchedDwords(
        gam.bytes,
        after.bytes,
        splice: splice,
        delta: delta,
        skipFrom: first.creOffset,
        skipTo: splice,
      ).toSet();

      // The six header offsets that sit after the protagonist's record.
      for (final field in [
        GamHeaderField.nonPartyNpcOffset,
        GamHeaderField.globalsOffset,
        GamHeaderField.journalOffset,
        GamHeaderField.familiarInfoOffset,
        GamHeaderField.storedLocationsOffset,
        GamHeaderField.pocketPlaneOffset,
      ]) {
        expect(
          patched,
          contains(field.offset),
          reason: '${field.name} must have been patched',
        );
      }

      // The owning struct's length.
      expect(
        patched,
        contains(first.structOffset + GamNpcField.creLength.offset),
      );

      // Every non-party creOffset — the 36 nothing recorded until 2026-08-09.
      final nonParty = gam.nonPartyMembers;
      expect(nonParty, hasLength(36));
      for (final npc in nonParty) {
        expect(
          patched,
          contains(npc.structOffset + GamNpcField.creOffset.offset),
          reason: '${npc.creResref} at ${npc.structOffset}',
        );
      }

      // And nothing the header uses as an absence marker.
      expect(
        patched,
        isNot(contains(GamHeaderField.partyInventoryOffset.offset)),
      );
      expect(
        patched,
        isNot(contains(GamHeaderField.familiarExtraOffset.offset)),
      );
    });

    test('⚠️ every creature is still readable at its new address', () {
      // The real gate: pointers that are arithmetically right but land on the
      // wrong bytes are exactly how a save loads and is subtly wrong.
      final first = gam.partyMembers.first;
      const delta = 20;
      final grown = Uint8List(first.creLength + delta)
        ..setRange(0, first.creLength, first.creBytes);
      final after = gam.withCreature(
        creOffset: first.creOffset,
        creature: Cre.trusted(grown),
      );

      final before = gam.nonPartyMembers;
      final moved = after.nonPartyMembers;
      expect(moved, hasLength(before.length));
      for (var i = 0; i < before.length; i++) {
        expect(moved[i].creOffset, before[i].creOffset + delta);
        expect(moved[i].creLength, before[i].creLength);
        expect(
          moved[i].creBytes,
          before[i].creBytes,
          reason: '${before[i].creResref} must arrive intact',
        );
      }
    });

    test('the EOF-anchored offsets land on the new end of file', () {
      final first = gam.partyMembers.first;
      const delta = 20;
      final grown = Uint8List(first.creLength + delta)
        ..setRange(0, first.creLength, first.creBytes);
      final after = gam.withCreature(
        creOffset: first.creOffset,
        creature: Cre.trusted(grown),
      );

      int read(GamHeaderField f) =>
          ByteData.sublistView(after.bytes).getUint32(f.offset, Endian.little);

      expect(read(GamHeaderField.storedLocationsOffset), after.bytes.length);
      expect(read(GamHeaderField.pocketPlaneOffset), after.bytes.length);
      expect(read(GamHeaderField.storedLocationsCount), 0);
    });

    test('a same-size replacement still patches nothing', () {
      final first = gam.partyMembers.first;
      final after = gam.withCreature(
        creOffset: first.creOffset,
        creature: Cre.trusted(Uint8List.fromList(first.creBytes)),
      );
      expect(after.bytes, gam.bytes);
    });
  }, skip: skip);
}
