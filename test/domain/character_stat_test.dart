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
      // "Save versus spells (0-20)", "Number of attacks (0-10)",
      // "Resist fire (0-100)", "Lore (0-100)", morale "capped 0 - 20".
      expect(CharacterStat.saveVersusSpells.maximum, 20);
      expect(CharacterStat.numberOfAttacks.maximum, 10);
      expect(CharacterStat.resistFire.maximum, 100);
      expect(CharacterStat.lore.maximum, 100);
      expect(CharacterStat.morale.maximum, 20);
    });

    test('a half-stated range keeps the half IESDP gives', () {
      // Five of the thief skills are documented only as "minimum value: 0" —
      // a floor and no ceiling. Taking the floor and leaving the field's own
      // width as the ceiling is the honest reading of that; inventing 100 to
      // match Lore would be a game-rules judgement with no source.
      expect(CharacterStat.moveSilently.minimum, 0);
      expect(
        CharacterStat.moveSilently.maximum,
        CreHeaderField.moveSilently.maximum,
      );
      expect(CharacterStat.moveSilently.declaredMaximum, isNull);
    });

    test('the whole editable sheet is reachable', () {
      // The panel is built from this table, so a field the table forgets is a
      // field the player cannot see. Counting the groups catches a block
      // dropped wholesale, which reading the list by eye does not.
      final fields = CharacterStat.values.map((s) => s.field).toSet();

      expect(
        fields,
        containsAll([
          CreHeaderField.saveVersusDeath,
          CreHeaderField.saveVersusWands,
          CreHeaderField.saveVersusPolymorph,
          CreHeaderField.saveVersusBreath,
          CreHeaderField.saveVersusSpells,
        ]),
        reason: 'all five saving throws',
      );
      expect(
        fields.where((f) => f.name.startsWith('resist')),
        hasLength(11),
        reason: 'all eleven resistances',
      );
      expect(
        fields.intersection({
          CreHeaderField.hideInShadows,
          CreHeaderField.detectIllusion,
          CreHeaderField.setTraps,
          CreHeaderField.lore,
          CreHeaderField.lockpicking,
          CreHeaderField.moveSilently,
          CreHeaderField.findTraps,
          CreHeaderField.pickPockets,
        }),
        hasLength(8),
        reason: 'all eight thief skills, Lore included',
      );
    });

    test('never offers to write a section pointer', () {
      // The reason this table is curated at all. A command free to name any
      // CreHeaderField could write knownSpellsOffset and destroy a savegame,
      // and the failure would not be a crash — it would be a file that loads
      // and is subtly wrong.
      const forbidden = {
        CreHeaderField.knownSpellsOffset,
        CreHeaderField.knownSpellsCount,
        CreHeaderField.memorizationInfoOffset,
        CreHeaderField.memorizationInfoCount,
        CreHeaderField.memorizedSpellsOffset,
        CreHeaderField.memorizedSpellsCount,
        CreHeaderField.itemSlotsOffset,
        CreHeaderField.itemsOffset,
        CreHeaderField.itemsCount,
        CreHeaderField.effectsOffset,
        CreHeaderField.effectsCount,
        CreHeaderField.effectVersion,
      };

      expect(
        CharacterStat.values
            .map((s) => s.field)
            .toSet()
            .intersection(
              forbidden,
            ),
        isEmpty,
      );
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
