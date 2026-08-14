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

/// Builds the 20-byte item entry the items section holds.
///
/// Beside `spell_entry.dart` and for the same reason: the layout table has one
/// copy, and a builder that wrote raw offsets would be a second.
library;

import 'dart:typed_data';

import 'package:infinity_formats/src/spec/cre_v1_0.dart';
import 'package:infinity_formats/src/text/fixed_field.dart';

/// An item entry: one thing the creature is carrying.
///
/// ⚠️ **[flags] defaults to identified, and that is a decision rather than a
/// convenience.** With the bit clear the engine draws the ITM's *unidentified*
/// name — a Belt of Antipode appears as "Belt" — so an item added by an editor
/// would arrive looking like a defect. A caller that wants the unidentified
/// state asks for it.
///
/// [quantity] fills the first count only. The second and third are charges for
/// an item's later abilities, which nothing writes yet.
///
/// Throws [ArgumentError] if [resref] does not fit the eight-byte field, rather
/// than silently truncating it into a resource that does not exist.
Uint8List itemEntry({
  required String resref,
  int quantity = 1,
  Set<CreItemFlag> flags = const {CreItemFlag.identified},
  int expiration = 0,
}) {
  if (resref.length > CreItemField.resref.length) {
    throw ArgumentError.value(
      resref,
      'resref',
      'is longer than the ${CreItemField.resref.length}-byte field',
    );
  }

  final out = Uint8List(creItemLength)
    ..setRange(
      CreItemField.resref.offset,
      CreItemField.resref.offset + CreItemField.resref.length,
      encodeFixedString(resref, CreItemField.resref.length),
    );
  ByteData.sublistView(out)
    ..setUint16(CreItemField.expiration.offset, expiration, Endian.little)
    ..setUint16(CreItemField.quantity1.offset, quantity, Endian.little)
    ..setUint32(
      CreItemField.flags.offset,
      CreItemFlag.maskOf(flags),
      Endian.little,
    );
  return out;
}
