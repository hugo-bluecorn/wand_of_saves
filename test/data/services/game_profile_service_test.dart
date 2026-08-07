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
import 'package:wand_of_saves/data/services/game_profile_service.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('wos_profile'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String makeDir(String name) => (Directory(
    '${tmp.path}${Platform.pathSeparator}$name',
  )..createSync(recursive: true)).path;

  void touch(String dir, String file) =>
      File('$dir${Platform.pathSeparator}$file').writeAsStringSync('x');

  group('findGameDirectory', () {
    test('is null when no candidate exists', () {
      const service = GameProfileService(
        gameCandidates: ['/definitely/not/here'],
      );

      expect(service.findGameDirectory(), isNull);
    });

    test('is null when a candidate exists but holds no chitin.key', () {
      // A directory named like the game is not the game. The marker file is
      // what makes it one.
      final decoy = makeDir('looks-like-the-game');
      final service = GameProfileService(gameCandidates: [decoy]);

      expect(service.findGameDirectory(), isNull);
    });

    test('returns the first candidate holding chitin.key', () {
      final wrong = makeDir('wrong');
      final right = makeDir('right')..let((d) => touch(d, 'chitin.key'));
      final service = GameProfileService(gameCandidates: [wrong, right]);

      expect(service.findGameDirectory(), right);
    });

    test('an environment override wins over the candidates', () {
      final candidate = makeDir('candidate')
        ..let((d) => touch(d, 'chitin.key'));
      final override = makeDir('override')..let((d) => touch(d, 'chitin.key'));
      final service = GameProfileService(
        gameCandidates: [candidate],
        environment: {GameProfileService.gameDirVariable: override},
      );

      expect(service.findGameDirectory(), override);
    });

    test('an invalid environment override yields null, not a fallback', () {
      // Falling back silently would hide the user's mistake: they said where
      // the game is, and they were wrong. Better to find nothing and say so.
      final candidate = makeDir('candidate')
        ..let((d) => touch(d, 'chitin.key'));
      final service = GameProfileService(
        gameCandidates: [candidate],
        environment: {GameProfileService.gameDirVariable: '/nope'},
      );

      expect(service.findGameDirectory(), isNull);
    });
  });

  group('findSaveRoot', () {
    test('is null when nothing holds a save slot', () {
      final empty = makeDir('empty');
      final service = GameProfileService(saveCandidates: [empty]);

      expect(service.findSaveRoot(), isNull);
    });

    test('returns a directory containing at least one slot', () {
      // A save root is recognised by what is *inside* it: a subdirectory with
      // a BALDUR.gam. The root itself has no marker file of its own.
      final root = makeDir('save');
      final slot = makeDir('save${Platform.pathSeparator}000000022-last');
      touch(slot, 'BALDUR.gam');
      final service = GameProfileService(saveCandidates: [root]);

      expect(service.findSaveRoot(), root);
    });

    test('ignores a directory whose subfolders hold no savegame', () {
      final root = makeDir('save');
      makeDir('save${Platform.pathSeparator}not-a-save');
      final service = GameProfileService(saveCandidates: [root]);

      expect(service.findSaveRoot(), isNull);
    });
  });

  _realMachine();
}

extension on String {
  void let(void Function(String) action) => action(this);
}

/// The defaults are the part most likely to rot silently: a path that changes
/// with a Steam update breaks discovery for everyone, and every unit test above
/// would still pass because they all inject their own candidates.
void _realMachine() {
  const service = GameProfileService();
  final saveRoot = service.findSaveRoot();

  group('against this machine', () {
    test(
      'the default candidates find a real save directory',
      () {
        expect(saveRoot, isNotNull);
        expect(service.slotsIn(saveRoot!), isNotEmpty);
      },
      skip: saveRoot == null ? 'no BG:EE save directory on this machine' : null,
    );
  });
}
