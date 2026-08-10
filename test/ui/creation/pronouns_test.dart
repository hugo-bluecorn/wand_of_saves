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
import 'package:wand_of_saves/ui/creation/pronouns.dart';

void main() {
  // The real thing, copied out of the player's `clastext.2da` (strref 9556).
  const fighter =
      'FIGHTER: The Fighter is a champion, swords<PRO_MANWOMAN>, soldier, '
      'and brawler who lives or dies by <PRO_HISHER> knowledge of weapons.';

  group('the tokens the engine leaves in its own text', () {
    test('read as a man for a male character', () {
      final text = substituteTokens(fighter, genderId: 1);

      expect(text, contains('swordsman'));
      expect(text, contains('by his knowledge'));
      expect(text, isNot(contains('<')));
    });

    test('read as a woman for a female character', () {
      final text = substituteTokens(fighter, genderId: 2);

      expect(text, contains('swordswoman'));
      expect(text, contains('by her knowledge'));
    });

    test('fall back to the masculine when gender is not yet chosen', () {
      // Unanswered is not "female". The flow asks gender first precisely so
      // this case is rare, but a description drawn before an answer must still
      // be a sentence rather than markup.
      final text = substituteTokens(fighter, genderId: null);

      expect(text, contains('swordsman'));
      expect(text, isNot(contains('<PRO_')));
    });

    test('replace the name only when there is one', () {
      const bio = 'They call <CHARNAME> a hero.';

      expect(
        substituteTokens(bio, genderId: 1, name: 'Aurel'),
        'They call Aurel a hero.',
      );
      expect(substituteTokens(bio, genderId: 1), contains('<CHARNAME>'));
    });

    test('leave a token this build does not know alone', () {
      // ⚠️ Deleting an unknown token would drop a word out of the middle of a
      // sentence and nobody would ever see that it had happened.
      expect(
        substituteTokens('A <PRO_NOTATHING> thing', genderId: 1),
        'A <PRO_NOTATHING> thing',
      );
    });

    test('leave text with no tokens untouched', () {
      expect(substituteTokens('Plain text.', genderId: 2), 'Plain text.');
    });
  });
}
