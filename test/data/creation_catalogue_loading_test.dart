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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/creation_catalogue_loading.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';

import '../support/fakes.dart';
import '../support/synthetic_installation.dart';

void main() {
  const rules = GeneratedGameRules();
  late Directory temp;
  late Directory game;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('wand_creation_');
    game = Directory('${temp.path}${Platform.pathSeparator}game');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  ResourceRepository installWith(Map<String, String> tables) {
    writeInstallation(game, [
      for (final MapEntry(key: resref, value: text) in tables.entries)
        (resref: resref, type: ResourceType.table2da, bytes: text.codeUnits),
    ]);
    return ResourceRepository(
      GameProfileService(gameCandidates: [game.path], environment: const {}),
    );
  }

  // Just enough of the six tables to name one race, one class and one kit.
  final tables = <String, String>{
    'CLSRCREQ':
        '2DA V1.0\n0\n     HUMAN  ELF\nFIGHTER  1     1\nRANGER   1  1\n',
    'ALIGNMNT': '2DA V1.0\n0\n     L_G  L_N\nFIGHTER  1    1\nRANGER   1  0\n',
    'KITLIST':
        '2DA V1.0\n*\n'
        '    ROWNAME  MIXED  HELP   CLASS  KITIDS\n'
        '7   FERALAN  25335  24298  12     0x00004007\n',
    'CLASTEXT':
        '2DA V1.0\n-1\n'
        '        CLASSID  KITID  DESCSTR\n'
        'FIGHTER 2        16384  9556\n'
        'RANGER  12       16384  9557\n',
    'RACETEXT': '2DA V1.0\n-1\n     ID  DESCSTR\nELF  2   9552\n',
    'ABRACEAD': '2DA V1.0\n0\n     MOD_DEX\nELF  1\n',
    // ⚠️ **Carries a name strref, which is the point.** The row label
    // `FLAILMORNINGSTAR` is not a name — the game writes "Flail/Morning Star"
    // — so a fixture without this table cannot notice the loader failing to
    // resolve it.
    'WEAPPROF':
        '2DA V1.0\n0\n'
        '                  ID   NAME_REF  DESC_REF  FIGHTER\n'
        'FLAILMORNINGSTAR  100  25012     25036     5\n',
  };

  group('resolving the text', () {
    test('names a specialisation the label could never have named', () async {
      // ⚠️ FERALAN is displayed as "Archer". Nothing but the talk table
      // says so.
      final catalogue = await loadCreationCatalogue(
        resources: installWith(tables),
        strings: FakeStringRepository(const {
          25335: 'Archer',
          24298: 'ARCHER: The epitome of skill with the bow.',
        }),
        rules: rules,
      );

      final archer = catalogue.kitsFor(12).single;
      expect(catalogue.textFor(archer.nameStrref), 'Archer');
      expect(
        catalogue.textFor(archer.descriptionStrref),
        startsWith('ARCHER:'),
      );
    });

    test('asks the talk table for the alignment names too', () async {
      // ⚠️ **The gap that would have shipped the fix invisibly.** The
      // alignment names became a talk-table lookup so the screen could say
      // "True Neutral" the way the engine does — but this loader only ever
      // asked for the strrefs carried by races, classes, kits and spells, so
      // the nine alignment strings were never fetched and every name fell back
      // to the derived one. The unit test passed because it handed the text
      // over itself; nothing asked the loader to go and get it.
      final catalogue = await loadCreationCatalogue(
        resources: installWith(tables),
        strings: FakeStringRepository(const {
          1102: 'Lawful Good',
          1106: 'True Neutral',
          1110: 'Chaotic Evil',
          9606: 'NEUTRAL GOOD: These characters believe…',
        }),
        rules: rules,
      );

      expect(catalogue.alignmentName(0x11), 'Lawful Good');
      expect(catalogue.alignmentName(0x22), 'True Neutral');
      expect(catalogue.alignmentName(0x33), 'Chaotic Evil');
      // The descriptions are the same trap twice: a strref no row carries, so
      // nothing asks for it unless this loader is told to.
      expect(
        catalogue.textFor(catalogue.alignmentChoice(0x21).descriptionStrref),
        startsWith('NEUTRAL GOOD:'),
      );
    });

    test('carries the race and class descriptions the game prints', () async {
      final catalogue = await loadCreationCatalogue(
        resources: installWith(tables),
        strings: FakeStringRepository(const {
          9552: 'ELVES: Elves tend to be shorter and slimmer than humans.',
          9556: 'FIGHTER: The Fighter is a champion.',
        }),
        rules: rules,
      );

      final elf = catalogue.races.singleWhere((r) => r.value == 2);
      final fighter = catalogue
          .classesFor(2)
          .singleWhere((c) => c.identifier == 'FIGHTER');

      expect(catalogue.textFor(elf.descriptionStrref), startsWith('ELVES:'));
      expect(
        catalogue.textFor(fighter.descriptionStrref),
        contains('champion'),
      );
    });

    test('asks for every strref the catalogue carries', () async {
      // ⚠️ **The same defect three times in one afternoon**, so it is worth a
      // test that catches the fourth. This `wanted` set is hand-maintained,
      // and every strref-bearing thing added to the catalogue has to remember
      // to join it. When one does not, nothing fails: `textFor` answers null
      // and the caller quietly falls back — to a derived name, or to the
      // table's row label.
      //
      // It shipped as `NEUTRAL` where the game says "True Neutral", as no
      // alignment description at all, and as **FLAILMORNINGSTAR** where the
      // game writes "Flail/Morning Star" — a row label has no spaces or
      // punctuation, which is what makes the fallback so recognisable on
      // screen.
      final strings = FakeStringRepository();
      final catalogue = await loadCreationCatalogue(
        resources: installWith(tables),
        strings: strings,
        rules: rules,
      );

      final carried = <int>{
        for (final choice in [
          ...catalogue.races,
          ...catalogue.classesByRace.values.expand((c) => c),
          ...catalogue.kitsByClass.values.expand((k) => k),
        ]) ...[
          if (choice.nameStrref case final int s) s,
          if (choice.descriptionStrref case final int s) s,
        ],
        for (final spell in catalogue.wizardSpells) ...[
          if (spell.nameStrref case final int s) s,
          if (spell.descriptionStrref case final int s) s,
        ],
        for (final entry in catalogue.proficiencies.entries.values)
          if (entry.nameStrref case final int s) s,
        ...alignmentNameStrrefs.values,
        ...alignmentDescriptionStrrefs.values,
      };

      expect(
        carried.difference(strings.lookups.toSet()),
        isEmpty,
        reason: 'these strrefs are on the catalogue and were never resolved',
      );
    });

    test('a strref the talk table does not have simply has no text', () async {
      final catalogue = await loadCreationCatalogue(
        resources: installWith(tables),
        strings: FakeStringRepository(),
        rules: rules,
      );

      expect(catalogue.textFor(9552), isNull);
      expect(catalogue.textFor(null), isNull);
    });

    test(
      'asks the talk table for each strref once, not once per use',
      () async {
        final strings = FakeStringRepository(const {25335: 'Archer'});

        await loadCreationCatalogue(
          resources: installWith(tables),
          strings: strings,
          rules: rules,
        );

        expect(
          strings.lookups.length,
          strings.lookups.toSet().length,
          reason: 'every strref should be looked up exactly once',
        );
      },
    );
  });

  group('with no installation', () {
    test('answers an empty catalogue rather than throwing', () async {
      final catalogue = await loadCreationCatalogue(
        resources: ResourceRepository(
          const GameProfileService(gameCandidates: []),
        ),
        strings: FakeStringRepository(),
        rules: rules,
      );

      expect(catalogue.races, isEmpty);
    });
  });
}
