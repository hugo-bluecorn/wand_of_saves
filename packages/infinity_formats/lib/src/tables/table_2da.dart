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

/// A `2DA` table — the game's own rules, as whitespace-separated columns.
///
/// ```text
/// 2DA V1.0
/// 0                     <- value for any cell a row does not reach
///      REACTION MISSILE  AC
/// 17   2        2        -3
/// ```
///
/// These are what turn a stored number into the number the player sees.
/// `dexmod.2da` says Dexterity 17 is −3 to armour class; `hpconbon.2da` says
/// Constitution 16 is +2 hit points per level. Both were confirmed against
/// what BG:EE printed on screen.
///
/// Row labels and column headers are both just strings, because the two axes
/// swap roles between tables: `dexmod` has ability scores down the side, while
/// `thac0` has class names down the side and *levels* across the top.
final class Table2da {
  /// Wraps parsed contents directly.
  const Table2da({
    required this.defaultValue,
    required this.columns,
    required this.rows,
  });

  /// Reads a `2DA` table from [text].
  ///
  /// Parsing **starts at the signature**, so the paragraphs of description
  /// IESDP puts above a payload are skipped rather than read as rows. Text
  /// with no signature yields an empty table rather than throwing — the
  /// generator is the one that decides an empty table is a failure, and it
  /// says so loudly.
  factory Table2da.parse(String text) {
    final lines = text.split('\n');
    final start = lines.indexWhere(_signature.hasMatch);
    if (start < 0) {
      return const Table2da(defaultValue: '', columns: [], rows: {});
    }

    final body = lines
        .skip(start + 1)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (body.length < 2) {
      return const Table2da(defaultValue: '', columns: [], rows: {});
    }

    final rows = <String, List<String>>{};
    for (final line in body.skip(2)) {
      final cells = line.trim().split(RegExp(r'\s+'));
      rows[cells.first] = cells.skip(1).toList();
    }

    return Table2da(
      defaultValue: body[0].trim(),
      columns: body[1].trim().split(RegExp(r'\s+')),
      rows: rows,
    );
  }

  /// The signature line, whose internal spacing varies.
  ///
  /// 17 of BG:EE's 194 tables — `hpclass.2da` among them — pad it out as
  /// `2DA        V1.0`. Matching the literal string `'2DA V1.0'` produced a
  /// silently *empty* table for every one of those, which is the worst way for
  /// a rules table to be wrong.
  static final RegExp _signature = RegExp(r'^\s*2DA\s+V1\.0\s*$');

  /// The value of any cell a row is too short to reach.
  final String defaultValue;

  /// Column headers, in file order.
  final List<String> columns;

  /// Cells by row label, in file order.
  final Map<String, List<String>> rows;

  /// Row labels, in file order.
  Iterable<String> get rowLabels => rows.keys;

  /// The cell at [row] and [column], or `null` if either is not in the table.
  ///
  /// A row that exists but is too short returns [defaultValue] — that is what
  /// the second line of the file is for, and it is a different answer from
  /// "no such row".
  String? cell(String row, String column) {
    final cells = rows[row];
    final index = columns.indexOf(column);
    if (cells == null || index < 0) return null;
    return index < cells.length ? cells[index] : defaultValue;
  }

  /// [cell] read as an integer, or `null` if it is absent or not a number.
  int? number(String row, String column) {
    final text = cell(row, column);
    return text == null ? null : int.tryParse(text);
  }

  @override
  String toString() =>
      'Table2da(${rows.length} rows x ${columns.length} columns)';
}
