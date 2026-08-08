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

import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';

/// A character as the *game* would show them, rather than as the file holds
/// them.
///
/// A savegame stores base values: hit points without the Constitution bonus,
/// armour class without the Dexterity modifier, a class as a number. Every
/// number here is that arithmetic applied — and every one of them is `null`
/// when the tables cannot answer, so a missing rule shows nothing rather than
/// a wrong figure.
///
/// **Derived, never stored.** The editable fields stay the file's own values,
/// because those are what a save actually contains. This exists so the two can
/// sit side by side and the difference stops looking like a bug.
class CharacterSheet {
  /// Views [character] through [rules].
  const CharacterSheet({required this.character, required this.rules});

  /// The character as the savegame holds them.
  final Character character;

  /// The game's own tables.
  final GameRules rules;

  /// Class, race and alignment, the way the record screen writes them.
  ///
  /// Anything the tables cannot name is left out rather than shown as a
  /// number — a raw `173` on a character sheet is noise, not information.
  String get identity => [
    rules.genderName(character.genderId),
    rules.raceName(character.raceId),
    rules.className(character.classId),
    rules.alignmentName(character.alignmentId),
  ].nonNulls.join(' · ');

  /// The character's kit, or `null` — which today is always `null`.
  ///
  /// **The encoding is not understood, so nothing is shown.** The fixture
  /// stores `0x40000000` for a character with no kit; shifted right 16 that
  /// is `0x4000`, and `KIT.IDS` numbers its *first* entry `0x4000` —
  /// `MAGESCHOOL_GENERALIST`. The obvious decoding therefore names a kit for
  /// everyone who has none, and `KIT.IDS` has no `TRUECLASS` row to mean
  /// "no kit". Guessing here would put a false kit on every plain fighter in
  /// the game, so it waits for a measurement.
  String? get kitName => null;

  /// The highest maximum hit points the rules would allow, or `null`.
  ///
  /// **Always `null` for now, deliberately.** Working it out needs the
  /// per-class dice tables — `hpwar.2da`, `hpwiz.2da` and the rest — which
  /// `hpclass.2da` merely points at. IESDP ships a *template* for their shape
  /// (`hpx.2da`, shown as `hpmonk.2da`) and none of the real ones, so the cap
  /// cannot be computed from the data available. Phase 3, reading the
  /// player's own installation, is where it becomes possible.
  int? get maximumHitPointsAllowed => null;

  /// The highest value [stat] may take **on this character**.
  ///
  /// A stat's own range is a property of one field — Strength is 1 to 25
  /// because IESDP says so. This is the other kind of bound: the one that
  /// depends on a *different* field's value.
  ///
  /// Current hit points are the case that matters. Their range is the field's
  /// width, 0 to 65535, so nothing stops an editor offering 20 against a
  /// maximum of 7 — and we measured what the engine does with that: it clamps
  /// it away on load and shows 9/9. Offering a number the game will discard is
  /// not editing, it is theatre.
  int upperBoundFor(CharacterStat stat) => switch (stat) {
    CharacterStat.currentHitPoints => character.maximumHitPoints,
    _ => stat.maximum,
  };

  /// The lowest value [stat] may take on this character.
  int lowerBoundFor(CharacterStat stat) => stat.minimum;

  /// Whether [value] is one [stat] may hold on this character.
  ///
  /// Applied to the value *already in the savegame* as well as to a typed one,
  /// so a file that arrives inconsistent says so rather than presenting itself
  /// as ordinary.
  bool isWithinBounds(CharacterStat stat, int value) =>
      value >= lowerBoundFor(stat) && value <= upperBoundFor(stat);

  /// What Dexterity does to armour class, or `null` off the table.
  int? get armourClassModifier =>
      rules.armourClassFromDexterity(character.abilities.dexterity);

  /// Armour class as the game will show it, before equipment.
  ///
  /// Confirmed at two different values, which is what makes it arithmetic
  /// rather than a coincidence: stored 10 with Dexterity 17 showed 7, and
  /// stored 6 showed 3. Both from the **effective** field — the natural one
  /// was set differently in each run and moved nothing.
  int? get armourClassInGame {
    final modifier = armourClassModifier;
    return modifier == null ? null : character.armorClass + modifier;
  }

  /// Hit points Constitution adds per level, or `null` off the table.
  ///
  /// The game prints this number itself, as "Bonus Hit Points/Level".
  int? get hitPointBonusPerLevel => rules.hitPointBonusPerLevel(
    constitution: character.abilities.constitution,
    warrior: rules.isWarrior(character.classId),
  );

  /// Total hit points Constitution adds.
  ///
  /// **The multi-class rule here is inferred, not measured.** The bonus is
  /// multiplied by the *highest* class level, which is right for a
  /// single-class character and right for the one fixture available — a
  /// level 1/1 Fighter/Mage, where every reading gives the same answer. A
  /// higher-level multi-class character would tell us whether the engine
  /// averages it instead, and none exists on this machine.
  int? get hitPointBonus {
    final perLevel = hitPointBonusPerLevel;
    if (perLevel == null) return null;
    final levels = character.levels;
    if (levels.isEmpty) return null;
    return perLevel * levels.reduce((a, b) => a > b ? a : b);
  }

  /// Current hit points as the game will show them.
  ///
  /// **Clamped to the maximum, because the engine clamps.** Measured: a save
  /// carrying 20 current against a maximum of 7 loaded showing 9/9, not 22/9.
  /// Showing the unclamped pair would report a state the game never holds.
  int? get currentHitPointsInGame {
    final bonus = hitPointBonus;
    final maximum = maximumHitPointsInGame;
    if (bonus == null || maximum == null) return null;
    final current = character.currentHitPoints + bonus;
    return current > maximum ? maximum : current;
  }

  /// Maximum hit points as the game will show them.
  ///
  /// Confirmed at two values: a stored maximum of 7 showed as 9, and 40 showed
  /// as 42, both with Constitution 16 at level 1 and the game's own breakdown
  /// reading "Bonus Hit Points/Level: +2". Still level 1 in both, so the
  /// multi-class multiplier in [hitPointBonus] remains untested.
  int? get maximumHitPointsInGame {
    final bonus = hitPointBonus;
    return bonus == null ? null : character.maximumHitPoints + bonus;
  }
}
