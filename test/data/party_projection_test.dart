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
import 'package:wand_of_saves/data/party_projection.dart';
import 'package:wand_of_saves/domain/save_slot.dart';

import '../support/synthetic_save.dart';

void main() {
  /// A slot the projection can look for portraits beside. The directory does
  /// not exist, so every character comes back with `portraitPath: null` —
  /// which is the documented degradation, not a failure.
  final slot = SaveSlot(
    path: '/nowhere',
    directoryName: '000000100-Party',
    area: 'AR2600',
    gameTime: 4791,
    partySize: 1,
    gold: 161,
    modified: DateTime(2026, 8, 8),
  );

  group('charactersFrom', () {
    test('carries the saving throws the record screen prints', () {
      // Xzar's, as BG:EE showed them on 2026-08-08. These are the one block
      // on the sheet that is stored exactly as displayed.
      final gam = GamCodec.decode(
        buildSave(
          party: const [
            SyntheticCharacter(
              saveVersusDeath: 14,
              saveVersusWands: 11,
              saveVersusPolymorph: 13,
              saveVersusBreath: 15,
              saveVersusSpells: 12,
            ),
          ],
        ),
      );

      final saves = charactersFrom(gam, slot).single.savingThrows;

      expect(saves.death, 14);
      expect(saves.wands, 11);
      expect(saves.polymorph, 13);
      expect(saves.breath, 15);
      expect(saves.spells, 12);
    });

    test('carries the thief skills as the points allocated', () {
      // Imoen's stored bytes, which the game displays as 35 and 10 — the
      // engine adds class, race and Dexterity bonuses. The projection must
      // not do that arithmetic; the panel says "base" instead.
      final gam = GamCodec.decode(
        buildSave(
          party: const [
            SyntheticCharacter(moveSilently: 15, findTraps: 25, lore: 3),
          ],
        ),
      );

      final skills = charactersFrom(gam, slot).single.thiefSkills;

      expect(skills.moveSilently, 15);
      expect(skills.findTraps, 25);
      expect(skills.lore, 3);
      expect(skills.hideInShadows, 0);
    });

    test('carries resistances and the signed armour class modifiers', () {
      final gam = GamCodec.decode(
        buildSave(
          party: const [
            SyntheticCharacter(
              resistFire: 50,
              resistMagic: 20,
              armorClassCrushing: -3,
              armorClassMissile: 4,
            ),
          ],
        ),
      );

      final character = charactersFrom(gam, slot).single;

      expect(character.resistances.fire, 50);
      expect(character.resistances.magic, 20);
      expect(character.resistances.cold, 0);
      // Signed, and the negative is the whole point: an unsigned read turns
      // −3 into 253, which is the armour-class bug in a different field.
      expect(character.armorClassModifiers.crushing, -3);
      expect(character.armorClassModifiers.missile, 4);
    });

    test('carries the loose scalars the record screen shows', () {
      // Eight distinct values, deliberately. Three of these are adjacent
      // bytes (fatigue, intoxication, luck at 0x6b-0x6d), as are turn undead
      // and tracking, and as are morale and its break point — so a reader off
      // by one lands on a neighbour, and only distinct values catch that.
      final gam = GamCodec.decode(
        buildSave(
          party: const [
            SyntheticCharacter(
              numberOfAttacks: 2,
              morale: 14,
              moraleBreak: 5,
              luck: 1,
              fatigue: 3,
              intoxication: 7,
              turnUndeadLevel: 4,
              trackingSkill: 30,
            ),
          ],
        ),
      );

      final character = charactersFrom(gam, slot).single;

      expect(character.numberOfAttacks, 2);
      expect(character.morale, 14);
      expect(character.moraleBreak, 5);
      expect(character.luck, 1);
      expect(character.fatigue, 3);
      expect(character.intoxication, 7);
      expect(character.turnUndeadLevel, 4);
      expect(character.trackingSkill, 30);
    });

    group('proficiencies', () {
      test('come from the effects section, not the header', () {
        // Aard's, measured: two pips in Two-Weapon Style and two in
        // Flail/Morning Star. On BG:EE these are opcode 233 effects; the
        // header bytes IESDP documents at 0x6e-0x81 are zero.
        final gam = GamCodec.decode(
          buildSave(
            party: const [
              SyntheticCharacter(proficiencies: {114: 2, 100: 2}),
            ],
          ),
        );

        final proficiencies = charactersFrom(gam, slot).single.proficiencies;

        expect(
          {for (final p in proficiencies) p.id: p.pips},
          {114: 2, 100: 2},
        );
      });

      test('each know where their effect sits, so a writer can patch it', () {
        // The pip count is a dword already in the record, so raising it is a
        // fixed-width edit — but only if the character remembers *where*.
        // Recomputing the position from an index and a stride is the kind of
        // arithmetic that produced a stride of −180.
        final gam = GamCodec.decode(
          buildSave(
            party: const [
              SyntheticCharacter(proficiencies: {114: 2, 100: 2}),
            ],
          ),
        );
        final character = charactersFrom(gam, slot).single;
        final twoWeapon = character.proficiencies.firstWhere(
          (p) => p.id == 114,
        );

        final after = gam.withEffectField(
          creOffset: character.creOffset,
          effectStart: twoWeapon.effectOffset,
          field: EffectV2Field.parameter1,
          value: 3,
        );

        expect(
          {
            for (final p in charactersFrom(after, slot).single.proficiencies)
              p.id: p.pips,
          },
          {114: 3, 100: 2},
        );
      });

      test('are empty for a character with no effects at all', () {
        final gam = GamCodec.decode(buildSave());

        expect(charactersFrom(gam, slot).single.proficiencies, isEmpty);
      });
    });
  });
}
