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

/// What `CHARBASE` — the engine's own seed — actually holds.
///
/// ⚠️ **Every character this application creates starts as a copy of this
/// record**, so a field it ships wrong is a field wrong in every one of them.
/// D14 found two legal values that make a character unplayable, and both live
/// here: `moraleBreak` at or above `morale` panics them permanently, and any
/// `intoxication` above zero disables EXPORT. Neither is out of range and
/// neither would fail to load.
///
/// Reads the player's installation and skips where there is none, the
/// convention `creation_golden_test.dart` already follows.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';

void main() {
  const profile = GameProfileService();
  final installed = profile.findGameDirectory() != null;
  const why = 'no Baldur’s Gate installation';

  final resources = ResourceRepository(profile);
  late Cre template;

  setUpAll(() async {
    final bytes = await resources.creature(characterTemplate);
    if (bytes != null) {
      template = CreCodec.decode(bytes, source: characterTemplate);
    }
  });

  group('the template is playable as it ships', () {
    test(
      'moraleBreak is below morale, so a new character does not panic',
      () {
        final morale = template.readField(CreHeaderField.morale);
        final moraleBreak = template.readField(CreHeaderField.moraleBreak);

        expect(
          moraleBreak,
          lessThan(morale),
          reason:
              'a character whose morale break reaches their morale panics '
              'permanently — no commands, no save, no export',
        );
      },
      skip: installed ? false : why,
    );

    test(
      'intoxication is zero, so EXPORT stays available',
      () {
        expect(template.readField(CreHeaderField.intoxication), 0);
      },
      skip: installed ? false : why,
    );
  });

  group('what the template does NOT carry, which creation has to add', () {
    test(
      'no effects, no known spells, no memorisation rows',
      () {
        // The three sections a created character builds from nothing, and the
        // reason `GrantProficiency`, `LearnSpell` and `MemoriseSpell` each
        // create their section rather than appending to one.
        expect(template.effectsCount, 0);
        expect(template.knownSpellsCount, 0);
        expect(template.memorizationInfoCount, 0);
      },
      skip: installed ? false : why,
    );

    test(
      'effectVersion is 0 — 48-byte effects, not the 264-byte kind',
      () {
        // ⚠️ The defect that shipped: a proficiency is a v2 record, and
        // granting one to a template claiming v1 was refused outright.
        expect(template.readField(CreHeaderField.effectVersion), 0);
      },
      skip: installed ? false : why,
    );
  });
}
