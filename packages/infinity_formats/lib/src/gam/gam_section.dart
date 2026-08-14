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

import 'package:infinity_formats/src/spec/gam_v2_0.dart';

/// The nine blocks the GAM header points at.
///
/// The GAM's answer to `CreSection`, and it exists for one reason: **a
/// relocation has to shift every one of these, and "absent" is encoded three
/// different ways in this one header.** Scattering that knowledge through the
/// relocation function is how a save gets a pointer 20 bytes inside itself.
///
/// ⚠️ **Four of these were unmodelled until 2026-08-12**, and one of them —
/// [familiarInfo] — is live on every save examined. The findings recorded the
/// cost of growing a creature as "3 GAM header offsets, 39 pointers"; that
/// counted only the offsets the layout table happened to name. With all nine
/// it is **43**.
///
/// Unlike `CreSection` this carries no stride: the GAM's blocks hold different
/// things — 352-byte NPC structs, variables, journal entries — and nothing here
/// needs to index into them. What a relocation needs is *where they start*.
enum GamSection {
  /// The party NPC struct array, protagonist first.
  partyNpcs(GamHeaderField.partyNpcOffset, GamHeaderField.partyNpcCount),

  /// The party's shared inventory.
  ///
  /// **Absent on every BG1EE save examined.** This is the field that taught the
  /// project the `0` rule: the read-path spike subtracted two offsets across it
  /// and computed a stride of −180.
  partyInventory(
    GamHeaderField.partyInventoryOffset,
    GamHeaderField.partyInventoryCount,
  ),

  /// The non-party NPC struct array — 33 to 36 of them on a BG1EE save.
  ///
  /// ⚠️ Each struct carries its own `creOffset`, and those are 36 of the 43
  /// pointers a relocation moves. Nothing recorded them until 2026-08-09.
  nonPartyNpcs(
    GamHeaderField.nonPartyNpcOffset,
    GamHeaderField.nonPartyNpcCount,
  ),

  /// The GLOBAL variable array.
  globals(GamHeaderField.globalsOffset, GamHeaderField.globalsCount),

  /// The familiar-extra block. **Absent as `0xFFFFFFFF`.**
  familiarExtra(
    GamHeaderField.familiarExtraOffset,
    null,
    absentMarker: allOnes,
  ),

  /// The journal entry array.
  journal(GamHeaderField.journalOffset, GamHeaderField.journalCount),

  /// The familiar-info block.
  ///
  /// ⚠️ **Live on every fixture** — always `file length - 400`, sitting after
  /// the journal and after every party creature, so a creature that grows moves
  /// it. It has an offset and no count.
  familiarInfo(GamHeaderField.familiarInfoOffset, null),

  /// The stored-location array.
  ///
  /// ⚠️ **Empty but positioned.** Holds exactly the file length with a count of
  /// zero. That is not the same as absent — see [isAbsent].
  storedLocations(
    GamHeaderField.storedLocationsOffset,
    GamHeaderField.storedLocationsCount,
  ),

  /// The pocket-plane location array. Same encoding as [storedLocations].
  pocketPlane(
    GamHeaderField.pocketPlaneOffset,
    GamHeaderField.pocketPlaneCount,
  );

  const GamSection(this.offsetField, this.countField, {this.absentMarker});

  /// The header field holding where this section starts.
  final GamHeaderField offsetField;

  /// The header field holding how many entries it has, where it has one.
  ///
  /// `null` for [familiarExtra] and [familiarInfo], which the format gives an
  /// offset and no count. Naming a count they do not have would point a reader
  /// at four bytes of something else.
  final GamHeaderField? countField;

  /// A second value meaning "absent", beyond the universal [absentZero].
  ///
  /// Declared per section rather than applied to all nine, because widening it
  /// would make a corrupt pointer elsewhere read as absence instead of failing.
  final int? absentMarker;

  /// The offset every section uses to mean "not present".
  ///
  /// Universal, and safe: no section can begin at byte 0 — that is the `'GAME'`
  /// signature — so a stored zero cannot be a position.
  static const int absentZero = 0;

  /// The all-ones marker [familiarExtra] uses.
  static const int allOnes = 0xFFFFFFFF;

  /// Whether [offset] means this section is not in the file.
  ///
  /// ⚠️ **Offset-equals-EOF with a count of zero is NOT absent.** It is the
  /// third encoding in this header, and it is the one a relocation must still
  /// move: measured across saves of 95,968, 101,352 and 88,280 bytes,
  /// [storedLocations] and [pocketPlane] hold exactly the file length every
  /// time, so the engine maintains them at the end of the file. Leaving them
  /// alone while the file grows puts them inside it.
  ///
  /// Nothing here needs a special case for that, and that is the point: an
  /// offset equal to the old end of file is `>= splice` for any splice, so the
  /// ordinary shift carries it to the new end of file for free.
  bool isAbsent(int offset) => offset == absentZero || offset == absentMarker;

  /// Every section, so a relocation can shift the ones that move.
  static const List<GamSection> all = values;
}
