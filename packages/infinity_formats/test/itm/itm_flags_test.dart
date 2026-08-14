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

/// The ITM header flags, which decide whether an item can be moved at all.
///
/// ⚠️ **The field existed and nothing read it.** `ItmHeaderField.flags` has sat
/// in the spec table since the codec was written, and an item the engine will
/// never release — `BOW99`, added to a real character — reached the game before
/// anyone asked what bit 2 said.
library;

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

void main() {
  group('ItmFlag', () {
    test('decodes the two bows that started this', () {
      // Measured from the installation: BOW05 is an ordinary shortbow and
      // BOW99 is "Protector of the Dryads +2", which cannot be moved.
      expect(ItmFlag.setFrom(0xae), {
        ItmFlag.twoHanded,
        ItmFlag.movable,
        ItmFlag.displayable,
        ItmFlag.cannotScribe,
        ItmFlag.leftHanded,
      });
      expect(ItmFlag.setFrom(0xe2), {
        ItmFlag.twoHanded,
        ItmFlag.cannotScribe,
        ItmFlag.magical,
        ItmFlag.leftHanded,
      });
    });

    test('⚠️ movable and cursed are different questions', () {
      // IESDP bit 2 is "Movable / Droppable"; bit 4 is Cursed, meaning the item
      // cannot be UNequipped. An item can be one without the other, and
      // treating them as the same would refuse items the game itself sells.
      expect(ItmFlag.setFrom(ItmFlag.movable.mask), contains(ItmFlag.movable));
      expect(
        ItmFlag.setFrom(ItmFlag.movable.mask),
        isNot(contains(ItmFlag.cursed)),
      );
    });

    test('ignores bits it does not document rather than refusing them', () {
      // The field is four bytes and IESDP documents well past bit 7; a record
      // may legitimately carry more than this enum names.
      expect(ItmFlag.setFrom(0xffff0000), isEmpty);
      expect(
        ItmFlag.setFrom(0xffff0000 | ItmFlag.cursed.mask),
        {ItmFlag.cursed},
      );
    });

    test('round-trips through maskOf', () {
      const flags = {ItmFlag.movable, ItmFlag.magical};
      expect(ItmFlag.setFrom(ItmFlag.maskOf(flags)), flags);
    });
  });
}
