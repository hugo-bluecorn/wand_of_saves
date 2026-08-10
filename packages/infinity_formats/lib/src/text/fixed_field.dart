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

import 'package:infinity_formats/src/exceptions.dart';

/// Decodes the fixed-width string field of [length] bytes at [offset].
///
/// Infinity Engine pads these with NUL, verified on a real save: an 8-byte
/// resref holds `*SPREY\0\0`, a 32-byte name holds `Aard` followed by 28
/// NULs — and `*HARBASE` fills its whole field with no terminator at all, so a
/// decoder that *requires* one would silently drop the last character.
///
/// Anything after the first NUL is ignored: buffers get reused, and stale
/// bytes past the terminator are not part of the value.
///
/// **Whitespace is preserved.** The spike trimmed it; that is wrong here.
/// Padding is NUL, so a leading or trailing space in a display name is
/// something a player typed, not padding to throw away.
///
/// Decoded as UTF-8, consistent with the rest of this library — see
/// `docs/findings/verified-format-offsets.md` §Encoding for why that is not
/// cp1252.
String decodeFixedString(Uint8List bytes, int offset, int length) {
  final field = Uint8List.sublistView(bytes, offset, offset + length);
  final end = field.indexOf(0);
  return utf8.decode(end < 0 ? field : Uint8List.sublistView(field, 0, end));
}

/// Encodes [value] into a NUL-padded field of exactly [length] bytes.
///
/// The counterpart to [decodeFixedString], and the one this project went
/// without until an edit needed to *write* text — a portrait resref.
///
/// ⚠️ **Refuses rather than truncates.** A value too long throws, matching what
/// `patchedField` already does for a number that will not fit. A resref
/// silently cut to eight bytes is a portrait that silently does not load, which
/// is precisely the quietly-wrong failure this project is shaped around.
///
/// Measured in **bytes, not characters**, because the field is bytes and the
/// encoding is UTF-8 — a name that fits in characters need not fit in the
/// field.
///
/// An empty [value] clears the field, which is how "no portrait" is written.
///
/// Throws [InfinityFormatException] if the encoded value does not fit.
Uint8List encodeFixedString(String value, int length) {
  final encoded = utf8.encode(value);
  if (encoded.length > length) {
    throw InfinityFormatException.valueOutOfRange(
      what: 'a $length-byte text field',
      value: encoded.length,
      minimum: 0,
      maximum: length,
    );
  }
  return Uint8List(length)..setRange(0, encoded.length, encoded);
}
