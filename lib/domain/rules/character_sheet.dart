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
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/domain/skill_catalogue.dart';

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
  const CharacterSheet({
    required this.character,
    required this.rules,
    this.proficiencies = ProficiencyCatalogue.empty,
    this.skills = SkillCatalogue.empty,
  });

  /// The character as the savegame holds them.
  final Character character;

  /// The game's own tables.
  final GameRules rules;

  /// What the player's `weapprof.2da` calls each proficiency, and how many
  /// pips it allows. Empty on a machine with no game installed.
  final ProficiencyCatalogue proficiencies;

  /// Which thief skills the player's `thiefscl.2da` lets each class allocate.
  /// Empty on a machine with no game installed.
  final SkillCatalogue skills;

  /// Class, race and alignment, the way the record screen writes them.
  ///
  /// Anything the tables cannot name is left out rather than shown as a
  /// number — a raw `173` on a character sheet is noise, not information.
  String get identity => [
    rules.genderName(character.genderId),
    rules.raceName(character.raceId),
    classOrKitName,
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
  String? get classOrKitName => kitName ?? rules.className(character.classId);

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
    // A maximum the game could actually have produced, rather than whatever
    // fits the field. Editing this to 1000 is not editing: measured
    // 2026-08-09, the engine threw away a stored 45 on import and recomputed
    // 12 from class and level. Falls back to the field's width when the
    // tables cannot name the class — the same rule the rest of this sheet
    // follows, since a bound nobody could look up is no bound at all.
    CharacterStat.maximumHitPoints => maximumRolledHitPoints ?? stat.maximum,
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

  /// The rules-table column that governs this character.
  ///
  /// A lookup key, not a rendering — `FIGHTER_MAGE`, never `Fighter / Mage`.
  /// One column serves both `weapprof.2da` and `thiefscl.2da`, which share a
  /// vocabulary.
  String? get classColumn => rules.classColumn(
    classId: character.classId,
    kitId: character.kitId,
  );

  /// The most pips [proficiencyId] allows **this character**, or `null`.
  ///
  /// **`null` rather than `0` when nothing is known**, and the difference
  /// matters: an editor that capped at zero without a game installed would
  /// refuse every proficiency edit and look broken rather than degraded.
  ///
  /// This is the only source there is. IESDP states no range for opcode 233's
  /// Amount, so the ceiling is the game's own table or nothing.
  int? maximumPipsFor(int proficiencyId) =>
      proficiencies[proficiencyId]?.maximumFor(classColumn);

  /// Whether this character's class may allocate points to [stat] at all.
  ///
  /// The panel greys out what this refuses. Most stats are universal and
  /// always allowed; the seven thief skills are not, and the player's own
  /// `thiefscl.2da` is what says so — a Fighter/Mage has none of them, a Bard
  /// has only Pick Pockets, a Ranger only the two stealth skills.
  ///
  /// **`true` whenever the tables cannot answer**, which covers three
  /// different cases and deliberately treats them alike:
  ///
  /// - no game installed, so [skills] is empty;
  /// - a class or kit the player's table has no column for;
  /// - a stat with no row at all — Lore, which every class has, and Turn
  ///   Undead and Tracking, for which no governing table has been found.
  ///
  /// Refusing an edit on the strength of a table that was never read would be
  /// a broken screen rather than a careful one.
  bool allows(CharacterStat stat) =>
      skills.allowanceFor(stat.thiefSkillRow, classColumn) != 0;

  /// Whether this character's class may have proficiency [id] at all.
  ///
  /// A cap of `0` in `weapprof.2da` is how the table says "not this class" —
  /// a Fighter/Mage gets 0 in Quarterstaff. Unknown to the table is *not* the
  /// same as forbidden, so that answers `true`.
  bool allowsProficiency(int id) => maximumPipsFor(id) != 0;

  /// Why [stat] cannot be edited, or `null` when it can.
  ///
  /// Phrased for a tooltip, and it names both the class and the table so the
  /// claim can be checked rather than taken on trust.
  String? unavailableReason(CharacterStat stat) {
    if (allows(stat)) return null;
    final name = rules.className(character.classId);
    final kit = kitName;
    final who = kit ?? name ?? 'This character';
    return '$who cannot allocate ${stat.label}. The game’s own '
        'thiefscl.2da gives ${classColumn ?? 'this class'} 0% of that skill, '
        'so the value is shown but not editable.';
  }

  /// What to call [proficiencyId] on screen.
  ///
  /// Degrades in steps, each one a little less informative and none of them
  /// invented: the talk table's name, else the rules table's own identifier,
  /// else the number. A blank tile would be the only worse answer.
  String proficiencyLabel(int proficiencyId) {
    final entry = proficiencies[proficiencyId];
    return entry?.name ?? entry?.identifier ?? 'Proficiency $proficiencyId';
  }

  /// Strength as the game writes it — `18/27` — or `null` when there is no
  /// percentile to write.
  ///
  /// **One value on screen, two bytes in the record.** BG:EE's own
  /// character-creation summary reads `Strength: 18/27` where the record keeps
  /// 18 at `0x238` and 27 at `0x239`. Both bytes stay separately editable,
  /// because both are real; this is only how the pair is *read out*.
  ///
  /// Only a Strength of exactly 18 has a percentile — the engine consults
  /// `strmodex.2da` nowhere else — so every other score is written plainly.
  ///
  /// ⚠️ **The 100 case is the one part of this not measured.** The player's
  /// own `strmodex.2da` runs 0 to 100 and keeps **100 as its own top row**
  /// (`TO_HIT 2, DAMAGE 4`), so the engine plainly *stores* 100; that it
  /// *prints* `18/00` is the percentile-dice convention, and no fixture or
  /// screenshot here has shown it. Rendered rather than withheld — a wrong
  /// rendering on screen can be falsified, an omission cannot — and one look
  /// at a character with a percentile of 100 settles it.
  String? get strengthInGame {
    final percentile = character.abilities.strengthBonus;
    if (character.abilities.strength != 18 || percentile == 0) return null;
    final written = percentile == 100 ? 0 : percentile;
    return '18/${written.toString().padLeft(2, '0')}';
  }

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
  /// **Multiplied by the MEAN of the class levels. Measured 2026-08-09,
  /// closing D10.** Draa — a Fighter 2 / Mage 1 at Constitution 18 — stores a
  /// maximum of 12, and BG:EE draws **18 / 18** into the portrait it saves
  /// beside the game. The bonus is 6: `4 × 1.5`. The *highest* class level,
  /// which this getter used until then, gives 8 and would have shown 20.
  ///
  /// The two candidate rules were never rivals — `bonus × Σlevels ÷ nClasses`
  /// **is** `bonus × mean(levels)`, identically, for any number of classes.
  ///
  /// ⚠️ **For a single class the mean and the highest are the same number**,
  /// which is why every earlier reading agreed and this stayed wrong for two
  /// days without a test failing.
  ///
  /// The *rate* is still not divided: Aard took the full +2 at Constitution 16
  /// and the engine printed the full **+4** at 18, where a halved rate gives
  /// 2. Nor is the column softened for a half-mage — +4 is the warrior row.
  /// It is the multiplier that is a mean, not the rate.
  ///
  /// **Residual unknown, not guessed at:** how the engine rounds when the mean
  /// is not exact. Constitution 17 (+3) at 2/1 gives 4.5. Integer division
  /// truncates here; nothing has measured which way the engine goes.
  int? get hitPointBonus {
    final perLevel = hitPointBonusPerLevel;
    if (perLevel == null) return null;
    // classLevels, not the raw slots: a junk 1 in an unused slot must not be
    // allowed to drag the mean.
    final levels = classLevels;
    if (levels.isEmpty) return null;
    return perLevel * levels.reduce((a, b) => a + b) ~/ levels.length;
  }

  /// The most hit points this character could have **rolled**, before
  /// Constitution — or `null` when the tables cannot name their class.
  ///
  /// **Each class rolls its own die to its own level, and the total is split
  /// between them.** Measured: an imported Fighter 2 / Mage 1 arrived with
  /// exactly `(10 + 10) ÷ 2 + 4 ÷ 2` = **12**, and a Fighter 1→2 level-up
  /// stored **+5**, which is `HPWAR` halved. See
  /// [GeneratedGameRules.classHitDice] for why the game's own `HPFM` table is
  /// not what this uses.
  ///
  /// **Rounded up.** A ceiling a point low refuses a value the game would
  /// happily produce, and refusing legitimate edits is the friction this
  /// exists to remove; a ceiling a point high merely fails to catch one
  /// absurd value.
  int? get maximumRolledHitPoints {
    final identifier = rules.classIdentifier(character.classId);
    if (identifier == null) return null;
    // ⚠️ **The composition lives in `GameRules`, not here.** A created
    // character has to compute the same number with no `Character` to hang it
    // on, and two copies of this arithmetic is how the sheet and the creation
    // flow start disagreeing about what a Fighter/Mage rolls.
    return rules.maximumRolledHitPointsFor(
      classIdentifier: identifier,
      levels: classLevels,
    );
  }

  /// Lore as the game will show it — stored plus Intelligence plus Wisdom.
  ///
  /// ⚠️ **Both abilities, and this is D14's second trap.** The stored value is
  /// the class-and-level part alone: the probe stored **3** and its record
  /// screen printed **83**, which is 3 + `LOREBON[Int 25]` 40 +
  /// `LOREBON[Wis 25]` 40. An editor that recomputed the stored value when an
  /// ability changed would double-count against the engine.
  int? get loreInGame {
    final fromIntelligence = rules.loreBonusFor(
      character.abilities.intelligence,
    );
    final fromWisdom = rules.loreBonusFor(character.abilities.wisdom);
    if (fromIntelligence == null || fromWisdom == null) return null;
    return character.thiefSkills.lore + fromIntelligence + fromWisdom;
  }

  /// A thief skill as the game will show it, or `null`.
  ///
  /// Stored plus `SKILLDEX` for Dexterity plus `SKILLRAC` for the race —
  /// confirmed on all seven of the probe's skills at once. `null` for a stat
  /// that is not a thief skill at all.
  int? thiefSkillInGame(CharacterStat stat) {
    final row = stat.thiefSkillRow;
    if (row == null) return null;

    final bonus = rules.thiefSkillBonusFor(
      row: row,
      dexterity: character.abilities.dexterity,
      raceIdentifier: rules.raceIdentifier(character.raceId),
    );
    if (bonus == null) return null;
    return _storedSkill(stat) + bonus;
  }

  /// The stored value behind [stat], or `0` for a stat with no skill.
  int _storedSkill(CharacterStat stat) {
    final skills = character.thiefSkills;
    return switch (stat) {
      CharacterStat.pickPockets => skills.pickPockets,
      CharacterStat.lockpicking => skills.lockpicking,
      CharacterStat.findTraps => skills.findTraps,
      CharacterStat.moveSilently => skills.moveSilently,
      CharacterStat.hideInShadows => skills.hideInShadows,
      CharacterStat.detectIllusion => skills.detectIllusion,
      CharacterStat.setTraps => skills.setTraps,
      _ => 0,
    };
  }

  /// What Strength takes off THAC0, or `null` off the table.
  ///
  /// Positive is an improvement: the probe stored `Base THAC0: 25` and the
  /// screen printed `THAC0: 22` with `Strength Modification: -3`.
  int? get strengthToHit => rules.strengthToHitFor(
    strength: character.abilities.strength,
    percentile: character.abilities.strengthBonus,
  );

  /// THAC0 as the game will show it, or `null` off the table.
  int? get thac0InGame {
    final bonus = strengthToHit;
    return bonus == null ? null : character.thac0 - bonus;
  }

  /// The chance this character has of learning a spell, as a percentage.
  int? get chanceToLearnSpell =>
      rules.chanceToLearnSpellFor(character.abilities.intelligence);

  /// Attacks per round, as the game writes it — `1`, `3/2`, `9/2`.
  ///
  /// ⚠️ **The stored byte is not a count.** 0 to 5 are whole attacks and 6 to
  /// 10 are halves, so a stored **10** is four and a half attacks and the game
  /// prints **9/2**. The sheet printed the raw byte until this existed, which
  /// showed that character as attacking ten times a round.
  ///
  /// Written as the game writes it — a vulgar fraction, not `4.5` — because
  /// that is what the player will be comparing it against.
  String get attacksPerRound {
    final stored = character.numberOfAttacks;
    if (stored <= wholeAttacksCeiling) return '$stored';
    // 6 is one half, 7 is three halves, and so on: `(stored - 5) * 2 - 1`.
    return '${(stored - wholeAttacksCeiling) * 2 - 1}/2';
  }

  /// The highest stored value that means whole attacks rather than halves.
  static const int wholeAttacksCeiling = 5;

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
