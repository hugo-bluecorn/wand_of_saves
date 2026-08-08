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

import 'package:dart_mappable/dart_mappable.dart';

part 'proficiency.mapper.dart';

/// One weapon or fighting style a character has pips in.
///
/// ⚠️ **Not a header field.** IESDP documents proficiencies at CRE
/// `0x6e`-`0x81`, and on BG:EE those bytes are zero for a character the game
/// plainly shows two pips for. They are stored as opcode 233 effects inside
/// the creature's own effects section instead, with the pip count in
/// parameter 1 and the proficiency in parameter 2.
///
/// So this carries [effectOffset] as well as the numbers: **a proficiency is
/// addressed by where its effect sits**, exactly as a character is addressed
/// by their creature offset. Recomputing the position from an index and a
/// stride is the arithmetic that produced a stride of −180.
@MappableClass()
class Proficiency with ProficiencyMappable {
  /// Records [pips] in proficiency [id], stored at [effectOffset].
  const Proficiency({
    required this.id,
    required this.pips,
    required this.effectOffset,
  });

  /// Which proficiency, as the number opcode 233 stores in parameter 2.
  ///
  /// A `STATS.IDS` index, and the row the player's `weapprof.2da` gives its
  /// name and its per-class pip cap. **Which numbers are proficiencies is a
  /// per-game fact** — BG:EE and BG2:EE disagree at 115 — so nothing here
  /// bounds it.
  final int id;

  /// How many pips, as opcode 233 stores in parameter 1.
  final int pips;

  /// Byte offset of the effect record from the start of the creature.
  final int effectOffset;
}
