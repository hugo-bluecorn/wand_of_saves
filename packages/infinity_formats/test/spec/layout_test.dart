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

import '../support/layout.dart';

/// A [FormatField] built inline, so broken layouts can be constructed on
/// purpose. Real layouts are enhanced enums (D6), which cannot be forged.
///
/// [toString] is overridden because that is how diagnostics label a field —
/// `FormatField` deliberately has no `name` member, since an enum's `.name` is
/// an extension and cannot satisfy an interface.
final class _Field implements FormatField {
  const _Field(this._label, this.offset, this.length);

  final String _label;

  @override
  final int offset;
  @override
  final int length;

  @override
  String toString() => _label;
}

void main() {
  group('layoutProblems', () {
    test('is empty for a gapless, ordered layout', () {
      expect(
        layoutProblems(const [
          _Field('a', 0, 4),
          _Field('b', 4, 2),
          _Field('c', 6, 8),
        ]),
        isEmpty,
      );
    });

    test('accepts documented gaps when no struct size is given', () {
      // A header table records the fields this project has verified, not
      // every byte the format defines. Gaps are expected there.
      expect(
        layoutProblems(const [_Field('a', 0, 4), _Field('b', 0x18, 4)]),
        isEmpty,
      );
    });

    test('reports overlapping fields, naming both', () {
      final problems = layoutProblems(const [
        _Field('first', 0, 8),
        _Field('second', 4, 4),
      ]);

      expect(problems, hasLength(1));
      expect(problems.single, allOf(contains('first'), contains('second')));
    });

    test('reports a negative offset', () {
      expect(layoutProblems(const [_Field('a', -1, 4)]), hasLength(1));
    });

    test('reports a non-positive length', () {
      expect(layoutProblems(const [_Field('a', 0, 0)]), hasLength(1));
    });

    test('detects overlap regardless of declaration order', () {
      // Enum values are declared in source order, which is usually offset
      // order — but nothing enforces that, so the check must not assume it.
      expect(
        layoutProblems(const [_Field('late', 8, 4), _Field('early', 6, 4)]),
        hasLength(1),
      );
    });
  });

  group('layoutProblems with a struct size', () {
    test('is empty when the last field ends exactly at the size', () {
      expect(
        layoutProblems(
          const [_Field('a', 0, 4), _Field('b', 4, 8)],
          structSize: 12,
        ),
        isEmpty,
      );
    });

    test('reports a layout that stops short of the declared size', () {
      // This is the assertion whose absence caused the stride bug: a struct
      // size believed to be 352 while the fields only account for 344 means
      // one of the two is wrong, and reading at that stride corrupts.
      final problems = layoutProblems(
        const [_Field('a', 0, 4)],
        structSize: 352,
      );

      expect(problems, hasLength(1));
      expect(problems.single, allOf(contains('352'), contains('4')));
    });

    test('reports a field running past the declared size', () {
      expect(
        layoutProblems(const [_Field('a', 0, 16)], structSize: 8),
        isNotEmpty,
      );
    });
  });
}
