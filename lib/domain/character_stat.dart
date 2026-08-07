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
  /// **Measured 2026-08-07: writing this had no visible effect in game.** Set
  /// to 8 on a real save, BG:EE still showed a base armour class of 10.
  armorClassNatural(CreHeaderField.armorClassNatural, 'Armour class (natural)'),

  /// Effective armour class — IESDP's "Armor Class (Effective)".
  ///
  /// Editable so the next in-game run can settle which field the engine
  /// actually reads. The observed base of 10 is **ambiguous**: it is both the
  /// value this field already held and the unarmoured default, so "the engine
  /// reads this one" and "the engine recomputes armour class from scratch"
  /// both fit. Writing a value that cannot arise naturally separates them.
  armorClassEffective(
    CreHeaderField.armorClassEffective,
    'Armour class (effective)',
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
