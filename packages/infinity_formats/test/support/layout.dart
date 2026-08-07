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

/// The layout invariant every format's field table is held to.
///
/// One check, reused by every format, made possible by [FormatField] layouts
/// being enumerable (D6).
library;

import 'package:infinity_formats/infinity_formats.dart';

/// Everything wrong with [fields] as a structure layout; empty when sound.
///
/// Always checked: offsets are non-negative, lengths are positive, and no two
/// fields overlap. Overlap is checked on offset order rather than declaration
/// order, because nothing forces an enum to be declared in offset order.
///
/// When [structSize] is given, two further checks apply — no field may run
/// past it, and **the fields must account for exactly that many bytes**. That
/// second one is the assertion whose absence caused the stride bug: a struct
/// believed to be 352 bytes whose fields only reach 344 means one of the two
/// numbers is wrong, and reading an array at that stride corrupts everything
/// after the first element.
///
/// A table without [structSize] is a *verified subset* of a format — gaps are
/// expected there, so the exact-fit rule would be wrong to apply.
///
/// Returning problems rather than asserting keeps this testable in both
/// directions: a test can check that a broken layout is caught, not only that
/// a sound one passes.
List<String> layoutProblems(List<FormatField> fields, {int? structSize}) {
  final problems = <String>[];

  for (final field in fields) {
    if (field.offset < 0) {
      problems.add('$field has a negative offset (${field.offset})');
    }
    if (field.length <= 0) {
      problems.add(
        '$field has a non-positive length '
        '(${field.length})',
      );
    }
  }

  final byOffset = [...fields]..sort((a, b) => a.offset.compareTo(b.offset));
  for (var i = 1; i < byOffset.length; i++) {
    final earlier = byOffset[i - 1];
    final later = byOffset[i];
    if (earlier.offset + earlier.length > later.offset) {
      problems.add(
        '$earlier (${earlier.offset}+${earlier.length}) overlaps '
        '$later (at ${later.offset})',
      );
    }
  }

  if (structSize != null) {
    for (final field in fields) {
      final end = field.offset + field.length;
      if (end > structSize) {
        problems.add(
          '$field ends at $end, past the declared size $structSize',
        );
      }
    }
    final accounted = fields.fold<int>(
      0,
      (most, f) => f.offset + f.length > most ? f.offset + f.length : most,
    );
    if (accounted != structSize) {
      problems.add(
        'fields account for $accounted bytes but the declared struct size '
        'is $structSize',
      );
    }
  }

  return problems;
}
