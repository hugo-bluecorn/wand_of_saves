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

import 'dart:convert';
import 'dart:typed_data';

import 'package:infinity_formats/src/text/fixed_field.dart';
import 'package:test/test.dart';

void main() {
  Uint8List field(List<int> content, int width) =>
      Uint8List(width)..setRange(0, content.length, content);

  test('stops at the first NUL', () {
    // Measured on a real save: `Aard` followed by 28 NULs in a 32-byte name.
    final bytes = field(utf8.encode('Aard'), 32);

    expect(decodeFixedString(bytes, 0, 32), 'Aard');
  });

  test('reads a field that is exactly full, with no terminator', () {
    // `*HARBASE` is 8 characters in an 8-byte resref: no room for a NUL, so
    // a decoder that requires one would lose the last character.
    final bytes = field(utf8.encode('*HARBASE'), 8);

    expect(decodeFixedString(bytes, 0, 8), '*HARBASE');
  });

  test('is empty when the field is all NUL', () {
    expect(decodeFixedString(Uint8List(8), 0, 8), isEmpty);
  });

  test('ignores anything after the terminator', () {
    // Buffers get reused; stale bytes past the NUL are not part of the value.
    final bytes = field([...utf8.encode('*SPREY'), 0, 0x7f], 8);

    expect(decodeFixedString(bytes, 0, 8), '*SPREY');
  });

  test('decodes multi-byte UTF-8', () {
    final bytes = field(utf8.encode('Ægir'), 32);

    expect(decodeFixedString(bytes, 0, 32), 'Ægir');
  });

  test('preserves spaces the player typed', () {
    // The spike trimmed whitespace. That is wrong for a display name: real
    // fields are NUL-padded, so a trailing space is something someone typed,
    // not padding to discard.
    final bytes = field(utf8.encode(' Sir Bob '), 32);

    expect(decodeFixedString(bytes, 0, 32), ' Sir Bob ');
  });

  test('reads at an offset within a larger buffer', () {
    final bytes = Uint8List(64)..setRange(16, 16 + 4, utf8.encode('Imoe'));

    expect(decodeFixedString(bytes, 16, 8), 'Imoe');
  });
}
