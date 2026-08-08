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

  group('SetProficiency', () {
    /// A save whose sole character has Aard's two proficiencies.
    Gam openProficientSave() => GamCodec.decode(
      buildSave(
        party: const [
          SyntheticCharacter(proficiencies: {114: 2, 100: 2}),
        ],
      ),
    );

    int offsetOf(Gam gam, int id) => CreCodec.decode(
      gam.partyMembers.single.creBytes,
    ).effects.firstWhere((e) => e.isProficiency && e.parameter2 == id).start;

    test('raises a pip inside the effect that already grants it', () {
      final gam = openProficientSave();

      final edited = applyEdit(
        gam,
        SetProficiency(
          creOffset: creOffsetOf(gam),
          effectOffset: offsetOf(gam, 114),
          proficiencyId: 114,
          pips: 3,
        ),
      );

      expect(creatureIn(edited).proficiencies, {114: 3, 100: 2});
    });

    test('touches exactly one byte and does not resize the save', () {
      // The whole reason a pip is editable this early. Parameter 1 is a dword
      // already sitting in the record, so 2 -> 3 moves its low byte and
      // nothing else — no layout pass, no offset cascade, no chance for the
      // GAM's nine offset fields to disagree with the file.
      final gam = openProficientSave();

      final edited = applyEdit(
        gam,
        SetProficiency(
          creOffset: creOffsetOf(gam),
          effectOffset: offsetOf(gam, 114),
          proficiencyId: 114,
          pips: 3,
        ),
      );

      expect(edited.bytes, hasLength(gam.bytes.length));
      expect(
        [
          for (var i = 0; i < gam.bytes.length; i++)
            if (gam.bytes[i] != edited.bytes[i]) i,
        ],
        hasLength(1),
      );
    });

    test('leaves the other proficiencies alone', () {
      // Two effects, one stride apart. Patching the wrong one is the failure
      // this catches, and it would look like a working edit on a character
      // with only one proficiency.
      final gam = openProficientSave();

      final edited = applyEdit(
        gam,
        SetProficiency(
          creOffset: creOffsetOf(gam),
          effectOffset: offsetOf(gam, 100),
          proficiencyId: 100,
          pips: 5,
        ),
      );

      expect(creatureIn(edited).proficiencies, {114: 2, 100: 5});
    });

    test('leaves the save it was given alone', () {
      final gam = openProficientSave();

      applyEdit(
        gam,
        SetProficiency(
          creOffset: creOffsetOf(gam),
          effectOffset: offsetOf(gam, 114),
          proficiencyId: 114,
          pips: 3,
        ),
      );

      expect(creatureIn(gam).proficiencies, {114: 2, 100: 2});
    });

    test('refuses a pip count the field cannot hold', () {
      // No game-rules cap lives here: IESDP states no range for opcode 233's
      // Amount, and the per-class ceiling is in the player's own weapprof.2da,
      // which is the panel's to consult. What this rejects is a number the
      // dword itself cannot store.
      final gam = openProficientSave();

      expect(
        () => applyEdit(
          gam,
          SetProficiency(
            creOffset: creOffsetOf(gam),
            effectOffset: offsetOf(gam, 114),
            proficiencyId: 114,
            pips: -1,
          ),
        ),
        throwsA(isA<InvalidEditException>()),
      );
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
      // The proficiency has only a number to go on: naming it needs the
      // player's weapprof.2da, which no domain command may reach for.
      const proficiency = SetProficiency(
        creOffset: 532,
        effectOffset: 1340,
        proficiencyId: 114,
        pips: 3,
      );
      expect(proficiency.label, contains('3'));
      expect(proficiency.label, contains('114'));
    });
  });
}
