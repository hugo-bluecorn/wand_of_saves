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

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

void main() {
  Uint8List seed() =>
      Uint8List(CreHeaderField.headerSize)
        ..setRange(0, 8, latin1.encode('CRE V1.0'));

  group('a new character', () {
    test('reads back as a CHR V2.0 with the name given', () {
      final chr = ChrCodec.blank(name: 'Aurel', record: seed());

      expect(ChrCodec.decode(ChrCodec.encode(chr)).name, 'Aurel');
    });

    test('wraps the record without touching it', () {
      // ⚠️ CHARBASE is the engine's own template, so it is copied, never
      // rebuilt from the fields a model happens to understand.
      final record = seed();

      expect(ChrCodec.blank(name: 'Aurel', record: record).creBytes, record);
    });

    test('puts the record at 100 and closes on the file length', () {
      final chr = ChrCodec.blank(name: 'Aurel', record: seed());

      expect(chr.creOffset, ChrHeaderField.headerSize);
      expect(chr.creOffset + chr.creLength, chr.bytes.length);
    });

    test('carries no quick slots, because it carries nothing', () {
      // 0xFFFF per word: "none" for a slot, "disabled" for an ability. Copying
      // a live character's block would point at items that are not there.
      final chr = ChrCodec.blank(name: 'Aurel', record: seed());

      expect(
        chr.bytes.sublist(
          ChrHeaderField.quickSlotsOffset,
          ChrHeaderField.headerSize,
        ),
        everyElement(0xFF),
      );
    });

    test('refuses a name too long for the field', () {
      expect(
        () => ChrCodec.blank(name: 'x' * 33, record: seed()),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('is editable exactly as an exported one is', () {
      final chr = ChrCodec.blank(name: 'Aurel', record: seed());

      final edited = chr.withCreatureField(
        creOffset: chr.creOffset,
        field: CreHeaderField.strength,
        value: 18,
      );

      expect(CreCodec.decode(edited.creBytes).strength, 18);
    });
  });
}
