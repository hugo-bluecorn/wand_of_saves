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

part 'saving_throws.mapper.dart';

/// A character's five saving throws. **Lower is better.**
///
/// Grouped for the same reason as `AbilityScores`: they are read, shown and
/// edited as a set, and the game's record screen prints them as one block.
///
/// ⚠️ **These are the one part of the sheet stored exactly as displayed.**
/// Verified 2026-08-08 against a record screen reading 14/11/13/15/12 for a
/// creature holding those five bytes. Hit points, THAC0 and the thief skills
/// are all bases; these are not, and assuming otherwise would have the panel
/// apologising for arithmetic the engine never does.
@MappableClass()
class SavingThrows with SavingThrowsMappable {
  /// Creates a set of saving throws.
  const SavingThrows({
    required this.death,
    required this.wands,
    required this.polymorph,
    required this.breath,
    required this.spells,
  });

  /// Every value zero — a creature with nothing rolled yet.
  static const SavingThrows none = SavingThrows(
    death: 0,
    wands: 0,
    polymorph: 0,
    breath: 0,
    spells: 0,
  );

  /// Save versus death — the record screen's "Paralysis / Poison / Death".
  final int death;

  /// Save versus wands — "Rod / Staff / Wand".
  final int wands;

  /// Save versus polymorph — "Petrification / Polymorph".
  final int polymorph;

  /// Save versus breath attacks — "Breath Weapon".
  final int breath;

  /// Save versus spells — "Spell".
  final int spells;
}
