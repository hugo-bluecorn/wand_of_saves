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

/// Class names, read from the player's own installation end to end.
///
/// ⚠️ **This is the test that would have caught it.** The class-selection
/// screen shipped reading `<FIGHTERTYPE>`, `<MAGESCHOOL>` and `Fallen Cleric`,
/// and every unit test passed — because each of them supplied a *name* where
/// the real table supplies a **template** and a duplicate row. Nothing but the
/// installation itself has that shape.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';

void main() {
  const profile = GameProfileService();
  final installed = profile.findGameDirectory() != null;
  const why = 'no Baldur’s Gate installation';

  late GameRules rules;

  setUpAll(() async {
    final container = ProviderContainer.test();
    await container.read(nameTablesProvider.future);
    rules = container.read(gameRulesProvider);
  });

  test(
    'every playable class reads as a name a player would recognise',
    () {
      // The nine a gnome may choose, which is the screen the defect was on.
      const expected = {
        1: 'Mage',
        2: 'Fighter',
        3: 'Cleric',
        4: 'Thief',
        7: 'Fighter / Mage',
        8: 'Fighter / Cleric',
        9: 'Fighter / Thief',
        13: 'Mage / Thief',
        14: 'Cleric / Mage',
      };

      for (final MapEntry(key: id, value: name) in expected.entries) {
        expect(rules.className(id), name, reason: 'class $id');
      }
    },
    skip: installed ? false : why,
  );

  test(
    'no class name carries a token the engine would have filled in',
    () {
      // ⚠️ The general form of the defect. A future table gaining a token this
      // does not know about fails here rather than on screen.
      for (var id = 0; id < 256; id++) {
        final name = rules.className(id);
        if (name == null) continue;
        expect(name, isNot(contains('<')), reason: 'class $id');
      }
    },
    skip: installed ? false : why,
  );

  test('races and specialisations carry real names too', () {
    // Checked because the class defect raised the question, not because
    // anything was wrong: `racetext.2da` and `kitlist.2da` hold finished
    // strings. ⚠️ And `kitlist` is where `FERALAN` reads **Archer**, which no
    // amount of title-casing an identifier reaches.
    expect(rules.raceName(4), 'Dwarf');
    expect(rules.raceName(5), 'Halfling');
    expect(rules.raceName(6), 'Gnome');
    expect(rules.raceName(7), 'Half-Orc');

    for (var id = 0; id < 256; id++) {
      final name = rules.raceName(id);
      if (name == null) continue;
      expect(name, isNot(contains('<')), reason: 'race $id');
    }
  }, skip: installed ? false : why);

  test('no class is named after its fallen twin', () {
    // `FALLEN_CLERIC` and `FALLEN_RANGER` share their class's id and its
    // "no kit" marker, and sit *later* in the file — so the last-wins map put
    // them on screen.
    for (var id = 0; id < 256; id++) {
      final name = rules.className(id);
      if (name == null) continue;
      expect(name.toLowerCase(), isNot(startsWith('fallen')), reason: '$id');
    }
  }, skip: installed ? false : why);
}
