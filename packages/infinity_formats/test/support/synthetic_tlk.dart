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

/// Builds TLK V1 images in memory so the codec suite needs no game data.
///
/// The real `dialog.tlk` is BioWare's copyright and cannot be committed, so the
/// logic tests run against files built here. Real files are used only to
/// *confirm* documented values, in a test that skips when the game is absent.
///
/// Layout per IESDP `file_formats/ie_formats/tlk_v1.htm`, cross-checked against
/// measurements recorded in `docs/findings/verified-format-offsets.md` §TLK.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Bytes before the entry array. The format hardcodes this; it is not derived.
const int tlkHeaderSize = 18;

/// Bytes per entry in the strref table.
const int tlkEntrySize = 26;

/// Builds a TLK V1 image whose strings are [strings], encoded UTF-8.
///
/// Defaults produce a well-formed file. Each other parameter introduces one
/// specific malformation so error paths can be tested in isolation:
///
/// * [signature] / [version] — wrong magic.
/// * [overrunEntry] — index of an entry whose declared length runs past EOF.
/// * [strBaseOverride] — a string-data offset that disagrees with the layout.
Uint8List buildTlk(
  List<String> strings, {
  String signature = 'TLK ',
  String version = 'V1  ',
  int languageId = 0,
  int? overrunEntry,
  int? strBaseOverride,
}) {
  final bodies = [for (final s in strings) utf8.encode(s)];
  final count = bodies.length;
  final strBase = tlkHeaderSize + count * tlkEntrySize;
  final bodyBytes = bodies.fold<int>(0, (sum, b) => sum + b.length);

  final out = Uint8List(strBase + bodyBytes);
  final data = ByteData.sublistView(out);

  out
    ..setRange(0, 4, _fixedAscii(signature, 4))
    ..setRange(4, 8, _fixedAscii(version, 4));
  data
    ..setUint16(8, languageId, Endian.little)
    ..setUint32(10, count, Endian.little)
    ..setUint32(14, strBaseOverride ?? strBase, Endian.little);

  var cursor = 0;
  for (var i = 0; i < count; i++) {
    final entry = tlkHeaderSize + i * tlkEntrySize;
    // Bit 0 is "text exists"; sound resref, volume and pitch stay zero.
    data
      ..setUint16(entry, bodies[i].isEmpty ? 0 : 1, Endian.little)
      ..setUint32(entry + 0x12, cursor, Endian.little)
      ..setUint32(
        entry + 0x16,
        i == overrunEntry ? bodyBytes + 64 : bodies[i].length,
        Endian.little,
      );
    out.setRange(
      strBase + cursor,
      strBase + cursor + bodies[i].length,
      bodies[i],
    );
    cursor += bodies[i].length;
  }
  return out;
}

/// Writes [bytes] into [dir] and returns the path, for APIs that take a path.
String writeTlkFixture(
  Directory dir,
  Uint8List bytes, {
  String name = 'x.tlk',
}) {
  final file = File('${dir.path}${Platform.pathSeparator}$name')
    ..writeAsBytesSync(bytes);
  return file.path;
}

/// [text] as exactly [width] bytes: truncated, or right-padded with spaces.
///
/// Signature and version are fixed-width ASCII fields; `'V1  '` is genuinely
/// two trailing spaces, not padding this function invented.
Uint8List _fixedAscii(String text, int width) {
  final out = Uint8List(width)..fillRange(0, width, 0x20);
  final bytes = ascii.encode(text);
  out.setRange(
    0,
    bytes.length < width ? bytes.length : width,
    bytes.take(width).toList(),
  );
  return out;
}
