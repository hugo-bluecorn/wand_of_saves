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

/// An `IDS` identifier table — a number and the name the engine calls it.
///
/// `CLASS.IDS` turns the `7` in a creature record into `FIGHTER_MAGE`;
/// `RACE.IDS` and `ALIGNMEN.IDS` do the same for their own fields. Without
/// these a character sheet can only show numbers.
///
/// The format is a line per entry, optionally preceded by an `IDS V1.0`
/// signature and a count. **Keys may be decimal or hexadecimal** and nothing
/// in the file says which: `CLASS.IDS` writes `7` where `ALIGNMEN.IDS` writes
/// `0x21`. Both are read.
///
/// Parsing is **tolerant by design**. A line counts as an entry only when it
/// is exactly a number and an identifier; everything else — signature, count,
/// blank lines, and the prose IESDP interleaves between entries — is skipped.
/// That is deliberately narrower than "starts with a number", so a sentence
/// opening with a digit cannot become an entry.
final class IdsMap {
  /// Wraps [entries] directly.
  const IdsMap(this.entries);

  /// Reads an `IDS` table from [text].
  ///
  /// Never throws: a file that yields no entries produces an empty table. The
  /// caller is better placed to decide whether that is a failure — for the
  /// generator it is, and it says so loudly.
  factory IdsMap.parse(String text) {
    final entries = <int, String>{};
    for (final line in text.split('\n')) {
      final match = _entry.firstMatch(line);
      if (match == null) continue;
      final key = _number(match.group(1)!);
      if (key != null) entries[key] = match.group(2)!;
    }
    return IdsMap(entries);
  }

  /// A number and an identifier, and nothing else on the line.
  static final RegExp _entry = RegExp(
    r'^\s*(0[xX][0-9a-fA-F]+|-?\d+)\s+([A-Za-z_][A-Za-z0-9_]*)\s*$',
  );

  /// Every identifier in the table, by its number.
  final Map<int, String> entries;

  /// The identifier numbered [key], or `null`.
  String? operator [](int key) => entries[key];

  /// The number of the entry called [name], or `null`.
  ///
  /// The reverse direction, so a question like "which classes are warriors"
  /// can be asked in the engine's own vocabulary rather than by hardcoding
  /// numbers that mean nothing at the call site.
  int? keyFor(String name) {
    for (final entry in entries.entries) {
      if (entry.value == name) return entry.key;
    }
    return null;
  }

  static int? _number(String token) => token.toLowerCase().startsWith('0x')
      ? int.tryParse(token.substring(2), radix: 16)
      : int.tryParse(token);

  @override
  String toString() => 'IdsMap(${entries.length} entries)';
}
