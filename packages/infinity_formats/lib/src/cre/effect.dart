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

import 'package:infinity_formats/src/spec/cre_v1_0.dart';
import 'package:infinity_formats/src/spec/format_field.dart';

/// Fields of a `V2` effect **as a creature record embeds it**.
///
/// ⚠️ **These are not IESDP's offsets, and the difference is eight bytes.**
/// IESDP splits `EFF V2.0` into a header and a body and numbers the body from
/// `0x08`; a creature embeds the *body alone*, so what IESDP calls body
/// `0x08` is byte 0 here. Reading with IESDP's numbers puts the opcode eight
/// bytes early and returns zero for every effect in the file, which is
/// exactly what it did before this table existed.
///
/// The first eight bytes are the signature and version, which IESDP says are
/// "zeroed out" for an embedded effect — and are, on all 42 effects in the
/// four-member fixture.
enum EffectV2Field implements FormatField {
  /// Signature. Zeroed when embedded.
  signature(0x00, 4),

  /// Version. Zeroed when embedded.
  version(0x04, 4),

  /// The opcode, which says what the effect does.
  opcode(0x08, 4),

  /// Target type. Irrelevant when attached directly to a creature.
  targetType(0x0c, 4),

  /// Power.
  power(0x10, 4),

  /// First parameter. For [Effect.proficiencyOpcode], the number of pips.
  parameter1(0x14, 4),

  /// Second parameter. For [Effect.proficiencyOpcode], a `STATS.IDS` index.
  parameter2(0x18, 4),

  /// Timing mode.
  timingMode(0x1c, 4);

  const EffectV2Field(this.offset, this.length);

  /// Byte offset from the start of the embedded record.
  @override
  final int offset;

  /// Width in bytes.
  @override
  final int length;

  /// No field read here is signed. Opcodes, parameters and timing modes are
  /// all counts or identifiers; a pip count below zero is not a state the
  /// engine has. It becomes a constructor parameter the day one turns up.
  @override
  bool get signed => false;
}

/// One effect attached to a creature — a **view** over the record's bytes.
///
/// Deliberately shallow. The full effects editor is Phase 6, and it needs an
/// opcode database generated from IESDP's 911 opcode pages. This reads the
/// handful of fields a character sheet needs, chiefly so proficiencies can be
/// found: on BG:EE they are not header bytes but opcode 233 effects.
final class Effect {
  /// Views the record beginning at [start] within [_cre].
  const Effect.at(this._cre, this.start);

  /// The opcode that grants weapon and fighting-style proficiencies.
  ///
  /// Parameter 1 is the pip count; parameter 2 is a `STATS.IDS` index.
  ///
  /// ⚠️ **Which indices are proficiencies is a per-game fact, so it is not
  /// stated here.** An earlier note said "89-108 weapons, 111-115 styles";
  /// the player's own `weapprof.2da` says otherwise on both ends — BG:EE
  /// numbers the weapons 89-107 **and 115** (`PROFICIENCYCLUB`, which BG2:EE
  /// calls `EXTRAPROFICIENCY1`), the styles 111-114, and gives 109 and 110 to
  /// things that are not proficiencies at all. The table is the authority;
  /// a hardcoded range would be wrong on the next game and silently so.
  static const int proficiencyOpcode = 233;

  final Uint8List _cre;

  /// Byte offset of this record from the start of the creature.
  ///
  /// What a writer needs in order to patch this effect in place rather than
  /// recomputing its position from an index and a stride.
  final int start;

  int _u32(EffectV2Field field) => ByteData.sublistView(
    _cre,
  ).getUint32(start + field.offset, Endian.little);

  /// What this effect does.
  int get opcode => _u32(EffectV2Field.opcode);

  /// First parameter — the pip count when [opcode] is [proficiencyOpcode].
  int get parameter1 => _u32(EffectV2Field.parameter1);

  /// Second parameter — a `STATS.IDS` index for [proficiencyOpcode].
  int get parameter2 => _u32(EffectV2Field.parameter2);

  /// Whether this effect grants a proficiency.
  bool get isProficiency => opcode == proficiencyOpcode;

  @override
  String toString() => 'Effect(opcode $opcode @$start)';
}

/// A proficiency effect exactly as BG:EE writes one, with the pips and the
/// proficiency left at zero.
///
/// ⚠️ **Copied from the engine's own bytes, not synthesised.** A `CRE` embedded
/// effect is 264 bytes and Aard's, read out of the party fixture, is zero
/// everywhere except eight places:
///
/// | offset | value | what |
/// |---|---|---|
/// | `0x008` | 233 | opcode — the proficiency effect |
/// | `0x014` | pips | parameter 1 |
/// | `0x018` | id | parameter 2, the `weapprof.2da` number |
/// | `0x01c` | 9 | timing mode |
/// | `0x024` | 100 | probability |
/// | `0x078`–`0x087` | `0xFF` | sixteen bytes of "none" |
/// | `0x09c`–`0x09f` | `0xFF` | four more |
/// | `0x0c4` | 1 | |
///
/// ⚠️ **`0x000` and `0x004` are zero**, which confirms in the data what IESDP
/// says in prose: an embedded effect is the EFF *body*, with no 8-byte header.
/// Building this from the field table alone would have left those two dwords
/// holding whatever a "signature" seemed to want.
Uint8List proficiencyEffectTemplate() {
  final out = Uint8List(creEffectV2Length);
  ByteData.sublistView(out)
    ..setUint32(EffectV2Field.opcode.offset, Effect.proficiencyOpcode, _le)
    ..setUint32(EffectV2Field.timingMode.offset, 9, _le)
    ..setUint32(0x24, 100, _le)
    ..setUint32(0xc4, 1, _le);
  out
    ..fillRange(0x78, 0x88, 0xFF)
    ..fillRange(0x9c, 0xa0, 0xFF);
  return out;
}

const Endian _le = Endian.little;
