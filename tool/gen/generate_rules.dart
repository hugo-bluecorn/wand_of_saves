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

/// Turns IESDP's copies of the game's own tables into Dart.
///
/// ```bash
/// fvm dart run tool/gen/generate_rules.dart      # from the repository root
/// ```
///
/// **Run by hand, output committed.** Not a `build_runner` builder, because
/// the input is a reference sibling (`../iesdp`) that a fresh clone does not
/// have — a build step over it would fail for anyone who has not cloned it.
/// D8's amendment already settled that generated output is committed, since
/// there is no CI to regenerate it.
///
/// **The tables are a snapshot, and a modded install has different ones.**
/// That is why the app reaches them through an interface: Phase 3's KEY/BIFF
/// reader can point the same interface at the player's actual files without
/// the UI noticing.
library;

import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';

/// Where IESDP is checked out. Argument → environment → the usual sibling.
String _iesdpRoot(List<String> args) =>
    args.firstOrNull ?? Platform.environment['IESDP_DIR'] ?? '../iesdp';

Future<void> main(List<String> args) async {
  final root = _iesdpRoot(args);
  if (!Directory(root).existsSync()) {
    _fail(
      'IESDP not found at "$root".\n'
      'Clone it beside this repository, or pass a path:\n'
      '  fvm dart run tool/gen/generate_rules.dart /path/to/iesdp',
    );
  }

  final revision = _revisionOf(root);
  stdout.writeln('Reading IESDP at $root (${revision ?? 'unknown revision'})');

  final classes = _ids(root, 'class');
  final races = _ids(root, 'race');
  final alignments = _ids(root, 'alignmen');
  final genders = _ids(root, 'gender');
  final kits = _ids(root, 'kit');
  final dexterity = _table(root, 'dexmod');
  final constitution = _table(root, 'hpconbon');

  _write('lib/domain/rules/identifiers.g.dart', revision, [
    _idsConstant(
      name: 'classIdentifiers',
      source: 'files/ids/bgee/class.ids',
      about: 'CRE `0x0273`. `7` is `FIGHTER_MAGE`.',
      ids: classes,
    ),
    _idsConstant(
      name: 'raceIdentifiers',
      source: 'files/ids/bgee/race.ids',
      about: 'CRE `0x0272`. `2` is `ELF`.',
      ids: races,
    ),
    _idsConstant(
      name: 'alignmentIdentifiers',
      source: 'files/ids/bgee/alignmen.ids',
      about: 'CRE `0x027b`. Written in hex: `0x21` is `NEUTRAL_GOOD`.',
      ids: alignments,
    ),
    _idsConstant(
      name: 'genderIdentifiers',
      source: 'files/ids/bgee/gender.ids',
      about: 'CRE `0x0275`.',
      ids: genders,
    ),
    _idsConstant(
      name: 'kitIdentifiers',
      source: 'files/ids/bgee/kit.ids',
      about:
          'CRE `0x0244`, a dword rather than a byte. `0x40000000` is '
          'TRUECLASS, meaning no kit at all.',
      ids: kits,
    ),
  ]);

  _write('lib/domain/rules/modifiers.g.dart', revision, [
    _numberConstant(
      name: 'dexterityArmourClass',
      source: 'files/2da/2da_bgee/dexmod.2da',
      about:
          'Dexterity to armour class. Confirmed against the game, which '
          'printed "Dexterity: -3" for a score of 17.',
      values: _column(dexterity, 'AC'),
    ),
    _numberConstant(
      name: 'constitutionHitPointsOther',
      source: 'files/2da/2da_bgee/hpconbon.2da, column OTHER',
      about:
          'Constitution to hit points per level, for everyone but warriors. '
          'Confirmed at 16, where the game printed '
          '"Bonus Hit Points/Level: +2".',
      values: _column(constitution, 'OTHER'),
    ),
    _numberConstant(
      name: 'constitutionHitPointsWarrior',
      source: 'files/2da/2da_bgee/hpconbon.2da, column WARRIOR',
      about:
          'The same, for fighters, paladins and rangers. The two columns are '
          'identical up to 16 and diverge from 17, so the fixture cannot tell '
          'them apart.',
      values: _column(constitution, 'WARRIOR'),
    ),
  ]);

  stdout.writeln('Done. Run `fvm dart format lib/domain/rules`.');
}

IdsMap _ids(String root, String name) {
  final ids = IdsMap.parse(_payload('$root/files/ids/bgee/$name.htm'));
  // An empty table would make every name it backs quietly disappear, so this
  // is a hard failure rather than an empty map.
  if (ids.entries.isEmpty) _fail('$name.ids parsed to nothing');
  return ids;
}

Table2da _table(String root, String name) {
  final table = Table2da.parse(_payload('$root/files/2da/2da_bgee/$name.htm'));
  if (table.rows.isEmpty) _fail('$name.2da parsed to nothing');
  return table;
}

/// Every row of [column], keyed by the row label read as a number.
Map<int, int> _column(Table2da table, String column) {
  final values = <int, int>{};
  for (final label in table.rowLabels) {
    final key = int.tryParse(label);
    final value = table.number(label, column);
    if (key != null && value != null) values[key] = value;
  }
  if (values.isEmpty) _fail('column $column is empty');
  return values;
}

/// The text inside an IESDP page, with tags and entities removed.
String _payload(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('missing $path');
  return _unescape(file.readAsStringSync().replaceAll(RegExp('<[^>]+>'), ''));
}

String _unescape(String html) => html
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

String _idsConstant({
  required String name,
  required String source,
  required String about,
  required IdsMap ids,
}) {
  final entries = [
    for (final entry in ids.entries.entries)
      "  ${entry.key}: '${entry.value}',",
  ];
  return '''
${_doc(about, source)}
const Map<int, String> $name = {
${entries.join('\n')}
};
''';
}

String _numberConstant({
  required String name,
  required String source,
  required String about,
  required Map<int, int> values,
}) {
  final entries = [
    for (final entry in values.entries) '  ${entry.key}: ${entry.value},',
  ];
  return '''
${_doc(about, source)}
const Map<int, int> $name = {
${entries.join('\n')}
};
''';
}

/// A doc comment wrapped to the line limit.
///
/// `dart format` does not reflow comments, so the generator has to emit them
/// already short enough — otherwise every regeneration reintroduces a
/// `lines_longer_than_80_chars` complaint, and D8 leaves no way to silence it.
String _doc(String about, String source) {
  final lines = <String>[];
  var current = StringBuffer('///');
  for (final word in '$about Generated from `$source`.'.split(' ')) {
    if (current.length + word.length + 1 > 80) {
      lines.add(current.toString());
      current = StringBuffer('///');
    }
    current.write(' $word');
  }
  lines.add(current.toString());
  return lines.join('\n');
}

void _write(String path, String? revision, List<String> constants) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(
      '''
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

// GENERATED BY tool/gen/generate_rules.dart — DO NOT EDIT.
// Source: IESDP${revision == null ? '' : ' @ $revision'}
//
// These are the game's own rules tables, transcribed by a program rather than
// by hand. Regenerate rather than editing:
//   fvm dart run tool/gen/generate_rules.dart

${constants.join('\n')}''',
    );
  stdout.writeln('  wrote $path');
}

/// The IESDP commit these tables came from, so a stale snapshot is visible.
///
/// Read-only: the reference tree has a single writer and this is not it.
String? _revisionOf(String root) {
  final result = Process.runSync('git', [
    '-C',
    root,
    'rev-parse',
    '--short',
    'HEAD',
  ]);
  if (result.exitCode != 0) return null;
  return (result.stdout as String).trim();
}

Never _fail(String message) {
  stderr.writeln('generate_rules: $message');
  exit(1);
}
