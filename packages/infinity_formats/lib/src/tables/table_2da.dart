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
/// One row of a [Table2da] — its label, and the cells after it.
///
/// A record rather than a class: it is two fields with no behaviour, and the
/// names are what carry the meaning (D-note in `context/dart-data-modelling.md`
/// §records).
typedef TableRow = ({String label, List<String> cells});

/// Row labels and column headers are both just strings, because the two axes
/// swap roles between tables: `dexmod` has ability scores down the side, while
/// `thac0` has class names down the side and *levels* across the top.
///
/// ⚠️ **A row label can repeat, and both rows are real.** BG:EE's own
/// `weapprof.2da` labels two rows `AXE` and two `SPEAR`. The last wins, and
/// the losers are kept in [shadowed] — see [allRows] for why that matters and
/// why "last" here where `IdsMap` takes the first.
final class Table2da {
  /// Wraps parsed contents directly, with the duplicate rows [shadowed].
  const Table2da({
    required this.defaultValue,
    required this.columns,
    required this.rows,
    this.shadowed = const [],
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
    final shadowed = <TableRow>[];
    for (final line in body.skip(2)) {
      final cells = line.trim().split(RegExp(r'\s+'));
      final label = cells.first;
      final values = cells.skip(1).toList();
      final displaced = rows[label];
      if (displaced != null) shadowed.add((label: label, cells: displaced));
      rows[label] = values;
    }

    return Table2da(
      defaultValue: body[0].trim(),
      columns: body[1].trim().split(RegExp(r'\s+')),
      rows: rows,
      shadowed: shadowed,
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

  /// Cells by row label. **Last row per label wins**; see [shadowed].
  ///
  /// Ordered by where each label *first* appeared, which is file order for
  /// every table without a repeat and subtly not for the ones with. Do not
  /// read position here as position in the file.
  final Map<String, List<String>> rows;

  /// The rows a repeated label displaced, in the order the file listed them.
  ///
  /// **Last-wins is measured, not a convention** — the opposite of `IdsMap`,
  /// and for a reason the data gives. `weapprof.2da` lists `AXE` as the
  /// obsolete BG1 proficiency 6 and *then* as 92, and 92 is the one BG:EE's
  /// opcode 233 uses; its type list does not start until 89. The later row is
  /// the live one.
  ///
  /// Keeping the losers is what stops that being a silent choice: a caller
  /// keyed on a *column* rather than on the label needs every row, and the
  /// equivalent loss in `IdsMap` is what left the kit encoding recorded as
  /// undecodable for want of a `TRUECLASS` row nothing had noticed was gone.
  final List<TableRow> shadowed;

  /// Every distinct row label. A label the file repeats appears once.
  Iterable<String> get rowLabels => rows.keys;

  /// Every row the file holds, [shadowed] ones included.
  ///
  /// What to walk when the key is a column — a proficiency's `ID`, say —
  /// rather than the label, so a consumer never has to know that [rows] and
  /// [shadowed] are two halves of one file.
  Iterable<TableRow> get allRows => [
    for (final entry in rows.entries) (label: entry.key, cells: entry.value),
    ...shadowed,
  ];

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
