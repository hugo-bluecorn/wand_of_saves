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

// Diffs two characters, field by field.
//
// Usage, from the repository root:
//   fvm dart run tool/dev/compare_characters.dart <before> <after>
//
// Each side is a `.chr` or a savegame's `BALDUR.gam`, and a savegame is read as
// its **first party member**. ⚠️ **The savegame is the better oracle of the
// two**: the engine gates EXPORT on things a probe character may well be
// carrying — intoxication does it — where Save Game stays available.
//
// Written for D14: hand it what this app wrote and what BG:EE wrote back, and
// every field that CHANGED is one the engine derives, while every field that
// survived is one the app owns.
//
// ⚠️ **Walks the whole header, not the fields anyone is curious about.** The
// project has been caught by this twice: a run asked about proficiencies came
// back with the real finding in *reputation*, which nothing in the run was
// about, and a run asked about a name's spelling corrected its *form*. The
// field you already suspect is the one thing you had reason to check.
//
// Reads only. Writes nothing anywhere.
//
// A command-line tool: stdout is the output, written directly rather than
// through dart:core's print(), because avoid_print is enabled repo-wide (D8).

import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';

Never _bail(String message) {
  stderr
    ..writeln('compare_characters: $message')
    ..writeln()
    ..writeln(
      'usage: fvm dart run tool/dev/compare_characters.dart '
      '<before.chr> <after.chr>',
    );
  exit(1);
}

/// Fields holding text rather than a number, compared as strings.
const Set<CreHeaderField> _textFields = {
  CreHeaderField.portraitMedium,
  CreHeaderField.portraitLarge,
  CreHeaderField.dialogFile,
};

Cre _open(String path) {
  final file = File(path);
  if (!file.existsSync()) _bail('no such file: $path');
  final bytes = file.readAsBytesSync();
  try {
    // Told apart by their signature rather than by the file name, so a slot
    // directory copied to any name still reads.
    if (path.toLowerCase().endsWith('.gam')) {
      final party = GamCodec.decode(bytes).partyMembers;
      if (party.isEmpty) _bail('$path has no party members.');
      return CreCodec.decode(party.first.creBytes);
    }
    return CreCodec.decode(ChrCodec.decode(bytes).creBytes);
  } on InfinityFormatException catch (error) {
    // ⚠️ A `.chr` the engine wrote past `startare.2da`'s XP cap is `V2.1`,
    // which this codec refuses by name. Say so rather than "malformed".
    _bail('$path did not decode: $error');
  }
}

void main(List<String> args) {
  if (args.length != 2) _bail('two files are needed.');
  final before = _open(args[0]);
  final after = _open(args[1]);

  final changed = <(String, String, String)>[];
  final kept = <String>[];

  for (final field in CreHeaderField.values) {
    final name = field.toString().replaceFirst('CreHeaderField.', '');
    if (_textFields.contains(field)) {
      final a = decodeFixedString(before.bytes, field.offset, field.length);
      final b = decodeFixedString(after.bytes, field.offset, field.length);
      if (a != b) {
        changed.add((name, a, b));
      } else {
        kept.add(name);
      }
      continue;
    }
    // Offsets and counts move whenever a section resizes and say nothing about
    // what the engine believes, so they are reported separately below.
    if (name.endsWith('Offset') || name.endsWith('Count')) continue;
    try {
      final a = before.readField(field);
      final b = after.readField(field);
      if (a != b) {
        changed.add((name, '$a', '$b'));
      } else {
        kept.add(name);
      }
    } on InfinityFormatException {
      // A field this tool cannot read as a number — skipped rather than
      // guessed at.
      continue;
    }
  }

  stdout
    ..writeln('before: ${args[0]}  (${before.bytes.length} bytes)')
    ..writeln('after:  ${args[1]}  (${after.bytes.length} bytes)')
    ..writeln()
    ..writeln('=== THE ENGINE CHANGED THESE — derived ===')
    ..writeln();
  if (changed.isEmpty) {
    stdout.writeln('  (nothing)');
  }
  for (final (name, a, b) in changed) {
    stdout.writeln('  ${name.padRight(26)} ${a.padLeft(8)}  ->  $b');
  }

  stdout
    ..writeln()
    ..writeln('=== THE ENGINE LEFT THESE ALONE — authored ===')
    ..writeln()
    ..writeln('  ${kept.join(', ')}')
    ..writeln()
    ..writeln('=== sections ===')
    ..writeln();

  void section(String label, Object a, Object b) => stdout.writeln(
    '  ${label.padRight(20)} $a\n  ${' '.padRight(20)} $b'
    '${a.toString() == b.toString() ? '   (same)' : '   <<< CHANGED'}',
  );

  section('proficiencies', before.proficiencies, after.proficiencies);
  section(
    'known spells',
    '${before.knownSpells.length}: '
        '${before.knownSpells.map((s) => s.resref).join(' ')}',
    '${after.knownSpells.length}: '
        '${after.knownSpells.map((s) => s.resref).join(' ')}',
  );
  section(
    'memorised',
    '${before.memorizedSpells.length}: '
        '${before.memorizedSpells.map((s) => s.resref).join(' ')}',
    '${after.memorizedSpells.length}: '
        '${after.memorizedSpells.map((s) => s.resref).join(' ')}',
  );
  section(
    'memorisation rows',
    '${before.memorizationInfoCount} rows, '
        '${before.memorizations.where((r) => r.count > 0).length} in use',
    '${after.memorizationInfoCount} rows, '
        '${after.memorizations.where((r) => r.count > 0).length} in use',
  );
  section('items', before.itemsCount, after.itemsCount);
  section('effects', before.effectsCount, after.effectsCount);
  section('effect version', before.effectVersion, after.effectVersion);

  stdout
    ..writeln()
    ..writeln('${changed.length} changed, ${kept.length} kept.');
}
