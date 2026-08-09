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
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/data/services/portrait_import_service.dart';

import '../../support/synthetic_save.dart';

void main() {
  late Directory temp;
  late Directory saveRoot;
  late Directory portraitRoot;
  late PortraitImportService importer;

  Uint8List bitmap() {
    final bytes = Uint8List(64);
    bytes[0] = 0x42;
    bytes[1] = 0x4d;
    return bytes;
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('wand_portrait_');
    saveRoot = Directory('${temp.path}${Platform.pathSeparator}save');
    portraitRoot = Directory('${temp.path}${Platform.pathSeparator}portraits');
    writeSaveSlot(saveRoot, '000000001-a');
    importer = PortraitImportService(
      profile: GameProfileService(
        saveCandidates: [saveRoot.path],
        environment: const {},
      ),
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  group('checking a name', () {
    test('accepts an ordinary one', () {
      expect(importer.nameProblem('MYCHAR'), isNull);
    });

    test('refuses one too long to carry a variant letter', () {
      // ⚠️ Seven, not eight: the L/M/S suffix has to fit an 8-byte resref.
      // This is the *only* hard rule an imported portrait has to meet.
      expect(importer.nameProblem('TOOLONGX'), contains('seven'));
    });

    test('refuses an empty one', () {
      expect(importer.nameProblem('  '), isNotNull);
    });

    test('refuses one that is really a path', () {
      expect(importer.nameProblem('../escape'), isNotNull);
    });

    test('refuses a name already taken, rather than overwriting it', () {
      // The player's own portraits are theirs. Nothing in this app overwrites
      // a file it did not just read.
      portraitRoot.createSync(recursive: true);
      File(
        '${portraitRoot.path}${Platform.pathSeparator}MYCHARM.bmp',
      ).writeAsBytesSync(bitmap());

      expect(importer.nameProblem('MYCHAR'), contains('already'));
    });
  });

  group('adding one', () {
    test('writes both variants, so both resrefs resolve', () async {
      // ⚠️ A CRE names two portraits — the M the sheet shows and the L — and
      // a character whose L does not resolve is one the game draws
      // inconsistently. One imported file serves both, which is the engine's
      // own tolerance for off-size portraits put to use.
      await importer.add(baseName: 'MYCHAR', bytes: bitmap());

      expect(
        File(
          '${portraitRoot.path}${Platform.pathSeparator}MYCHARM.bmp',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '${portraitRoot.path}${Platform.pathSeparator}MYCHARL.bmp',
        ).existsSync(),
        isTrue,
      );
    });

    test('makes the portraits folder when there is none', () async {
      // Present and empty on the developer's machine; absent on a player who
      // has never added one.
      expect(portraitRoot.existsSync(), isFalse);

      await importer.add(baseName: 'MYCHAR', bytes: bitmap());

      expect(portraitRoot.existsSync(), isTrue);
    });

    test('copies the bytes untouched — nothing is converted', () async {
      // No encoder, no resample. What is missing is named precisely so the
      // player can fix it in any image editor.
      final original = bitmap()..[10] = 0x36;

      await importer.add(baseName: 'MYCHAR', bytes: original);

      expect(
        File(
          '${portraitRoot.path}${Platform.pathSeparator}MYCHARM.bmp',
        ).readAsBytesSync(),
        original,
      );
    });

    test('upper-cases the name, as every resref in the game is', () async {
      await importer.add(baseName: 'mychar', bytes: bitmap());

      expect(
        File(
          '${portraitRoot.path}${Platform.pathSeparator}MYCHARM.bmp',
        ).existsSync(),
        isTrue,
      );
    });

    test('refuses a name it would have complained about', () async {
      await expectLater(
        importer.add(baseName: 'TOOLONGX', bytes: bitmap()),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
