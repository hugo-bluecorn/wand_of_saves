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

import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/domain/character_stat.dart';

void main() {
  group('the editable stat table', () {
    test('every range fits the field it writes into', () {
      // A stat whose range exceeds its field would be offering the player a
      // value that cannot be stored -- caught at the format boundary, but only
      // after they typed it.
      for (final stat in CharacterStat.values) {
        expect(
          stat.field.holds(stat.minimum),
          isTrue,
          reason: '$stat minimum ${stat.minimum} does not fit ${stat.field}',
        );
        expect(
          stat.field.holds(stat.maximum),
          isTrue,
          reason: '$stat maximum ${stat.maximum} does not fit ${stat.field}',
        );
      }
    });

    test('no two stats write the same bytes', () {
      // Two entries pointing at one field would let the UI show a value twice
      // and disagree with itself.
      final fields = CharacterStat.values.map((s) => s.field).toList();

      expect(fields.toSet(), hasLength(fields.length));
    });

    test('every stat has a non-empty label and a usable range', () {
      for (final stat in CharacterStat.values) {
        expect(stat.label, isNotEmpty, reason: '$stat has no label');
        expect(
          stat.minimum,
          lessThan(stat.maximum),
          reason: '$stat has an empty range',
        );
      }
    });

    test('quotes the ranges IESDP documents', () {
      // Where IESDP states a range it is taken verbatim; where it does not,
      // the field's own width is the range. No numbers are invented here.
      expect(CharacterStat.strength.minimum, 1);
      expect(CharacterStat.strength.maximum, 25);
      expect(CharacterStat.strengthBonus.minimum, 0);
      expect(CharacterStat.strengthBonus.maximum, 100);
      expect(CharacterStat.thac0.minimum, 1);
      expect(CharacterStat.thac0.maximum, 25);
    });

    test('an undocumented range falls back to what the field holds', () {
      // Natural armour class is a signed word and IESDP states no range, so
      // inventing "-20 to 20" would be a game-rules judgement this slice has
      // no source for.
      expect(
        CharacterStat.armorClassNatural.minimum,
        CreHeaderField.armorClassNatural.minimum,
      );
      expect(
        CharacterStat.armorClassNatural.maximum,
        CreHeaderField.armorClassNatural.maximum,
      );
      expect(CharacterStat.armorClassNatural.minimum, isNegative);
    });
  });

  group('holds', () {
    test('accepts the ends of the range', () {
      expect(CharacterStat.strength.holds(1), isTrue);
      expect(CharacterStat.strength.holds(25), isTrue);
    });

    test('rejects outside it', () {
      // 200 fits a byte perfectly well, which is exactly why the stat needs a
      // range of its own rather than leaning on the field's width.
      expect(CharacterStat.strength.holds(0), isFalse);
      expect(CharacterStat.strength.holds(26), isFalse);
      expect(CharacterStat.strength.holds(200), isFalse);
      expect(CreHeaderField.strength.holds(200), isTrue);
    });
  });
}
