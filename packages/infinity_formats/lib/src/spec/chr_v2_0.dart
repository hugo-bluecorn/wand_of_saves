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

import 'package:infinity_formats/src/spec/format_field.dart';

/// CHR V2.0 header layout — data only, no logic (D6).
///
/// Source: IESDP `file_formats/ie_formats/chr_v2.htm`, confirmed against every
/// `.chr` the player has exported.
///
/// **The whole table, unlike `CreHeaderField`**, so it carries the exact-fit
/// check: the fields account for precisely [headerSize] bytes and the record
/// begins where they stop. That is worth having here because this format has
/// exactly **one** pointer — [creOffset] — and nothing else to cross-check it
/// against. A GAM has nine offsets that tile; a CHR has a single length field,
/// and if it is wrong the file is simply misread.
///
/// ### The quick-slot block is shared with the savegame, byte for byte
///
/// `0x30`–`0x63` is the same 52 bytes as `GamNpcField`'s `0x8c`–`0xbf`.
/// Measured 2026-08-09 across three exported characters against the party
/// members they came from: **identical in every comparison**, including across
/// different characters and different saves. That is what makes an export a
/// copy rather than a translation.
///
/// ⚠️ **IESDP names the second group differently on its two pages.** The CHR
/// page calls `0x38`–`0x3f` "Show Quick Weapon 1-4" where the GAM page calls
/// the same bytes "quick weapon slot ability, -1 is disabled". The names here
/// follow `GamNpcField`, so the export reads as the identity it is.
enum ChrHeaderField implements FormatField {
  /// `'CHR '`.
  signature(0x00, 4),

  /// `'V2.0'`.
  ///
  /// ⚠️ **`V2.1` exists and this app can provoke it.** IESDP: the engine writes
  /// V2.1 once experience reaches `START_MP_XP_CAP`, which the player's own
  /// `startare.2da` gives as `START_XP_CAP 161000` — and setting experience is
  /// something this app does. `ChrCodec` refuses it by name rather than reading
  /// it as a V2.0.
  version(0x04, 4),

  /// The character's name, NUL-padded.
  ///
  /// ⚠️ **This is the only name a `.chr` has.** The embedded record's
  /// `dialogFile` is eight zero bytes and its `longNameStrref` is `-1` on every
  /// file measured — the protagonist's shape, which an exported character
  /// always is. Byte-identical to `GamNpcField.displayName` on both matched
  /// pairs, so an export copies this field rather than deriving it.
  ///
  /// It is **not** the filename: `Aard1.chr` holds `Aard`.
  name(0x08, 32),

  /// Offset to the embedded creature record, from the start of the file.
  ///
  /// 100 on every file measured — which is [headerSize], so the record begins
  /// immediately after this table. ⚠️ **Read it anyway.** Inferring a position
  /// that is written down is the same class of mistake as inferring a stride
  /// from the gap between two offsets.
  creOffset(0x28, 4),

  /// Length of the embedded creature record.
  ///
  /// **The only bound this format carries.** `creOffset + creLength` equals the
  /// file length exactly on every file measured, which is the one consistency
  /// check available here.
  creLength(0x2c, 4),

  /// Index into `SLOTS.IDS` for quick weapon 1; `0xFFFF` is none.
  quickWeaponSlot1(0x30, 2),

  /// Index into `SLOTS.IDS` for quick weapon 2; `0xFFFF` is none.
  quickWeaponSlot2(0x32, 2),

  /// Index into `SLOTS.IDS` for quick weapon 3; `0xFFFF` is none.
  quickWeaponSlot3(0x34, 2),

  /// Index into `SLOTS.IDS` for quick weapon 4; `0xFFFF` is none.
  quickWeaponSlot4(0x36, 2),

  /// Quick weapon 1 slot ability; `-1` is disabled. IESDP's CHR page calls this
  /// "Show Quick Weapon 1" — see the class note.
  quickWeaponAbility1(0x38, 2),

  /// Quick weapon 2 slot ability; `-1` is disabled.
  quickWeaponAbility2(0x3a, 2),

  /// Quick weapon 3 slot ability; `-1` is disabled.
  quickWeaponAbility3(0x3c, 2),

  /// Quick weapon 4 slot ability; `-1` is disabled.
  quickWeaponAbility4(0x3e, 2),

  /// Quick spell 1 resref.
  quickSpell1(0x40, 8),

  /// Quick spell 2 resref.
  quickSpell2(0x48, 8),

  /// Quick spell 3 resref.
  quickSpell3(0x50, 8),

  /// Index into `SLOTS.IDS` for quick item 1.
  quickItemSlot1(0x58, 2),

  /// Index into `SLOTS.IDS` for quick item 2.
  quickItemSlot2(0x5a, 2),

  /// Index into `SLOTS.IDS` for quick item 3.
  quickItemSlot3(0x5c, 2),

  /// Quick item 1 slot ability; `-1` is disabled.
  quickItemAbility1(0x5e, 2),

  /// Quick item 2 slot ability; `-1` is disabled.
  quickItemAbility2(0x60, 2),

  /// Quick item 3 slot ability; `-1` is disabled — the last header field.
  quickItemAbility3(0x62, 2);

  const ChrHeaderField(this.offset, this.length);

  /// Bytes of header before the embedded creature record.
  ///
  /// `0x62 + 2`. Confirmed on every `.chr` measured: [creOffset] holds exactly
  /// this, so the record starts where the header ends.
  static const int headerSize = 100;

  /// Where the quick-slot block begins.
  ///
  /// Named so an export can copy it as one run rather than field by field —
  /// see the class note on why that is a copy and not a translation.
  static const int quickSlotsOffset = 0x30;

  /// Bytes in the quick-slot block, `0x30`–`0x63`.
  static const int quickSlotsLength = headerSize - quickSlotsOffset;

  @override
  final int offset;

  @override
  final int length;

  /// Always `false`: **no field in this header is signed.**
  ///
  /// A getter rather than a constructor parameter, unlike `CreHeaderField` and
  /// `GamHeaderField` where some fields are. Declaring one nothing ever passes
  /// invites the reader to wonder which field needs it.
  ///
  /// The quick-slot abilities read as `-1 when disabled` in IESDP's prose and
  /// are still unsigned here, matching `GamNpcField`'s reading of the same
  /// bytes: the sentinel is `0xFFFF`, and nothing does arithmetic on it.
  @override
  bool get signed => false;
}
