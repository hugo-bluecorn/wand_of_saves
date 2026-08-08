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

/// Confirmation against a real installation, which cannot be committed.
///
/// The hermetic logic tests live in `key_index_test.dart`; this file only
/// checks that the reader agrees with values measured from the shipped game,
/// and skips entirely when the game is absent.
///
/// ⚠️ **Why this reader exists at all, when a rules generator already reads
/// IESDP.** IESDP's copy of `weapprof.2da` is the **BG2:EE** one, and its
/// `NAME_REF` strrefs point into BG2's talk table: generating proficiency
/// names from it yields tutorial prose. The player's own file gives 25023
/// where IESDP gives 31138, and only the former reads "Two-Weapon Style" in
/// this game. Tables of pure numbers survived the mismatch — `dexmod` and
/// `hpconbon` were both confirmed in game — but **anything carrying a strref
/// has to come from the installation.**
library;

import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

void main() {
  final game = _gameDirectory();
  final skip = game == null
      ? 'BG:EE not found — set BGEE_GAME_DIR to run this'
      : null;

  KeyIndex indexOf() =>
      KeyIndex.parse(File('$game/chitin.key').readAsBytesSync());

  group('chitin.key', () {
    test(
      'reports the archive and resource counts measured 2026-08-08',
      () {
        final index = indexOf();

        expect(index.archives, hasLength(83));
        expect(index.resourceCount, 37342);
      },
      skip: skip,
    );

    test(
      'its resource table closes exactly at the end of the file',
      () {
        // 2405 + 37342 * 14 == 525193, the file's own length. The strongest
        // structural check the format offers, and the same one that gives
        // confidence in the GAM layout.
        final bytes = File('$game/chitin.key').readAsBytesSync();
        final index = KeyIndex.parse(bytes);

        expect(
          index.resourceTableOffset + index.resourceCount * KeyIndex.entrySize,
          bytes.length,
        );
      },
      skip: skip,
    );

    test(
      'locates a 2DA the party editor actually needs',
      () {
        expect(
          indexOf().locate('WEAPPROF', ResourceType.table2da),
          (archive: 23, file: 512),
        );
      },
      skip: skip,
    );

    test(
      'is case-insensitive, because resrefs in the wild are not consistent',
      () {
        final index = indexOf();

        expect(
          index.locate('weapprof', ResourceType.table2da),
          index.locate('WEAPPROF', ResourceType.table2da),
        );
      },
      skip: skip,
    );

    test(
      'returns null for something that is not there',
      () {
        expect(indexOf().locate('NOSUCHRES', ResourceType.table2da), isNull);
      },
      skip: skip,
    );

    test(
      'every archive it names exists on disk and is a plain BIFF',
      () {
        // All 83 are uncompressed `BIFFV1  ` on BG:EE, so no decompressor is
        // needed. If a future install carries BIFC this test says so rather
        // than letting the reader fail somewhere deeper.
        for (final archive in indexOf().archives) {
          final file = File('$game/$archive');
          expect(file.existsSync(), isTrue, reason: archive);
          expect(
            String.fromCharCodes(file.readAsBytesSync().sublist(0, 8)),
            'BIFFV1  ',
            reason: archive,
          );
        }
      },
      skip: skip,
    );
  });

  group('reading a resource out of its archive', () {
    test(
      'weapprof.2da comes back as a 2DA the existing parser understands',
      () {
        final index = indexOf();
        final at = index.locate('WEAPPROF', ResourceType.table2da)!;
        final archive = BifArchive.parse(
          File('$game/${index.archives[at.archive]}').readAsBytesSync(),
        );

        final table = Table2da.parse(
          String.fromCharCodes(archive.resource(at.file)),
        );

        expect(table.rowLabels, contains('2WEAPON'));
      },
      skip: skip,
    );

    test(
      'and it carries the strrefs that name each proficiency',
      () {
        // The measurement this whole reader exists for. 25023 resolves to
        // "Two-Weapon Style" in this installation's talk table, and Aard
        // holds two pips in it.
        final index = indexOf();
        final at = index.locate('WEAPPROF', ResourceType.table2da)!;
        final archive = BifArchive.parse(
          File('$game/${index.archives[at.archive]}').readAsBytesSync(),
        );
        final table = Table2da.parse(
          String.fromCharCodes(archive.resource(at.file)),
        );

        expect(table.number('2WEAPON', 'ID'), 114);
        expect(table.number('2WEAPON', 'NAME_REF'), 25023);
        expect(table.number('LONGSWORD', 'NAME_REF'), 25001);
      },
      skip: skip,
    );
  });
}

/// The game directory, or null when it is not installed.
///
/// Same resolution order as `dialog_tlk_integration_test.dart`: where a game
/// lives is a fact about the machine, not about the format.
String? _gameDirectory() {
  final home = Platform.environment['HOME'] ?? '.';
  const game = "Baldur's Gate Enhanced Edition";
  const steam = 'steamapps/common';
  final roots = [
    ?Platform.environment['BGEE_GAME_DIR'],
    '$home/.local/share/Steam/$steam/$game',
    '$home/.steam/steam/$steam/$game',
    '$home/Library/Application Support/Steam/$steam/$game',
    "$home/GOG Games/Baldur's Gate - Enhanced Edition",
  ];
  for (final root in roots) {
    if (File('$root/chitin.key').existsSync()) return root;
  }
  return null;
}
