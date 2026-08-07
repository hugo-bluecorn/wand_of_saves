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

// Copies real BG:EE save slots into the test fixture directory.
//
// Usage, from the repository root:
//   fvm dart run tool/dev/sync_fixtures.dart [saveRoot]
//
// Resolution order: argument, then $BGEE_SAVE_DIR, then well-known locations.
//
// THIS SCRIPT ONLY READS THE SOURCE. The save directory is the player's real
// game; nothing here opens it for writing, and the copies it produces are what
// every test touches. Fixtures are gitignored (`**/fixtures/`) because
// BALDUR.gam is BioWare's copyright and must never enter the repository.
//
// A command-line tool: stdout is the output, written directly rather than
// through dart:core's print(), because avoid_print is enabled repo-wide (D8).
import 'dart:io';

/// Where fixtures land, relative to the repository root.
const _destination = 'packages/infinity_formats/test/fixtures/saves';

const _gam = 'BALDUR.gam';

String get _home =>
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';

List<String> get _saveCandidates => [
  "$_home/.local/share/Baldur's Gate - Enhanced Edition/save",
  "$_home/Documents/Baldur's Gate - Enhanced Edition/save",
  "$_home/Library/Application Support/Baldur's Gate - Enhanced Edition/save",
];

String _basename(String path) => path.split(Platform.pathSeparator).last;

/// Save-slot directories under [root], newest first.
List<Directory> _slotsIn(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync()
      .whereType<Directory>()
      .where(
        (d) => File('${d.path}${Platform.pathSeparator}$_gam').existsSync(),
      )
      .toList();
}

Never _bail(String message) {
  stderr
    ..writeln('sync_fixtures: $message')
    ..writeln()
    ..writeln('Usage, from the repository root:')
    ..writeln('  fvm dart run tool/dev/sync_fixtures.dart [saveRoot]')
    ..writeln()
    ..writeln(r'or set $BGEE_SAVE_DIR. Looked in:');
  for (final candidate in _saveCandidates) {
    stderr.writeln('  $candidate');
  }
  exit(2);
}

void main(List<String> args) {
  if (!Directory('packages/infinity_formats').existsSync()) {
    _bail('run this from the repository root');
  }

  final requested = args.isNotEmpty
      ? args.first
      : Platform.environment['BGEE_SAVE_DIR'];

  final roots = requested != null ? [requested] : _saveCandidates;
  final root = roots.where((r) => _slotsIn(r).isNotEmpty).firstOrNull;
  if (root == null) _bail('no save slots found');

  final slots = _slotsIn(root)
    ..sort((a, b) => _basename(a.path).compareTo(_basename(b.path)));

  stdout
    ..writeln('source : $root  (read-only)')
    ..writeln('dest   : $_destination')
    ..writeln();

  for (final slot in slots) {
    final name = _basename(slot.path);
    final target = Directory('$_destination${Platform.pathSeparator}$name')
      ..createSync(recursive: true);

    var files = 0;
    var bytes = 0;
    for (final file in slot.listSync().whereType<File>()) {
      final to =
          '${target.path}${Platform.pathSeparator}'
          '${_basename(file.path)}';
      file.copySync(to);
      files++;
      bytes += file.lengthSync();
    }
    stdout.writeln('  $name  ($files files, $bytes bytes)');
  }

  stdout
    ..writeln()
    ..writeln('${slots.length} slot(s) copied. Fixtures are gitignored.');
}
