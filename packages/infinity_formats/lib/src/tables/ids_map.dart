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
///
/// ⚠️ **A key can appear twice, and both names are real.** `KIT.IDS` numbers
/// `0x4000` as `TRUECLASS` and again as `MAGESCHOOL_GENERALIST`; IESDP's
/// `CLASS.IDS` page says in prose that 202 is shared by `LONG_BOW` and
/// `MAGE_ALL`. The first name wins and the rest are kept in [shadowed] — see
/// its note for why "first" rather than "last", which is measured rather than
/// arbitrary.
final class IdsMap {
  /// Wraps [entries] directly, with the duplicate rows [shadowed] displaced.
  const IdsMap(this.entries, {this.shadowed = const []});

  /// Reads an `IDS` table from [text].
  ///
  /// Never throws: a file that yields no entries produces an empty table. The
  /// caller is better placed to decide whether that is a failure — for the
  /// generator it is, and it says so loudly.
  factory IdsMap.parse(String text) {
    final entries = <int, String>{};
    final shadowed = <(int, String)>[];
    for (final line in text.split('\n')) {
      final match = _entry.firstMatch(line);
      if (match == null) continue;
      final key = _number(match.group(1)!);
      if (key == null) continue;
      final name = match.group(2)!;
      if (entries.containsKey(key)) {
        shadowed.add((key, name));
      } else {
        entries[key] = name;
      }
    }
    return IdsMap(entries, shadowed: shadowed);
  }

  /// A number and an identifier, and nothing else on the line.
  static final RegExp _entry = RegExp(
    r'^\s*(0[xX][0-9a-fA-F]+|-?\d+)\s+([A-Za-z_][A-Za-z0-9_]*)\s*$',
  );

  /// Every identifier in the table, by its number. First name per key wins.
  final Map<int, String> entries;

  /// The rows a duplicate key displaced, in the order the file listed them.
  ///
  /// **First-wins is measured, not a convention.** `KIT.IDS` lists `0x4000`
  /// as `TRUECLASS` before it lists it as `MAGESCHOOL_GENERALIST`, and a real
  /// save stores `0x4000` for a Fighter/Thief — a character with no mage
  /// component at all, who therefore cannot have a mage school. `TRUECLASS`
  /// is the name that describes what the field holds, and it is the first.
  ///
  /// Keeping the losers matters because dropping them is what hid that:
  /// last-wins made `KIT.IDS` look as though it had no `TRUECLASS` row, and
  /// the kit encoding was recorded as unresolved for want of it.
  final List<(int, String)> shadowed;

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
