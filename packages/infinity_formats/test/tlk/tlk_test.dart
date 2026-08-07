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

import 'dart:io';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/synthetic_tlk.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('infinity_tlk'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<Tlk> open(
    List<String> strings, {
    String signature = 'TLK ',
    String version = 'V1  ',
    int? overrunEntry,
    int? strBaseOverride,
  }) {
    final bytes = buildTlk(
      strings,
      signature: signature,
      version: version,
      overrunEntry: overrunEntry,
      strBaseOverride: strBaseOverride,
    );
    return Tlk.open(writeTlkFixture(tmp, bytes));
  }

  group('header', () {
    test('accepts a well-formed TLK V1 and reports its entry count', () async {
      final tlk = await open(['one', 'two', 'three']);
      addTearDown(tlk.close);

      expect(tlk.length, 3);
    });

    test('rejects a wrong signature, naming what it found', () async {
      await expectLater(
        open(['x'], signature: 'BIFF'),
        throwsA(
          isA<InfinityFormatException>().having(
            (e) => e.message,
            'message',
            contains('BIFF'),
          ),
        ),
      );
    });

    test('rejects a wrong version, naming what it found', () async {
      await expectLater(
        open(['x'], version: 'V2  '),
        throwsA(
          isA<InfinityFormatException>().having(
            (e) => e.message,
            'message',
            contains('V2'),
          ),
        ),
      );
    });

    test('rejects a file too short to hold a header', () async {
      final path = writeTlkFixture(tmp, Uint8List.fromList([0x54, 0x4c, 0x4b]));
      await expectLater(
        Tlk.open(path),
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });

  group('entry table', () {
    test('reads strBase from the header rather than computing it', () async {
      // Bodies are 'AAA' then 'BBB', laid out contiguously at the natural
      // strBase. Shifting the *declared* strBase one byte right means entry 0
      // (offset 0, length 3) spans the boundary and reads 'AAB'. A codec that
      // recomputed 18 + count * 26 would still read 'AAA' and fail here.
      final tlk = await open(['AAA', 'BBB'], strBaseOverride: 71);
      addTearDown(tlk.close);

      expect(tlk.length, 2);
      expect(await tlk.get(0), 'AAB');
    });

    test('addresses each entry at a 26-byte stride', () async {
      final tlk = await open(['first', 'second', 'third', 'fourth']);
      addTearDown(tlk.close);

      expect(await tlk.get(0), 'first');
      expect(await tlk.get(3), 'fourth');
    });
  });

  group('decoding', () {
    test('decodes a three-byte UTF-8 sequence as one character', () async {
      // e2 80 94. cp1252 would encode an em dash as the single byte 0x97, and
      // String.fromCharCodes would yield three characters here.
      final tlk = await open(['Why you—']);
      addTearDown(tlk.close);

      final s = await tlk.get(0);
      expect(s, 'Why you—');
      expect(s!.length, 8);
    });

    test('decodes a two-byte UTF-8 sequence as one character', () async {
      // c3 a3. latin1 would render this as two characters, 'Ã£'.
      final tlk = await open(['não']);
      addTearDown(tlk.close);

      final s = await tlk.get(0);
      expect(s, 'não');
      expect(s!.length, 3);
    });

    test('decodes text outside cp1252 entirely', () async {
      final tlk = await open(['Ну и ладно.']);
      addTearDown(tlk.close);

      expect(await tlk.get(0), 'Ну и ладно.');
    });

    test('trims a trailing NUL but keeps the text before it', () async {
      // IESDP: some classic-era strings are NUL-terminated, others are not.
      // BG:EE has none, so this is a no-op there and correctness elsewhere.
      final tlk = await open(['Candlekeep\u0000']);
      addTearDown(tlk.close);

      expect(await tlk.get(0), 'Candlekeep');
    });
  });

  group('bounds', () {
    test('a zero-length entry is the empty string, not null', () async {
      final tlk = await open(['', 'after']);
      addTearDown(tlk.close);

      expect(await tlk.get(0), '');
      expect(await tlk.get(1), 'after');
    });

    test('strref -1 is null, not a sentinel string', () async {
      // The protagonist's CRE carries 0xFFFFFFFF here. A '<invalid>' sentinel
      // manufactured in the data layer would reach the UI as display text.
      final tlk = await open(['one']);
      addTearDown(tlk.close);

      expect(await tlk.get(-1), isNull);
    });

    test('a strref past the end is null', () async {
      final tlk = await open(['one', 'two']);
      addTearDown(tlk.close);

      expect(await tlk.get(2), isNull);
      expect(await tlk.get(99999), isNull);
    });

    test('an entry running past EOF throws rather than truncating', () async {
      final tlk = await open(['one', 'two'], overrunEntry: 1);
      addTearDown(tlk.close);

      await expectLater(tlk.get(1), throwsA(isA<InfinityFormatException>()));
    });
  });

  group('cache', () {
    test('serves a repeated lookup without touching the file', () async {
      final tlk = await open(['cached', 'uncached']);

      expect(await tlk.get(0), 'cached');
      await tlk.close();

      // A cache hit needs no I/O and still answers; a miss must reach the
      // closed handle and fail. Asserting both proves the cache did the work.
      expect(await tlk.get(0), 'cached');
      await expectLater(tlk.get(1), throwsA(isA<FileSystemException>()));
    });
  });
}
