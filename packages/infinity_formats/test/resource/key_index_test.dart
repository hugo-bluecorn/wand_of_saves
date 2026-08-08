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

/// Hermetic tests for the resource index. The confirmation against a real
/// `chitin.key` lives in `resource_index_integration_test.dart`; these cover
/// the paths a healthy installation never takes.
library;

import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

void main() {
  group('KeyIndex.parse', () {
    test('reads a minimal index', () {
      final index = KeyIndex.parse(_key());

      expect(index.archives, ['data/DEFAULT.BIF']);
      expect(index.resourceCount, 1);
      expect(index.locate('WEAPPROF', ResourceType.table2da), (
        archive: 0,
        file: 7,
      ));
    });

    test('unpacks the archive and file indices out of one locator', () {
      // The locator packs an archive index, a tileset index and a file index
      // into 32 bits; reading it as a flat number is a whole class of bug.
      final index = KeyIndex.parse(
        _key(locator: (5 << 20) | (3 << 14) | 1234),
      );

      expect(index.locate('WEAPPROF', ResourceType.table2da), (
        archive: 5,
        file: 1234,
      ));
    });

    test('turns the shipped backslashes into path separators', () {
      expect(KeyIndex.parse(_key()).archives.single, 'data/DEFAULT.BIF');
    });

    test('does not confuse two resources that differ only by type', () {
      // Resrefs are unique per type, not globally: an item and a 2DA may share
      // a name, and keying on the resref alone would silently return one for
      // the other.
      final index = KeyIndex.parse(
        _key(extra: (resref: 'WEAPPROF', type: ResourceType.item, locator: 99)),
      );

      expect(index.locate('WEAPPROF', ResourceType.table2da)?.file, 7);
      expect(index.locate('WEAPPROF', ResourceType.item)?.file, 99);
    });

    test('rejects a file that is not a key', () {
      expect(
        () => KeyIndex.parse(_key(signature: 'GAME')),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('rejects a version it has not been checked against', () {
      expect(
        () => KeyIndex.parse(_key(version: 'V2  ')),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('rejects a header too short to hold one', () {
      expect(
        () => KeyIndex.parse(Uint8List(8)),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('rejects a resource table that runs past the end', () {
      // The failure that matters: a count field nobody checked, read as a
      // loop bound, walks off the buffer.
      final bytes = _key();
      ByteData.sublistView(bytes).setUint32(12, 100000, Endian.little);

      expect(
        () => KeyIndex.parse(bytes),
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });

  group('BifArchive', () {
    test('returns the bytes of one entry', () {
      final archive = BifArchive.parse(_bif());

      expect(archive.resourceCount, 1);
      expect(archive.resource(0), [1, 2, 3, 4]);
    });

    test('refuses a compressed archive by name rather than misreading it', () {
      expect(
        () => BifArchive.parse(_bif(version: 'V1.0')),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('rejects an index outside the table', () {
      expect(() => BifArchive.parse(_bif()).resource(1), throwsRangeError);
    });

    test('rejects an entry claiming bytes the archive does not have', () {
      final bytes = _bif();
      // Entry size, at the table's +8.
      ByteData.sublistView(bytes).setUint32(20 + 8, 9999, Endian.little);

      expect(
        () => BifArchive.parse(bytes).resource(0),
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });
}

/// A one-archive, one-or-two-resource `chitin.key`.
Uint8List _key({
  String signature = 'KEY ',
  String version = 'V1  ',
  int locator = 7,
  ({String resref, ResourceType type, int locator})? extra,
}) {
  const nameOffset = 24;
  const name = r'data\DEFAULT.BIF';
  const archiveTable = nameOffset + name.length + 1;
  const resourceTable = archiveTable + KeyIndex.archiveEntrySize;
  final count = extra == null ? 1 : 2;

  final bytes = Uint8List(resourceTable + count * KeyIndex.entrySize);
  final view = ByteData.sublistView(bytes);
  bytes
    ..setRange(0, 4, signature.codeUnits)
    ..setRange(4, 8, version.codeUnits);
  view
    ..setUint32(8, 1, Endian.little)
    ..setUint32(12, count, Endian.little)
    ..setUint32(16, archiveTable, Endian.little)
    ..setUint32(20, resourceTable, Endian.little);

  bytes.setRange(nameOffset, nameOffset + name.length, name.codeUnits);
  view
    ..setUint32(archiveTable + 4, nameOffset, Endian.little)
    ..setUint16(archiveTable + 8, name.length + 1, Endian.little);

  void resource(int slot, String resref, ResourceType type, int at) {
    final entry = resourceTable + slot * KeyIndex.entrySize;
    bytes.setRange(entry, entry + resref.length, resref.codeUnits);
    view
      ..setUint16(entry + 8, type.code, Endian.little)
      ..setUint32(entry + 10, at, Endian.little);
  }

  resource(0, 'WEAPPROF', ResourceType.table2da, locator);
  if (extra != null) resource(1, extra.resref, extra.type, extra.locator);
  return bytes;
}

/// A one-entry `BIFF` holding the bytes `1 2 3 4`.
Uint8List _bif({String version = 'V1  '}) {
  const table = 20;
  const payload = table + BifArchive.entrySize;
  final bytes = Uint8List(payload + 4);
  final view = ByteData.sublistView(bytes);
  bytes
    ..setRange(0, 4, 'BIFF'.codeUnits)
    ..setRange(4, 8, version.codeUnits);
  view
    ..setUint32(8, 1, Endian.little)
    ..setUint32(16, table, Endian.little)
    ..setUint32(table + 4, payload, Endian.little)
    ..setUint32(table + 8, 4, Endian.little);
  bytes.setRange(payload, payload + 4, [1, 2, 3, 4]);
  return bytes;
}
