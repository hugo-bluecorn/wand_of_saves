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

/// Builders for the three spell-section entries.
///
/// Here rather than at the call site for the reason `proficiencyEffectTemplate`
/// is: the layout is a table (D6), and a caller assembling one from literals is
/// a second copy of that table waiting to disagree with the first. Each of
/// these writes through [CreKnownSpellField], [CreMemorizationField] or
/// [CreMemorizedSpellField], so the reader and the writer cannot drift.
library;

import 'dart:typed_data';

import 'package:infinity_formats/src/spec/cre_v1_0.dart';
import 'package:infinity_formats/src/spec/format_field.dart';
import 'package:infinity_formats/src/text/fixed_field.dart';

/// A known-spell entry: a spell the creature may prepare.
///
/// [level] is what a player counts — `1` for a first-level spell. The record
/// stores it less one, which is done here exactly once.
Uint8List knownSpellEntry({
  required String resref,
  required int level,
  required int type,
}) {
  final out = _entry(creKnownSpellLength, CreKnownSpellField.resref, resref);
  ByteData.sublistView(out)
    ..setUint16(CreKnownSpellField.levelLessOne.offset, level - 1, _le)
    ..setUint16(CreKnownSpellField.type.offset, type, _le);
  return out;
}

/// A memorisation row: one window of the memorised-spells array.
///
/// ⚠️ **[firstIndex] is a pointer into another section**, so a row is only
/// meaningful beside the array it describes. A new row opens at the end of that
/// array — which is what leaves every window already there untouched.
///
/// [memorisable] fills both counts, the plain one and the after-effects one.
/// They differ only when something is modifying the character's slots, which
/// nothing this project writes does; the engine's own created character has
/// them equal.
Uint8List memorizationRowEntry({
  required int level,
  required int type,
  required int memorisable,
  required int firstIndex,
  int count = 0,
}) {
  final out = Uint8List(creMemorizationInfoLength);
  ByteData.sublistView(out)
    ..setUint16(CreMemorizationField.levelLessOne.offset, level - 1, _le)
    ..setUint16(CreMemorizationField.memorisable.offset, memorisable, _le)
    ..setUint16(CreMemorizationField.afterEffects.offset, memorisable, _le)
    ..setUint16(CreMemorizationField.type.offset, type, _le)
    ..setUint32(CreMemorizationField.firstIndex.offset, firstIndex, _le)
    ..setUint32(CreMemorizationField.count.offset, count, _le);
  return out;
}

/// A memorised-spell entry: a spell prepared and ready to cast.
///
/// [memorized] is `false` for a spell that has been cast today — the engine
/// keeps the entry and clears the bit rather than removing it, which is how a
/// rest can put it back.
Uint8List memorizedSpellEntry({required String resref, bool memorized = true}) {
  final out = _entry(
    creMemorizedSpellLength,
    CreMemorizedSpellField.resref,
    resref,
  );
  ByteData.sublistView(out).setUint32(
    CreMemorizedSpellField.flags.offset,
    memorized ? creSpellMemorizedFlag : 0,
    _le,
  );
  return out;
}

/// A zeroed entry of [length] with [resref] written into [field].
Uint8List _entry(int length, FormatField field, String resref) =>
    Uint8List(length)..setRange(
      field.offset,
      field.offset + field.length,
      encodeFixedString(resref, field.length),
    );

const Endian _le = Endian.little;
