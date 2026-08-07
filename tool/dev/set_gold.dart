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

// Stages a copy of a fixture save with party gold changed.
//
// Usage, from the repository root:
//   fvm dart run tool/dev/set_gold.dart <slot> <gold>
//
// Reads only from the *fixture* copies under
// packages/infinity_formats/test/fixtures/saves/ and writes only under
// build/staged-saves/. It will refuse to write anywhere near a real save
// directory. Installing a staged slot into the game is a separate, deliberate
// act — see the note it prints when it finishes.
//
// A command-line tool: stdout is the output, written directly rather than
// through dart:core's print(), because avoid_print is enabled repo-wide (D8).
import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';

const _fixtures = 'packages/infinity_formats/test/fixtures/saves';
const _staging = 'build/staged-saves';
const _gamName = 'BALDUR.gam';

String _basename(String path) => path.split(Platform.pathSeparator).last;

Never _bail(String message) {
  stderr
    ..writeln('set_gold: $message')
    ..writeln()
    ..writeln('Usage, from the repository root:')
    ..writeln('  fvm dart run tool/dev/set_gold.dart <slot> <gold>')
    ..writeln()
    ..writeln('Available fixture slots:');
  final dir = Directory(_fixtures);
  if (dir.existsSync()) {
    for (final slot in dir.listSync().whereType<Directory>()) {
      stderr.writeln('  ${_basename(slot.path)}');
    }
  } else {
    stderr.writeln('  (none — run tool/dev/sync_fixtures.dart first)');
  }
  exit(2);
}

Future<void> main(List<String> args) async {
  if (!Directory('packages/infinity_formats').existsSync()) {
    _bail('run this from the repository root');
  }
  if (args.length != 2) _bail('expected a slot name and a gold amount');

  final slot = args[0];
  final gold = int.tryParse(args[1]);
  if (gold == null || gold < 0) _bail('gold must be a non-negative integer');

  final sourceDir = Directory('$_fixtures${Platform.pathSeparator}$slot');
  if (!sourceDir.existsSync()) _bail('no fixture slot named "$slot"');

  final destPath = '$_staging${Platform.pathSeparator}$slot';
  // Belt and braces: this tool must never be able to reach a live save.
  if (!Directory(destPath).absolute.path.contains('build')) {
    _bail('refusing to write outside build/');
  }
  final dest = Directory(destPath)..createSync(recursive: true);

  // Copy the whole slot: the game wants BALDUR.SAV, the screenshot and the
  // portraits alongside the savegame, not just the file being edited.
  var copied = 0;
  for (final file in sourceDir.listSync().whereType<File>()) {
    file.copySync(
      '${dest.path}${Platform.pathSeparator}'
      '${_basename(file.path)}',
    );
    copied++;
  }

  final gamPath = '${dest.path}${Platform.pathSeparator}$_gamName';
  final before = File(gamPath).readAsBytesSync();
  final parsed = GamCodec.decode(before, source: gamPath);
  final after = GamCodec.encode(parsed.withPartyGold(gold));

  await writeFileAtomically(gamPath, after);

  var changed = 0;
  for (var i = 0; i < before.length; i++) {
    if (before[i] != after[i]) changed++;
  }

  stdout
    ..writeln('slot     : $slot  ($copied files staged)')
    ..writeln('gold     : ${parsed.partyGold} -> $gold')
    ..writeln('bytes    : $changed of ${before.length} changed')
    ..writeln('staged to: ${dest.path}')
    ..writeln()
    ..writeln('Nothing under the real save directory was touched.')
    ..writeln('To try it in-game, copy this directory into the save folder')
    ..writeln('under a NEW slot name — never over an existing save.');
}
