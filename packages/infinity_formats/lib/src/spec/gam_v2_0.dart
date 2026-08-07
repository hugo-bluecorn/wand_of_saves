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

/// GAM V2.0 header layout — data only, no logic (D6).
///
/// Source: IESDP `file_formats/ie_formats/gam_v2.0.htm`, confirmed against a
/// real BG1EE save. The numbers are recorded in
/// `docs/findings/verified-format-offsets.md`; do not re-derive them here.
///
/// This is the subset this project has **verified**, not every byte GAM V2.0
/// defines, so the offsets are deliberately non-contiguous. That is why the
/// layout check runs without a struct size: gaps are expected, overlaps are
/// not.
enum GamHeaderField implements FormatField {
  /// `'GAME'`.
  signature(0x00, 4),

  /// `'V2.0'`.
  version(0x04, 4),

  /// Game time; 300 units is one hour.
  gameTime(0x08, 4),

  /// Party gold — shared, not per-character.
  partyGold(0x18, 4),

  /// Absolute offset to the party NPC struct array.
  partyNpcOffset(0x20, 4),

  /// Number of party NPC structs, including the protagonist.
  partyNpcCount(0x24, 4),

  /// Absolute offset to the party inventory. **`0` means absent**, which is
  /// the case on every BG1EE save examined — arithmetic on it is meaningless.
  partyInventoryOffset(0x28, 4),

  /// Number of party inventory entries.
  partyInventoryCount(0x2c, 4),

  /// Absolute offset to the non-party NPC struct array.
  nonPartyNpcOffset(0x30, 4),

  /// Number of non-party NPC structs. 36 on every save examined.
  nonPartyNpcCount(0x34, 4),

  /// Absolute offset to the GLOBAL variable array.
  globalsOffset(0x38, 4),

  /// Number of GLOBAL variables.
  globalsCount(0x3c, 4),

  /// Main area resref.
  mainArea(0x40, 8),

  /// Number of journal entries.
  journalCount(0x4c, 4),

  /// Absolute offset to the journal entry array.
  journalOffset(0x50, 4),

  /// Party reputation, stored **times ten** — `110` means 11.0.
  reputation(0x54, 4),

  /// Current area resref.
  currentArea(0x58, 8);

  const GamHeaderField(this.offset, this.length);

  @override
  final int offset;

  @override
  final int length;

  /// No GAM header field is signed. Offsets, counts, gold and game time are
  /// all quantities that cannot go below zero, and reputation is stored ×10
  /// over a 0-20 range.
  ///
  /// A getter rather than a constructor parameter, so the table says this once
  /// instead of every value repeating a default. It becomes a parameter on the
  /// day a signed field turns up.
  @override
  bool get signed => false;
}

/// GAM V2.0 NPC struct layout — data only, no logic (D6).
///
/// The same 352-byte struct serves both party and non-party characters.
///
/// Source: IESDP `file_formats/ie_formats/gam_v2.0.htm`, "GAME V2.0 NPCs".
/// Unlike [GamHeaderField], this table is **complete**: IESDP documents the
/// struct in 58 contiguous fields with no gaps, so the layout check runs with
/// [structSize] and the table becomes self-checking — any mistranscribed
/// offset or size leaves a gap or an overlap that the invariant catches.
///
/// Two departures from IESDP's wording, both for clarity:
///
/// * IESDP calls `0x0c` "Character Name"; it holds the **CRE resref**
///   (`*HARBASE` on the fixture), so it is [creResref] here. The player-visible
///   name is [displayName] at `0xc0`.
/// * IESDP lists 24 consecutive dwords at `0x2c`, every one of them named
///   "NumTimesInteracted NPC count (unused)". They are recorded here as the
///   single span [unusedInteractionCounts]: it accounts for the same bytes,
///   and 24 identical names would carry no more information.
enum GamNpcField implements FormatField {
  /// Character selection state (`0x8000` means dead).
  selection(0x00, 2),

  /// Party order; `0xFFFF` means not in the party.
  partyOrder(0x02, 2),

  /// **Absolute** offset, from the start of the GAM, to this character's CRE.
  creOffset(0x04, 4),

  /// Size in bytes of this character's embedded CRE.
  creLength(0x08, 4),

  /// The CRE resref. IESDP calls this "Character Name"; it is not the name.
  creResref(0x0c, 8),

  /// Character orientation.
  orientation(0x14, 4),

  /// Resref of the area the character is in.
  currentArea(0x18, 8),

  /// Character X coordinate.
  x(0x20, 2),

  /// Character Y coordinate.
  y(0x22, 2),

  /// Viewing rectangle X coordinate.
  viewportX(0x24, 2),

  /// Viewing rectangle Y coordinate.
  viewportY(0x26, 2),

  /// Modal action.
  modalAction(0x28, 2),

  /// Happiness.
  happiness(0x2a, 2),

  /// 24 dwords IESDP marks unused, recorded as one span. See the class note.
  unusedInteractionCounts(0x2c, 96),

  /// Index into `slots.ids` for quick weapon 1; `0xFFFF` is none.
  quickWeaponSlot1(0x8c, 2),

  /// Index into `slots.ids` for quick weapon 2; `0xFFFF` is none.
  quickWeaponSlot2(0x8e, 2),

  /// Index into `slots.ids` for quick weapon 3; `0xFFFF` is none.
  quickWeaponSlot3(0x90, 2),

  /// Index into `slots.ids` for quick weapon 4; `0xFFFF` is none.
  quickWeaponSlot4(0x92, 2),

  /// Quick weapon 1 slot ability; `-1` is disabled.
  quickWeaponAbility1(0x94, 2),

  /// Quick weapon 2 slot ability; `-1` is disabled.
  quickWeaponAbility2(0x96, 2),

  /// Quick weapon 3 slot ability; `-1` is disabled.
  quickWeaponAbility3(0x98, 2),

  /// Quick weapon 4 slot ability; `-1` is disabled.
  quickWeaponAbility4(0x9a, 2),

  /// Quick spell 1 resref.
  quickSpell1(0x9c, 8),

  /// Quick spell 2 resref.
  quickSpell2(0xa4, 8),

  /// Quick spell 3 resref.
  quickSpell3(0xac, 8),

  /// Index into `slots.ids` for quick item 1; `0xFFFF` is none.
  quickItemSlot1(0xb4, 2),

  /// Index into `slots.ids` for quick item 2; `0xFFFF` is none.
  quickItemSlot2(0xb6, 2),

  /// Index into `slots.ids` for quick item 3; `0xFFFF` is none.
  quickItemSlot3(0xb8, 2),

  /// Quick item 1 slot ability; `-1` is disabled.
  quickItemAbility1(0xba, 2),

  /// Quick item 2 slot ability; `-1` is disabled.
  quickItemAbility2(0xbc, 2),

  /// Quick item 3 slot ability; `-1` is disabled.
  quickItemAbility3(0xbe, 2),

  /// The player-visible character name, plain text.
  ///
  /// This is where a displayed name comes from when the CRE's name strref is
  /// `-1`, which is the protagonist's case.
  displayName(0xc0, 32),

  /// Number of times talked to.
  talkCount(0xe0, 4),

  /// The embedded character-stats sub-struct (kill statistics and the like).
  ///
  /// Recorded as one span; open it into its own table when something needs a
  /// field inside it.
  characterStats(0xe4, 116),

  /// Voice set — the last field, ending exactly at [structSize].
  voiceSet(0x158, 8);

  const GamNpcField(this.offset, this.length);

  /// Total size of the struct in bytes.
  ///
  /// **Read this; never infer it from the distance between two section
  /// offsets.** Verified three ways — IESDP's last field ending here, the
  /// party array landing on its CRE, and 36 non-party structs chaining
  /// perfectly. See `docs/findings/verified-format-offsets.md`.
  static const int structSize = 352;

  @override
  final int offset;

  @override
  final int length;

  /// No NPC struct field is signed. `partyOrder`'s `0xFFFF` is a sentinel read
  /// unsigned, not a negative.
  @override
  bool get signed => false;
}
