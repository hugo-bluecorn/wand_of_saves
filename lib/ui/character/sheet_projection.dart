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

/// Turns a record and its rules into what the Workbench draws.
///
/// Free functions rather than methods on either, for the same reason
/// `party_projection.dart` is a library of them: the projection is **pure** and
/// wanted from more than one place. A savegame's party shell and a `.chr`
/// editor open the same sheet on the same record, and a ViewModel that composed
/// its own presentation model would give the two screens two of them.
///
/// ⚠️ **This is the only place that decides what goes where.** A widget that
/// reached back into `CharacterSheet` for a bound, or into `GameRules` for a
/// name, would be a second answer to a question already answered here — and the
/// panel this replaces had four of them.
///
/// **Nothing is invented.** Where `CharacterSheet` answers `null` — no game
/// installed, a class the tables cannot name, a rule nobody has measured — the
/// row carries no in-game value and no arithmetic, rather than a number that
/// would look authoritative.
library;

import 'package:flutter/material.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/rules/character_sheet.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';

/// [character] as the Workbench draws them, read through [sheet].
///
/// [fileName] is the document they live in — a savegame's slot name or a
/// `.chr`'s file name. It is passed rather than derived because the record
/// itself does not know: the same projection serves a character embedded in a
/// savegame and one exported to a file of their own.
SheetCharacter sheetCharacterFrom({
  required Character character,
  required CharacterSheet sheet,
  required String fileName,
}) => SheetCharacter(
  name: character.name,
  fileName: fileName,
  levelLine: 'Level ${sheet.levelLabel}',
  // `CharacterSheet.identity`, unjoined: the engine prints these on separate
  // lines and the sheet decides whether to join them. Anything the tables
  // cannot name is left out rather than shown as a number.
  identity: [
    sheet.rules.genderName(character.genderId),
    sheet.rules.raceName(character.raceId),
    sheet.classOrKitName,
    sheet.rules.alignmentName(character.alignmentId),
  ].nonNulls.toList(),
  // ⚠️ **The record screen prints `Next Level: 2500` here, and that needs
  // `xplevel.2da`** — a table no `GameTable` value names and no rules API
  // reads. So this is the experience the record holds and nothing more: an
  // invented threshold on a character sheet is worse than a plain total.
  experienceLine: '${character.experience} XP',
  sections: [
    _characterSection(sheet),
    _abilitiesSection(sheet),
    _skillsSection(sheet),
    _combatSection(sheet),
  ],
  proficiencies: _proficienciesFrom(sheet),
  creOffset: character.creOffset,
);

/// The Character section — the numbers that belong to the person.
SheetSection _characterSection(CharacterSheet sheet) {
  final character = sheet.character;
  final perLevel = sheet.hitPointBonusPerLevel;

  return SheetSection('Character', Icons.person_outline, [
    SheetGroup('Character', [
      _statField(
        sheet,
        CharacterStat.currentHitPoints,
        character.currentHitPoints,
        inGame: sheet.currentHitPointsInGame?.toString(),
        caveat: 'Clamped to the maximum when the save is loaded.',
      ),
      _statField(
        sheet,
        CharacterStat.maximumHitPoints,
        character.maximumHitPoints,
        inGame: sheet.maximumHitPointsInGame?.toString(),
        arithmetic: perLevel == null
            ? null
            : 'stored ${character.maximumHitPoints}, '
                  '${_signed(perLevel)}/level from Constitution '
                  '${character.abilities.constitution}',
      ),
      _statField(sheet, CharacterStat.experience, character.experience),
      _statField(
        sheet,
        CharacterStat.gold,
        character.gold,
        label: 'Gold (carried)',
        caveat:
            'This character’s own, not the shared party purse — and the '
            'engine resets it when a character file is imported.',
      ),
    ]),
    SheetGroup('Condition', [
      _statField(
        sheet,
        CharacterStat.fatigue,
        character.fatigue,
        caveat:
            'Play state rather than a property of the character: the '
            'engine resets it when a character file is imported.',
      ),
      _statField(
        sheet,
        CharacterStat.intoxication,
        character.intoxication,
        // Measured, and it is the reason this row is worth a caveat at all.
        caveat: 'Any value above zero disables EXPORT in the game.',
      ),
    ]),
  ]);
}

/// The Abilities section — the game's own ABILITIES step.
SheetSection _abilitiesSection(CharacterSheet sheet) {
  final abilities = sheet.character.abilities;
  final toHit = sheet.strengthToHit;
  final armourClass = sheet.armourClassModifier;
  final hitPoints = sheet.hitPointBonus;
  final chance = sheet.chanceToLearnSpell;

  return SheetSection('Abilities', Icons.fitness_center_outlined, [
    SheetGroup('Abilities', [
      _statField(
        sheet,
        CharacterStat.strength,
        abilities.strength,
        inGame: sheet.strengthInGame,
        // ⚠️ To hit only. `strmod`'s DAMAGE column is read by no rules API
        // here, and half a sum is better than an invented one.
        arithmetic: toHit == null || toHit == 0
            ? null
            : '${_signed(toHit)} to hit',
      ),
      _statField(
        sheet,
        CharacterStat.strengthBonus,
        abilities.strengthBonus,
        caveat:
            'Only a Strength of exactly 18 carries a percentile. Shown '
            'because the record really does hold it.',
      ),
      _statField(
        sheet,
        CharacterStat.dexterity,
        abilities.dexterity,
        arithmetic: armourClass == null || armourClass == 0
            ? null
            : '${_signed(armourClass)} to armour class',
      ),
      _statField(
        sheet,
        CharacterStat.constitution,
        abilities.constitution,
        arithmetic: hitPoints == null || hitPoints == 0
            ? null
            : '${_signed(hitPoints)} hit points at this class and level',
      ),
      _statField(
        sheet,
        CharacterStat.intelligence,
        abilities.intelligence,
        arithmetic: chance == null ? null : '$chance% chance to learn a spell',
      ),
      _statField(sheet, CharacterStat.wisdom, abilities.wisdom),
      _statField(sheet, CharacterStat.charisma, abilities.charisma),
      // ⚠️ Beside the score it comes from, rather than in a group of derived
      // values. That group also held a second `Lore` — the same label twice on
      // one sheet, which is the duplication the UI review found.
      if (chance != null)
        SheetField(
          'Chance to learn a spell',
          '$chance',
          unit: '%',
          editable: false,
          arithmetic: 'from Intelligence ${abilities.intelligence}',
          source: FieldSource.derived,
        ),
    ]),
  ]);
}

/// The Skills section — the game's SKILLS step, less the proficiencies.
///
/// ⚠️ **Proficiencies are not a group here.** They hang off
/// `SheetCharacter.proficiencies`, because a pip is not a [CharacterStat]: it
/// is parameter 1 of an opcode 233 effect, addressed by where that effect sits.
SheetSection _skillsSection(CharacterSheet sheet) {
  final character = sheet.character;
  final skills = character.thiefSkills;
  final lore = sheet.loreInGame;

  return SheetSection('Skills', Icons.psychology_outlined, [
    SheetGroup(
      'Skills',
      [
        _statField(
          sheet,
          CharacterStat.lore,
          skills.lore,
          inGame: lore?.toString(),
          // ⚠️ Both abilities, and the stored value is the class-and-level
          // part alone. An editor that recomputed it would double-count.
          arithmetic: lore == null
              ? null
              : 'stored ${skills.lore}, + Intelligence + Wisdom',
        ),
        for (final (stat, value) in _thiefSkillsOf(character))
          _thiefSkillField(sheet, stat, value),
        _statField(
          sheet,
          CharacterStat.turnUndeadLevel,
          character.turnUndeadLevel,
          caveat: _classGated,
        ),
        _statField(
          sheet,
          CharacterStat.trackingSkill,
          character.trackingSkill,
          caveat: _classGated,
        ),
      ],
      note: _skillsNote(sheet),
    ),
  ]);
}

/// The Combat section — how they fight, and what they shrug off.
SheetSection _combatSection(CharacterSheet sheet) {
  final character = sheet.character;
  final saves = character.savingThrows;
  final modifiers = character.armorClassModifiers;
  final toHit = sheet.strengthToHit;
  final dexterity = sheet.armourClassModifier;

  return SheetSection('Combat', Icons.shield_outlined, [
    SheetGroup('Combat', [
      _statField(
        sheet,
        CharacterStat.thac0,
        character.thac0,
        label: 'THAC0 (base)',
        inGame: sheet.thac0InGame?.toString(),
        // ⚠️ Signed as the change to THAC0, not as the Strength bonus: a bonus
        // of 3 takes 3 *off*, and at a low Strength the table's own number is
        // negative — where the panel's `20 − -1` reads as a typo.
        arithmetic: toHit == null
            ? null
            : 'stored ${character.thac0}, ${_signed(-toHit)} from Strength '
                  '${character.abilities.strength}',
        caveat:
            'The engine never recomputes this: a stored value survives a '
            'level-up, better or worse. Measured.',
      ),
      _statField(
        sheet,
        CharacterStat.armorClassNatural,
        character.armorClassNatural,
        caveat:
            'Measured twice: changing this alone does not move what the '
            'game shows.',
      ),
      _statField(
        sheet,
        CharacterStat.armorClassEffective,
        character.armorClass,
        inGame: sheet.armourClassInGame?.toString(),
        arithmetic: dexterity == null
            ? null
            : 'stored ${character.armorClass}, ${_signed(dexterity)} from '
                  'Dexterity ${character.abilities.dexterity}',
        caveat: 'The field the engine actually reads. Confirmed in game.',
      ),
      _statField(
        sheet,
        CharacterStat.numberOfAttacks,
        character.numberOfAttacks,
        inGame: sheet.attacksPerRound,
        arithmetic: 'stored ${character.numberOfAttacks} — 6 to 10 are halves',
      ),
      _statField(
        sheet,
        CharacterStat.saveVersusDeath,
        saves.death,
        caveat:
            'The five saving throws are stored exactly as the game prints '
            'them — nothing is added before display. Lower is better.',
      ),
      _statField(sheet, CharacterStat.saveVersusWands, saves.wands),
      _statField(sheet, CharacterStat.saveVersusPolymorph, saves.polymorph),
      _statField(sheet, CharacterStat.saveVersusBreath, saves.breath),
      _statField(sheet, CharacterStat.saveVersusSpells, saves.spells),
      _statField(sheet, CharacterStat.armorClassCrushing, modifiers.crushing),
      _statField(sheet, CharacterStat.armorClassMissile, modifiers.missile),
      _statField(sheet, CharacterStat.armorClassPiercing, modifiers.piercing),
      _statField(sheet, CharacterStat.armorClassSlashing, modifiers.slashing),
      _statField(sheet, CharacterStat.morale, character.morale),
      _statField(
        sheet,
        CharacterStat.moraleBreak,
        character.moraleBreak,
        // Measured by writing it at maximum, which is what an editor lets
        // someone do: a field bound is not a safety check.
        caveat:
            'At or above morale the character panics permanently — no '
            'commands, no Save Game, no EXPORT. The protagonist stores 0.',
      ),
      _statField(sheet, CharacterStat.luck, character.luck),
    ]),
    SheetGroup('Resistances', [
      for (final (stat, value) in _resistancesOf(character))
        _statField(sheet, stat, value, unit: '%'),
    ]),
  ]);
}

/// One stat as a row, with every verdict D16 needs already decided.
///
/// **The single place the flags are set.** `editable`, `available`,
/// `anomalous`, `source` and the two ceilings are each one rule, and a screen
/// that worked any of them out for itself would be a second rule.
SheetField _statField(
  CharacterSheet sheet,
  CharacterStat stat,
  int value, {
  String? label,
  String? inGame,
  String? arithmetic,
  String? caveat,
  String? unit,
}) {
  final available = _availableFor(sheet, stat);
  return SheetField(
    label ?? stat.label,
    '$value',
    stat: stat,
    inGame: inGame,
    arithmetic: arithmetic,
    caveat: caveat,
    // ⚠️ **`engineOwned` is NOT "read-only", and reading it that way would
    // regress a proven capability.** D14 measured the **import** boundary: gold
    // and fatigue are reset when a `.chr` goes into a new game. Editing gold in
    // a running savegame works and has been confirmed in BG:EE. So the field
    // stays editable and carries `FieldSource.derived` to say the edit is
    // provisional — which is what that value's own dartdoc means by it.
    available: available,
    // ⚠️ A stored value the class cannot have keeps the row editable, which is
    // what `SheetField.enabledUnder` reads this for: an anomaly you cannot
    // touch is one you cannot correct.
    anomalous: value != 0 && !available,
    source: stat.engineOwned ? FieldSource.derived : FieldSource.authored,
    unit: unit,
    rulesMaximum: _rulesMaximumFor(sheet, stat, available: available),
    gameMaximum: stat.maximum,
  );
}

/// One thief skill, with what the game will draw beside what was allocated.
///
/// ⚠️ **Silent about the game's number when the class cannot allocate the
/// skill**, and that is a correctness rule rather than a tidiness one. The
/// modifiers are readable for any character — `skilldex` and `skillrac` answer
/// for a Fighter/Mage as readily as for a thief — so this used to compute
/// `0 + Dexterity + race` and print the result. **The engine draws no such
/// row.** Measured 2026-08-10: a stored 25 and 100 on a Fighter/Mage/Thief both
/// survived the record and the Skills tab showed *neither*, so the display is
/// class-gated and a stored value alone grants nothing.
///
/// The `in game` value is the one thing on this sheet that claims to speak for
/// the engine, so a wrong number there is worse than a missing one.
///
/// ⚠️ **An anomaly gets the same silence.** Whether the engine draws a *stored*
/// value on a gated row was not established by that run — only that it drew
/// nothing on the screen. Absent, rather than invented in either direction.
SheetField _thiefSkillField(
  CharacterSheet sheet,
  CharacterStat stat,
  int value,
) {
  final shown = _availableFor(sheet, stat)
      ? sheet.thiefSkillInGame(stat)
      : null;
  return _statField(
    sheet,
    stat,
    value,
    inGame: shown?.toString(),
    arithmetic: shown == null ? null : 'allocated, + Dexterity + race',
  );
}

/// Whether the class may have [stat] at all.
///
/// `CharacterSheet.allows` for everything with a `thiefscl.2da` row, plus the
/// one field whose availability depends on another field's value: a percentile
/// is meaningful only at a Strength of exactly 18, which is the one score the
/// engine consults `strmodex.2da` for. Measured 2026-08-09 — a character
/// storing 19/100 arrived in a new game as 19/0.
bool _availableFor(CharacterSheet sheet, CharacterStat stat) => switch (stat) {
  CharacterStat.strengthBonus => sheet.character.abilities.strength == 18,
  _ => sheet.allows(stat),
};

/// The largest value the game's own tables would produce for [stat] here.
///
/// Three cases, and keeping them apart is what D16 is:
///
/// - **`0` when the class may not have the field at all.** `thiefscl.2da`
///   giving `FIGHTER_MAGE` 0% of Open Locks is the rules saying the number
///   should be zero — so a stored 40 is beyond the rules, which is what the
///   sheet should say about it while still letting it be corrected.
/// - **`null` when the rules bound is the field's own width**, because then
///   there is no gap to report, and a rules ceiling equal to the hard one
///   would draw a limit that is not a rule.
/// - Otherwise the bound `CharacterSheet` computes — current hit points
///   against the maximum, maximum hit points against what the class dice
///   could have rolled.
int? _rulesMaximumFor(
  CharacterSheet sheet,
  CharacterStat stat, {
  required bool available,
}) {
  if (!available) return 0;
  final bound = sheet.upperBoundFor(stat);
  return bound == stat.maximum ? null : bound;
}

/// Every proficiency the sheet can name, and every one the record holds.
///
/// ⚠️ **The catalogue's rows first, then anything the record holds that the
/// catalogue does not name**, because either half can be missing and dropping
/// either loses something. A list of only what is taken cannot say what else is
/// available, which is the whole interaction; and on a machine with no game
/// installed the catalogue is empty, where showing nothing would hide the pips
/// the character actually has.
List<SheetProficiency> _proficienciesFrom(CharacterSheet sheet) {
  final held = {
    for (final proficiency in sheet.character.proficiencies)
      proficiency.id: proficiency,
  };

  // ⚠️ **A row that names nothing is not a proficiency.** BG:EE's
  // `weapprof.2da` ends with fourteen padding rows — `EXTRA2`…`EXTRA15`, IDs
  // 116–129 — whose `NAME_REF` is 4294967296, which is 2^32 and beyond any talk
  // table, and whose every class column is zero. `ResourceRepository` already
  // rejects an out-of-range strref, so they arrive with a null `nameStrref` and
  // that is the signal. Offered unfiltered, they became fourteen rows labelled
  // with their own row label — the `FLAILMORNINGSTAR` defect class — each
  // reading `0/0` under an `at ceiling` tag.
  //
  // ⚠️ **Gated on `nameStrref`, never on `name`.** A machine with no game
  // installed resolves no names at all; filtering on the resolved string would
  // empty the panel there instead of degrading it.
  //
  // ⚠️ **The catalogue half only.** A pip the record actually holds survives
  // regardless, because an anomaly you cannot touch is one you cannot correct.
  final named = {
    for (final entry in sheet.proficiencies.entries.entries)
      if (entry.value.nameStrref != null) entry.key,
  };

  return [
    for (final id in {...named, ...held.keys})
      SheetProficiency(
        id,
        sheet.proficiencyLabel(id),
        held[id]?.pips ?? 0,
        sheet.maximumPipsFor(id) ?? _unknownPipCeiling,
        effectOffset: held[id]?.effectOffset,
      ),
  ];
}

/// [value] with its sign, in the typographic minus the game's screens use.
String _signed(int value) => value < 0 ? '−${-value}' : '+$value';

/// The pip ceiling used when no table was read.
///
/// ⚠️ **`SheetProficiency.maximum` cannot say "unknown", and the two candidates
/// are not equivalent.** `maximumPipsFor` answers `null` on a machine with no
/// game installed; a ceiling of `0` there would refuse every proficiency edit
/// on the screen and look broken rather than degraded. This refuses only a
/// sixth pip, which no column of `weapprof.2da` grants anybody — `FIGHTER` is
/// 5 and is the largest.
const int _unknownPipCeiling = 5;

/// What Turn Undead and Tracking cannot say for themselves.
///
/// Measured 2026-08-10: a Fighter/Mage/Thief storing 25 and 100 kept both, and
/// the game's Skills tab drew neither — so the display is gated by class and a
/// stored value alone grants nothing. Which classes qualify is in no table that
/// has been found, so both stay editable rather than take an invented rule.
const String _classGated =
    'The game only draws this for the classes that have it — a stored value '
    'alone grants nothing. Measured.';

/// One line on the skills group, when there is one fact true of all of it.
///
/// Only the case the greyed rows would otherwise leave unexplained: a class
/// with no thief skills at all, which is most of them. Named after the kit when
/// there is one, because a kit replaces the class name rather than qualifying
/// it. `null` on a machine with no game installed, where `allows` answers true
/// for everything and there is nothing to explain.
String? _skillsNote(CharacterSheet sheet) {
  final any = _thiefSkillsOf(
    sheet.character,
  ).any((entry) => sheet.allows(entry.$1));
  if (any) return null;
  final who = sheet.classOrKitName ?? 'This character';
  return '$who has no thief skills — the greyed rows are what the class '
      'cannot allocate.';
}

/// The seven thief skills, in the order the record stores them.
List<(CharacterStat, int)> _thiefSkillsOf(Character character) {
  final skills = character.thiefSkills;
  return [
    (CharacterStat.lockpicking, skills.lockpicking),
    (CharacterStat.findTraps, skills.findTraps),
    (CharacterStat.pickPockets, skills.pickPockets),
    (CharacterStat.moveSilently, skills.moveSilently),
    (CharacterStat.hideInShadows, skills.hideInShadows),
    (CharacterStat.detectIllusion, skills.detectIllusion),
    (CharacterStat.setTraps, skills.setTraps),
  ];
}

/// The eleven resistances, in the order the record stores them.
List<(CharacterStat, int)> _resistancesOf(Character character) {
  final resists = character.resistances;
  return [
    (CharacterStat.resistFire, resists.fire),
    (CharacterStat.resistCold, resists.cold),
    (CharacterStat.resistElectricity, resists.electricity),
    (CharacterStat.resistAcid, resists.acid),
    (CharacterStat.resistMagic, resists.magic),
    (CharacterStat.resistMagicFire, resists.magicFire),
    (CharacterStat.resistMagicCold, resists.magicCold),
    (CharacterStat.resistSlashing, resists.slashing),
    (CharacterStat.resistCrushing, resists.crushing),
    (CharacterStat.resistPiercing, resists.piercing),
    (CharacterStat.resistMissile, resists.missile),
  ];
}
