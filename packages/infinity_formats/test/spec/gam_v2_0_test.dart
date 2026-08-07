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
  });
}
