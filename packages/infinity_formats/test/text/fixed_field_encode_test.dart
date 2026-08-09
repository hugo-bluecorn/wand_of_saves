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

import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:infinity_formats/src/text/fixed_field.dart';
import 'package:test/test.dart';

void main() {
  group('encodeFixedString', () {
    test('pads with NUL to the full width', () {
      // What the engine writes: an 8-byte resref holding `BDTMIL` fills the
      // remaining two bytes with NUL, verified on real records.
      expect(
        encodeFixedString('BDTMIL', 8),
        Uint8List.fromList([66, 68, 84, 77, 73, 76, 0, 0]),
      );
    });

    test('fills the field exactly when the value is the full width', () {
      // `*HARBASE` fills its 8 bytes with no terminator at all, which is why
      // the decoder does not require one.
      expect(encodeFixedString('AJANTISL', 8), hasLength(8));
      expect(
        decodeFixedString(encodeFixedString('AJANTISL', 8), 0, 8),
        'AJANTISL',
      );
    });

    test('round-trips through the decoder', () {
      expect(decodeFixedString(encodeFixedString('Aurel', 32), 0, 32), 'Aurel');
    });

    test('refuses a value too long for the field rather than truncating', () {
      // ⚠️ The whole reason this exists as a checked function. A resref
      // silently cut to 8 bytes is a portrait that silently does not load, and
      // this project refuses rather than truncates everywhere else.
      expect(
        () => encodeFixedString('TOOLONGRESREF', 8),
        throwsA(
          isA<InfinityFormatException>().having(
            (e) => e.message,
            'message',
            contains('13'),
          ),
        ),
      );
    });

    test('measures bytes, not characters', () {
      // UTF-8, consistent with the decoder: a name that fits in characters may
      // not fit in bytes, and the field is bytes.
      expect(() => encodeFixedString('éééé', 4), throwsA(isA<Exception>()));
      expect(encodeFixedString('éé', 4), hasLength(4));
    });

    test('accepts an empty value, which clears the field', () {
      expect(encodeFixedString('', 8), Uint8List(8));
    });
  });
}
