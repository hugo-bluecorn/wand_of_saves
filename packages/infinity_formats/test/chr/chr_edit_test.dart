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

/// Editing an exported character, which must work exactly as editing a
/// savegame does — one sheet serves both documents, so one of them behaving
/// differently is a defect the user would meet as "this field only works in
/// one place".
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  final names = fixtureChrNames();

  Chr open(String name) =>
      ChrCodec.decode(File(fixtureChr(name)!).readAsBytesSync(), source: name);

  List<int> differences(Uint8List a, Uint8List b) => [
    for (var i = 0; i < a.length; i++)
      if (a[i] != b[i]) i,
  ];

  /// A value for [field] that is **not** the one already stored.
  ///
  /// ⚠️ **Never a literal.** These fixtures are exports of a character this
  /// app has already edited in earlier sessions -- Aard's Strength really is
  /// 19, written to prove the write path in game -- so writing a constant 19
  /// changes nothing and the test then fails claiming the writer is broken.
  /// That has now cost time twice in this repository.
  int somethingElse(Chr chr, CreHeaderField field) {
    final stored = chr.bytes[chr.creOffset + field.offset];
    return stored == 19 ? 18 : 19;
  }

  group('a fixed-width field inside the record', () {
    test('moves exactly the bytes it should', () {
      // The gate the savegame writer already passes, applied to the other
      // document: change one field and every other byte is untouched.
      final chr = open(names.first);

      final edited = chr.withCreatureField(
        creOffset: chr.creOffset,
        field: CreHeaderField.strength,
        value: somethingElse(chr, CreHeaderField.strength),
      );

      expect(edited.bytes, hasLength(chr.bytes.length));
      expect(differences(chr.bytes, edited.bytes), [
        chr.creOffset + CreHeaderField.strength.offset,
      ]);
    });

    test('reads back through the codec', () {
      final chr = open(names.first);
      final value = somethingElse(chr, CreHeaderField.strength);

      final edited = chr.withCreatureField(
        creOffset: chr.creOffset,
        field: CreHeaderField.strength,
        value: value,
      );

      expect(CreCodec.decode(edited.creBytes).strength, value);
    });

    test('leaves the header alone, so the record still closes on EOF', () {
      final chr = open(names.first);

      final edited = chr.withCreatureField(
        creOffset: chr.creOffset,
        field: CreHeaderField.thac0,
        value: somethingElse(chr, CreHeaderField.thac0),
      );

      expect(edited.creOffset, chr.creOffset);
      expect(edited.creOffset + edited.creLength, edited.bytes.length);
    });

    test('refuses a value the field cannot hold', () {
      // Refused rather than truncated: a wrapped number written into a
      // character is silent corruption, which is the failure this project is
      // shaped around.
      final chr = open(names.first);

      expect(
        () => chr.withCreatureField(
          creOffset: chr.creOffset,
          field: CreHeaderField.strength,
          value: 300,
        ),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('refuses an offset outside the file', () {
      final chr = open(names.first);

      expect(
        () => chr.withCreatureField(
          creOffset: chr.bytes.length,
          field: CreHeaderField.strength,
          value: 18,
        ),
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });

  group('a field inside an effect', () {
    test('moves exactly one byte of one dword', () {
      // Proficiencies live in effects on BG:EE, in an exported character
      // exactly as in a savegame -- the record is the same record.
      final chr = open(names.first);
      final cre = CreCodec.decode(chr.creBytes);
      final proficiency = cre.effects.firstWhere((e) => e.isProficiency);

      final edited = chr.withEffectField(
        creOffset: chr.creOffset,
        effectStart: proficiency.start,
        field: EffectV2Field.parameter1,
        value: proficiency.parameter1 + 1,
      );

      expect(differences(chr.bytes, edited.bytes), hasLength(1));
      expect(
        CreCodec.decode(edited.creBytes).proficiencies[proficiency.parameter2],
        proficiency.parameter1 + 1,
      );
    });
  });

  group('as a CreatureDocument', () {
    test('both documents satisfy the same interface', () {
      // What lets one character sheet drive both. The type argument is the
      // concrete document, so an edit to a Chr returns a Chr rather than
      // something the caller has to cast.
      final chr = open(names.first);

      expect(chr, isA<CreatureDocument<Chr>>());

      final CreatureDocument<Chr> document = chr;
      final luck = somethingElse(chr, CreHeaderField.luck);
      final edited = document.withCreatureField(
        creOffset: chr.creOffset,
        field: CreHeaderField.luck,
        value: luck,
      );

      expect(edited, isA<Chr>());
      expect(CreCodec.decode(edited.creBytes).luck, luck);
    });
  });
}
