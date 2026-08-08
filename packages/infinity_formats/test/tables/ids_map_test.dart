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
  group('parse', () {
    test('reads decimal keys', () {
      final ids = IdsMap.parse('IDS V1.0\n1 MAGE\n2 FIGHTER\n7 FIGHTER_MAGE\n');

      expect(ids[1], 'MAGE');
      expect(ids[2], 'FIGHTER');
      expect(ids[7], 'FIGHTER_MAGE');
    });

    test('reads hex keys', () {
      // ALIGNMEN.IDS is written in hex where CLASS.IDS is decimal, and the
      // file says nothing about which it uses -- so both have to work.
      final ids = IdsMap.parse('0x11 LAWFUL_GOOD\n0x21 NEUTRAL_GOOD\n');

      expect(ids[0x21], 'NEUTRAL_GOOD');
      expect(ids[33], 'NEUTRAL_GOOD', reason: '0x21 and 33 are one key');
    });

    test('skips the signature line', () {
      expect(IdsMap.parse('IDS V1.0\n1 MAGE\n').entries, hasLength(1));
    });

    test('skips a bare count line', () {
      // ALIGNMEN.IDS opens with "15" and then lists sixteen entries, so the
      // count is not even right -- it is skipped rather than trusted.
      final ids = IdsMap.parse('15\n0x00 NONE\n0x11 LAWFUL_GOOD\n');

      expect(ids.entries, hasLength(2));
      expect(ids[0], 'NONE');
    });

    test('skips prose between entries', () {
      // IESDP's rendering of CLASS.IDS interleaves a description after every
      // entry. A line is an entry only if it is exactly a number and an
      // identifier.
      final ids = IdsMap.parse('''
IDS V1.0

1 MAGE

Detects mages (and sorcerers), though only single class & kits.

2 FIGHTER

Detects fighters (and monks), though only single class & kits.
''');

      expect(ids.entries, hasLength(2));
      expect(ids[1], 'MAGE');
      expect(ids[2], 'FIGHTER');
    });

    test('skips a line that starts with a number but is prose', () {
      // The one way the "starts with a number" rule could go wrong.
      final ids = IdsMap.parse('1 MAGE\n15 entries are listed above\n');

      expect(ids.entries, hasLength(1));
      expect(ids[15], isNull);
    });

    test('is empty for text with no entries at all', () {
      expect(IdsMap.parse('IDS V1.0\n\n').entries, isEmpty);
    });

    test('the first entry wins over a later one with the same key', () {
      // IDS files really do repeat a key: KIT.IDS numbers 0x4000 both
      // TRUECLASS and MAGESCHOOL_GENERALIST, and IESDP's CLASS.IDS page says
      // in prose that 202 is shared by LONG_BOW and MAGE_ALL. Last-wins lost
      // TRUECLASS, which is the name a character with no kit stores -- so the
      // kit encoding looked undecodable when it was only mis-parsed.
      expect(IdsMap.parse('1 FIRST\n1 SECOND\n')[1], 'FIRST');
    });

    test('a shadowed entry is recorded rather than dropped', () {
      // Both names are real. Keeping the loser means a table can say so
      // instead of silently presenting one reading as the only one.
      final ids = IdsMap.parse(
        '0x4000 TRUECLASS\n0x4000 MAGESCHOOL_GENERALIST\n',
      );

      expect(ids.entries, hasLength(1));
      expect(ids.shadowed, [(0x4000, 'MAGESCHOOL_GENERALIST')]);
    });

    test('shadowed is empty when every key is distinct', () {
      expect(IdsMap.parse('1 MAGE\n2 FIGHTER\n').shadowed, isEmpty);
    });

    test('a key repeated three times keeps the first and shadows two', () {
      final ids = IdsMap.parse('1 A\n1 B\n1 C\n');

      expect(ids[1], 'A');
      expect(ids.shadowed, [(1, 'B'), (1, 'C')]);
    });
  });

  group('lookup', () {
    final ids = IdsMap.parse('IDS V1.0\n1 MAGE\n7 FIGHTER_MAGE\n');

    test('is null for a key that is not there', () {
      expect(ids[99], isNull);
    });

    test('finds a key by its name', () {
      // Which is how "is this class a warrior?" gets asked without hardcoding
      // the number 2 anywhere.
      expect(ids.keyFor('FIGHTER_MAGE'), 7);
      expect(ids.keyFor('DRUID'), isNull);
    });
  });
}
