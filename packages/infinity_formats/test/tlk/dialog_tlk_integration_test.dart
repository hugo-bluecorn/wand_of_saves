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

/// Confirmation against a real `dialog.tlk`, which cannot be committed — it is
/// BioWare's copyright. The hermetic logic tests live in `tlk_test.dart`; this
/// file only checks that the codec agrees with values measured from the
/// shipped game, and skips entirely when the game is absent.
///
/// Deliberately pinned to `en_US`: the string assertions below are
/// locale-specific and must not depend on which language is installed.
library;

import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

void main() {
  final path = _englishDialogTlk();
  final skip = path == null
      ? 'BG:EE en_US not found — set BGEE_GAME_DIR to run this'
      : null;

  group('dialog.tlk', () {
    late Tlk tlk;

    setUp(() async => tlk = await Tlk.open(path!));
    tearDown(() => tlk.close());

    test('reports the entry count recorded in the findings', () async {
      expect(tlk.length, 34000);
    });

    test(
      'decodes a multi-byte string the spike rendered as mojibake',
      () async {
        // String.fromCharCodes turns the em dash's e2 80 94 into three
        // characters. See docs/findings/verified-format-offsets.md §TLK.
        expect(await tlk.get(1371), 'Why you—');
        expect(await tlk.get(520), startsWith('My name is Viconia.'));
        expect(await tlk.get(520), contains('—'));
      },
    );

    test('returns null outside the table rather than throwing', () async {
      expect(await tlk.get(-1), isNull);
      expect(await tlk.get(34000), isNull);
    });

    test('decodes every entry without throwing', () async {
      var nonEmpty = 0;
      for (var strref = 0; strref < tlk.length; strref++) {
        final text = await tlk.get(strref);
        expect(text, isNotNull, reason: 'strref $strref is inside the table');
        if (text!.isNotEmpty) nonEmpty++;
      }
      // 34,000 entries of which 837 are empty, measured 2026-08-07.
      expect(nonEmpty, 33163);
    });
  }, skip: skip);
}

/// Path to the English `dialog.tlk`, or null if the game is not installed.
///
/// Resolution order matches the project convention: environment variable, then
/// well-known install locations. This lives in the test rather than in the
/// library on purpose — where a game is installed is a fact about the machine,
/// not about the format.
String? _englishDialogTlk() {
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
    final candidate = '$root/lang/en_US/dialog.tlk';
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}
