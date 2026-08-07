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
}
