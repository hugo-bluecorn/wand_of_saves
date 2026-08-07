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

/// Builds TLK V1 images so the app's suite needs no game data.
///
/// The real `dialog.tlk` is BioWare's copyright and cannot be committed.
///
/// `packages/infinity_formats` has a fuller builder of its own, under its
/// `test/`, which is **not reachable from here** — test directories are not
/// part of a package's public surface. Duplicating twenty lines of header
/// writing is cheaper and less invasive than exporting test helpers from the
/// library, so this is deliberate rather than an oversight.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Bytes before the entry array. The format hardcodes this.
const int tlkHeaderSize = 18;

/// Bytes per entry in the strref table.
const int tlkEntrySize = 26;

/// Writes a TLK V1 file into [dir] holding [strings], and returns its path.
///
/// Strings are encoded **UTF-8**, which is what BG:EE ships — an earlier
/// project-wide claim of cp1252 was falsified against the real game data.
String writeTlk(
  Directory dir,
  List<String> strings, {
  String name = 'dialog.tlk',
  String signature = 'TLK ',
}) {
  final bodies = [for (final s in strings) utf8.encode(s)];
  final stringBase = tlkHeaderSize + bodies.length * tlkEntrySize;
  final bodyBytes = bodies.fold<int>(0, (sum, b) => sum + b.length);

  final out = Uint8List(stringBase + bodyBytes);
  final data = ByteData.sublistView(out);

  out
    ..setRange(0, 4, ascii.encode(signature))
    ..setRange(4, 8, ascii.encode('V1  '));
  data
    ..setUint32(0x0a, bodies.length, Endian.little)
    ..setUint32(0x0e, stringBase, Endian.little);

  var cursor = 0;
  for (var i = 0; i < bodies.length; i++) {
    final entry = tlkHeaderSize + i * tlkEntrySize;
    data
      ..setUint16(entry, bodies[i].isEmpty ? 0 : 1, Endian.little)
      ..setUint32(entry + 0x12, cursor, Endian.little)
      ..setUint32(entry + 0x16, bodies[i].length, Endian.little);
    out.setRange(
      stringBase + cursor,
      stringBase + cursor + bodies[i].length,
      bodies[i],
    );
    cursor += bodies[i].length;
  }

  final file = File('${dir.path}${Platform.pathSeparator}$name')
    ..writeAsBytesSync(out);
  return file.path;
}
