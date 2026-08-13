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

import 'package:infinity_formats/src/chr/chr.dart';
import 'package:infinity_formats/src/exceptions.dart';
import 'package:infinity_formats/src/gam/gam_npc.dart';
import 'package:infinity_formats/src/spec/chr_v2_0.dart';
import 'package:infinity_formats/src/text/fixed_field.dart';

/// Reads exported character files — `.chr`.
///
/// Version dispatch follows `GamCodec` and `CreCodec`: the offsets live in
/// [ChrHeaderField], a data table, so a second layout means a second table
/// rather than a rewritten reader (D3).
abstract final class ChrCodec {
  static const String _signature = 'CHR ';

  /// Versions this build reads.
  ///
  /// ⚠️ **`V2.1` is deliberately absent.** IESDP prints one header table for
  /// both, so accepting it would very likely work — and "very likely" is not
  /// the standard this project writes savegames to. The engine writes V2.1 once
  /// experience reaches `startare.2da`'s `START_XP_CAP` (161,000 here), which
  /// this app can bring about by editing experience, so this will be met. Add
  /// it when a real V2.1 file has been measured, not before.
  static const Set<String> supportedVersions = {'V2.0'};

  /// The version [exportOf] writes.
  ///
  /// Named separately from [supportedVersions] because reading and writing are
  /// different questions: this codec could one day read several layouts and
  /// would still only ever write the one BG1EE uses (D3).
  static const String writtenVersion = 'V2.0';

  /// Parses [bytes] as an exported character.
  ///
  /// The returned [Chr] holds an unmodifiable **copy**, for the same reason
  /// `GamCodec.decode` copies: `asUnmodifiableView` stops writes through the
  /// view, but the caller still holds the original.
  ///
  /// Throws [InfinityFormatException] if the file is too short, carries a
  /// signature or version this codec does not read, or declares a record that
  /// does not lie inside the file.
  static Chr decode(Uint8List bytes, {Object? source}) {
    if (bytes.length < ChrHeaderField.headerSize) {
      throw InfinityFormatException.truncated(
        what: 'CHR header',
        expected: ChrHeaderField.headerSize,
        actual: bytes.length,
        source: source,
      );
    }

    // Fixed-width ASCII magic. latin1 cannot throw on corrupt input, so the
    // message can report what was actually there.
    final signature = latin1.decode(bytes.sublist(0, 4));
    if (signature != _signature) {
      throw InfinityFormatException.badSignature(
        expected: _signature,
        found: signature,
        source: source,
      );
    }

    final version = latin1.decode(bytes.sublist(4, 8));
    if (!supportedVersions.contains(version)) {
      throw InfinityFormatException.unsupportedVersion(
        found: version,
        supported: supportedVersions,
        source: source,
      );
    }

    final view = ByteData.sublistView(bytes);
    final creOffset = view.getUint32(
      ChrHeaderField.creOffset.offset,
      Endian.little,
    );
    final creLength = view.getUint32(
      ChrHeaderField.creLength.offset,
      Endian.little,
    );

    // The single pointer this format has, so it is the only thing that can be
    // wrong about the layout — and believing a bad one reads whatever follows
    // in the buffer as a creature. Both ends are checked.
    if (creOffset < ChrHeaderField.headerSize) {
      throw InfinityFormatException.truncated(
        what: 'CHR embedded CRE (declared at $creOffset, inside the header)',
        expected: ChrHeaderField.headerSize,
        actual: creOffset,
        source: source,
        offset: ChrHeaderField.creOffset.offset,
      );
    }
    if (creOffset + creLength > bytes.length) {
      throw InfinityFormatException.truncated(
        what: 'CHR embedded CRE ($creLength bytes at $creOffset)',
        expected: creOffset + creLength,
        actual: bytes.length,
        source: source,
        offset: ChrHeaderField.creLength.offset,
      );
    }

    return Chr.trusted(Uint8List.fromList(bytes).asUnmodifiableView());
  }

  /// The character [npc] would be, exported.
  ///
  /// **The safest write this application performs**: it produces a new file and
  /// never touches the savegame. It is also how a *resizing* edit will first
  /// become possible — a `.chr` carries one pointer where a savegame carries
  /// forty-three — so this is a load-bearing path, not a convenience.
  ///
  /// ### Every byte is copied, none is computed
  ///
  /// Measured 2026-08-09 against three characters BG:EE itself exported,
  /// compared with the party members they came from:
  ///
  /// | CHR header | comes from | measured |
  /// |---|---|---|
  /// | `0x08` name, 32 bytes | `GamNpcField.displayName` (`0xc0`) | identical |
  /// | `0x30`-`0x63` quick slots | GAM NPC `0x8c`-`0xbf` | identical |
  /// | the record | `GamNpc.creBytes` | copied verbatim |
  ///
  /// Only [ChrHeaderField.creOffset] and [ChrHeaderField.creLength] are written
  /// rather than copied, and both are facts about the file being built.
  ///
  /// ⚠️ **No `.bio` is written, and that is a decision rather than an
  /// omission.** The game keeps a biography beside each exported character, and
  /// nothing in GAM, CRE or CHR holds one — IESDP documents biographies only in
  /// the `.tot`/`.toh` talk-table override, which no save on the developer's
  /// machine has. All three `.bio` files on disk are byte-identical: the
  /// shipped default text. Writing that text ourselves would be inventing a
  /// biography; omitting the file lets the engine fall back to exactly the same
  /// default.
  ///
  /// ⚠️ **The engine rebuilds part of the record on import** — a character
  /// exported with 45 maximum hit points came back with 12. See `Chr`.
  static Chr exportOf(GamNpc npc) {
    final record = npc.creBytes;
    final bytes = Uint8List(ChrHeaderField.headerSize + record.length);
    bytes
      ..setRange(0, 4, latin1.encode(_signature))
      ..setRange(4, 8, latin1.encode(writtenVersion))
      ..setRange(
        ChrHeaderField.name.offset,
        ChrHeaderField.name.offset + ChrHeaderField.name.length,
        npc.displayNameBytes,
      )
      ..setRange(
        ChrHeaderField.quickSlotsOffset,
        ChrHeaderField.headerSize,
        npc.quickSlotBytes,
      )
      // A copy, not a view: an exported character must not change when the
      // savegame it came from is next edited.
      ..setRange(ChrHeaderField.headerSize, bytes.length, record);

    ByteData.sublistView(bytes)
      ..setUint32(
        ChrHeaderField.creOffset.offset,
        ChrHeaderField.headerSize,
        Endian.little,
      )
      ..setUint32(
        ChrHeaderField.creLength.offset,
        record.length,
        Endian.little,
      );

    return Chr.trusted(bytes.asUnmodifiableView());
  }

  /// A brand-new character called [name], wrapped around [record].
  ///
  /// ⚠️ **[record] is the engine's own `CHARBASE`, not something synthesised.**
  /// The key file indexes it as a `CRE` in `data/DEFAULT.BIF`, and it is the
  /// template every protagonist is built from — which is *why* the resref of
  /// the player's own character always reads `*HARBASE`, and why two different
  /// characters in two different campaigns are both it. Creating a character
  /// therefore means loading the seed and editing it, never inventing 6,000
  /// bytes of creature and hoping.
  ///
  /// The quick-slot block is filled with `0xFF`, which is `0xFFFF` per word —
  /// the engine's "none" for a slot and "disabled" for an ability. A new
  /// character carries nothing, so every slot is empty; copying a live
  /// character's block instead would point at items that are not there.
  static Chr blank({required String name, required Uint8List record}) {
    final bytes = Uint8List(ChrHeaderField.headerSize + record.length);
    bytes
      ..setRange(0, 4, latin1.encode(_signature))
      ..setRange(4, 8, latin1.encode(writtenVersion))
      ..setRange(
        ChrHeaderField.name.offset,
        ChrHeaderField.name.offset + ChrHeaderField.name.length,
        encodeFixedString(name, ChrHeaderField.name.length),
      )
      ..fillRange(
        ChrHeaderField.quickSlotsOffset,
        ChrHeaderField.headerSize,
        0xFF,
      )
      ..setRange(ChrHeaderField.headerSize, bytes.length, record);

    ByteData.sublistView(bytes)
      ..setUint32(
        ChrHeaderField.creOffset.offset,
        ChrHeaderField.headerSize,
        Endian.little,
      )
      ..setUint32(
        ChrHeaderField.creLength.offset,
        record.length,
        Endian.little,
      );

    return Chr.trusted(bytes.asUnmodifiableView());
  }

  /// Serialises [chr] back to bytes.
  ///
  /// **Deliberately trivial, exactly as `GamCodec.encode` is.** `Chr` keeps the
  /// original buffer and edits patch a copy of it, so there is nothing to
  /// reassemble and nothing this codec fails to understand can be lost. Which
  /// also means byte-identity round-tripping proves little on its own — the
  /// test that constrains a writer is "edit one field and assert every *other*
  /// byte is unchanged".
  static Uint8List encode(Chr chr) => chr.bytes;
}
