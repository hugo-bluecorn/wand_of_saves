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

part 'skill_catalogue.mapper.dart';

/// Which thief skills each class and kit may allocate points to.
///
/// The player's own `thiefscl.2da`, which is a row per skill and a column per
/// class or kit — **the same column vocabulary as `weapprof.2da`**, so one
/// resolver serves both (`CharacterSheet.classColumn`).
///
/// The cell is a *percentage* of the character's skill points that may go into
/// that skill, and `0` is the answer to "does this class have this skill at
/// all". Read off a real installation: `FIGHTER_MAGE` is 0 on all seven rows,
/// `THIEF` is 100 on all seven, `BARD` is 100 for Pick Pockets and 0 for the
/// rest, `RANGER` only Move Silently and Hide in Shadows.
///
/// ⚠️ **A kit is a column of its own and does not follow its class.** A Blade
/// picks pockets at 50 where a Bard is 100; a Shadowdancer is a Thief who
/// cannot set traps. Neither is derivable from the base class.
///
/// **Lore is deliberately absent from the table**, because every class has it
/// — confirmed in game, where a Necromancer's record screen prints `Lore: 15`.
@MappableClass()
class SkillCatalogue with SkillCatalogueMappable {
  /// Wraps the table, keyed by row label then by column header.
  const SkillCatalogue(this.allowanceByRow);

  /// Nothing known — no installation, or a file that would not parse.
  static const SkillCatalogue empty = SkillCatalogue({});

  /// Percentage allocatable, by `thiefscl.2da` row then class/kit column.
  final Map<String, Map<String, int>> allowanceByRow;

  /// What percentage [column] may put into [row], or `null` if unknown.
  ///
  /// **`null`, never `0`, when the table cannot answer.** The two mean
  /// opposite things — `0` is "this class does not have this skill" and `null`
  /// is "no table was read" — and collapsing them would let a machine with no
  /// game installed silently forbid every edit on the screen. Same distinction
  /// `ProficiencyEntry.maximumFor` makes.
  int? allowanceFor(String? row, String? column) =>
      row == null || column == null ? null : allowanceByRow[row]?[column];
}
