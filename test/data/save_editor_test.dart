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
import 'package:wand_of_saves/data/save_editor.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/edit_command.dart';

import '../support/synthetic_save.dart';

void main() {
  Gam openSave() => GamCodec.decode(buildSave());
  int creOffsetOf(Gam gam) => gam.partyMembers.single.creOffset;

  Cre creatureIn(Gam gam) => CreCodec.decode(gam.partyMembers.single.creBytes);

  group('SetCharacterStat', () {
    test('writes the stat into the creature record', () {
      final gam = openSave();

      final edited = applyEdit(
        gam,
        SetCharacterStat(
          creOffset: creOffsetOf(gam),
          stat: CharacterStat.strength,
          value: 19,
        ),
      );

      expect(creatureIn(edited).strength, 19);
    });

    test('writes a negative armour class', () {
      final gam = openSave();

      final edited = applyEdit(
        gam,
        SetCharacterStat(
          creOffset: creOffsetOf(gam),
          stat: CharacterStat.armorClassNatural,
          value: -2,
        ),
      );

      expect(creatureIn(edited).armorClassNatural, -2);
    });

    test('refuses a value outside the stat range, not just the field', () {
      // 200 fits the byte. The stat is what says it is not a Strength.
      final gam = openSave();

      expect(
        () => applyEdit(
          gam,
          SetCharacterStat(
            creOffset: creOffsetOf(gam),
            stat: CharacterStat.strength,
            value: 200,
          ),
        ),
        throwsA(isA<InvalidEditException>()),
      );
    });

    test('leaves the save it was given alone', () {
      final gam = openSave();

      applyEdit(
        gam,
        SetCharacterStat(
          creOffset: creOffsetOf(gam),
          stat: CharacterStat.strength,
          value: 19,
        ),
      );

      expect(creatureIn(gam).strength, 18, reason: 'the original was mutated');
    });
  });

  group('SetPartyGold', () {
    test('writes the shared purse', () {
      final edited = applyEdit(openSave(), const SetPartyGold(12345));

      expect(edited.partyGold, 12345);
    });

    test('refuses a negative purse', () {
      expect(
        () => applyEdit(openSave(), const SetPartyGold(-1)),
        throwsA(isA<InvalidEditException>()),
      );
    });
  });

  group('command labels', () {
    test('say what the edit did, for the undo entry', () {
      const command = SetCharacterStat(
        creOffset: 532,
        stat: CharacterStat.strength,
        value: 19,
      );

      expect(command.label, contains('Strength'));
      expect(command.label, contains('19'));
      expect(const SetPartyGold(500).label, contains('500'));
    });
  });
}
