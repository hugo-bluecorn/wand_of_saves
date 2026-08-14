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

import '../support/layout.dart';

void main() {
  group('GamHeaderField', () {
    test('is a well-formed layout', () {
      // No struct size: the header table records the fields verified against
      // IESDP and a real save, not every byte GAM V2.0 defines, so gaps are
      // expected. What must hold is that no two of them overlap.
      expect(layoutProblems(GamHeaderField.values), isEmpty);
    });

    test('carries the offsets recorded in the findings document', () {
      // Spot-checks, not a restatement of the whole table — these are the
      // ones this slice depends on, plus the two that anchor the file.
      expect(GamHeaderField.signature.offset, 0x00);
      expect(GamHeaderField.version.offset, 0x04);
      expect(GamHeaderField.partyGold.offset, 0x18);
      expect(GamHeaderField.partyGold.length, 4);
      expect(GamHeaderField.partyNpcOffset.offset, 0x20);
      expect(GamHeaderField.partyNpcCount.offset, 0x24);
    });

    test('gives every field a name for free at the enum type', () {
      // `.name` is `extension EnumName on Enum`, not an interface member --
      // the SDK made it an extension so an enum may have a value called
      // `name` (dart:core enum.dart:134-137). It works here because the
      // static type is GamHeaderField, but it cannot satisfy an interface,
      // which is why FormatField declares no `name` and diagnostics use
      // toString() instead.
      expect(GamHeaderField.partyGold.name, 'partyGold');
      expect(GamHeaderField.partyGold.toString(), contains('partyGold'));
    });

    test('leaves party gold isolated from its neighbours', () {
      // IESDP puts words at 0x16 and 0x1c, so a 4-byte write at 0x18 cannot
      // touch an adjacent field. The whole edit-gold slice rests on this.
      final others = GamHeaderField.values.where(
        (f) => f != GamHeaderField.partyGold,
      );
      for (final field in others) {
        final overlaps =
            field.offset < 0x18 + 4 && 0x18 < field.offset + field.length;
        expect(overlaps, isFalse, reason: '${field.name} overlaps partyGold');
      }
    });

    test("names all nine of the header's section offsets", () {
      // ⚠️ **The four added here are the reason a relocation was unsafe.** The
      // table stopped at 0x58, so `familiarInfoOffset` — which every fixture
      // holds as a live pointer — was invisible to any code that shifted the
      // file. `docs/findings/verified-format-offsets.md` recorded "3 GAM
      // header offsets, 39 pointers"; that counted only what this enum
      // modelled, and the real figure is 43.
      //
      // Read off IESDP's GAM V2.0 page 2026-08-12, not recalled.
      expect(GamHeaderField.familiarExtraOffset.offset, 0x48);
      expect(GamHeaderField.familiarInfoOffset.offset, 0x68);
      expect(GamHeaderField.storedLocationsOffset.offset, 0x6c);
      expect(GamHeaderField.storedLocationsCount.offset, 0x70);
      expect(GamHeaderField.pocketPlaneOffset.offset, 0x78);
      expect(GamHeaderField.pocketPlaneCount.offset, 0x7c);
    });
  });

  group('GamNpcField', () {
    test('accounts for exactly the 352 bytes of the struct', () {
      // The first real use of the exact-fit branch, and the reason D6 chose
      // enums. IESDP documents this struct in 58 contiguous fields with no
      // gaps, so the table is dense — which makes it self-checking: any one
      // mistranscribed offset or size necessarily leaves a gap or an overlap,
      // and this catches it.
      //
      // It is also the assertion whose absence caused the stride bug. A struct
      // believed to be 352 bytes whose fields only reach 344 would read every
      // element of an array after the first at the wrong place.
      expect(
        layoutProblems(GamNpcField.values, structSize: GamNpcField.structSize),
        isEmpty,
      );
    });

    test('declares the struct size verified three ways in the findings', () {
      expect(GamNpcField.structSize, 352);
    });

    test('carries the offsets the codec depends on', () {
      expect(GamNpcField.creOffset.offset, 0x04);
      expect(GamNpcField.creLength.offset, 0x08);
      expect(GamNpcField.creResref.offset, 0x0c);
      expect(GamNpcField.creResref.length, 8);
      expect(GamNpcField.displayName.offset, 0xc0);
      expect(GamNpcField.displayName.length, 32);
      expect(GamNpcField.voiceSet.offset, 0x158);
      expect(GamNpcField.voiceSet.length, 8);
    });

    test('records the unused interaction block as one span, not 24', () {
      // IESDP lists 24 consecutive dwords all named "NumTimesInteracted NPC
      // count (unused)". Recording them individually would add 24 identical
      // names and no information; one honestly-labelled span accounts for the
      // same bytes. Deliberate — see the plan and D6.
      expect(GamNpcField.unusedInteractionCounts.offset, 0x2c);
      expect(GamNpcField.unusedInteractionCounts.length, 24 * 4);
    });
  });
}
