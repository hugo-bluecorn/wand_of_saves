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

import 'package:infinity_formats/src/spec/format_field.dart';

/// CRE V1.0 header layout — data only, no logic (D6).
///
/// Source: IESDP `file_formats/ie_formats/cre_v1.htm`, confirmed against the
/// 37 creatures embedded in a real BG1EE save.
///
/// **A verified subset, deliberately — unlike `GamNpcField`, this is not the
/// whole table.** IESDP's CRE page interleaves game variants in one column: at
/// `0x0084` a BG1/BG2/BGEE row competes with a run of PSTEE-only rows, and
/// reading them in order produces a *backwards* offset jump. Transcribing all
/// 126 fields of the BGEE branch is possible but is exactly the territory
/// where an error is easy to make and hard to spot.
///
/// So this table runs **without** an exact-fit check, and a stronger guarantee
/// is taken from data instead: [headerSize] is confirmed on every real
/// creature by the first section starting precisely there, and the section
/// chain is asserted to close on the declared file length. See
/// `test/cre/cre_codec_test.dart`.
enum CreHeaderField implements FormatField {
  /// `'CRE '`.
  signature(0x00, 4),

  /// `'V1.0'`.
  version(0x04, 4),

  /// Strref of the long name.
  ///
  /// Signed: `-1` is the engine's "no string" sentinel, and every consumer is
  /// written around a *negative* strref.
  longName(0x08, 4, signed: true),

  /// Strref of the short name, used for tooltips.
  shortName(0x0c, 4, signed: true),

  /// Creature flags.
  flags(0x10, 4),

  /// Experience awarded for *killing* this creature — 0 for most companions.
  killExperience(0x14, 4),

  /// Creature power level for summoning, **or this character's XP**.
  ///
  /// IESDP: *"Creature Power Level (for summoning spells) / XP of the creature
  /// (for party members)"*. One field, two meanings, chosen by what the
  /// creature is. Measured across the fixture: 325 for the protagonist, 36,293
  /// for Minsc, 42 for Khalid — party-joinable characters carry XP here.
  experience(0x18, 4),

  /// Gold carried by this creature.
  gold(0x1c, 4),

  /// Permanent status flags (`STATE.IDS`).
  statusFlags(0x20, 4),

  /// Current hit points.
  currentHitPoints(0x24, 2),

  /// Maximum hit points.
  maximumHitPoints(0x26, 2),

  /// Animation ID.
  animationId(0x28, 4),

  /// Which effect layout the effects section uses: `0` → v1, `1` → v2.
  ///
  /// Not decorative. It selects a 48- or 264-byte entry, and on the fixture
  /// only the 264-byte reading makes the section chain close on the file's
  /// declared length. Get it wrong and the CRE does not parse.
  effectVersion(0x33, 1),

  /// Reputation, stored **times ten** — `110` means 11.0.
  ///
  /// **Unsigned, against IESDP's "1 (signed byte)".** The two claims on that
  /// row contradict each other: the range is 0-20 and the value is stored ×10,
  /// so a reputation of 20 is `200`, which no signed byte holds. Read signed
  /// it would come back as −56 and display as −5.6.
  reputation(0x44, 1),

  /// Natural armour class, before equipment. IESDP: "2 (signed word)".
  armorClassNatural(0x46, 2, signed: true),

  /// Effective armour class, equipment included. IESDP: "2 (signed word)".
  ///
  /// Plate and shield reaches −2, which an unsigned read renders as 65534.
  armorClassEffective(0x48, 2, signed: true),

  /// THAC0.
  thac0(0x52, 1),

  /// Level in the first class.
  levelFirstClass(0x234, 1),

  /// Level in the second class.
  levelSecondClass(0x235, 1),

  /// Level in the third class.
  levelThirdClass(0x236, 1),

  /// Sex (`GENDER.IDS`).
  sex(0x237, 1),

  /// Strength (1-25).
  strength(0x238, 1),

  /// Percentile strength bonus (0-100), meaningful only at Strength 18.
  strengthBonus(0x239, 1),

  /// Intelligence (1-25).
  intelligence(0x23a, 1),

  /// Wisdom (1-25).
  wisdom(0x23b, 1),

  /// Dexterity (1-25).
  dexterity(0x23c, 1),

  /// Constitution (1-25).
  constitution(0x23d, 1),

  /// Charisma (1-25).
  charisma(0x23e, 1),

  /// Morale.
  morale(0x23f, 1),

  /// Offset to the known-spells section, relative to the start of the CRE.
  knownSpellsOffset(0x2a0, 4),

  /// Number of known-spell entries.
  knownSpellsCount(0x2a4, 4),

  /// Offset to the spell-memorisation info section.
  memorizationInfoOffset(0x2a8, 4),

  /// Number of spell-memorisation info entries.
  memorizationInfoCount(0x2ac, 4),

  /// Offset to the memorised-spells section.
  memorizedSpellsOffset(0x2b0, 4),

  /// Number of memorised-spell entries.
  memorizedSpellsCount(0x2b4, 4),

  /// Offset to the item-slot table.
  ///
  /// **The only section with no count field** — the slot table is a fixed
  /// [creItemSlotsLength] bytes.
  itemSlotsOffset(0x2b8, 4),

  /// Offset to the items section.
  itemsOffset(0x2bc, 4),

  /// Number of item entries.
  itemsCount(0x2c0, 4),

  /// Offset to the effects section.
  effectsOffset(0x2c4, 4),

  /// Number of effect entries.
  effectsCount(0x2c8, 4),

  /// Resref of this creature's dialogue file — the last header field.
  dialogFile(0x2cc, 8);

  const CreHeaderField(this.offset, this.length, {this.signed = false});

  /// Bytes of fixed header before the first variable-length section.
  ///
  /// `0x2cc + 8`. Confirmed on every creature in the fixture: the
  /// known-spells offset is exactly this value, so the first section begins
  /// where the header ends.
  static const int headerSize = 724;

  @override
  final int offset;

  @override
  final int length;

  @override
  final bool signed;
}

/// Bytes per known-spell entry. IESDP's sub-table ends at `0x0a` + 2.
const int creKnownSpellLength = 12;

/// Bytes per spell-memorisation info entry. IESDP's sub-table: `0x0c` + 4.
const int creMemorizationInfoLength = 16;

/// Bytes per memorised-spell entry.
const int creMemorizedSpellLength = 12;

/// Bytes in the item-slot table, which is fixed-size and has no count field.
const int creItemSlotsLength = 80;

/// Bytes per item entry. IESDP's sub-table ends at `0x10` + 4.
///
/// Independently corroborated by EE Keeper's disassembly — `imul ebx,ebx,0x14`
/// indexing its inventory array (`docs/findings/eekeeper-reverse-engineering.md`).
const int creItemLength = 20;

/// Bytes per effect entry when [CreHeaderField.effectVersion] is `0`.
const int creEffectV1Length = 48;

/// Bytes per effect entry when [CreHeaderField.effectVersion] is `1`.
const int creEffectV2Length = 264;
