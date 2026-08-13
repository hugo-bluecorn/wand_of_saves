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

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

void main() {
  group('GamSection', () {
    test('names every section the header points at', () {
      // Nine offsets, and the relocation has to know about all of them. Four
      // were unmodelled until 2026-08-12, which is why the recorded pointer
      // count was 39 rather than 43.
      expect(GamSection.values, hasLength(9));
      expect(
        GamSection.values.map((s) => s.offsetField.offset),
        containsAll(<int>[
          0x20,
          0x28,
          0x30,
          0x38,
          0x48,
          0x50,
          0x68,
          0x6c,
          0x78,
        ]),
      );
    });

    test('pairs each section with its count, where it has one', () {
      // ⚠️ Two sections have an offset and no count. Modelling a count they do
      // not have would invent a field, which is how a reader ends up trusting
      // four bytes of something else.
      expect(GamSection.familiarExtra.countField, isNull);
      expect(GamSection.familiarInfo.countField, isNull);

      expect(GamSection.partyNpcs.countField, GamHeaderField.partyNpcCount);
      expect(GamSection.journal.countField, GamHeaderField.journalCount);
      expect(
        GamSection.storedLocations.countField,
        GamHeaderField.storedLocationsCount,
      );
    });

    test('⚠️ treats zero as absent everywhere', () {
      // No section can begin at byte 0 — that is the 'GAME' signature — so a
      // stored zero is the absence marker rather than a position. Every BG1EE
      // fixture carries `partyInventoryOffset = 0`, and adding a delta to it
      // is exactly how the read-path spike computed a stride of -180.
      for (final section in GamSection.values) {
        expect(
          section.isAbsent(0),
          isTrue,
          reason: '${section.name} must read 0 as absent',
        );
      }
    });

    test('⚠️ treats all-ones as absent only where the format uses it', () {
      // `familiarExtraOffset` holds 0xFFFFFFFF on every fixture. Nothing else
      // does, and widening the rule to every section would silently accept a
      // corrupt pointer elsewhere as "absent" instead of failing loudly.
      expect(GamSection.familiarExtra.isAbsent(0xFFFFFFFF), isTrue);
      expect(GamSection.journal.isAbsent(0xFFFFFFFF), isFalse);
      expect(GamSection.partyNpcs.isAbsent(0xFFFFFFFF), isFalse);
    });

    test('⚠️ does NOT treat offset-equals-EOF as absent', () {
      // The third encoding, and the one that must not be skipped. Stored
      // locations and pocket plane both hold exactly the file length with a
      // count of zero. They are empty, but they are *positioned* — measured
      // across saves of 95,968 / 101,352 / 88,280 bytes, the value tracks the
      // length every time. So the engine maintains them at EOF, and a writer
      // that leaves them alone puts them 20 bytes inside the file.
      expect(GamSection.storedLocations.isAbsent(95968), isFalse);
      expect(GamSection.pocketPlane.isAbsent(95968), isFalse);
    });

    test('a real position is never absent', () {
      expect(GamSection.partyNpcs.isAbsent(180), isFalse);
      expect(GamSection.nonPartyNpcs.isAbsent(7312), isFalse);
    });
  });
}
