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
import 'dart:io';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/layout.dart';

/// A minimal well-formed `.chr`, for the cases a real fixture cannot produce.
///
/// Real exported characters are all valid by construction, so every rejection
/// path needs a file built to be wrong — the same reason `synthetic_gam.dart`
/// exists.
Uint8List buildChr({
  String signature = 'CHR ',
  String version = 'V2.0',
  String name = 'Testy',
  int? creOffset,
  int? creLength,
  int? truncateTo,
}) {
  final cre = Uint8List(CreHeaderField.headerSize)
    ..setRange(0, 8, latin1.encode('CRE V1.0'));
  final offset = creOffset ?? ChrHeaderField.headerSize;
  final length = creLength ?? cre.length;

  final bytes = Uint8List(ChrHeaderField.headerSize + cre.length);
  bytes
    ..setRange(0, 4, latin1.encode(signature))
    ..setRange(4, 8, latin1.encode(version))
    ..setRange(8, 8 + name.length, utf8.encode(name))
    ..setRange(ChrHeaderField.headerSize, bytes.length, cre);
  ByteData.sublistView(bytes)
    ..setUint32(ChrHeaderField.creOffset.offset, offset, Endian.little)
    ..setUint32(ChrHeaderField.creLength.offset, length, Endian.little);

  if (truncateTo == null) return bytes;
  return Uint8List.sublistView(bytes, 0, truncateTo);
}

void main() {
  final names = fixtureChrNames();

  group('ChrHeaderField layout', () {
    test('accounts for exactly the 100 bytes before the record', () {
      expect(
        layoutProblems(
          ChrHeaderField.values,
          structSize: ChrHeaderField.headerSize,
        ),
        isEmpty,
      );
    });

    test('the header ends where the record begins', () {
      // 0x30 + 52 bytes of quick slots. Every .chr measured stores exactly this
      // in its CRE-offset field, but the field is still read rather than
      // assumed -- see ChrCodec.decode.
      expect(ChrHeaderField.headerSize, 100);
    });
  });

  group('header validation', () {
    test('accepts a well-formed CHR V2.0', () {
      expect(ChrCodec.decode(buildChr()).name, 'Testy');
    });

    test('rejects a wrong signature, naming what it found', () {
      expect(
        () => ChrCodec.decode(buildChr(signature: 'GAME')),
        throwsA(
          isA<InfinityFormatException>().having(
            (e) => e.message,
            'message',
            contains('GAME'),
          ),
        ),
      );
    });

    test('rejects CHR V2.1 by name rather than reading it as V2.0', () {
      // Reachable from this app's own edits: the engine writes V2.1 once
      // experience passes startare.2da's START_XP_CAP, which is 161000 -- and
      // this app can set experience. A version no file has been measured of is
      // refused, not guessed at.
      expect(
        () => ChrCodec.decode(buildChr(version: 'V2.1')),
        throwsA(
          isA<InfinityFormatException>().having(
            (e) => e.message,
            'message',
            contains('V2.1'),
          ),
        ),
      );
    });

    test('rejects a file too short to hold the documented header', () {
      expect(
        () => ChrCodec.decode(buildChr(truncateTo: 64)),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('rejects a record that runs past the end of the file', () {
      // The one check that cannot be skipped: creLength is the single pointer
      // this format has, and believing a wrong one reads whatever follows in
      // the buffer as a creature.
      expect(
        () => ChrCodec.decode(buildChr(creLength: 999999)),
        throwsA(
          isA<InfinityFormatException>().having(
            (e) => e.message,
            'message',
            contains('CRE'),
          ),
        ),
      );
    });

    test('rejects a record offset inside the header', () {
      expect(
        () => ChrCodec.decode(buildChr(creOffset: 8)),
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });

  group(
    'real exported characters',
    () {
      test(
        'there are fixtures to read',
        () {
          expect(names, isNotEmpty);
        },
        skip: names.isEmpty ? 'run tool/dev/sync_fixtures.dart' : null,
      );

      for (final name in names) {
        group(name, () {
          late Uint8List bytes;
          late Chr chr;

          setUp(() {
            bytes = File(fixtureChr(name)!).readAsBytesSync();
            chr = ChrCodec.decode(bytes, source: name);
          });

          test('round-trips byte for byte', () {
            expect(ChrCodec.encode(chr), bytes);
          });

          test(
            'the record is at 100 and closes exactly on the file length',
            () {
              expect(chr.creOffset, 100);
              expect(chr.creOffset + chr.creLength, bytes.length);
            },
          );

          test('embeds a CRE V1.0, not the v2.0 IESDP documents', () {
            // IESDP's CHR V2.0 page says the embedded file is a "CRE v2.0".
            // On BG:EE it is V1.0 -- the record CreCodec already reads.
            // Dispatch on the embedded signature, never on the CHR version.
            expect(latin1.decode(chr.creBytes.sublist(0, 8)), 'CRE V1.0');
            expect(() => CreCodec.decode(chr.creBytes), returnsNormally);
          });

          test('the name lives in the header, not in the record', () {
            // A .chr carries no identity key inside the creature: dialogFile is
            // eight zero bytes and longNameStrref is -1 on every file measured.
            // The 32-byte header name is the only name there is.
            final cre = CreCodec.decode(chr.creBytes);
            expect(chr.name, isNotEmpty);
            expect(cre.dialogFile, isEmpty);
            expect(cre.longNameStrref, -1);
          });
        });
      }
    },
    skip: names.isEmpty ? 'run tool/dev/sync_fixtures.dart' : null,
  );
}
