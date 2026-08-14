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
import 'package:wand_of_saves/domain/item_catalogue.dart';

/// ⚠️ Shaped like the installation, not tidied. `BOOT01` and `TROLLBOO` share
/// an identified name; `MISC01` has only an unidentified one; `GHOST` resolves
/// to empty text, which is the five-item second stage of the filter.
ItemCatalogue catalogue() => const ItemCatalogue({
  'BOOT01': ItemEntry(
    resref: 'BOOT01',
    itemType: 4,
    identifiedName: 'The Paws of the Cheetah',
    unidentifiedName: 'Boots',
    description:
        'These are the fabled Boots of Speed, which double the '
        'wearer’s movement.',
  ),
  'TROLLBOO': ItemEntry(
    resref: 'TROLLBOO',
    itemType: 4,
    identifiedName: 'The Paws of the Cheetah',
    unidentifiedName: 'Boots',
  ),
  'MISC01': ItemEntry(
    resref: 'MISC01',
    itemType: 0,
    unidentifiedName: 'A rock',
  ),
  'GHOST': ItemEntry(
    resref: 'GHOST',
    itemType: 0,
    identifiedName: '',
    unidentifiedName: '',
  ),
  'AROW01': ItemEntry(
    resref: 'AROW01',
    itemType: 5,
    identifiedName: 'Arrow',
    description: 'A standard arrow, of no particular speed.',
  ),
});

void main() {
  group('ItemEntry', () {
    test('labels itself with the identified name when it has one', () {
      expect(catalogue().entries['BOOT01']!.label, 'The Paws of the Cheetah');
    });

    test('falls back to the unidentified name', () {
      expect(catalogue().entries['MISC01']!.label, 'A rock');
    });

    test('⚠️ is not offerable when its names resolve to empty text', () {
      // The second stage of the filter. `Itm.hasName` cannot see this — a
      // strref is present, it just points at nothing — so it is caught here,
      // above the repository, which is the only layer holding the talk table.
      expect(catalogue().entries['GHOST']!.isOfferable, isFalse);
      expect(catalogue().entries['BOOT01']!.isOfferable, isTrue);
    });

    test('falls back to the resref rather than showing nothing', () {
      const bare = ItemEntry(resref: 'XYZZY', itemType: 0);
      expect(bare.label, 'XYZZY');
    });
  });

  group('ItemCatalogue.offerable', () {
    test('drops the nameless and sorts by what a reader sees', () {
      final labels = catalogue().offerable.map((e) => e.label).toList();
      expect(labels, isNot(contains('GHOST')));
      expect(labels, [
        'A rock',
        'Arrow',
        'The Paws of the Cheetah',
        'The Paws of the Cheetah',
      ]);
    });
  });

  group('ItemCatalogue.search', () {
    test('⚠️ "Boots of Speed" is found by DESCRIPTION, not by name', () {
      // The ask, exactly. BG:EE has no item called this; the phrase is in
      // BOOT01's own description text.
      final found = catalogue().search('boots of speed').results;
      expect(found, hasLength(1));
      expect(found.single.entry.resref, 'BOOT01');
      expect(
        found.single.how,
        ItemMatch.description,
        reason: 'it must be labelled as a description match, not a name one',
      );
    });

    test('an exact resref ranks first', () {
      final found = catalogue().search('BOOT01').results;
      expect(found.first.entry.resref, 'BOOT01');
      expect(found.first.how, ItemMatch.resref);
    });

    test('searches BOTH names', () {
      // Ten of the fourteen "boot" items are called simply "Boots" when
      // unidentified, which is what a player who has not identified one sees.
      final found = catalogue().search('boots').results;
      expect(
        found.map((f) => f.entry.resref),
        containsAll(<String>['BOOT01', 'TROLLBOO']),
      );
      expect(found.every((f) => f.how == ItemMatch.name), isTrue);
    });

    test('⚠️ description matches sort AFTER name matches', () {
      // "speed" hits 238 descriptions in the real installation. Mixing them
      // into the name results is what makes the tier labelling necessary.
      final found = catalogue().search('speed').results;
      expect(found.map((f) => f.how).toList(), [
        ItemMatch.description,
        ItemMatch.description,
      ]);
    });

    test('never returns the unofferable', () {
      expect(catalogue().search('ghost').results, isEmpty);
    });

    test('an empty query returns nothing rather than everything', () {
      expect(catalogue().search('   ').results, isEmpty);
    });
  });

  group('⚠️ items the engine will never let go of', () {
    // The defect that prompted this: BOW99 could be added to a character and
    // then neither equipped nor moved, because its own ITM header has the
    // Movable bit clear. 432 of the installation's 1,428 named items are like
    // that, and searching "attack" returned sixty of them and nothing else.
    ItemCatalogue stuckAnd(ItemEntry offered) => ItemCatalogue({
      offered.resref: offered,
      'BOW99': const ItemEntry(
        resref: 'BOW99',
        itemType: 15,
        identifiedName: 'Protector of the Dryads +2',
        unidentifiedName: 'Shortbow',
        isMovable: false,
      ),
    });

    test('an immovable item never appears, at any match tier', () {
      final catalogue = stuckAnd(
        const ItemEntry(
          resref: 'BOW05',
          itemType: 15,
          identifiedName: 'Shortbow',
        ),
      );

      // By resref, by name, and by the unidentified name.
      expect(catalogue.search('BOW99').results, isEmpty);
      expect(
        catalogue.search('protector').results,
        isEmpty,
        reason: 'the identified name must not smuggle it in',
      );
      expect(
        catalogue.search('shortbow').results.map((f) => f.entry.resref),
        ['BOW05'],
        reason: 'the movable twin survives, sharing its name',
      );
    });

    test('withheld counts exactly what was hidden', () {
      final catalogue = stuckAnd(
        const ItemEntry(
          resref: 'BOW05',
          itemType: 15,
          identifiedName: 'Shortbow',
        ),
      );
      expect(catalogue.search('shortbow').withheld, 1);
      expect(catalogue.search('BOW05').withheld, 0, reason: 'nothing hidden');
      expect(catalogue.search('nothing at all').withheld, 0);
    });

    test('⚠️ a CURSED item is offered, because cursed is not stuck', () {
      // IESDP bit 4 means "cannot be UNequipped" — the item moves perfectly
      // well until somebody wears it, and the game's own shops sell them.
      // Refusing it would be this application overruling the player.
      const catalogue = ItemCatalogue({
        'RING06': ItemEntry(
          resref: 'RING06',
          itemType: 10,
          identifiedName: 'Ring of Clumsiness',
          isCursed: true,
        ),
      });

      final found = catalogue.search('clumsiness').results;
      expect(found.single.entry.resref, 'RING06');
      expect(found.single.entry.isCursed, isTrue);
      expect(catalogue.search('clumsiness').withheld, 0);
    });

    test('offerable still answers the naming question, unchanged', () {
      // ⚠️ Two different filters. `isOfferable` asks "does this name a string";
      // withholding asks "can the game move it". Folding them together would
      // lose the two-stage filter the catalogue documents.
      final catalogue = stuckAnd(
        const ItemEntry(
          resref: 'BOW05',
          itemType: 15,
          identifiedName: 'Shortbow',
        ),
      );
      expect(
        catalogue.offerable.map((e) => e.resref),
        containsAll(<String>['BOW05', 'BOW99']),
      );
    });
  });

  group('ItemEntry.nameWhen', () {
    // ⚠️ **The rule about what the ENGINE draws, so it lives in the domain.**
    // Two surfaces need it — the backpack cell and the equipped row — and a
    // copy in each is how they drift apart, which is the defect being fixed.
    const both = ItemEntry(
      resref: 'BELT16',
      itemType: 8,
      identifiedName: 'Belt of Antipode',
      unidentifiedName: 'Belt',
    );

    test('identified draws its name, unidentified draws the plain one', () {
      expect(both.nameWhen(identified: true), 'Belt of Antipode');
      expect(
        both.nameWhen(identified: false),
        'Belt',
        reason: 'the engine shows "Belt" with the flag clear',
      );
    });

    test('each falls back to the other when its own is missing', () {
      const identifiedOnly = ItemEntry(
        resref: 'RING01',
        itemType: 10,
        identifiedName: 'Ring of Protection +1',
      );
      const unidentifiedOnly = ItemEntry(
        resref: 'MISC01',
        itemType: 0,
        unidentifiedName: 'A rock',
      );

      expect(
        identifiedOnly.nameWhen(identified: false),
        'Ring of Protection +1',
        reason: 'better the wrong register than no name at all',
      );
      expect(unidentifiedOnly.nameWhen(identified: true), 'A rock');
    });

    test('answers null when it knows no name, rather than inventing one', () {
      const nameless = ItemEntry(resref: 'GHOST1', itemType: 0);
      expect(nameless.nameWhen(identified: true), isNull);
      expect(nameless.nameWhen(identified: false), isNull);
    });
  });
}
