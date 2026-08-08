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
  });
}
