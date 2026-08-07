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

  /// Creates `<tmp>/userdata/save/000000022-last/BALDUR.gam` and returns the
  /// save root, so the settings file can be placed beside it as the game does.
  String makeUserData({String? language}) {
    final separator = Platform.pathSeparator;
    final userData = makeDir('userdata');
    final root = makeDir('userdata${separator}save');
    touch(
      makeDir('userdata${separator}save${separator}000000022-last'),
      'BALDUR.gam',
    );
    if (language != null) {
      File('$userData${separator}Baldur.lua').writeAsStringSync(
        "SetPrivateProfileString('Window','Full Screen','1')\n"
        "SetPrivateProfileString('Language','Text','$language')\n"
        "SetPrivateProfileString('Program Options','Volume Music','60')\n",
      );
    }
    return root;
  }

  /// Creates a game directory with `lang/<code>/dialog.tlk` for each code.
  String makeGameWithLocales(List<String> locales) {
    final separator = Platform.pathSeparator;
    final game = makeDir('game');
    touch(game, 'chitin.key');
    for (final locale in locales) {
      touch(
        makeDir('game${separator}lang$separator$locale'),
        'dialog.tlk',
      );
    }
    return game;
  }

  group('findLanguage', () {
    test('reads the language the player configured in Baldur.lua', () {
      // The settings file sits beside the save root, in the user data
      // directory -- not in the game installation.
      final root = makeUserData(language: 'de_DE');
      final service = GameProfileService(saveCandidates: [root]);

      expect(service.findLanguage(), 'de_DE');
    });

    test('falls back to en_US when there is no settings file', () {
      final root = makeUserData();
      final service = GameProfileService(saveCandidates: [root]);

      expect(service.findLanguage(), GameProfileService.defaultLanguage);
    });

    test('falls back to en_US when no save directory was found at all', () {
      const service = GameProfileService(saveCandidates: ['/nope']);

      expect(service.findLanguage(), GameProfileService.defaultLanguage);
    });

    test('an environment override wins over the settings file', () {
      final root = makeUserData(language: 'de_DE');
      final service = GameProfileService(
        saveCandidates: [root],
        environment: {GameProfileService.languageVariable: 'ru_RU'},
      );

      expect(service.findLanguage(), 'ru_RU');
    });

    test('rejects a value that is not a locale code', () {
      // The value becomes a path segment, so a settings file carrying
      // '../../etc' must not be able to steer the search out of lang/.
      final root = makeUserData(language: '../../etc');
      final service = GameProfileService(saveCandidates: [root]);

      expect(service.findLanguage(), GameProfileService.defaultLanguage);
    });
  });

  group('findDialogTlk', () {
    test('resolves the talk table for the configured language', () {
      // This is the fix for the spike's arbitrary locale selection: it took
      // whatever lang/* listSync() happened to return first -- pt_BR on this
      // machine -- while Baldur.lua says en_US.
      final root = makeUserData(language: 'de_DE');
      final game = makeGameWithLocales(['de_DE', 'en_US', 'pt_BR']);
      final service = GameProfileService(
        gameCandidates: [game],
        saveCandidates: [root],
      );

      expect(
        service.findDialogTlk(),
        '$game${Platform.pathSeparator}lang'
        '${Platform.pathSeparator}de_DE'
        '${Platform.pathSeparator}dialog.tlk',
      );
    });

    test(
      'falls back to en_US when the configured language is not installed',
      () {
        final root = makeUserData(language: 'ja_JP');
        final game = makeGameWithLocales(['en_US']);
        final service = GameProfileService(
          gameCandidates: [game],
          saveCandidates: [root],
        );

        expect(
          service.findDialogTlk(),
          endsWith(
            'en_US'
            '${Platform.pathSeparator}dialog.tlk',
          ),
        );
      },
    );

    test('is null when no talk table exists at all', () {
      final root = makeUserData();
      final game = makeGameWithLocales([]);
      final service = GameProfileService(
        gameCandidates: [game],
        saveCandidates: [root],
      );

      expect(service.findDialogTlk(), isNull);
    });

    test('is null when the game installation was not found', () {
      // The app has to open on a machine with saves but no game -- there is
      // simply no text to resolve strrefs against.
      final root = makeUserData();
      final service = GameProfileService(
        gameCandidates: ['/nope'],
        saveCandidates: [root],
      );

      expect(service.findDialogTlk(), isNull);
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
  final gameDirectory = service.findGameDirectory();

  group('against this machine', () {
    test(
      'the default candidates find a real save directory',
      () {
        expect(saveRoot, isNotNull);
        expect(service.slotsIn(saveRoot!), isNotEmpty);
      },
      skip: saveRoot == null ? 'no BG:EE save directory on this machine' : null,
    );

    test(
      'the real Baldur.lua and installation agree on a readable talk table',
      () {
        // The unit tests above all inject their own directories, so none of
        // them would notice the real settings file moving or changing shape.
        final tlk = service.findDialogTlk();
        expect(tlk, isNotNull);
        expect(File(tlk!).existsSync(), isTrue);
        expect(tlk, contains(service.findLanguage()));
      },
      skip: saveRoot == null || gameDirectory == null
          ? 'no BG:EE installation on this machine'
          : null,
    );
  });
}
