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

/// THAC0, Lore and the fixed skills against **the game's own NPC records**.
///
/// The same oracle as `saving_throw_oracle_test.dart`, and it does not tell the
/// same story twice: THAC0 agrees on every character, the fixed skills agree
/// on every ranger and bard, and **Lore does not settle**. Recording which is
/// which is the point — a suite asserting all three equally would claim a
/// confidence two of them have and the third does not.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';

void main() {
  const profile = GameProfileService();
  final installed = profile.findGameDirectory() != null;
  const why = 'no Baldur’s Gate installation';

  final resources = ResourceRepository(profile);
  late GameRules rules;

  setUpAll(() async {
    rules = GeneratedGameRules(rulesTables: await resources.rulesTables());
  });

  /// [resref]'s record, its class identifier and its levels.
  Future<({Cre cre, String identifier, List<int> levels})> npc(
    String resref,
  ) async {
    final bytes = await resources.creature(resref);
    expect(bytes, isNotNull, reason: '$resref is not in this installation');

    final cre = CreCodec.decode(bytes!, source: resref);
    final classId = cre.readField(CreHeaderField.characterClass);
    final (first, second, third) = cre.levels;
    return (
      cre: cre,
      identifier: rules.classIdentifier(classId) ?? '',
      // The slot count comes from CLASS.IDS, never from the bytes.
      levels: [
        first,
        second,
        third,
      ].take(rules.classCount(classId) ?? 1).toList(),
    );
  }

  group('THAC0 — the table is right for every character in the game', () {
    test(
      'twelve NPCs, single and multi-class, all exact',
      () async {
        // ⚠️ This is the strongest agreement in the project: no exceptions, no
        // hand-authored outliers. `thac0.2da` enumerates the multi-class rows,
        // so a Fighter/Thief is a lookup rather than a composition.
        for (final resref in [
          'KAGAIN',
          'KHALID',
          'MINSC',
          'KIVAN',
          'XAN',
          'EDWIN',
          'XZAR',
          'SAFANA',
          'SKIE',
          'ALORA',
          'ELDOTH',
          'CORAN',
          'TIAX',
          'QUAYLE',
        ]) {
          final (:cre, :identifier, :levels) = await npc(resref);

          expect(
            rules.thac0For(classIdentifier: identifier, levels: levels),
            cre.readField(CreHeaderField.thac0),
            reason: '$resref, a $identifier at ${levels.join('/')}',
          );
        }
      },
      skip: installed ? false : why,
    );
  });

  group('the skills a class gets without allocating them', () {
    test(
      'a ranger’s ONE stealth number goes into both skills',
      () async {
        // `skillrng.2da` has a MOVE_SILENTLY column and no other, and both
        // rangers hold that number twice: Minsc 15/15 at level 1, Kivan 21/21
        // at 2. A reader that filled only Move Silently would leave every
        // created ranger visibly worse than the game's own.
        for (final resref in ['MINSC', 'KIVAN']) {
          final (:cre, :identifier, :levels) = await npc(resref);
          final fixed = rules.fixedThiefSkillsFor(
            classIdentifier: identifier,
            levels: levels,
          );
          final skills = cre.thiefSkills;

          expect(fixed['MOVE_SILENTLY'], skills.moveSilently, reason: resref);
          expect(
            fixed['HIDE_IN_SHADOWS'],
            skills.hideInShadows,
            reason: resref,
          );
          expect(skills.moveSilently, skills.hideInShadows, reason: resref);
        }
      },
      skip: installed ? false : why,
    );

    test(
      'a bard’s pick pockets is the table at their level',
      () async {
        // Garrick at 1 holds 25 and Eldoth at 3 holds 35, which is `skillbrd`
        // read straight down.
        for (final resref in ['GARRIC', 'ELDOTH']) {
          final (:cre, :identifier, :levels) = await npc(resref);

          expect(
            rules.fixedThiefSkillsFor(
              classIdentifier: identifier,
              levels: levels,
            )['PICK_POCKETS'],
            cre.thiefSkills.pickPockets,
            reason: resref,
          );
        }
      },
      skip: installed ? false : why,
    );
  });

  group('Lore — single class agrees, multi-class does NOT', () {
    test('every single-class NPC is rate × level', () async {
      // Eleven of thirteen. The two that are not are below.
      for (final resref in [
        'KAGAIN',
        'MINSC',
        'KIVAN',
        'XAN',
        'EDWIN',
        'XZAR',
        'SAFANA',
        'SKIE',
        'ALORA',
        'ELDOTH',
        'GARRIC',
      ]) {
        final (:cre, :identifier, :levels) = await npc(resref);

        expect(
          rules.loreFor(classIdentifier: identifier, levels: levels),
          cre.readField(CreHeaderField.lore),
          reason: '$resref, a $identifier at ${levels.join('/')}',
        );
      }
    }, skip: installed ? false : why);

    test('KHALID and IMOEN hold Lore no rule produces', () async {
      // ⚠️ **This is what stops the NPC files refereeing the multi-class
      // rule.** A Fighter 1 whose rate is 1 holds 4, and a Mage 1 whose rate
      // is 3 holds 0. Both are hand-written, so agreement elsewhere is not
      // proof that these files are derived at all.
      final khalid = await npc('KHALID');
      final imoen = await npc('IMOEN');

      expect(khalid.cre.readField(CreHeaderField.lore), 4);
      expect(
        rules.loreFor(
          classIdentifier: khalid.identifier,
          levels: khalid.levels,
        ),
        1,
      );
      expect(imoen.cre.readField(CreHeaderField.lore), 0);
    }, skip: installed ? false : why);

    test(
      'the multi-class NPCs read like SUMS, and we follow the engine',
      () {
        // ⚠️ **Recorded, not resolved.** Coran (Fighter/Thief 3/3) holds 12,
        // Tiax (Cleric/Thief 2/2) holds 8 and Quayle (Cleric/Mage 2/2) holds
        // 8 — each the sum of rate × level over both classes, where the
        // highest gives 9, 6 and 6. But the engine's own recomputation on
        // import stored **3** for a Fighter/Mage/Thief 1/1/1, a sum giving 7.
        //
        // Engine outranks table outranks file, and the files are demonstrably
        // hand-written (see above), so `loreFor` takes the highest. This test
        // exists to state the disagreement rather than to hide it: if the
        // multi-class rule is ever measured properly, this is where the
        // evidence already is.
        expect(
          rules.loreFor(classIdentifier: 'FIGHTER_THIEF', levels: const [3, 3]),
          9,
          reason: 'the highest; Coran’s record holds 12, which is the sum',
        );
      },
      skip: installed ? false : why,
    );
  });
}
