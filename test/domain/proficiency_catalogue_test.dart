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

/// Which rows of `weapprof.2da` are a proficiency a character may be given.
///
/// ⚠️ **The fixture is the real file's shape, not a convenient one.** BG:EE's
/// copy has three bands and two of them are junk, and a fixture holding only
/// live rows would have passed against the code that shipped `Bow` beside
/// `Long Bow` and fourteen rows called `EXTRA*`. The ids, row labels and
/// strrefs below are the installation's own, read with
/// `fvm dart run tool/dev/dump_table.dart weapprof`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';

void main() {
  // One row from each band, with the file's real values.
  const catalogue = ProficiencyCatalogue({
    // Obsolete BG1 generation: a valid name, a valid description, and a
    // non-zero cap — which is why no column separates it from the live band.
    2: ProficiencyEntry(
      id: 2,
      identifier: 'BOW',
      nameStrref: 8733,
      name: 'Bow',
      maximumByColumn: {'FIGHTER_MAGE': 2},
    ),
    // Live EE generation.
    104: ProficiencyEntry(
      id: 104,
      identifier: 'LONGBOW',
      nameStrref: 25016,
      name: 'Long Bow',
      maximumByColumn: {'FIGHTER_MAGE': 2},
    ),
    105: ProficiencyEntry(
      id: 105,
      identifier: 'SHORTBOW',
      nameStrref: 25017,
      name: 'Short Bow',
      maximumByColumn: {'FIGHTER_MAGE': 2},
    ),
    // Padding: `NAME_REF` is 2^32, which ResourceRepository rejects as out of
    // range, so it arrives with no strref at all and every column zero.
    116: ProficiencyEntry(
      id: 116,
      identifier: 'EXTRA2',
      maximumByColumn: {'FIGHTER_MAGE': 0},
    ),
  });

  group('live', () {
    test('keeps the current generation', () {
      expect(catalogue.live.entries.keys, [104, 105]);
      expect(catalogue.live.entries.values.map((e) => e.name), [
        'Long Bow',
        'Short Bow',
      ]);
    });

    test('drops the padding rows, which name nothing', () {
      expect(catalogue.live[116], isNull);
      // ⚠️ Gated on the strref, not the resolved name: a machine with no
      // installation resolves no names and must degrade, not empty.
      expect(catalogue.entries[116]!.nameStrref, isNull);
    });

    test('drops the obsolete generation, which names something real', () {
      // ⚠️ The point of a separate test. `Bow` has a valid name, a valid
      // description and a cap of 2, so neither the name filter nor a
      // zero-column filter touches it — and it was the user-visible complaint.
      final obsolete = catalogue.entries[2]!;

      expect(obsolete.name, 'Bow');
      expect(obsolete.nameStrref, isNotNull);
      expect(obsolete.maximumFor('FIGHTER_MAGE'), 2);
      expect(catalogue.live[2], isNull);
    });

    test('an empty catalogue stays empty rather than throwing', () {
      expect(ProficiencyCatalogue.empty.live.entries, isEmpty);
    });

    test('holds nothing back that the live band contains', () {
      // A guard on the floor itself: 89 is the lowest id the shipped creature
      // records use, so an entry at exactly 89 must survive.
      const boundary = ProficiencyCatalogue({
        89: ProficiencyEntry(
          id: 89,
          identifier: 'BASTARDSWORD',
          nameStrref: 25000,
          name: 'Bastard Sword',
          maximumByColumn: {'FIGHTER_MAGE': 2},
        ),
      });

      expect(boundary.live.entries.keys, [89]);
    });
  });

  group('⚠️ the eight weapon classes, and the game states them itself', () {
    // ⚠️ **Not invented, and not inferred from the names either.** BG:EE's
    // `weapprof.2da` still carries the eight obsolete BG1 rows, and each one's
    // DESC_REF is a sentence naming exactly which weapons it covers. Resolved
    // against the player's own talk table 2026-08-16:
    //
    //   9589 LARGE SWORD  — "Bastard Swords, Two handed swords, Long Swords,
    //                        and Scimitars"
    //   9590 SMALL SWORD  — "Daggers and Short swords"
    //   9591 BOW          — "Longbows, Composite Longbows, and Shortbows"
    //   9592 SPEAR        — "Spears and Halberds"
    //   9593 BLUNT        — "Maces, Clubs, Warhammers, and the Staff"
    //   9594 SPIKED       — "Morning Stars and Flails"
    //   9595 AXE          — "Battle axes and Throwing axes"
    //   9596 MISSILE      — "Slings, Darts, and Crossbows"
    //
    // Nineteen of the twenty live weapon proficiencies are named there. The
    // twentieth is Katana, which did not exist in BG1 — see its own test.

    test('the sentences are transcribed exactly', () {
      // ⚠️ Large Sword is the sentence's four **plus 94, the Katana**, which
      // no sentence names — see the next test. Every other class here is its
      // sentence and nothing else.
      expect(WeaponClass.largeSword.members, {89, 90, 93, 95, 94});
      expect(
        WeaponClass.largeSword.members.difference({94}),
        {89, 90, 93, 95},
        reason: 'strref 9589, transcribed',
      );
      expect(WeaponClass.smallSword.members, {91, 96});
      expect(WeaponClass.bow.members, {104, 105});
      expect(WeaponClass.spear.members, {98, 99});
      expect(WeaponClass.blunt.members, {97, 101, 102, 115});
      expect(WeaponClass.spiked.members, {100});
      expect(WeaponClass.axe.members, {92});
      expect(WeaponClass.missile.members, {103, 106, 107});
    });

    test('⚠️ Katana is the one the sentences do not cover', () {
      // BG1 had no katanas, so no BG1 weapon class names one. It is placed by
      // MEASUREMENT instead: all four katanas BioWare ships are `ITEMCAT`
      // category `BGSWORD`, the same category as every bastard, long and
      // two-handed sword. Evidence, not a guess — but weaker evidence than the
      // other nineteen, and that is why it has its own test.
      expect(WeaponClass.of(94), WeaponClass.largeSword);
      expect(
        WeaponClass.largeSword.members.contains(94),
        isTrue,
        reason: 'measured from the shipped items, not read from a sentence',
      );
    });

    test('the classes are disjoint', () {
      // Every proficiency has ONE class, so a tabbed reading of them shows
      // each exactly once.
      final seen = <int>{};
      for (final each in WeaponClass.values) {
        for (final id in each.members) {
          expect(seen.add(id), isTrue, reason: '$id is in two classes');
        }
      }
    });

    test('⚠️ together they cover every live WEAPON and no style', () {
      // The live band is 89–107 plus 111–115. The four styles — 111 to 114 —
      // belong to no weapon class, which is what makes "unclassified" a safe
      // definition of *style* rather than a second constant to keep in step.
      final classified = {
        for (final each in WeaponClass.values) ...each.members,
      };
      final live = {
        for (var id = 89; id <= 107; id++) id,
        111,
        112,
        113,
        114,
        115,
      };
      expect(
        classified.difference(live),
        isEmpty,
        reason: 'no class claims an id the table does not have',
      );
      expect(
        live.difference(classified),
        {111, 112, 113, 114},
        reason: 'exactly the four styles are left over',
      );
    });

    test('an id no class claims answers null', () {
      expect(WeaponClass.of(114), isNull, reason: 'Two-Weapon Style');
      expect(WeaponClass.of(2), isNull, reason: 'the obsolete BOW row');
      expect(WeaponClass.of(116), isNull, reason: 'a padding row');
    });

    test('⚠️ the labels are the game’s own words', () {
      // 8668, 8733, 8734, 9400, 9401, 9402, 9403 are the NAME_REF strings.
      expect(WeaponClass.largeSword.label, 'Large Sword');
      expect(WeaponClass.bow.label, 'Bow');
      expect(WeaponClass.blunt.label, 'Blunt Weapons');
      expect(WeaponClass.missile.label, 'Missile Weapons');
      // ⚠️ The exception, and it is deliberate: NAME_REF 8732 resolves to
      // "Short Sword", which is ALSO live proficiency 91. A heading reading
      // "Short Sword" over a list containing "Short Sword" and "Dagger" states
      // the wrong thing. The class's own description (9590) heads itself
      // "SMALL SWORD", so that is the word used — still the game's, and
      // unambiguous.
      expect(WeaponClass.smallSword.label, 'Small Sword');
    });
  });
}
