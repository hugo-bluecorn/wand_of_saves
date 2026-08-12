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

/// Aard, a Fighter 2 / Mage 1, and the lineup he appears in.
///
/// ⚠️ **Provenance.** Every value marked *(record)* below is read straight off
/// `docs/findings/screens/level-up/03-record-after-level-2.png` — BG:EE's own
/// record screen. Values not on that screen are illustrative and chosen to be
/// internally consistent; they are demo data for judging layout, not rules
/// claims, and nothing here should be cited as a format or rules finding.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/demo_character.dart';

/// The character every spike draws.
const DemoCharacter aard = DemoCharacter(
  name: 'Aard',
  fileName: 'AARD.CHR',
  levelLine: 'Level 2/1',
  // Four lines, the way the engine prints them, rather than one concatenated
  // sentence. A spike may join them; the point is that it is a choice.
  identity: ['Male', 'Elf', 'Fighter / Mage', 'Neutral Good'],
  experienceLine: 'Next level in 500 XP',
  proficiencies: _proficiencies,
  equipped: _equipped,
  backpack: _backpack,
  anomalies: _anomalies,
  // Six pips granted, six spent — so the sheet opens on the exhausted
  // state, which is the one worth seeing.
  proficiencySlots: 6,
  spellbooks: [_mageBook],
  sections: [_character, _abilities, _skills, _combat, _inventory],
);

/// The second card in the lineup, so the home screen is not a single tile.
const DemoCharacter nadia = DemoCharacter(
  name: 'Nadia',
  fileName: 'NADIA.CHR',
  levelLine: 'Level 4',
  // ⚠️ A kit **replaces** the class name. The game writes `Swashbuckler`,
  // never `Thief (Swashbuckler)`.
  identity: ['Female', 'Halfling', 'Swashbuckler', 'Chaotic Good'],
  experienceLine: 'Next level in 2,750 XP',
  proficiencies: [],
  equipped: [],
  backpack: [],
  anomalies: [],
  sections: [],
);

// Held out of the list literal because adjacent string concatenation inside one
// reads as a missing comma, and very_good_analysis says so.
const String _staleReputation =
    'Reputation reads 10 here where the party holds 11 — every record but '
    "the protagonist's goes stale.";

const List<String> _anomalies = [
  'Tracking holds 25, and a Fighter / Mage cannot allocate it.',
  _staleReputation,
  'Two-Weapon Style is at its ceiling of 3 pips.',
];

const DemoSection _character = DemoSection(
  'Character',
  Icons.person_outline,
  [
    DemoGroup('Character', [
      DemoField(
        'Current hit points',
        '18',
        caveat: 'Clamped to the maximum when the save is loaded.',
      ),
      DemoField(
        'Maximum hit points',
        '12',
        inGame: '18',
        arithmetic: 'stored 12, +6 from Constitution 18',
        source: FieldSource.derived,
      ),
      DemoField('Experience', '2000'), // (record)
      DemoField(
        'Gold (carried)',
        '189',
        rulesMaximum: 5000,
        gameMaximum: 999999,
      ),
      DemoField(
        'Reputation (party)',
        '10',
        inGame: '11', // (record) — the screen prints Average (11)
        caveat: "The party's, not this character's. Every record but the "
            "protagonist's goes stale.",
        source: FieldSource.derived,
      ),
    ]),
    DemoGroup('Condition', [
      DemoField('Fatigue', '0'),
      DemoField(
        'Intoxication',
        '0',
        caveat: 'Any value above zero disables EXPORT in the game.',
      ),
    ]),
  ],
);

const DemoSection _abilities = DemoSection(
  'Abilities',
  Icons.fitness_center_outlined,
  [
    DemoGroup('Abilities', [
      DemoField(
        'Strength',
        '19', // (record)
        // Creation cannot roll past 18; the engine draws and applies up to 25.
        rulesMaximum: 18,
        gameMaximum: 25,
        arithmetic: '+3 to hit, +7 to damage',
      ),
      // ⚠️ 148 px truncated this label. It is here on purpose.
      DemoField(
        'Exceptional strength',
        '0',
        available: false,
        caveat: 'Only a Strength of exactly 18 carries a percentile.',
      ),
      DemoField(
        'Dexterity',
        '17', // (record)
        arithmetic: '−3 to armour class',
      ),
      DemoField(
        'Constitution',
        '18', // (record)
        arithmetic: '+6 hit points at this class and level',
      ),
      DemoField(
        'Intelligence',
        '18', // (record)
        arithmetic: '85% chance to learn a spell',
      ),
      DemoField('Wisdom', '9'), // (record)
      DemoField('Charisma', '9'), // (record)
      // ⚠️ Moved here when `What the game shows` was dissolved. That group held
      // a second copy of `Lore` — the same label twice on one sheet, which is
      // the duplication the review found in the real application. Every row
      // now carries stored beside in-game, so the group had nothing left to
      // say. This one had no stored counterpart to merge into, and it is
      // computed from Intelligence, so it belongs beside it.
      DemoField(
        'Chance to learn a spell',
        '85',
        unit: '%',
        editable: false,
        arithmetic: 'from Intelligence 18',
        source: FieldSource.derived,
      ),
    ]),
  ],
);

const DemoSection _skills = DemoSection(
  'Skills',
  Icons.psychology_outlined,
  [
    DemoGroup(
      'Skills',
      [
        // ⚠️ The real application caps this at 100 from IESDP's stated range,
        // where a bard at the experience cap legitimately stores about 120.
        // That is the range check being wrong, which is why the two limits
        // here are separate numbers rather than one.
        DemoField('Lore', '3', rulesMaximum: 120, gameMaximum: 255),
        DemoField('Open Locks', '0', available: false),
        DemoField('Find / Disarm Traps', '0', available: false),
        DemoField('Pick Pockets', '0', available: false),
        DemoField('Move Silently', '0', available: false),
        DemoField('Hide in Shadows', '0', available: false),
        DemoField('Detect Illusion', '0', available: false),
        DemoField('Set Traps', '0', available: false),
        DemoField('Turn Undead level', '0', available: false),
        // ⚠️ The anomaly: greyed by the table, but the record holds it, so it
        // stays editable. A value you cannot touch is one you cannot correct.
        DemoField(
          'Tracking',
          '25',
          // A Fighter / Mage allocates none of this, so the rules ceiling is
          // zero and the stored 25 is already past it — the inherited
          // violation the linter must flag without holding the record hostage.
          rulesMaximum: 0,
          gameMaximum: 100,
          available: false,
          anomalous: true,
          caveat: 'A Fighter / Mage cannot allocate this, but the record '
              'holds it. Editable so it can be corrected.',
        ),
      ],
      note: 'A Fighter / Mage has no thief skills — the greyed rows are what '
          'the class cannot allocate.',
    ),
  ],
);

const DemoSection _combat = DemoSection(
  'Combat',
  Icons.shield_outlined,
  [
    DemoGroup('Combat', [
      DemoField(
        'THAC0 (base)',
        '15', // (record)
        // The rules give a Fighter 2 a base of 19; anything lower is already a
        // bonus, and 25 was stored, imported and played (the engine never
        // recomputes it). So the rules ceiling and the game's are far apart.
        rulesMaximum: 20,
        gameMaximum: 25,
        inGame: '12', // (record) — Main Hand THAC0
        arithmetic: 'stored 15, −3 from Strength 19',
        caveat: 'The engine never recomputes this: a stored value survives a '
            'level-up, better or worse.',
      ),
      DemoField(
        'Armour class (natural)',
        '10',
        caveat: 'Measured twice: changing this alone does not move what the '
            'game shows.',
      ),
      DemoField(
        'Armour class (effective)',
        '6',
        inGame: '3',
        arithmetic: 'stored 6, −3 from Dexterity 17',
      ),
      DemoField(
        'Attacks per round',
        '2', // (record)
        arithmetic: 'stored 2 — 6 to 10 are halves, so 10 draws as 9/2',
      ),
      // ⚠️ 190 px truncated this label to `Paralysis / Poison / De…`, and it is
      // what drove the current 222 px tile. Any layout must hold it.
      DemoField('Paralysis / Poison / Death', '14'), // (record)
      DemoField('Wands / Rods / Staves', '16'),
      DemoField('Petrification / Polymorph', '15'),
      DemoField('Breath weapon', '17'),
      DemoField('Spell', '17'),
      DemoField('Armour class (crushing)', '0'),
      DemoField('Armour class (missile)', '0'),
      DemoField('Armour class (piercing)', '0'),
      DemoField('Armour class (slashing)', '0'),
      DemoField('Morale', '10'),
      DemoField(
        'Morale break',
        '0',
        caveat: 'A break at or above morale panics the character permanently.',
      ),
      DemoField('Luck', '0'),
    ]),
    DemoGroup('Resistances', [
      DemoField('Fire', '0', unit: '%'),
      DemoField('Cold', '0', unit: '%'),
      DemoField('Electricity', '0', unit: '%'),
      DemoField('Acid', '0', unit: '%'),
      DemoField('Magic', '0', unit: '%'),
      DemoField('Magic fire', '0', unit: '%'),
      DemoField('Magic cold', '0', unit: '%'),
      DemoField('Slashing', '0', unit: '%'),
      DemoField('Crushing', '0', unit: '%'),
      DemoField('Piercing', '0', unit: '%'),
      DemoField('Missiles', '0', unit: '%'),
    ]),
  ],
);

const DemoSection _inventory = DemoSection(
  'Inventory',
  Icons.backpack_outlined,
  [],
);

/// Aard's arcane half. A Fighter 2 / **Mage 1**, so one spell level and one
/// memorisation slot.
///
/// ⚠️ **Matched to the engine's own creation flow.** BG:EE's screens for this
/// character show *choose 2* into the book and *1 remaining* to memorise, then
/// Magic Missile memorised — which is why two spells are known and only one is
/// ready.
const DemoSpellbook _mageBook = DemoSpellbook(
  caster: 'Mage',
  learnsIntoBook: true,
  slotsPerLevel: [1],
  known: [_magicMissile, _shield],
  memorised: [_magicMissile],
  available: [
    _magicMissile,
    _shield,
    DemoSpell('Sleep', 1, school: 'Enchantment', note: 'Puts weak foes down.'),
    DemoSpell(
      'Burning Hands',
      1,
      school: 'Evocation',
      note: 'A close cone of flame.',
    ),
    DemoSpell(
      'Charm Person',
      1,
      school: 'Enchantment',
      note: 'One humanoid fights for you.',
    ),
    DemoSpell(
      'Identify',
      1,
      school: 'Divination',
      note: 'Names what an item is.',
    ),
    DemoSpell('Armor', 1, school: 'Conjuration', note: 'Armour class 6.'),
    DemoSpell(
      'Chromatic Orb',
      1,
      school: 'Alteration',
      note: 'Scales with your level.',
    ),
    DemoSpell(
      'Colour Spray',
      1,
      school: 'Alteration',
      note: 'Blinds and stuns a cone.',
    ),
    DemoSpell(
      'Grease',
      1,
      school: 'Conjuration',
      note: 'A slick that drops those crossing it.',
    ),
    DemoSpell(
      'Shocking Grasp',
      1,
      school: 'Alteration',
      note: 'A charged touch.',
    ),
    DemoSpell('Spook', 1, school: 'Illusion', note: 'One target flees.'),
  ],
);

const DemoSpell _magicMissile = DemoSpell(
  'Magic Missile',
  1,
  school: 'Evocation',
  note: 'Never misses. More darts as you level.',
);

const DemoSpell _shield = DemoSpell(
  'Shield',
  1,
  school: 'Evocation',
  note: 'Blocks Magic Missile outright.',
);

/// Every proficiency BG:EE offers, not only the ones Aard has taken — the
/// panel cannot show what is available otherwise.
const List<DemoProficiency> _proficiencies = [
  DemoProficiency('War Hammer', 1, 5),
  // ⚠️ The display name, never the 2DA row label. `FLAILMORNINGSTAR` shipped
  // once and was a defect.
  DemoProficiency('Flail / Morning Star', 2, 5),
  DemoProficiency('Two-Weapon Style', 3, 3),
  DemoProficiency('Long Sword', 0, 5),
  DemoProficiency('Bastard Sword', 0, 5),
  DemoProficiency('Two-Handed Sword', 0, 5),
  DemoProficiency('Short Sword', 0, 5),
  DemoProficiency('Axe', 0, 5),
  DemoProficiency('Katana', 0, 5),
  DemoProficiency('Scimitar / Wakizashi / Ninja-to', 0, 5),
  DemoProficiency('Dagger', 0, 5),
  DemoProficiency('Club', 0, 5),
  DemoProficiency('Mace', 0, 5),
  DemoProficiency('Quarterstaff', 0, 5),
  DemoProficiency('Spear', 0, 5),
  DemoProficiency('Halberd', 0, 5),
  DemoProficiency('Long Bow', 0, 5),
  DemoProficiency('Short Bow', 0, 5),
  DemoProficiency('Crossbow', 0, 5),
  DemoProficiency('Sling', 0, 5),
  DemoProficiency('Dart', 0, 5),
  DemoProficiency('Sword and Shield Style', 0, 2),
  DemoProficiency('Single-Weapon Style', 0, 2),
  DemoProficiency('Two-Handed Weapon Style', 0, 2),
];

const List<DemoItem> _equipped = [
  DemoItem('Battle Axe of Mauletar +2', slot: 'Main hand'),
  DemoItem('Small Shield +1', slot: 'Off hand'),
  DemoItem('Chain Mail', slot: 'Armour'),
  DemoItem('Helmet', slot: 'Helmet'),
  DemoItem('Ring of Protection +1', slot: 'Ring'),
  DemoItem('Boots of Stealth', slot: 'Boots', undroppable: true),
  DemoItem('Cloak of Displacement', slot: 'Cloak'),
  DemoItem('Bullet +1', slot: 'Ammunition', quantity: 40),
];

const List<DemoItem> _backpack = [
  DemoItem('Potion of Healing', quantity: 5),
  DemoItem('Wand of Magic Missiles', charges: 28),
  DemoItem('Scroll of Identify', quantity: 2),
  DemoItem('Bastard Sword', identified: false),
  DemoItem('Antidote', quantity: 3),
  DemoItem('Gem Bag', stolen: true),
  DemoItem('Emerald', quantity: 2),
  DemoItem('Oil of Speed'),
  DemoItem('Bolt +1', quantity: 40),
  DemoItem('Traveller’s Robe'),
  DemoItem('Potion of Fire Resistance'),
  DemoItem('Scroll of Magic Missile'),
];
