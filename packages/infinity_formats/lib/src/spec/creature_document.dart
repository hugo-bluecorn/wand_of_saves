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

import 'package:infinity_formats/src/cre/cre.dart';
import 'package:infinity_formats/src/cre/effect.dart';
import 'package:infinity_formats/src/spec/cre_v1_0.dart';

/// A file that contains an editable creature record.
///
/// The two documents this application opens — a savegame and an exported
/// character — differ in almost everything and agree on the part that matters:
/// **both wrap the same `CRE V1.0` record**, and a fixed-width edit to a field
/// inside one means precisely what it means inside the other. This is that
/// agreement, stated as a type, so one character sheet can drive both.
///
/// ### Why the type parameter
///
/// `T` is the implementing class itself — `Gam implements
/// CreatureDocument&lt;Gam&gt;`, `Chr implements CreatureDocument&lt;Chr&gt;`.
/// Without it
/// an edit would have to return the interface, and every caller would cast back
/// to the concrete document before doing anything else. With it, editing a
/// `Chr` yields a `Chr` and the undo stack of a character editor is a
/// `List<Chr>` rather than a list of things that might be savegames.
///
/// ### What is deliberately *not* here
///
/// Party gold, reputation, the area, the NPC arrays — everything that belongs
/// to a *savegame* rather than to a character. `SetPartyGold` is outside the
/// shared edit hierarchy for the same reason: a `.chr` has no party, and a
/// document that had to throw `UnsupportedError` at run time would be exactly
/// the bug a sealed hierarchy exists to prevent at compile time.
///
/// ⚠️ **All but one of these edits is fixed-width, and the exception is
/// [withCreature].** Adding an item or granting a proficiency resizes a
/// section, which means relocating everything after it — a far smaller problem
/// in a `.chr` (one pointer) than in a savegame (thirty-nine), which is why
/// exporting matters and why `Chr` implements that method while `Gam` refuses
/// it. An earlier version of this comment said "nothing here moves anything",
/// which was true when it was written and has been false since [withCreature]
/// was declared below it.
abstract interface class CreatureDocument<T extends CreatureDocument<T>> {
  /// The complete file, exactly as read. Unmodifiable.
  Uint8List get bytes;

  /// A copy of this document with [field] of the creature at [creOffset] set
  /// to [value].
  ///
  /// [creOffset] is where the record starts **within this file**: an absolute
  /// position in a savegame, and the CHR header's own offset in an exported
  /// character. The byte written is at `creOffset + field.offset`.
  T withCreatureField({
    required int creOffset,
    required CreHeaderField field,
    required int value,
  });

  /// A copy of this document with the **text** [field] of the creature at
  /// [creOffset] set to [value].
  ///
  /// The sibling of [withCreatureField] for the fields that hold a resref
  /// rather than a number — portraits, so far. Still fixed-width: the field is
  /// a fixed run of bytes and [value] is NUL-padded into it.
  ///
  /// ⚠️ **Refuses a value too long for the field**, never truncates. A resref
  /// silently cut to eight bytes is a portrait that silently does not load.
  T withCreatureText({
    required int creOffset,
    required CreHeaderField field,
    required String value,
  });

  /// A copy with [field] of the effect at [effectStart] inside the creature at
  /// [creOffset] set to [value].
  ///
  /// One level deeper than [withCreatureField]: proficiencies live in opcode
  /// 233 effects on BG:EE rather than in the creature header, so raising a pip
  /// means patching a dword inside an effect record. [effectStart] is relative
  /// to the creature, as `Effect.start` reports it.
  T withEffectField({
    required int creOffset,
    required int effectStart,
    required EffectV2Field field,
    required int value,
  });

  /// The creature record at [creOffset], as bytes.
  ///
  /// The read half of [withCreature]: a resizing edit has to parse the record
  /// before it can grow it, and it must reach it the same way in either
  /// document.
  Uint8List creatureAt(int creOffset);

  /// A copy with the creature at [creOffset] **replaced** by [creature].
  ///
  /// ⚠️ **The only edit here that may change a record's size**, which is why it
  /// takes a whole creature rather than a field: a grown record moves every
  /// pointer that follows it, and how many of those there are is the difference
  /// between the two documents. A `.chr` has **one** — the length in its
  /// 100-byte header. A savegame has thirty-nine, so it **refuses**: growing a
  /// file that holds hours of someone's play is Phase 1's work and is not
  /// attempted here.
  ///
  /// Throws `UnsupportedError` on a document that cannot resize safely.
  T withCreature({required int creOffset, required Cre creature});
}
