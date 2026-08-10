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
