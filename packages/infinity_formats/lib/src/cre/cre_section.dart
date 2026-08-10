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

import 'package:infinity_formats/src/cre/cre.dart';
import 'package:infinity_formats/src/spec/cre_v1_0.dart';

/// A variable-length section of a creature record.
///
/// **The table a resize is driven from** — which offset field points at the
/// section, which count field says how many entries it holds, and how wide one
/// entry is. Each value carrying its own facts is the same choice D6 made for
/// [CreHeaderField]: one table, so a writer cannot disagree with a reader.
///
/// ⚠️ **The item-slot table is deliberately absent.** It has an offset but no
/// count and a fixed size, so nothing can be appended to it — it is a section a
/// resize must *move*, never one it may grow.
enum CreSection {
  /// Spells the creature knows. 12 bytes each.
  knownSpells(
    CreHeaderField.knownSpellsOffset,
    CreHeaderField.knownSpellsCount,
    creKnownSpellLength,
  ),

  /// How many spells of each level and type may be memorised. 16 bytes each.
  ///
  /// ⚠️ **Entries here hold an index into [memorizedSpells]**, so inserting a
  /// memorised spell anywhere but at the very end leaves those indices pointing
  /// at the wrong entry. Appending is the only safe move, and keeping the
  /// indices honest is the caller's job — this table does not know about it.
  memorizationInfo(
    CreHeaderField.memorizationInfoOffset,
    CreHeaderField.memorizationInfoCount,
    creMemorizationInfoLength,
  ),

  /// Spells currently memorised. 12 bytes each.
  memorizedSpells(
    CreHeaderField.memorizedSpellsOffset,
    CreHeaderField.memorizedSpellsCount,
    creMemorizedSpellLength,
  ),

  /// Items carried. 20 bytes each.
  items(CreHeaderField.itemsOffset, CreHeaderField.itemsCount, creItemLength),

  /// Effects. ⚠️ **The stride depends on the record**, not on this table:
  /// `effectVersion` picks 48 or 264, so [strideIn] asks the creature.
  effects(CreHeaderField.effectsOffset, CreHeaderField.effectsCount, null);

  const CreSection(this.offsetField, this.countField, this._fixedStride);

  /// The header field holding where this section starts.
  final CreHeaderField offsetField;

  /// The header field holding how many entries it has.
  final CreHeaderField countField;

  /// Bytes per entry, or `null` when the record decides — see [strideIn].
  final int? _fixedStride;

  /// Bytes per entry of this section in [cre].
  ///
  /// Only [effects] varies: `effectVersion` of `1` means the 264-byte v2
  /// record, which is what BG:EE writes and what proficiencies live in.
  int strideIn(Cre cre) => _fixedStride ?? cre.effectLength;

  /// Every section, so a resize can shift the ones that move.
  static const List<CreSection> all = values;
}
