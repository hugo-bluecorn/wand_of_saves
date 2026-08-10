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

/// The specialist exclusion bits, measured against the player's own spells.
///
/// ⚠️ **This is what turned an invented pairing into a lookup.** No table in
/// the installation pairs a school with its opposite — `mschool.2da` is dispel
/// text and `kitlist.2da` has no such column — so the eight opposed pairs
/// would otherwise have had to be written into the code from memory of the
/// rulebook. The `SPL` header carries them, and this proves the bit numbering:
/// **every first-level spell that excludes a specialist belongs to exactly the
/// school that specialist is opposed to**, with no exceptions.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';

void main() {
  const profile = GameProfileService();
  final installed = profile.findGameDirectory() != null;
  const why = 'no Baldur’s Gate installation';

  final resources = ResourceRepository(profile);
  late List<SpellChoice> spells;

  setUpAll(() async {
    spells = await resources.wizardSpells(level: 1);
  });

  /// The eight schools, as `mschool.2da` numbers them, against their opposite.
  ///
  /// **Not the source of anything** — the spells are. This is written out only
  /// so the test can say what it expects to find, and finding it is the point.
  const opposed = {1: 8, 2: 3, 3: 2, 4: 6, 5: 7, 6: 4, 7: 5, 8: 1};

  test(
    'a spell excludes exactly the specialists opposed to its school',
    () {
      // 22 spells, eight specialists, no exception. If the bit numbering were
      // off by one this would fail on every spell at once.
      for (final spell in spells) {
        for (final MapEntry(key: school, value: opposite) in opposed.entries) {
          if (spell.school != opposite) continue;
          expect(
            spell.excludedSchools,
            contains(school),
            reason:
                '${spell.resref} is school ${spell.school} and should be '
                'closed to specialist $school',
          );
        }
      }
    },
    skip: installed ? false : why,
  );

  test(
    'and excludes nobody else, except what is closed to everyone',
    () {
      // ⚠️ One spell — `SPWI124`, school 10 — excludes all eight. Its
      // school is past the nine `mschool.2da` names, so it belongs to no
      // specialist and is barred from every one of them.
      for (final spell in spells) {
        if (spell.excludedSchools.length == opposed.length) continue;
        for (final school in spell.excludedSchools) {
          expect(
            opposed[school],
            spell.school,
            reason:
                '${spell.resref} excludes specialist $school without being '
                'their opposed school',
          );
        }
      }
    },
    skip: installed ? false : why,
  );

  test(
    'every specialist has spells closed to them, and few',
    () {
      // Three or four of the twenty-two each — which is the shape the engine's
      // own spellbook screen shows. Zero would mean the bits were never read.
      for (var school = 1; school <= 8; school++) {
        final closed = spells.where((s) => s.excludedSchools.contains(school));

        expect(closed, isNotEmpty, reason: 'school $school');
        expect(closed.length, lessThan(spells.length ~/ 2), reason: '$school');
      }
    },
    skip: installed ? false : why,
  );
}
