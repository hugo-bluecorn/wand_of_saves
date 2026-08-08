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
    _classOrKit,
    rules.alignmentName(character.alignmentId),
  ].nonNulls.join(' · ');

  /// The kit if there is one, otherwise the class.
  ///
  /// **A kit replaces the class name; it does not qualify it.** Measured
  /// 2026-08-08 — BG:EE's record screen for a Necromancer reads
  /// `Necromancer: Level 1` and `Male / Human / Necromancer / Chaotic Evil`,
  /// with the word "Mage" nowhere on the screen, while the progression
  /// underneath is still the mage's (`Next Level: 2500`). An earlier pass
  /// rendered `Mage (Necromancer)`, which nothing in the game does.
  ///
  /// Measured on a mage school, which is the only kit any fixture carries.
  /// BG:EE names the other kits the same way — a kitted fighter reads
  /// `Berserker` — but that part is convention here until one turns up.
  String? get _classOrKit => kitName ?? rules.className(character.classId);

  /// The character's kit, or `null` when they have none.
  ///
  /// **Settled 2026-08-08 by the four-member `Party` save.** The stored dword
  /// carries the `KIT.IDS` key in its high word: Xzar stores `0x10000000`,
  /// which shifted right 16 is `0x1000` — `MAGESCHOOL_NECROMANCER`, and Xzar
  /// is a Necromancer.
  ///
  /// What made this look undecodable was our own parser. `KIT.IDS` names
  /// `0x4000` twice, `TRUECLASS` first and `MAGESCHOOL_GENERALIST` second,
  /// and the table generator was last-wins — so the row meaning "no kit" was
  /// dropped and the remaining name put a mage school on every plain fighter.
  /// Montaron settles it from the data alone: a Fighter/Thief with no mage
  /// component stores `0x4000`, so `0x4000` cannot be a school.
  String? get kitName => rules.kitName(character.kitId);

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

  /// The class levels this character actually has, in slot order.
  ///
  /// **The count comes from `CLASS.IDS`, never from the bytes.** A savegame
  /// leaves its unused level slots holding `1` in every shipped NPC record
  /// and `0` in the player's own, so a single-class Thief reads `1/1/1` on
  /// disk. Taking the first `classCount` slots reads `FIGHTER_MAGE` as two
  /// and `THIEF` as one, which is what the game shows.
  ///
  /// When the class is not in the table there is nothing better to go on, so
  /// this falls back to the slots that are filled — showing the bytes beats
  /// showing nothing.
  List<int> get classLevels {
    final slots = character.levels;
    final count = rules.classCount(character.classId);
    return count == null
        ? slots.where((level) => level > 0).toList()
        : slots.take(count).toList();
  }

  /// Levels as the game writes them — `1` single-classed, `1/1` multi-classed.
  String get levelLabel => classLevels.isEmpty ? '—' : classLevels.join('/');

  /// Total hit points Constitution adds.
  ///
  /// **The multi-class rule here is inferred, not measured.** The bonus is
  /// multiplied by the *highest* class level, which is right for a
  /// single-class character and right for every fixture available — the
  /// four-member party is level 1 throughout, where every reading gives the
  /// same answer. A higher-level multi-class character would tell us whether
  /// the engine averages it instead, and none exists on this machine.
  ///
  /// **Do not answer it by editing a level** — D10. A level is not a field:
  /// hit dice, THAC0, saving throws, proficiency and spell slots are all
  /// granted on level-up, so writing one produces a character the engine
  /// disagrees with. The answer arrives free once the protagonist's *total*
  /// experience is between 4000 and 5000, where the Fighter half has reached
  /// level 2 and the Mage half has not.
  ///
  /// What the party *did* settle is that the bonus is **not divided among
  /// classes**: Aard is a Fighter/Mage and took the full +2 at Constitution
  /// 16, Montaron a Fighter/Thief and took the full +1 at 15 — and at 18 the
  /// engine printed the full **+4** for Aard, where a halved reading gives 2.
  /// Nor is the *column* softened for a half-mage: +4 is the warrior row.
  int? get hitPointBonus {
    final perLevel = hitPointBonusPerLevel;
    if (perLevel == null) return null;
    // classLevels, not the raw slots: a junk 1 in an unused slot must not be
    // able to become the "highest" level.
    final levels = classLevels;
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
  /// Confirmed at three values, and the third moved the bonus as well as the
  /// base: stored 7 showed as 9 and stored 40 as 42, both at Constitution 16
  /// with the game printing "Bonus Hit Points/Level: +2"; then stored 40 at
  /// Constitution 18 showed as **44**, printing **+4**. Varying the modifier
  /// and not just the number it applies to is what makes this arithmetic
  /// rather than an offset that happens to fit.
  ///
  /// Every run was still level 1, so the multi-class multiplier in
  /// [hitPointBonus] remains untested.
  int? get maximumHitPointsInGame {
    final bonus = hitPointBonus;
    return bonus == null ? null : character.maximumHitPoints + bonus;
  }
}
