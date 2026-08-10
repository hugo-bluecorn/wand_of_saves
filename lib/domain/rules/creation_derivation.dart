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

/// What a created character's record needs beyond the player's own choices.
///
/// ⚠️ **D14 is the whole reason this exists.** A probe character was imported,
/// played and saved: the engine overwrote **six** fields and left the other
/// **sixty-seven** alone. Saving throws and THAC0 are in the sixty-seven —
/// written *worse* than computed and kept — so a character created without them
/// keeps whatever the template had for the rest of the game. Nothing else fills
/// these in.
///
/// **Pure, and separate from the wizard.** The creation flow decides what the
/// player picked; this decides what the tables say follows from it. Keeping the
/// two apart is what lets the second be tested without a screen.
library;

import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';

/// The stats a new [classIdentifier] of [raceIdentifier] at [levels] should
/// hold.
///
/// ⚠️ **A stat the tables cannot answer is left OUT, never defaulted.** The
/// record being edited is the engine's own `CHARBASE`, so an absent entry keeps
/// the game's value; writing a zero over it would be worse than writing
/// nothing. That is why every entry below is conditional.
///
/// The one exception is [CharacterStat.moraleBreak], which needs no table: a
/// morale break at or above morale panics a character permanently, and `0` is
/// what the protagonist's own record holds.
Map<CharacterStat, int> derivedStatsFor({
  required GameRules rules,
  required String classIdentifier,
  required String? raceIdentifier,
  required List<int> levels,
  required int constitution,
}) {
  final derived = <CharacterStat, int>{
    // Not derived from anything, and not optional. See above.
    CharacterStat.moraleBreak: 0,
  };

  final saves = rules.savingThrowsFor(
    classIdentifier: classIdentifier,
    levels: levels,
    raceIdentifier: raceIdentifier,
    constitution: constitution,
  );
  if (saves != null) {
    derived
      ..[CharacterStat.saveVersusDeath] = saves.death
      ..[CharacterStat.saveVersusWands] = saves.wands
      ..[CharacterStat.saveVersusPolymorph] = saves.polymorph
      ..[CharacterStat.saveVersusBreath] = saves.breath
      ..[CharacterStat.saveVersusSpells] = saves.spells;
  }

  final thac0 = rules.thac0For(
    classIdentifier: classIdentifier,
    levels: levels,
  );
  if (thac0 != null) derived[CharacterStat.thac0] = thac0;

  final lore = rules.loreFor(classIdentifier: classIdentifier, levels: levels);
  if (lore != null) derived[CharacterStat.lore] = lore;

  // ⚠️ **The rolled maximum, and the Constitution bonus is NOT added.** D14
  // measured that the stored value is the class-and-level part alone and the
  // engine adds the ability bonus at display; adding it here would double it.
  // Maximum rather than an average because the game's own difficulty setting
  // maximises hit-point rolls at Story, Easy and Normal.
  final hitPoints = rules.maximumRolledHitPointsFor(
    classIdentifier: classIdentifier,
    levels: levels,
  );
  if (hitPoints != null) {
    derived
      ..[CharacterStat.maximumHitPoints] = hitPoints
      ..[CharacterStat.currentHitPoints] = hitPoints;
  }

  // A bard's Pick Pockets and a ranger's stealth are fixed by level rather
  // than allocated, so the wizard never asks and the record would otherwise
  // ship at zero.
  for (final MapEntry(key: row, :value)
      in rules
          .fixedThiefSkillsFor(
            classIdentifier: classIdentifier,
            levels: levels,
          )
          .entries) {
    final stat = _skillsByRow[row];
    if (stat != null) derived[stat] = value;
  }

  return derived;
}

/// Which stat each `thiefscl.2da` row label writes into.
///
/// The row names are the game's; each [CharacterStat] already carries its own
/// in [CharacterStat.thiefSkillRow], so this is that table read backwards
/// rather than a second copy of it.
final Map<String, CharacterStat> _skillsByRow = {
  for (final stat in CharacterStat.values)
    if (stat.thiefSkillRow case final String row) row: stat,
};
