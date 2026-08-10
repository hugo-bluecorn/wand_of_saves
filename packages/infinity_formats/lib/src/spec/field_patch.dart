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
import 'package:infinity_formats/src/spec/format_field.dart';
import 'package:infinity_formats/src/text/fixed_field.dart';

/// One patch routine for every fixed-width field, in every document.
///
/// Keyed on [FormatField] so width and signedness always come from the layout
/// table (D6) and never from the call site.
///
/// **One copy, deliberately.** A savegame and an exported character carry the
/// *same* creature record, so patching a field in one has to mean exactly what
/// it means in the other. Two implementations of this `switch` would be two
/// chances for them to disagree — which the user would meet as "that field only
/// works when I open the save".
///
/// Returns a patched **copy**; nothing is mutated, so everything the codec does
/// not understand survives untouched.
///
/// Throws [InfinityFormatException] if [value] does not fit [field], or if the
/// field would land outside the buffer. Both are refused rather than truncated
/// or allowed to wrap: a file that loads and is quietly wrong is worse than one
/// that fails loudly.
Uint8List patchedField({
  required Uint8List bytes,
  required int base,
  required FormatField field,
  required int value,
  required String what,
}) {
  final at = base + field.offset;
  if (base < 0 || at + field.length > bytes.length) {
    throw InfinityFormatException.truncated(
      what: what,
      expected: at + field.length,
      actual: bytes.length,
      offset: at,
    );
  }
  if (!field.holds(value)) {
    throw InfinityFormatException.valueOutOfRange(
      what: '$field',
      value: value,
      minimum: field.minimum,
      maximum: field.maximum,
    );
  }

  final copy = Uint8List.fromList(bytes);
  final view = ByteData.sublistView(copy);
  switch ((field.length, field.signed)) {
    case (1, false):
      view.setUint8(at, value);
    case (1, true):
      view.setInt8(at, value);
    case (2, false):
      view.setUint16(at, value, Endian.little);
    case (2, true):
      view.setInt16(at, value, Endian.little);
    case (4, false):
      view.setUint32(at, value, Endian.little);
    case (4, true):
      view.setInt32(at, value, Endian.little);
    case _:
      throw InfinityFormatException.unreadableField(
        what: '$field',
        length: field.length,
      );
  }
  return copy.asUnmodifiableView();
}

/// The text counterpart to [patchedField], for the resref fields.
///
/// One copy for both documents, for the same reason [patchedField] has one: a
/// savegame and an exported character carry the same record, so writing a
/// portrait resref has to mean the same thing in either.
///
/// Throws [InfinityFormatException] if [value] does not fit [field], or if the
/// field would land outside the buffer.
Uint8List patchedTextField({
  required Uint8List bytes,
  required int base,
  required FormatField field,
  required String value,
  required String what,
}) {
  final at = base + field.offset;
  if (base < 0 || at + field.length > bytes.length) {
    throw InfinityFormatException.truncated(
      what: what,
      expected: at + field.length,
      actual: bytes.length,
      offset: at,
    );
  }

  // Encoded first, so a value that will not fit is refused before anything is
  // copied -- the failure leaves no half-written buffer to reason about.
  final encoded = encodeFixedString(value, field.length);
  return (Uint8List.fromList(
    bytes,
  )..setRange(at, at + field.length, encoded)).asUnmodifiableView();
}
