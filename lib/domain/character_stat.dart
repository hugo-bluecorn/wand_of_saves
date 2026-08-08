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

import 'package:infinity_formats/infinity_formats.dart';

/// A numeric field on a character that this build knows how to edit.
///
/// **Curated deliberately.** A command that could name any [CreHeaderField]
/// would be free to write `knownSpellsOffset` and destroy a savegame; this
/// enum is the list of fields where writing a number is a meaningful edit.
///
/// Each value *carries* its [CreHeaderField] rather than restating an offset,
/// so there is still exactly one table of layout facts (D6). Ranges come from
/// IESDP where IESDP states one — "Strength (1-25)", "Strength % Bonus
/// (0-100)" — and otherwise from what the field itself can hold. **No range
/// here is invented**: a game-rules bound like "armour class runs −20 to 20"
/// would need a source this slice does not have, and the rules tables are the
/// next slice's work.
enum CharacterStat {
  /// Strength. IESDP: "Strength (1-25)".
  strength(
    CreHeaderField.strength,
    'Strength',
    declaredMinimum: 1,
    declaredMaximum: 25,
  ),

  /// Percentile strength, meaningful only at [strength] 18.
  /// IESDP: "Strength % Bonus (0-100)".
  strengthBonus(
    CreHeaderField.strengthBonus,
    'Exceptional strength',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Dexterity. IESDP: "(1-25)".
  dexterity(
    CreHeaderField.dexterity,
    'Dexterity',
    declaredMinimum: 1,
    declaredMaximum: 25,
  ),

  /// Constitution. IESDP: "(1-25)".
  constitution(
    CreHeaderField.constitution,
    'Constitution',
    declaredMinimum: 1,
    declaredMaximum: 25,
  ),

  /// Intelligence. IESDP: "(1-25)".
  intelligence(
    CreHeaderField.intelligence,
    'Intelligence',
    declaredMinimum: 1,
    declaredMaximum: 25,
  ),

  /// Wisdom. IESDP: "(1-25)".
  wisdom(
    CreHeaderField.wisdom,
    'Wisdom',
    declaredMinimum: 1,
    declaredMaximum: 25,
  ),

  /// Charisma. IESDP: "(1-25)".
  charisma(
    CreHeaderField.charisma,
    'Charisma',
    declaredMinimum: 1,
    declaredMaximum: 25,
  ),

  /// Current hit points, as stored — without the Constitution bonus.
  currentHitPoints(CreHeaderField.currentHitPoints, 'Current hit points'),

  /// Maximum hit points, as stored — without the Constitution bonus.
  maximumHitPoints(CreHeaderField.maximumHitPoints, 'Maximum hit points'),

  /// Experience points.
  experience(CreHeaderField.experience, 'Experience'),

  /// Gold on this character, not the shared party purse.
  gold(CreHeaderField.gold, 'Gold'),

  /// THAC0. IESDP: "THAC0 (1-25)".
  thac0(CreHeaderField.thac0, 'THAC0', declaredMinimum: 1, declaredMaximum: 25),

  /// Natural armour class — IESDP's "Armor Class (Natural)".
  ///
  /// **Measured twice, and it changes nothing the character sheet shows.** Set
  /// to 8 while the effective field read 10, BG:EE showed 10; left at 8 while
  /// the effective field read 6, BG:EE showed 6. Kept editable because the
  /// field is real and may matter to the engine elsewhere, but it is not the
  /// one that moves armour class.
  armorClassNatural(CreHeaderField.armorClassNatural, 'Armour class (natural)'),

  /// Effective armour class — IESDP's "Armor Class (Effective)".
  ///
  /// **This is the field the engine reads.** Settled 2026-08-08 by writing 6,
  /// a value that cannot arise unarmoured: BG:EE then showed "Armor Class: 6"
  /// and, with Dexterity 17 at −3, an AC of 3. The earlier reading of 10 was
  /// ambiguous — it was both this field's value and the unarmoured default —
  /// so a number that could not arise by accident was what separated them.
  armorClassEffective(
    CreHeaderField.armorClassEffective,
    'Armour class (effective)',
  ),

  /// Attacks per round. IESDP: "Number of attacks (0-10)".
  numberOfAttacks(
    CreHeaderField.numberOfAttacks,
    'Attacks per round',
    declaredMinimum: 0,
    declaredMaximum: 10,
  ),

  /// Save versus death. IESDP: "(0-20)". Lower is better.
  saveVersusDeath(
    CreHeaderField.saveVersusDeath,
    'Paralysis / Poison / Death',
    declaredMinimum: 0,
    declaredMaximum: 20,
  ),

  /// Save versus wands. IESDP: "(0-20)".
  saveVersusWands(
    CreHeaderField.saveVersusWands,
    'Rod / Staff / Wand',
    declaredMinimum: 0,
    declaredMaximum: 20,
  ),

  /// Save versus polymorph. IESDP: "(0-20)".
  saveVersusPolymorph(
    CreHeaderField.saveVersusPolymorph,
    'Petrification / Polymorph',
    declaredMinimum: 0,
    declaredMaximum: 20,
  ),

  /// Save versus breath attacks. IESDP: "(0-20)".
  saveVersusBreath(
    CreHeaderField.saveVersusBreath,
    'Breath Weapon',
    declaredMinimum: 0,
    declaredMaximum: 20,
  ),

  /// Save versus spells. IESDP: "(0-20)".
  saveVersusSpells(
    CreHeaderField.saveVersusSpells,
    'Spell',
    declaredMinimum: 0,
    declaredMaximum: 20,
  ),

  /// Armour class modifier against crushing attacks. Signed; no stated range.
  armorClassCrushing(CreHeaderField.armorClassCrushing, 'vs. crushing'),

  /// Armour class modifier against missile attacks. Signed.
  armorClassMissile(CreHeaderField.armorClassMissile, 'vs. missile'),

  /// Armour class modifier against piercing attacks. Signed.
  armorClassPiercing(CreHeaderField.armorClassPiercing, 'vs. piercing'),

  /// Armour class modifier against slashing attacks. Signed.
  armorClassSlashing(CreHeaderField.armorClassSlashing, 'vs. slashing'),

  /// Hide in Shadows, as points allocated. IESDP states no range.
  hideInShadows(CreHeaderField.hideInShadows, 'Hide in Shadows'),

  /// Detect Illusion. IESDP: "minimum value : 0", and no maximum.
  detectIllusion(
    CreHeaderField.detectIllusion,
    'Detect Illusion',
    declaredMinimum: 0,
  ),

  /// Set Traps. IESDP states no range.
  setTraps(CreHeaderField.setTraps, 'Set Traps'),

  /// Lore. IESDP: "(0-100)".
  lore(
    CreHeaderField.lore,
    'Lore',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Lockpicking — the record screen's "Open Locks". IESDP: "minimum value: 0".
  lockpicking(
    CreHeaderField.lockpicking,
    'Open Locks',
    declaredMinimum: 0,
  ),

  /// Move Silently. IESDP: "minimum value: 0".
  moveSilently(
    CreHeaderField.moveSilently,
    'Move Silently',
    declaredMinimum: 0,
  ),

  /// Find/disarm traps. IESDP: "minimum value: 0".
  findTraps(CreHeaderField.findTraps, 'Find Traps', declaredMinimum: 0),

  /// Pick Pockets. IESDP: "minimum value: 0".
  pickPockets(CreHeaderField.pickPockets, 'Pick Pockets', declaredMinimum: 0),

  /// Fatigue. IESDP: "(0-100)".
  fatigue(
    CreHeaderField.fatigue,
    'Fatigue',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Intoxication. IESDP: "(0-100)".
  intoxication(
    CreHeaderField.intoxication,
    'Intoxication',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Luck. IESDP states no range.
  luck(CreHeaderField.luck, 'Luck'),

  /// Turn undead level. IESDP states no range.
  turnUndeadLevel(CreHeaderField.turnUndeadLevel, 'Turn Undead'),

  /// Tracking skill. IESDP: "(0-100)".
  trackingSkill(
    CreHeaderField.trackingSkill,
    'Tracking',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Morale. IESDP: "default value is 10 (capped 0 — 20)".
  morale(
    CreHeaderField.morale,
    'Morale',
    declaredMinimum: 0,
    declaredMaximum: 20,
  ),

  /// The morale at which the character panics. IESDP states no range.
  moraleBreak(CreHeaderField.moraleBreak, 'Morale break'),

  /// Fire resistance. IESDP: "(0-100)".
  resistFire(
    CreHeaderField.resistFire,
    'Fire',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Cold resistance. IESDP: "(0-100)".
  resistCold(
    CreHeaderField.resistCold,
    'Cold',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Electricity resistance. IESDP: "(0-100)".
  resistElectricity(
    CreHeaderField.resistElectricity,
    'Electricity',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Acid resistance. IESDP: "(0-100)".
  resistAcid(
    CreHeaderField.resistAcid,
    'Acid',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Magic resistance. IESDP: "(0-100)".
  resistMagic(
    CreHeaderField.resistMagic,
    'Magic',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Magic fire resistance. IESDP: "(0-100)".
  resistMagicFire(
    CreHeaderField.resistMagicFire,
    'Magic fire',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Magic cold resistance. IESDP: "(0-100)".
  resistMagicCold(
    CreHeaderField.resistMagicCold,
    'Magic cold',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Slashing resistance. IESDP: "(0-100)".
  resistSlashing(
    CreHeaderField.resistSlashing,
    'Slashing',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Crushing resistance. IESDP: "(0-100)".
  resistCrushing(
    CreHeaderField.resistCrushing,
    'Crushing',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Piercing resistance. IESDP: "(0-100)".
  resistPiercing(
    CreHeaderField.resistPiercing,
    'Piercing',
    declaredMinimum: 0,
    declaredMaximum: 100,
  ),

  /// Missile resistance. IESDP: "(0-100)".
  resistMissile(
    CreHeaderField.resistMissile,
    'Missile',
    declaredMinimum: 0,
    declaredMaximum: 100,
  );

  const CharacterStat(
    this.field,
    this.label, {
    this.declaredMinimum,
    this.declaredMaximum,
  });

  /// The creature-record field this stat is stored in.
  final CreHeaderField field;

  /// What to call it on screen.
  final String label;

  /// The lowest value IESDP documents, or `null` if it documents none.
  ///
  /// Nullable on purpose, and public so the distinction is visible: a stat
  /// with `null` here has no *game-rules* bound this project has a source for,
  /// only what its field can physically hold.
  final int? declaredMinimum;

  /// The highest value IESDP documents, or `null` if it documents none.
  final int? declaredMaximum;

  /// The lowest value this stat accepts.
  int get minimum => declaredMinimum ?? field.minimum;

  /// The highest value this stat accepts.
  int get maximum => declaredMaximum ?? field.maximum;

  /// Whether [value] is one this stat accepts.
  ///
  /// Tighter than what the field can hold: a Strength of 200 fits the byte
  /// perfectly well and is still not a Strength.
  bool holds(int value) => value >= minimum && value <= maximum;
}
