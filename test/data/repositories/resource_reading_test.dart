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

/// Reading the player's installation — the path that had no test at all.
///
/// Every other `ResourceRepository` test exercises the pure parsing functions
/// and stops at the file boundary. That left the index and archive caches
/// covered by nothing, and a race in them lost two portraits out of three on
/// the home screen.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';

import '../../support/synthetic_installation.dart';
import '../../support/synthetic_save.dart';

void main() {
  late Directory temp;
  late Directory game;
  late Directory saveRoot;

  Uint8List picture(int marker) =>
      Uint8List.fromList([0x42, 0x4d, marker, 0, 0, 0]);

  ResourceRepository repositoryOver(List<SyntheticResource> resources) {
    writeInstallation(game, resources);
    return ResourceRepository(
      GameProfileService(
        gameCandidates: [game.path],
        saveCandidates: [saveRoot.path],
        environment: const {},
      ),
    );
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('wand_resource_');
    game = Directory('${temp.path}${Platform.pathSeparator}game');
    saveRoot = Directory('${temp.path}${Platform.pathSeparator}save');
    writeSaveSlot(saveRoot, '000000001-a');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  group('reading a portrait', () {
    test('finds one the key file names', () async {
      final repository = repositoryOver([
        (resref: 'AJANTISM', type: ResourceType.bitmap, bytes: picture(1)),
      ]);

      expect(await repository.portrait('AJANTISM'), picture(1));
    });

    test('answers null for one it does not', () async {
      final repository = repositoryOver([
        (resref: 'AJANTISM', type: ResourceType.bitmap, bytes: picture(1)),
      ]);

      expect(await repository.portrait('NOBODYM'), isNull);
    });

    test('⚠️ answers every one of several asked for at once', () async {
      // **The bug this file exists for.** The home screen draws three
      // character cards, so it asks for three portraits in the same turn. The
      // index cache set its "already read" flag *before* awaiting the file, so
      // the two callers that arrived while the first was still reading were
      // told the index was ready and handed `null`.
      //
      // On screen: one picture and two blanks, which looks like a decoding
      // problem rather than a caching one.
      final repository = repositoryOver([
        (resref: 'ONEM', type: ResourceType.bitmap, bytes: picture(1)),
        (resref: 'TWOM', type: ResourceType.bitmap, bytes: picture(2)),
        (resref: 'THREEM', type: ResourceType.bitmap, bytes: picture(3)),
      ]);

      final all = await Future.wait([
        repository.portrait('ONEM'),
        repository.portrait('TWOM'),
        repository.portrait('THREEM'),
      ]);

      expect(all, [picture(1), picture(2), picture(3)]);
    });

    test('answers the same after the first read as during it', () async {
      final repository = repositoryOver([
        (resref: 'ONEM', type: ResourceType.bitmap, bytes: picture(1)),
      ]);

      final during = await Future.wait([
        repository.portrait('ONEM'),
        repository.portrait('ONEM'),
      ]);
      final after = await repository.portrait('ONEM');

      expect(during, [picture(1), picture(1)]);
      expect(after, picture(1));
    });
  });

  group('reading other resources through the same index', () {
    test('a creature and a table come back too', () async {
      // One lookup path for every kind of resource, so the caches are in one
      // place rather than once per caller.
      final repository = repositoryOver([
        (resref: 'CHARBASE', type: ResourceType.creature, bytes: picture(9)),
        (
          resref: 'THIEFSCL',
          type: ResourceType.table2da,
          bytes: '2DA V1.0\n0\n'.codeUnits,
        ),
      ]);

      expect(await repository.creature(characterTemplate), picture(9));
      expect(await repository.thiefSkills(), isNotNull);
    });

    test('a creature is looked up as 0x03f1, not 0x03f9', () async {
      // ⚠️ The type code was `0x03f9`, which is `.bs`. It never threw — it
      // answered null forever, which is the quiet kind of wrong.
      final repository = repositoryOver([
        (resref: 'CHARBASE', type: ResourceType.creature, bytes: picture(9)),
      ]);

      expect(ResourceType.creature.code, 0x03f1);
      expect(await repository.creature('CHARBASE'), isNotNull);
    });
  });

  group('listing the spells a wizard may learn', () {
    /// An `SPL V1` header with the five fields the listing reads.
    List<int> spell({
      required int level,
      int type = 1,
      int nameStrref = 26344,
    }) {
      final out = Uint8List(splHeaderLength)
        ..setRange(0, 4, 'SPL '.codeUnits)
        ..setRange(4, 8, 'V1  '.codeUnits);
      ByteData.sublistView(out)
        ..setInt32(SplHeaderField.name.offset, nameStrref, Endian.little)
        ..setUint16(SplHeaderField.spellType.offset, type, Endian.little)
        ..setUint32(SplHeaderField.level.offset, level, Endian.little)
        ..setInt32(SplHeaderField.description.offset, 26345, Endian.little);
      return out;
    }

    test('takes the first-level ones and leaves the rest', () async {
      final repository = repositoryOver([
        (resref: 'SPWI101', type: ResourceType.spell, bytes: spell(level: 1)),
        (resref: 'SPWI112', type: ResourceType.spell, bytes: spell(level: 1)),
        (resref: 'SPWI201', type: ResourceType.spell, bytes: spell(level: 2)),
      ]);

      final spells = await repository.wizardSpells(level: 1);

      expect(spells.map((s) => s.resref), ['SPWI101', 'SPWI112']);
      expect(spells.first.nameStrref, 26344);
      expect(spells.first.descriptionStrref, 26345);
    });

    test('⚠️ drops a header claiming a level its name does not', () async {
      // The filter no one would think to write. `SPWI989` and `SPWI998` are
      // named, are typed wizard, and say **level 1** — and are not first-level
      // spells. Where the resref's digit and the header disagree, the resource
      // is not what it looks like.
      final repository = repositoryOver([
        (resref: 'SPWI101', type: ResourceType.spell, bytes: spell(level: 1)),
        (resref: 'SPWI989', type: ResourceType.spell, bytes: spell(level: 1)),
        (resref: 'SPWI003', type: ResourceType.spell, bytes: spell(level: 1)),
      ]);

      expect(
        (await repository.wizardSpells(level: 1)).map((s) => s.resref),
        ['SPWI101'],
      );
    });

    test('⚠️ drops the engine’s own plumbing, which carries no name', () async {
      // Eighty-six of the installation's 108 first-level-wizard headers do.
      final repository = repositoryOver([
        (resref: 'SPWI101', type: ResourceType.spell, bytes: spell(level: 1)),
        (
          resref: 'SPWI151',
          type: ResourceType.spell,
          bytes: spell(level: 1, nameStrref: -1),
        ),
      ]);

      expect(
        (await repository.wizardSpells(level: 1)).map((s) => s.resref),
        ['SPWI101'],
      );
    });

    test('drops a priest spell that happens to be named SPWI1nn', () async {
      final repository = repositoryOver([
        (
          resref: 'SPWI105',
          type: ResourceType.spell,
          bytes: spell(level: 1, type: 2),
        ),
      ]);

      expect(await repository.wizardSpells(level: 1), isEmpty);
    });

    test('drops a sub-spell, whose resref carries a letter', () async {
      // `SPWI119A` and `spwi117a` are real, and are not entries in a book.
      final repository = repositoryOver([
        (resref: 'SPWI119A', type: ResourceType.spell, bytes: spell(level: 1)),
      ]);

      expect(await repository.wizardSpells(level: 1), isEmpty);
    });

    test('a resource that will not parse costs that spell, not the list', () {
      final repository = repositoryOver([
        (resref: 'SPWI101', type: ResourceType.spell, bytes: spell(level: 1)),
        (resref: 'SPWI102', type: ResourceType.spell, bytes: const [1, 2, 3]),
      ]);

      expect(
        repository.wizardSpells(level: 1).then((s) => s.length),
        completion(1),
      );
    });
  });

  group('with no installation at all', () {
    test('answers null rather than failing', () async {
      // The app opens saves on machines with no game on them.
      final repository = ResourceRepository(
        const GameProfileService(gameCandidates: [], environment: {}),
      );

      expect(await repository.portrait('AJANTISM'), isNull);
      expect(await repository.creature(characterTemplate), isNull);
      expect(await repository.portraitNames(), isEmpty);
      expect(await repository.wizardSpells(level: 1), isEmpty);
    });
  });
}
