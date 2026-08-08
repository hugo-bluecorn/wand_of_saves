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

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

void main() {
  /// Shaped like `dexmod.2da`, down to the column names.
  const dexmod = '''
2DA V1.0
0
     REACTION MISSILE  AC
15   0        0        -1
16   1        1        -2
17   2        2        -3
''';

  group('parse', () {
    test('reads the columns from the header line', () {
      expect(Table2da.parse(dexmod).columns, ['REACTION', 'MISSILE', 'AC']);
    });

    test('reads a cell by row and column', () {
      // Dexterity 17 gives -3 to armour class. The game printed exactly that.
      expect(Table2da.parse(dexmod).number('17', 'AC'), -3);
    });

    test('reads the default from the second line', () {
      expect(Table2da.parse(dexmod).defaultValue, '0');
    });

    test('lists its row labels in file order', () {
      expect(Table2da.parse(dexmod).rowLabels, ['15', '16', '17']);
    });

    test('starts at the signature, ignoring any preamble', () {
      // IESDP puts several paragraphs of description above the payload.
      final table = Table2da.parse('''
This file defines constitution influence on the creature.
First column is the value of NPCs constitution
In BG2EE we have:

$dexmod
''');

      expect(table.number('16', 'AC'), -2);
    });

    test('a short row falls back to the default', () {
      // 2DA rows are ragged in the wild; a missing cell is the default, which
      // is what the second line is for.
      final table = Table2da.parse('2DA V1.0\n9\n   A   B   C\nR1 1   2\n');

      expect(table.cell('R1', 'B'), '2');
      expect(table.cell('R1', 'C'), '9');
    });

    test('is null for a row or column that is not there', () {
      final table = Table2da.parse(dexmod);

      expect(table.cell('99', 'AC'), isNull);
      expect(table.cell('17', 'NOPE'), isNull);
      expect(table.number('99', 'AC'), isNull);
    });

    test('is null for a cell that is not a number', () {
      final table = Table2da.parse('2DA V1.0\n0\n   A\nR1 x\n');

      expect(table.cell('R1', 'A'), 'x');
      expect(table.number('R1', 'A'), isNull);
    });

    test('skips blank lines between rows', () {
      final table = Table2da.parse('2DA V1.0\n0\n   A\n\nR1 5\n\n');

      expect(table.number('R1', 'A'), 5);
    });

    test('handles a table whose columns are numbers', () {
      // thac0.2da is the other way round: classes down the side, levels
      // across the top.
      final table = Table2da.parse('''
2DA V1.0
0
             1   2   3
MAGE         20  20  20
FIGHTER      20  19  18
''');

      expect(table.number('FIGHTER', '2'), 19);
      expect(table.columns, ['1', '2', '3']);
    });

    test('accepts a signature padded with extra spaces', () {
      // 17 of the 194 BG:EE tables are written `2DA        V1.0`, including
      // hpclass.2da. Matching the exact string "2DA V1.0" silently produced an
      // empty table for every one of them.
      final table = Table2da.parse('2DA        V1.0\n0\n   A\nR1 5\n');

      expect(table.number('R1', 'A'), 5);
    });

    test('is empty when there is no table at all', () {
      final table = Table2da.parse('nothing to see here\n');

      expect(table.columns, isEmpty);
      expect(table.rowLabels, isEmpty);
    });

    group('a row label that repeats', () {
      /// The shape of the player's own `weapprof.2da`, cut to three columns.
      ///
      /// **Not hypothetical.** BG:EE's file labels two rows `AXE` and two
      /// `SPEAR` — the obsolete BG1 proficiencies 6 and 3, then the ones the
      /// engine actually uses, 92 and 98. The label is not the key; the `ID`
      /// column is.
      const weapprof = '''
2DA V1.0
0
                 ID   NAME_REF FIGHTER
LARGE_SWORD      0    0        0
SPEAR            3    0        0
AXE              6    0        0
BASTARDSWORD     89   25000    5
AXE              92   25003    5
SPEAR            98   25010    5
''';

      test('keeps the last row under the label, as the engine reads it', () {
        // Last-wins is right here and it is measured, not a convention: the
        // rows BG:EE uses are the *second* of each pair, and its own opcode
        // 233 type list starts at 89.
        final table = Table2da.parse(weapprof);

        expect(table.number('AXE', 'ID'), 92);
        expect(table.number('SPEAR', 'ID'), 98);
      });

      test('keeps the displaced rows rather than dropping them', () {
        // The whole point. A caller keyed on the ID column — which is what
        // proficiencies need — cannot see rows 3 and 6 through `rows` at all,
        // and losing a row silently is exactly what made KIT.IDS's duplicate
        // key look like an undecodable kit encoding.
        final table = Table2da.parse(weapprof);

        expect(table.shadowed, hasLength(2));
        // In the order the file displaced them: `AXE 92` is read before
        // `SPEAR 98`, so `AXE 6` is the first row to lose its label.
        expect(table.shadowed.map((row) => row.label), ['AXE', 'SPEAR']);
        expect(table.shadowed.map((row) => row.cells.first), ['6', '3']);
      });

      test('reports every row once, displaced ones included', () {
        // So a consumer keying on a column never has to know that `rows` and
        // `shadowed` are two halves of one file.
        //
        // Unordered, and deliberately: a repeated label keeps its *first*
        // position in `rows` while holding its *last* value, so the winners
        // are not in file order and nothing should be written as if they were.
        final table = Table2da.parse(weapprof);

        expect(
          table.allRows.map((row) => row.cells.first),
          unorderedEquals(['0', '3', '6', '89', '92', '98']),
        );
      });
    });
  });
}
