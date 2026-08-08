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
  const _Field(this._label, this.offset, this.length, {this.signed = false});

  final String _label;

  @override
  final int offset;
  @override
  final int length;
  @override
  final bool signed;

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

  group('bounds', () {
    // These six lines decide whether a value is written or refused, so a
    // boundary that is off by one is the difference between a saved edit and a
    // wrapped number in someone's savegame.

    test('an unsigned field spans zero to all-ones', () {
      expect(const _Field('byte', 0, 1).minimum, 0);
      expect(const _Field('byte', 0, 1).maximum, 255);
      expect(const _Field('word', 0, 2).maximum, 65535);
      expect(const _Field('dword', 0, 4).maximum, 4294967295);
    });

    test('a signed field spans two-s complement', () {
      const byte = _Field('byte', 0, 1, signed: true);
      const word = _Field('word', 0, 2, signed: true);
      const dword = _Field('dword', 0, 4, signed: true);

      expect((byte.minimum, byte.maximum), (-128, 127));
      expect((word.minimum, word.maximum), (-32768, 32767));
      expect((dword.minimum, dword.maximum), (-2147483648, 2147483647));
    });

    test('holds accepts the ends and refuses one past them', () {
      const field = _Field('byte', 0, 1);

      expect(field.holds(0), isTrue);
      expect(field.holds(255), isTrue);
      expect(field.holds(-1), isFalse);
      expect(field.holds(256), isFalse);
    });

    test('signedness moves the boundary rather than widening it', () {
      // Both hold 256 distinct values; a signed byte simply cannot hold 200.
      expect(const _Field('u', 0, 1).holds(200), isTrue);
      expect(const _Field('s', 0, 1, signed: true).holds(200), isFalse);
      expect(const _Field('s', 0, 1, signed: true).holds(-100), isTrue);
      expect(const _Field('u', 0, 1).holds(-100), isFalse);
    });
  });
}
