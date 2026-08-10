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

/// Class names, and the two things `clastext.2da` does that break them.
///
/// ⚠️ **Both were on screen.** The creation flow's class list read
/// `<FIGHTERTYPE>`, `<MAGESCHOOL>` and — worse, because it looks like a real
/// name — **`Fallen Cleric`** where the game draws `Cleric`.
///
/// Every string here was resolved out of the player's own talk table with
/// `tool/dev/dump_table.dart --text`, so they are the game's, not invented.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/domain/rules/name_tables.dart';

void main() {
  // What `clastext.2da`'s MIXED column actually resolves to, by CLASS.IDS id.
  const tables = NameTables(
    classNames: {
      2: '<FIGHTERTYPE>',
      1: '<MAGESCHOOL>',
      3: 'Cleric',
      4: 'Thief',
      7: '<FIGHTERTYPE> / <MAGESCHOOL>',
      14: 'Cleric / <MAGESCHOOL>',
      8: '<FIGHTERTYPE> / Cleric',
    },
  );
  const rules = GeneratedGameRules(tables: tables);

  group('the engine’s substitution tokens', () {
    test('a plain fighter is a Fighter, not <FIGHTERTYPE>', () {
      expect(rules.className(2), 'Fighter');
    });

    test('a plain mage is a Mage, not <MAGESCHOOL>', () {
      expect(rules.className(1), 'Mage');
    });

    test('a name with no token is left exactly as the table has it', () {
      expect(rules.className(3), 'Cleric');
      expect(rules.className(4), 'Thief');
    });

    test('⚠️ a HALF-tokened name keeps the table’s separator', () {
      // The case that rules out "fall back to the derived name when a token
      // appears": `Cleric / <MAGESCHOOL>` has one real word in it, and the
      // separator and ordering are the table's — which is the whole reason
      // D13 says to read it rather than derive one.
      expect(rules.className(14), 'Cleric / Mage');
      expect(rules.className(8), 'Fighter / Cleric');
    });

    test('both tokens at once', () {
      expect(rules.className(7), 'Fighter / Mage');
    });

    test('an unknown token is refused, not shown', () {
      // A name still carrying angle brackets after substitution is one the
      // engine would have filled in and we cannot. Showing it is worse than
      // falling back to the identifier, which at least reads as English.
      const odd = GeneratedGameRules(
        tables: NameTables(classNames: {2: '<SOMETHINGNEW>'}),
      );

      expect(odd.className(2), 'Fighter');
    });
  });
}
