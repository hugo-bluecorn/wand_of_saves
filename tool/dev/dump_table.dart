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

// Prints a 2DA out of the player's own installation, exactly as it is stored.
//
// Usage, from the repository root:
//   fvm dart run tool/dev/dump_table.dart <resref> [<resref> ...]
//   fvm dart run tool/dev/dump_table.dart --list <substring>
//   fvm dart run tool/dev/dump_table.dart --text <strref> [<strref> ...]
//
// D13 says to look for the game's own table before writing a rules judgement
// into code, and D11 says the copy that matters is the player's rather than
// IESDP's. This is the one-line way to do both. Read-only throughout: it opens
// chitin.key and the archives and writes nothing anywhere.
//
// A command-line tool: stdout is the output, written directly rather than
// through dart:core's print(), because avoid_print is enabled repo-wide (D8).
import 'dart:convert';
import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';

Never _bail(String message) {
  stderr
    ..writeln('dump_table: $message')
    ..writeln()
    ..writeln('Usage, from the repository root:')
    ..writeln('  fvm dart run tool/dev/dump_table.dart <resref> [<resref> ...]')
    ..writeln('  fvm dart run tool/dev/dump_table.dart --list <substring>')
    ..writeln('  fvm dart run tool/dev/dump_table.dart --text <strref> ...');
  exit(2);
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) _bail('expected at least one 2DA resref');

  const profile = GameProfileService();
  final game = profile.findGameDirectory();
  if (game == null) _bail('no Baldur’s Gate installation found');

  final index = KeyIndex.parse(
    File(
      '$game${Platform.pathSeparator}${GameProfileService.gameMarker}',
    ).readAsBytesSync(),
    source: GameProfileService.gameMarker,
  );

  // ⚠️ A table column holding a number that names a string is only half an
  // answer — D11 exists because IESDP's copy of one such column named tutorial
  // prose. This resolves them against the player's own talk table.
  if (args.first == '--text') {
    final talk = profile.findDialogTlk();
    if (talk == null) _bail('no dialog.tlk found');
    final tlk = await Tlk.open(talk);
    for (final each in args.skip(1)) {
      final strref = int.tryParse(each);
      if (strref == null) continue;
      stdout.writeln('$strref: ${await tlk.get(strref) ?? '(none)'}');
    }
    await tlk.close();
    return;
  }

  if (args.first == '--list') {
    if (args.length != 2) _bail('--list takes one substring');
    final needle = args[1].toLowerCase();
    final found =
        index
            .resrefsOf(ResourceType.table2da)
            .where((r) => r.toLowerCase().contains(needle))
            .toList()
          ..sort();
    stdout.writeln('${found.length} tables matching "$needle":');
    for (final resref in found) {
      stdout.writeln('  $resref');
    }
    return;
  }

  // Read straight from the archives rather than through ResourceRepository:
  // that class exposes domain models, and widening it to hand out raw bytes
  // for the sake of a dev tool would be the tool shaping the application.
  final archives = <int, BifArchive>{};
  for (final resref in args) {
    stdout.writeln('===== $resref.2da =====');
    final where = index.locate(resref, ResourceType.table2da);
    if (where == null) {
      stdout.writeln('(not in this installation)');
      continue;
    }
    // The key file writes archive paths Windows-separated, whatever the host.
    final named = index.archives[where.archive];
    final relative = named.replaceAll(r'\', Platform.pathSeparator);
    final archive = archives[where.archive] ??= BifArchive.parse(
      File('$game${Platform.pathSeparator}$relative').readAsBytesSync(),
      source: relative,
    );
    stdout.writeln(utf8.decode(archive.resource(where.file)));
  }
}
