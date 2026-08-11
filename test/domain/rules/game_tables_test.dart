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

/// The table vocabulary, checked the way `values` lets you check an enum.
///
/// ⚠️ **Why this exists at all.** Every rules lookup used to name its table
/// with a bare string, and that shape cost this project twice: `thiefskl` read
/// where `thiefscl` was meant, and `profs` read where `profsmax` was meant —
/// the second built a proficiency rule on the wrong table and shipped. The same
/// argument D6 settled for binary layouts applies here, and the payoff is the
/// same: `values` being iterable turns an invariant into a test.
///
/// ⚠️ **What this does NOT catch, said plainly so nobody assumes otherwise.**
/// An enum makes a *misspelling* impossible and *duplication* visible. It does
/// not stop you choosing the wrong one of two tables that both exist and both
/// carry the column you asked for — `profs` and `profsmax` both have
/// `FIRST_LEVEL`, which is exactly how that bug shipped. What guards that is
/// each value's doc comment and D13's requirement that a rule in code names the
/// tables it checked.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/rules/game_tables.dart';

void main() {
  group('the vocabulary is internally consistent', () {
    test('no two tables share a resref', () {
      // The duplication this replaces was real: `thiefSkillPointTable` was
      // declared once in the domain layer and once in the data layer, and
      // nothing could have told you they were the same file.
      final byResref = <String, List<GameTable>>{};
      for (final table in GameTable.values) {
        byResref.putIfAbsent(table.resref, () => <GameTable>[]).add(table);
      }

      expect(
        {
          for (final entry in byResref.entries)
            if (entry.value.length > 1) entry.key: entry.value,
        },
        isEmpty,
      );
    });

    test('every resref is lowercase and plausible as a file name', () {
      for (final table in GameTable.values) {
        expect(
          table.resref,
          matches(RegExp(r'^[a-z0-9]{1,8}$')),
          reason: '${table.name} — a 2DA resref is at most eight characters',
        );
      }
    });

    test('D11 — nothing generated from IESDP carries a strref', () {
      // ⚠️ **This is D11 made checkable rather than left as a paragraph.**
      // IESDP's copies are per-game: its `weapprof.2da` is BG2:EE's, and that
      // file's strref for Two-Weapon Style resolves against a BG:EE talk table
      // to a paragraph about temples. A number is still a number across games;
      // a strref is not. So a table may be generated, or it may carry strrefs,
      // and never both.
      expect(
        GameTable.generatedFromIesdp
            .where((table) => table.carriesStrrefs)
            .map((table) => table.name),
        isEmpty,
      );
    });

    test('a table carrying strrefs is one the installation supplies', () {
      // The same rule from the other side: every strref-carrying table has to
      // be reachable from the player's own files, or D11 is unenforceable.
      for (final table in GameTable.values.where((t) => t.carriesStrrefs)) {
        expect(
          GameTable.generatedFromIesdp,
          isNot(contains(table)),
          reason: '${table.name} carries strrefs and must be read, not baked',
        );
      }
    });
  });

  group('against the player’s own installation', () {
    const profile = GameProfileService();
    final game = profile.findGameDirectory();
    final why = game == null ? 'no Baldur’s Gate installation' : null;

    test(
      'every table this app names is really in the archives',
      () async {
        // ⚠️ The check with teeth: a typo in a resref stops being a lookup
        // that quietly returns null and becomes a named failure. Tables the
        // *data* names rather than the code — the `hp*` hit-die tables, which
        // `hpclass.2da` points at — are deliberately not enum values and are
        // not covered here.
        final index = KeyIndex.parse(
          await File(
            '$game${Platform.pathSeparator}${GameProfileService.gameMarker}',
          ).readAsBytes(),
          source: GameProfileService.gameMarker,
        );

        final missing = <String>[
          for (final table in GameTable.values)
            if (index.locate(table.resref, ResourceType.table2da) == null)
              '${table.name} (${table.resref})',
        ];

        expect(missing, isEmpty);
      },
      skip: why,
    );
  });
}
