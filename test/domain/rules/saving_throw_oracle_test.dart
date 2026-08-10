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

/// The saving-throw derivation against **the game's own creature records**.
///
/// This is the measurement that settled how a multi-class composes its saves,
/// and it needed no trip into the game: BioWare's own NPCs are in the archives,
/// each one a character built by the people who wrote the rules. It reads the
/// player's installation and skips where there is none, the convention
/// `creation_golden_test.dart` already follows.
///
/// ⚠️ **Why it exists.** BG:EE's own Aurel — a level-1 Fighter/Mage — cannot
/// separate "the best of each class" from "the caster's table wins": at level 1
/// `savewar` is worse in all five categories, so every multi-class holding a
/// fighter gives the other table's row under either rule. The separating case
/// is a multi-class with no fighter in it, and the game ships two.
///
/// ⚠️ **And it caught something nobody was looking for.** Four of the NPCs
/// disagreed with the class tables by up to five points, all of them dwarves,
/// gnomes and halflings — which is `savecndh.2da` and `savecng.2da`, the racial
/// Constitution bonus. A derivation without those is wrong for three of the
/// seven playable races.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/domain/saving_throws.dart';

void main() {
  const profile = GameProfileService();
  final installed = profile.findGameDirectory() != null;
  const why = 'no Baldur’s Gate installation';

  final resources = ResourceRepository(profile);
  late GameRules rules;

  setUpAll(() async {
    rules = GeneratedGameRules(
      savingThrows: await resources.savingThrowTables(),
    );
  });

  /// The five the record holds, and the five the tables give, for [resref].
  Future<({SavingThrows stored, SavingThrows? derived})> compare(
    String resref,
  ) async {
    final bytes = await resources.creature(resref);
    expect(bytes, isNotNull, reason: '$resref is not in this installation');

    final cre = CreCodec.decode(bytes!, source: resref);
    final classId = cre.readField(CreHeaderField.characterClass);
    final (first, second, third) = cre.levels;
    // ⚠️ The slot count comes from CLASS.IDS, never from the bytes: a record
    // leaves its unused level slots holding 1.
    final levels = [
      first,
      second,
      third,
    ].take(rules.classCount(classId) ?? 1).toList();

    final saves = cre.savingThrows;
    return (
      stored: SavingThrows(
        death: saves.death,
        wands: saves.wands,
        polymorph: saves.polymorph,
        breath: saves.breath,
        spells: saves.spells,
      ),
      derived: rules.savingThrowsFor(
        classIdentifier: rules.classIdentifier(classId) ?? '',
        levels: levels,
        raceIdentifier: rules.raceIdentifier(
          cre.readField(CreHeaderField.race),
        ),
        constitution: cre.readField(CreHeaderField.constitution),
      ),
    );
  }

  Matcher matches(SavingThrows expected) => isA<SavingThrows>()
      .having((s) => s.death, 'death', expected.death)
      .having((s) => s.wands, 'wands', expected.wands)
      .having((s) => s.polymorph, 'polymorph', expected.polymorph)
      .having((s) => s.breath, 'breath', expected.breath)
      .having((s) => s.spells, 'spells', expected.spells);

  group('the multi-class rule — best of each column', () {
    test(
      'QUAYLE, a Cleric/Mage, holds a row NEITHER table has',
      () async {
        // The measurement that settles it. His death save is the priest's 10
        // and his other four are the wizard's; `saveprs` alone would give a
        // polymorph of 13 and `savewiz` alone a death of 14.
        final (:stored, :derived) = await compare('QUAYLE');

        expect(stored.death, 10, reason: 'saveprs, not savewiz’s 14');
        expect(stored.polymorph, 13);
        expect(derived, matches(stored));
      },
      skip: installed ? false : why,
    );

    test(
      'TIAX, a Cleric/Thief, is a mix of both tables too',
      () async {
        // Independent of Quayle, and it rules out a different pair: `saveprs`
        // alone gives polymorph 13 where he stores 12, and `saverog` alone
        // gives death 13 where he stores 10.
        final (:stored, :derived) = await compare('TIAX');

        expect(stored.death, 10, reason: 'the priest’s');
        expect(stored.polymorph, 12, reason: 'the rogue’s');
        expect(derived, matches(stored));
      },
      skip: installed ? false : why,
    );

    test(
      'CORAN, a Fighter/Thief, is the rogue table outright',
      () async {
        // The unsurprising half of the rule, and worth keeping: at these levels
        // `savewar` is worse in every category, so best-of collapses to one
        // table. This is the shape every earlier measurement had.
        final (:stored, :derived) = await compare('CORAN');

        expect(derived, matches(stored));
      },
      skip: installed ? false : why,
    );
  });

  group('the racial Constitution bonus', () {
    test(
      'KAGAIN, a dwarf at Constitution 20, is five better',
      () async {
        // 14/16/15/17/17 from `savewar`, less `savecndh`'s 5 on three of them.
        final (:stored, :derived) = await compare('KAGAIN');

        expect(stored.death, 9);
        expect(stored.wands, 11);
        expect(stored.polymorph, 15, reason: 'no bonus to polymorph');
        expect(stored.breath, 17, reason: 'nor to breath');
        expect(stored.spells, 12);
        expect(derived, matches(stored));
      },
      skip: installed ? false : why,
    );

    test(
      'ALORA, a halfling, takes the bonus on death as well',
      () async {
        final (:stored, :derived) = await compare('ALORA');

        expect(stored.death, 10, reason: 'the rogue’s 13, less 3');
        expect(derived, matches(stored));
      },
      skip: installed ? false : why,
    );

    test(
      'QUAYLE and TIAX, gnomes, take NO bonus on death',
      () async {
        // The difference between the two tables, and the only thing that makes
        // them two. `savecng`'s DEATH row is all zeros.
        final quayle = await compare('QUAYLE');
        final tiax = await compare('TIAX');

        expect(quayle.stored.death, 10, reason: 'the priest’s, unimproved');
        expect(quayle.stored.wands, 8, reason: '11 less 3 at Constitution 11');
        expect(tiax.stored.death, 10, reason: 'unimproved at Constitution 16');
        expect(tiax.stored.wands, 10, reason: '14 less 4');
      },
      skip: installed ? false : why,
    );

    test('an elf and a human take none at all', () async {
      // Four of the seven playable races have no table, and their records say
      // so: KIVAN and SKIE land on the class tables untouched.
      for (final resref in ['KIVAN', 'SKIE', 'XAN', 'EDWIN']) {
        final (:stored, :derived) = await compare(resref);
        expect(derived, matches(stored), reason: resref);
      }
    }, skip: installed ? false : why);
  });

  group('what the sweep found that the rule does not explain', () {
    test('IMOEN’s record matches no table at any level', () async {
      // ⚠️ **Recorded rather than asserted past.** Her record is class MAGE
      // with 14/15/16/17/17, which is `savewar` level 1 with wands and
      // polymorph transposed — a hand-written record, not a derived one. BG1's
      // Imoen is a Thief, and `saverog` level 1 is 13/14/12/16/15.
      //
      // This is the one disagreement in fifteen shipped NPCs, and it is
      // evidence about *her file*, not about the derivation. The assertion is
      // written so that a future installation agreeing would fail loudly.
      final (:stored, :derived) = await compare('IMOEN');

      expect(stored.death, 14);
      expect(stored.wands, 15);
      expect(stored.polymorph, 16);
      expect(derived, isNot(matches(stored)));
    }, skip: installed ? false : why);
  });
}
