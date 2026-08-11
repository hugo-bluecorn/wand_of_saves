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

/// What the spell step shows beside the list.
///
/// ⚠️ **The description was read and resolved all along and simply never
/// drawn** — the step had two lists and no detail panel, where the engine shows
/// one. See `docs/findings/screens/char-create/21-mage-book-spell-detail.png`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/ui/creation/creation_viewmodel.dart';

void main() {
  const burningHands = SpellChoice(
    resref: 'SPWI103',
    school: 8,
    nameStrref: 25001,
    descriptionStrref: 26091,
  );

  // Abridged, but the shape is the game's own: name, school, the stat block
  // and the prose all arrive as **one** string.
  const description =
      'Burning Hands\n(Alteration)\n\nLevel: 1\nRange: 0\n\n'
      'a jet of searing flame shoots from <PRO_HISHER> fingertips.';

  CreationState stateFor({int? genderId}) => CreationState(
    catalogue: const CreationCatalogue(
      races: [],
      classesByRace: {},
      kitsByClass: {},
      alignmentsByRow: {},
      adjustmentsByRace: {},
      wizardSpells: [burningHands],
    ).withText(const {26091: description}),
    genderId: genderId,
  );

  group('the spell description', () {
    test('is the game’s whole panel, not a name', () {
      final text = stateFor(genderId: 1).spellDescription('SPWI103');

      expect(text, contains('(Alteration)'));
      expect(text, contains('Level: 1'));
      expect(text, contains('searing flame'));
    });

    test('resolves the pronoun tokens it carries', () {
      // ⚠️ Drawing this unsubstituted prints markup at the player — the same
      // trap the class descriptions already pay for.
      expect(
        stateFor(genderId: 1).spellDescription('SPWI103'),
        contains('from his fingertips'),
      );
      expect(
        stateFor(genderId: 2).spellDescription('SPWI103'),
        contains('from her fingertips'),
      );
    });

    test('has nothing to say about a spell it does not know', () {
      expect(stateFor(genderId: 1).spellDescription('SPWI999'), isNull);
    });
  });
}
