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
import 'package:wand_of_saves/domain/character.dart';

import '../support/fakes.dart';

/// The protagonist of the fixture save, whose values are recorded in
/// `docs/findings/verified-format-offsets.md`.
///
/// Delegates to [fakeCharacter] rather than restating those values. It used to
/// be a second copy of them, which was tolerable at twenty fields and is not
/// at forty — two lists of Aard's numbers is two chances for one of them to
/// stop being Aard's.
Character aard({
  int levelFirstClass = 1,
  int levelSecondClass = 1,
  int levelThirdClass = 0,
  int strength = 18,
  int strengthBonus = 100,
  int partyOrder = 0,
}) => fakeCharacter(
  partyOrder: partyOrder,
  levelFirstClass: levelFirstClass,
  levelSecondClass: levelSecondClass,
  levelThirdClass: levelThirdClass,
  strength: strength,
  strengthBonus: strengthBonus,
);

void main() {
  group('levels', () {
    // Deliberately raw. Trimming the slots to the classes the character
    // actually has needs CLASS.IDS, so it lives on CharacterSheet -- see
    // its `class levels` group. Character reports what the bytes hold.
    test('reports all three slots exactly as the record holds them', () {
      // The fixture protagonist is (1, 1, 0): the player's own record zeroes
      // the slot it does not use.
      expect(aard().levels, [1, 1, 0]);
    });

    test('keeps a junk slot rather than guessing it away', () {
      // Every recruited NPC stores 1/1/1, single-class Imoen and Xzar
      // included, so a zero here is not what marks a slot unused.
      expect(aard(levelThirdClass: 1).levels, [1, 1, 1]);
    });

    test('keeps three real levels', () {
      final triple = aard(
        levelFirstClass: 7,
        levelSecondClass: 8,
        levelThirdClass: 9,
      );

      expect(triple.levels, [7, 8, 9]);
    });
  });

  group('strength', () {
    test('writes percentile strength the way the game does', () {
      // 18/00 is the top of the range, stored as 100 -- not "18/100".
      expect(aard().abilities.strengthLabel, '18/00');
    });

    test('pads a percentile below ten', () {
      expect(aard(strengthBonus: 5).abilities.strengthLabel, '18/05');
    });

    test('shows a mid-range percentile as written', () {
      expect(aard(strengthBonus: 50).abilities.strengthLabel, '18/50');
    });

    test('omits the percentile at strength 18 with no bonus', () {
      expect(aard(strengthBonus: 0).abilities.strengthLabel, '18');
    });

    test('ignores a percentile at any strength but 18', () {
      // The engine stores the field whatever the strength is; only 18 uses it.
      expect(
        aard(strength: 17, strengthBonus: 75).abilities.strengthLabel,
        '17',
      );
      expect(
        aard(strength: 19, strengthBonus: 75).abilities.strengthLabel,
        '19',
      );
    });
  });

  group('party membership', () {
    test('a party order of 0xFFFF means not in the party', () {
      expect(aard(partyOrder: Character.notInParty).isInParty, isFalse);
      expect(aard().isInParty, isTrue);
    });
  });

  group('value semantics', () {
    test('two characters with the same values compare equal', () {
      // dart_mappable (D9): the party list is rebuilt on every edit, and
      // identity equality would repaint the whole rail each time.
      expect(aard(), aard());
      expect(aard().hashCode, aard().hashCode);
    });

    test('copyWith reaches a nested ability score', () {
      final stronger = aard().copyWith(
        abilities: aard().abilities.copyWith(strength: 19),
      );

      expect(stronger.abilities.strength, 19);
      expect(stronger.abilities.dexterity, 17, reason: 'nothing else moved');
      expect(stronger.name, 'Aard');
    });
  });
}
