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

  /// Resref of the **medium** portrait — the one a character sheet shows.
  ///
  /// ⚠️ **IESDP calls this "Small Portrait" and it is not.** Measured on eight
  /// records: it holds the `…M` variant — `BDTMIM`, `IMOENM`, `MONTARM`,
  /// `XZARM` — which is 169×266. A field named `smallPortrait` returning
  /// `BDTMIM` is a trap for the next reader, so this is named for what it
  /// holds.
  ///
  /// ⚠️ **The `…S` variant is referenced by no CRE at all.** 54×84 is what the
  /// game bakes into `PORTRT<n>.bmp` beside a save — a different picture for a
  /// different purpose, and the one this project uses as an oracle.
  portraitMedium(0x34, 8),

  /// Resref of the **large** portrait, 210×330.
  ///
  /// ⚠️ IESDP calls this "Large Portrait", which is right — but only by
  /// accident of the pair being swapped. See [portraitMedium].
  portraitLarge(0x3c, 8),

  /// Reputation, stored **times ten** — `110` means 11.0.
  ///
  /// **Unsigned, against IESDP's "1 (signed byte)".** The two claims on that
  /// row contradict each other: the range is 0-20 and the value is stored ×10,
  /// so a reputation of 20 is `200`, which no signed byte holds. Read signed
  /// it would come back as −56 and display as −5.6.
  reputation(0x44, 1),

  /// Hide in Shadows, **as allocated** — see [lore].
  ///
  /// The one thief skill that does not live with the others; IESDP puts it
  /// here, between reputation and armour class, and the rest at `0x64`.
  hideInShadows(0x45, 1),

  /// Natural armour class, before equipment. IESDP: "2 (signed word)".
  armorClassNatural(0x46, 2, signed: true),

  /// Effective armour class, equipment included. IESDP: "2 (signed word)".
  ///
  /// Plate and shield reaches −2, which an unsigned read renders as 65534.
  armorClassEffective(0x48, 2, signed: true),

  /// Armour class modifier against crushing attacks. IESDP: "2 (signed word)".
  armorClassCrushing(0x4a, 2, signed: true),

  /// Armour class modifier against missile attacks. IESDP: "2 (signed word)".
  armorClassMissile(0x4c, 2, signed: true),

  /// Armour class modifier against piercing attacks. IESDP: "2 (signed word)".
  armorClassPiercing(0x4e, 2, signed: true),

  /// Armour class modifier against slashing attacks. IESDP: "2 (signed word)".
  armorClassSlashing(0x50, 2, signed: true),

  /// THAC0.
  ///
  /// A **base**: the game labels it "Base THAC0" and prints a second, lower
  /// figure beside it after Strength, Dexterity and proficiencies.
  thac0(0x52, 1),

  /// Number of attacks per round.
  numberOfAttacks(0x53, 1),

  /// Save versus death. IESDP: "(0-20)". Lower is better.
  ///
  /// The saving throws are stored **exactly as the game prints them** —
  /// verified 2026-08-08 against a record screen reading 14/11/13/15/12 for
  /// a creature holding those five bytes. Unlike hit points, THAC0 and the
  /// thief skills, nothing is added before display.
  saveVersusDeath(0x54, 1),

  /// Save versus wands — the record screen's "Rod / Staff / Wand".
  saveVersusWands(0x55, 1),

  /// Save versus polymorph — "Petrification / Polymorph".
  saveVersusPolymorph(0x56, 1),

  /// Save versus breath attacks — "Breath Weapon".
  saveVersusBreath(0x57, 1),

  /// Save versus spells — "Spell".
  saveVersusSpells(0x58, 1),

  /// Resistance to fire, as a percentage.
  resistFire(0x59, 1),

  /// Resistance to cold, as a percentage.
  resistCold(0x5a, 1),

  /// Resistance to electricity, as a percentage.
  resistElectricity(0x5b, 1),

  /// Resistance to acid, as a percentage.
  resistAcid(0x5c, 1),

  /// Resistance to magic, as a percentage.
  resistMagic(0x5d, 1),

  /// Resistance to magic fire, as a percentage.
  resistMagicFire(0x5e, 1),

  /// Resistance to magic cold, as a percentage.
  resistMagicCold(0x5f, 1),

  /// Resistance to slashing damage, as a percentage.
  resistSlashing(0x60, 1),

  /// Resistance to crushing damage, as a percentage.
  resistCrushing(0x61, 1),

  /// Resistance to piercing damage, as a percentage.
  resistPiercing(0x62, 1),

  /// Resistance to missile damage, as a percentage.
  resistMissile(0x63, 1),

  /// Detect Illusion, **as allocated** — see [lore].
  detectIllusion(0x64, 1),

  /// Set Traps, **as allocated** — see [lore].
  setTraps(0x65, 1),

  /// Lore, **as allocated**. IESDP: "(0-100)".
  ///
  /// ⚠️ **Every skill on this row is a base, not the number the game shows.**
  /// Measured 2026-08-08: a creature storing Lore `3` displayed `10` on one
  /// character and `15` on another, and one storing Move Silently `15`
  /// displayed `35`. The engine adds class, race and Dexterity bonuses. Same
  /// hazard as hit points and THAC0 — label it, do not silently present it as
  /// the skill.
  lore(0x66, 1),

  /// Lockpicking — the record screen's "Open Locks". **As allocated**.
  lockpicking(0x67, 1),

  /// Move Silently, **as allocated** — see [lore].
  moveSilently(0x68, 1),

  /// Find/disarm traps — "Find Traps". **As allocated**.
  findTraps(0x69, 1),

  /// Pick Pockets, **as allocated** — see [lore].
  pickPockets(0x6a, 1),

  /// Fatigue. IESDP: "(0-100)".
  fatigue(0x6b, 1),

  /// Intoxication. IESDP: "(0-100)".
  intoxication(0x6c, 1),

  /// Luck.
  luck(0x6d, 1),

  /// Turn undead level.
  ///
  /// ⚠️ Sits **after** the proficiency bytes at `0x6e`–`0x81`, which BG:EE
  /// leaves empty — proficiencies are opcode 233 effects there, not header
  /// bytes. Those bytes are deliberately absent from this table rather than
  /// recorded as zeroes that mean something.
  turnUndeadLevel(0x82, 1),

  /// Tracking skill. IESDP: "(0-100)".
  trackingSkill(0x83, 1),

  /// Level in the first class.
  levelFirstClass(0x234, 1),

  /// Level in the second class — **junk unless the class uses it.**
  ///
  /// ⚠️ Unused slots are not zeroed. Measured 2026-08-08: the player's own
  /// record stores `01 01 00`, every shipped NPC record stores `01 01 01`,
  /// and that includes single-class characters. **How many slots mean
  /// anything comes from `CLASS.IDS`, never from these bytes.**
  levelSecondClass(0x235, 1),

  /// Level in the third class — **junk unless the class uses it.** See
  /// [levelSecondClass].
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

  /// Morale break — the morale at which the creature panics.
  moraleBreak(0x240, 1),

  /// Racial enemy (`RACE.IDS`), the ranger's chosen foe.
  racialEnemy(0x241, 1),

  /// Morale recovery time.
  moraleRecoveryTime(0x242, 2),

  /// Kit, as a dword carrying the `KIT.IDS` key in its **high word**.
  ///
  /// Reported raw; shift right 16 to get the key. Settled 2026-08-08 against
  /// a four-member party: Xzar stores `0x10000000`, whose `0x1000` is
  /// `MAGESCHOOL_NECROMANCER`, and Xzar is a Necromancer. **"No kit" has two
  /// encodings** — `0x40000000` (`KIT.IDS`'s `TRUECLASS`) and plain `0`.
  kit(0x244, 4),

  /// Race (`RACE.IDS`). `2` is `ELF`.
  race(0x272, 1),

  /// Class (`CLASS.IDS`). `7` is `FIGHTER_MAGE`.
  ///
  /// Named `characterClass` because `class` is a Dart keyword and cannot be an
  /// identifier. The IESDP row is simply "Class".
  characterClass(0x273, 1),

  /// Gender (`GENDER.IDS`). `1` is `MALE`.
  gender(0x275, 1),

  /// Alignment (`ALIGNMEN.IDS`). `0x21` is `NEUTRAL_GOOD`.
  ///
  /// The identifier table for this one is written in **hex**, unlike
  /// `CLASS.IDS` and `RACE.IDS` — the stored byte 33 is `0x21`.
  alignment(0x27b, 1),

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

/// One entry of the known-spells section: a spell the creature may prepare.
enum CreKnownSpellField implements FormatField {
  /// Resref of the `SPL` resource, e.g. `SPWI112`.
  resref(0x00, 8),

  /// ⚠️ **The spell's level *less one*, in IESDP's own words.** A first-level
  /// spell stores `0`. Written straight through, a spellbook comes out full of
  /// level-zero spells — which is why the arithmetic lives behind
  /// `Cre.knownSpells` rather than at each call site.
  levelLessOne(0x08, 2),

  /// `0` priest, `1` wizard, `2` innate.
  type(0x0a, 2);

  const CreKnownSpellField(this.offset, this.length);

  @override
  final int offset;

  @override
  final int length;

  /// Nothing here is signed: two resref halves, a level and an enumeration.
  @override
  bool get signed => false;
}

/// One entry of the spell-memorisation info section.
///
/// ⚠️ **This is the only structure in the format that points *into* another
/// section.** [firstIndex] and [count] name a window of the memorised-spells
/// array, and the engine's own characters lay those windows out as a partition
/// in row order — each row's index is the running total of the counts before
/// it. So inserting a memorised spell anywhere but at the very end rewrites a
/// pointer in a section it did not touch, which is the one place a resize here
/// is not mechanical.
///
/// ⚠️ **The engine writes a full grid, not only the rows in use.** A
/// Fighter / Mage the game made carries seven priest rows and nine wizard rows
/// with `memorisable` zero on every one it cannot cast.
enum CreMemorizationField implements FormatField {
  /// The spell level *less one*, as [CreKnownSpellField.levelLessOne] is.
  levelLessOne(0x00, 2),

  /// How many spells of this level and type may be memorised.
  memorisable(0x02, 2),

  /// The same count after effects have applied — what the engine draws.
  afterEffects(0x04, 2),

  /// `0` priest, `1` wizard, `2` innate.
  type(0x06, 2),

  /// Index into the memorised-spells array of the first spell in this window.
  firstIndex(0x08, 4),

  /// How many memorised-spell entries this window holds.
  count(0x0c, 4);

  const CreMemorizationField(this.offset, this.length);

  @override
  final int offset;

  @override
  final int length;

  /// Counts and an index; none of them is meaningful below zero.
  @override
  bool get signed => false;
}

/// One entry of the memorised-spells section: a spell prepared for casting.
enum CreMemorizedSpellField implements FormatField {
  /// Resref of the `SPL` resource.
  resref(0x00, 8),

  /// Bit 0 memorised, bit 1 disabled — a spell cast today is still listed.
  flags(0x08, 4);

  const CreMemorizedSpellField(this.offset, this.length);

  @override
  final int offset;

  @override
  final int length;

  @override
  bool get signed => false;
}

/// [CreMemorizedSpellField.flags] bit 0: this spell is ready to cast.
const int creSpellMemorizedFlag = 1;

/// [CreMemorizedSpellField.flags] bit 1: this spell has been cast today.
const int creSpellDisabledFlag = 2;

/// Bytes in the item-slot table, which is fixed-size and has no count field.
const int creItemSlotsLength = 80;

/// Bytes per item entry. IESDP's sub-table ends at `0x10` + 4.
///
/// Independently corroborated by EE Keeper's disassembly — `imul ebx,ebx,0x14`
/// indexing its inventory array (`docs/findings/eekeeper-reverse-engineering.md`).
const int creItemLength = 20;

/// One entry of the items section: something the creature is carrying.
///
/// Dense with no gaps, so the table is self-checking under the exact-fit rule.
enum CreItemField implements FormatField {
  /// Resref of the `ITM` resource, e.g. `BOOT01`.
  resref(0x00, 8),

  /// Expiration time in days; `0` means the item does not expire.
  ///
  /// ⚠️ **Not an unknown, and not a wear count.** IESDP names it: above 255 the
  /// item expires at game hour `value - 255`, and within 1–255 it converts to a
  /// delay in days, after which the engine swaps in the ITM's replacement item
  /// or removes it. Anything this project writes leaves it `0`.
  expiration(0x08, 2),

  /// First quantity or charge count.
  ///
  /// **Quantity for a stack, charges for a wand.** The format does not
  /// distinguish them; the `ITM` does, through its extended headers.
  quantity1(0x0a, 2),

  /// Second quantity or charge count — the second ability's charges.
  quantity2(0x0c, 2),

  /// Third quantity or charge count.
  quantity3(0x0e, 2),

  /// Identified, unstealable, stolen and undroppable — see [CreItemFlag].
  flags(0x10, 4);

  const CreItemField(this.offset, this.length);

  @override
  final int offset;

  @override
  final int length;

  /// Nothing here is signed: a resref, three counts and a bit field.
  @override
  bool get signed => false;
}

/// The bits of [CreItemField.flags].
///
/// ⚠️ **EE Keeper exposes a fourth checkbox it calls "Given"**, where IESDP
/// names bit 1 *Unstealable*. Whether those are the same bit under two names is
/// not established, so this follows IESDP and the discrepancy is recorded in
/// `docs/findings/known-defects.md` rather than guessed at.
enum CreItemFlag {
  /// The player knows what it is.
  ///
  /// ⚠️ **This changes the name the engine draws.** Clear, the game shows the
  /// ITM's *unidentified* name — "Belt", not "Belt of Antipode". `Aard1.chr`
  /// carries exactly that case.
  identified(1),

  /// A thief cannot steal it.
  unstealable(2),

  /// It was stolen, so no shopkeeper will buy it.
  stolen(4),

  /// It cannot be removed in game — only from an editor.
  undroppable(8);

  const CreItemFlag(this.mask);

  /// The bit this flag occupies.
  final int mask;

  /// Which flags [stored] sets.
  ///
  /// Unknown bits are ignored rather than refused: the field is four bytes and
  /// IESDP documents four of them, so a record may legitimately carry more than
  /// this enum names.
  static Set<CreItemFlag> setFrom(int stored) => {
    for (final flag in values)
      if (stored & flag.mask != 0) flag,
  };

  /// The stored value for [flags].
  static int maskOf(Iterable<CreItemFlag> flags) =>
      flags.fold(0, (mask, flag) => mask | flag.mask);
}

/// A slot in the creature's inventory, in the order the record stores them.
///
/// ⚠️ **The table is 40 words and only these 38 are item indices.** The last
/// two — [selectedWeaponOffset] and [selectedWeaponAbilityOffset] — are
/// *selection state*, and a model that mapped all forty to items would corrupt
/// them the first time it wrote a slot.
///
/// ⚠️ **There are FOUR quivers**, not three. IESDP marks the fourth
/// "cannot be accesed from GUI" (sic), and a three-quiver model misaligns every
/// slot after it by one word — which silently puts the backpack somewhere else.
///
/// Source: IESDP's CRE V1.0 page, "BG1, BG2, BGEE: There are 40 slots, and they
/// are **not** the same as the order specified in SLOTS.IDS." Confirmed against
/// three real `.chr` fixtures: `Aard1.chr` has `BLUN03` in [shield], the
/// off-hand, and `BOOT01` in [boots].
enum CreItemSlot {
  /// Worn on the head.
  helmet,

  /// Body armour.
  armor,

  /// The off-hand slot — a shield, or a second weapon.
  shield,

  /// Gauntlets and bracers.
  gloves,

  /// Ring, left hand.
  leftRing,

  /// Ring, right hand.
  rightRing,

  /// Amulets and necklaces.
  amulet,

  /// Belts and girdles.
  belt,

  /// Boots.
  boots,

  /// Weapon 1 — the main hand.
  weapon1,

  /// Weapon 2.
  weapon2,

  /// Weapon 3.
  weapon3,

  /// Weapon 4.
  weapon4,

  /// Quiver 1.
  quiver1,

  /// Quiver 2.
  quiver2,

  /// Quiver 3.
  quiver3,

  /// Quiver 4. ⚠️ Real, and unreachable from the game's own interface.
  quiver4,

  /// Cloaks and robes.
  cloak,

  /// Quick item 1.
  quick1,

  /// Quick item 2.
  quick2,

  /// Quick item 3.
  quick3,

  /// Backpack 1.
  pack1,

  /// Backpack 2.
  pack2,

  /// Backpack 3.
  pack3,

  /// Backpack 4.
  pack4,

  /// Backpack 5.
  pack5,

  /// Backpack 6.
  pack6,

  /// Backpack 7.
  pack7,

  /// Backpack 8.
  pack8,

  /// Backpack 9.
  pack9,

  /// Backpack 10.
  pack10,

  /// Backpack 11.
  pack11,

  /// Backpack 12.
  pack12,

  /// Backpack 13.
  pack13,

  /// Backpack 14.
  pack14,

  /// Backpack 15.
  pack15,

  /// Backpack 16.
  pack16,

  /// The magical-weapon slot the engine fills itself.
  magicWeapon;

  /// Where this slot's word sits inside the 80-byte table.
  int get byteOffset => index * 2;

  /// Whether this is one of the sixteen backpack slots.
  ///
  /// **Always legal for any item**, which is what makes the backpack the
  /// honest destination when no rule says where something may go.
  bool get isPack => index >= pack1.index && index <= pack16.index;

  /// The sixteen backpack slots, in order.
  static List<CreItemSlot> get pack =>
      values.where((slot) => slot.isPack).toList();

  /// Byte offset of the *selected weapon* word — not an item index.
  static const int selectedWeaponOffset = 76;

  /// Byte offset of the *selected weapon ability* word — not an item index.
  static const int selectedWeaponAbilityOffset = 78;

  /// The word an empty slot holds.
  ///
  /// ⚠️ **`0xFFFF`, not `0`** — unlike a section offset, where zero means
  /// absent. Item `0` is a perfectly ordinary item, and `Aard1.chr` has one in
  /// its off-hand.
  static const int empty = 0xFFFF;
}

/// Bytes per effect entry when [CreHeaderField.effectVersion] is `0`.
const int creEffectV1Length = 48;

/// Bytes per effect entry when [CreHeaderField.effectVersion] is `1`.
const int creEffectV2Length = 264;
