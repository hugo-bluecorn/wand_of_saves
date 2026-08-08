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

import 'package:infinity_formats/src/exceptions.dart';
import 'package:infinity_formats/src/text/fixed_field.dart';

/// A `BIFF` archive — the container `chitin.key` points into.
///
/// **Uncompressed only, and that is a measurement rather than a limitation
/// accepted blindly.** All 83 archives of a BG:EE install carry the plain
/// `BIFFV1  ` signature, so no decompressor is needed for this game. The
/// compressed variants (`BIF V1.0`, `BIFCV1.0`) belong to other titles, which
/// D3 puts out of scope; a file carrying one is refused by name rather than
/// misread.
final class BifArchive {
  const BifArchive._(this._bytes, this._entryTable, this.resourceCount);

  /// Reads an archive from its bytes.
  ///
  /// Throws [InfinityFormatException] on a signature or version this codec
  /// does not read, or when the entry table runs past the end.
  factory BifArchive.parse(Uint8List bytes, {Object? source}) {
    if (bytes.length < headerSize) {
      throw InfinityFormatException.truncated(
        what: 'BIFF header',
        expected: headerSize,
        actual: bytes.length,
        source: source,
      );
    }
    final signature = decodeFixedString(bytes, 0, 4);
    if (signature != _signature) {
      throw InfinityFormatException.badSignature(
        expected: _signature,
        found: signature,
        source: source,
      );
    }
    final version = decodeFixedString(bytes, 4, 4);
    if (version != supportedVersion) {
      throw InfinityFormatException.unsupportedVersion(
        found: version,
        supported: const {supportedVersion},
        source: source,
      );
    }

    final view = ByteData.sublistView(bytes);
    final count = view.getUint32(8, Endian.little);
    // Tileset entries follow the file entries and are not read here.
    final table = view.getUint32(16, Endian.little);
    if (table + count * entrySize > bytes.length) {
      throw InfinityFormatException.truncated(
        what: 'BIFF file table',
        expected: table + count * entrySize,
        actual: bytes.length,
        source: source,
      );
    }

    return BifArchive._(bytes, table, count);
  }

  /// Bytes before the file-entry table pointer is resolved.
  static const int headerSize = 20;

  /// Bytes per file entry: locator, offset, size, type, unused.
  static const int entrySize = 16;

  static const String _signature = 'BIFF';

  /// The only version this codec reads. See the class note.
  static const String supportedVersion = 'V1  ';

  final Uint8List _bytes;
  final int _entryTable;

  /// How many file entries the archive holds.
  final int resourceCount;

  /// The bytes of entry [index], as a view rather than a copy.
  ///
  /// [index] comes from `KeyIndex.locate`'s `file` field. Throws
  /// [RangeError] if it is outside the table and [InfinityFormatException] if
  /// the entry claims bytes the archive does not have.
  Uint8List resource(int index) {
    RangeError.checkValidIndex(index, this, 'index', resourceCount);
    final view = ByteData.sublistView(_bytes);
    final entry = _entryTable + index * entrySize;
    final offset = view.getUint32(entry + 4, Endian.little);
    final size = view.getUint32(entry + 8, Endian.little);
    if (offset + size > _bytes.length) {
      throw InfinityFormatException.truncated(
        what: 'BIFF entry $index',
        expected: offset + size,
        actual: _bytes.length,
      );
    }
    return Uint8List.sublistView(_bytes, offset, offset + size);
  }

  /// So [RangeError.checkValidIndex] can report a sensible length.
  int get length => resourceCount;

  @override
  String toString() => 'BifArchive($resourceCount resources)';
}
