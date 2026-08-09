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

import 'package:infinity_formats/src/cre/effect.dart';
import 'package:infinity_formats/src/spec/chr_v2_0.dart';
import 'package:infinity_formats/src/spec/cre_v1_0.dart';
import 'package:infinity_formats/src/spec/creature_document.dart';
import 'package:infinity_formats/src/spec/field_patch.dart';
import 'package:infinity_formats/src/spec/format_field.dart';
import 'package:infinity_formats/src/text/fixed_field.dart';

/// A parsed exported character — a `.chr` file.
///
/// **The bytes are the model**, exactly as in `Gam`: every accessor reads
/// through [bytes] rather than caching a parsed copy, so there is no second
/// representation to drift out of step with the file, and an edit produces a
/// *new* `Chr` over a patched copy. The "preserve unknown bytes" rule holds by
/// construction.
///
/// ### Why this is a document and not a savegame's by-product
///
/// A `.chr` is a 100-byte header wrapped around a plain `CRE`, and the header
/// carries **one** pointer. A savegame carries thirty-nine, and adding a single
/// 264-byte effect inside one shifts about 90 KB of file. So a resizing edit —
/// granting a proficiency, adding an item — is reachable through this format
/// long before it is safe in place. That is why exporting is a first-class
/// output path rather than a convenience.
///
/// ⚠️ **The engine rebuilds part of the record on import.** A character
/// exported with a stored maximum of 45 hit points arrives in a new game with
/// 12, recomputed from class and level, and percentile strength is normalised.
/// Experience, class levels, THAC0, ability scores, proficiencies and effects
/// all cross intact. Which edits survive is not guessable — see
/// `docs/findings/verified-format-offsets.md` §CHR V2.0.
final class Chr implements CreatureDocument<Chr> {
  /// Wraps [bytes], which must already be validated and unmodifiable.
  const Chr.trusted(this.bytes);

  /// The complete file, exactly as read. Unmodifiable.
  @override
  final Uint8List bytes;

  int _u32(ChrHeaderField field) =>
      ByteData.sublistView(bytes).getUint32(field.offset, Endian.little);

  /// The character's name, as the header holds it.
  ///
  /// ⚠️ **The only name this file has**, and not the filename — see
  /// [ChrHeaderField.name]. The embedded record carries neither a dialogue
  /// resref nor a name strref.
  String get name => decodeFixedString(
    bytes,
    ChrHeaderField.name.offset,
    ChrHeaderField.name.length,
  );

  /// Where the creature record starts, from the beginning of the file.
  int get creOffset => _u32(ChrHeaderField.creOffset);

  /// How many bytes the creature record occupies.
  int get creLength => _u32(ChrHeaderField.creLength);

  /// The embedded creature record, as a view rather than a copy.
  ///
  /// Feed it to `CreCodec.decode`. The slice inherits this buffer's
  /// unmodifiability, the same arrangement `GamNpc.creBytes` uses.
  Uint8List get creBytes =>
      Uint8List.sublistView(bytes, creOffset, creOffset + creLength);

  /// A copy with [field] of the creature at [creOffset] set to [value].
  ///
  /// [creOffset] is [this.creOffset] — the CHR header's own — rather than an
  /// absolute savegame position. It is passed in rather than read here so the
  /// call reads identically against either document, which is the whole point
  /// of [CreatureDocument].
  @override
  Chr withCreatureField({
    required int creOffset,
    required CreHeaderField field,
    required int value,
  }) => _withField(
    base: creOffset,
    field: field,
    value: value,
    what: '$field of the creature at $creOffset',
  );

  /// A copy with the text [field] of the creature at [creOffset] set to
  /// [value] — a portrait resref, so far.
  ///
  /// Fixed-width like every other edit here: the field is a fixed run of bytes
  /// and nothing moves.
  @override
  Chr withCreatureText({
    required int creOffset,
    required CreHeaderField field,
    required String value,
  }) => Chr.trusted(
    patchedTextField(
      bytes: bytes,
      base: creOffset,
      field: field,
      value: value,
      what: '$field of the creature at $creOffset',
    ),
  );

  /// A copy with [field] of the effect at [effectStart] set to [value].
  ///
  /// Proficiencies live here rather than in the creature header on BG:EE, in an
  /// exported character exactly as in a savegame — it is the same record.
  @override
  Chr withEffectField({
    required int creOffset,
    required int effectStart,
    required EffectV2Field field,
    required int value,
  }) => _withField(
    base: creOffset + effectStart,
    field: field,
    value: value,
    what: '$field of the effect at $effectStart in the creature at $creOffset',
  );

  Chr _withField({
    required int base,
    required FormatField field,
    required int value,
    required String what,
  }) => Chr.trusted(
    patchedField(
      bytes: bytes,
      base: base,
      field: field,
      value: value,
      what: what,
    ),
  );

  @override
  String toString() => 'Chr($name, $creLength bytes of record)';
}
