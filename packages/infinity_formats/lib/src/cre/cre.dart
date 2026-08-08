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

import 'dart:typed_data';

import 'package:infinity_formats/src/cre/effect.dart';
import 'package:infinity_formats/src/exceptions.dart';
import 'package:infinity_formats/src/spec/cre_v1_0.dart';
import 'package:infinity_formats/src/text/fixed_field.dart';

/// A parsed creature record — the `CRE` embedded in a savegame.
///
/// Like `Gam`, **the bytes are the model**: every accessor reads through
/// [bytes], so there is no parsed copy to drift out of step with the file.
final class Cre {
  /// Wraps [bytes], which must already be validated.
  const Cre.trusted(this.bytes);

  /// The complete creature record, exactly as read.
  final Uint8List bytes;

  ByteData get _view => ByteData.sublistView(bytes);

  /// Reads [field] at its declared width and signedness.
  ///
  /// One reader for every numeric field, rather than each accessor picking
  /// `getInt16` or `getUint16` for itself. That discretion is what produced
  /// the armour-class bug: the table already knew the answer and the getter
  /// was free to ignore it. `Gam.withCreatureField` writes through the mirror
  /// of this, so the two cannot drift.
  int _read(CreHeaderField field) => switch ((field.length, field.signed)) {
    (1, false) => _view.getUint8(field.offset),
    (1, true) => _view.getInt8(field.offset),
    (2, false) => _view.getUint16(field.offset, Endian.little),
    (2, true) => _view.getInt16(field.offset, Endian.little),
    (4, false) => _view.getUint32(field.offset, Endian.little),
    (4, true) => _view.getInt32(field.offset, Endian.little),
    _ => throw InfinityFormatException.unreadableField(
      what: '$field',
      length: field.length,
    ),
  };

  /// Strref of this creature's long name, or `-1` when there is none.
  ///
  /// `-1` for the protagonist, whose name is not in `dialog.tlk` — it comes
  /// from the GAM NPC struct instead.
  ///
  /// Read **signed**, so the engine's "no string" sentinel arrives as the `-1`
  /// every consumer is written around rather than as `4294967295`. `Tlk.get`
  /// documents its contract in terms of a negative strref; an unsigned read
  /// satisfied it only by accident of the bounds check.
  int get longNameStrref => _read(CreHeaderField.longName);

  /// This character's experience points.
  ///
  /// The same field means "power level" for summoned creatures; see
  /// [CreHeaderField.experience].
  int get experience => _read(CreHeaderField.experience);

  /// Gold carried by this creature specifically, not the shared party purse.
  int get gold => _read(CreHeaderField.gold);

  /// Current hit points.
  int get currentHitPoints => _read(CreHeaderField.currentHitPoints);

  /// Maximum hit points.
  int get maximumHitPoints => _read(CreHeaderField.maximumHitPoints);

  /// THAC0.
  ///
  /// Unsigned, and verified as such rather than assumed: IESDP gives this one
  /// as "1 (byte)" with a range of 1-25, while the armour class fields two
  /// rows above it are explicitly signed.
  int get thac0 => _read(CreHeaderField.thac0);

  /// Effective armour class — what the character actually defends at.
  ///
  /// **Signed**, per IESDP's "2 (signed word)". Plate and shield reaches AC
  /// −2, and an unsigned read renders that as 65534. Nothing in the fixture
  /// catches this: all 37 creatures there sit at AC 10.
  int get armorClass => _read(CreHeaderField.armorClassEffective);

  /// Natural armour class, before equipment.
  int get armorClassNatural => _read(CreHeaderField.armorClassNatural);

  /// Reputation, as displayed — the stored value divided by ten.
  ///
  /// The field holds `110` where the game shows 11.0. Confirmed rather than
  /// assumed: BG1 reputation only ranges 0-20, so a stored 110 cannot be raw.
  double get reputation => _read(CreHeaderField.reputation) / 10;

  /// Levels in each of the three class slots.
  (int, int, int) get levels => (
    _read(CreHeaderField.levelFirstClass),
    _read(CreHeaderField.levelSecondClass),
    _read(CreHeaderField.levelThirdClass),
  );

  /// Attacks per round.
  int get numberOfAttacks => _read(CreHeaderField.numberOfAttacks);

  /// The five saving throws. Lower is better.
  ///
  /// A record because they are read as a set and the names carry the meaning
  /// — the game labels them "Paralysis / Poison / Death", "Rod / Staff /
  /// Wand", "Petrification / Polymorph", "Breath Weapon" and "Spell".
  ///
  /// **Stored exactly as displayed**, unusually for this format. Verified
  /// 2026-08-08: a creature holding 14/11/13/15/12 showed those five numbers
  /// on the record screen with nothing added.
  ({int death, int wands, int polymorph, int breath, int spells})
  get savingThrows => (
    death: _read(CreHeaderField.saveVersusDeath),
    wands: _read(CreHeaderField.saveVersusWands),
    polymorph: _read(CreHeaderField.saveVersusPolymorph),
    breath: _read(CreHeaderField.saveVersusBreath),
    spells: _read(CreHeaderField.saveVersusSpells),
  );

  /// Percentage resistances to each damage type.
  ({
    int fire,
    int cold,
    int electricity,
    int acid,
    int magic,
    int magicFire,
    int magicCold,
    int slashing,
    int crushing,
    int piercing,
    int missile,
  })
  get resistances => (
    fire: _read(CreHeaderField.resistFire),
    cold: _read(CreHeaderField.resistCold),
    electricity: _read(CreHeaderField.resistElectricity),
    acid: _read(CreHeaderField.resistAcid),
    magic: _read(CreHeaderField.resistMagic),
    magicFire: _read(CreHeaderField.resistMagicFire),
    magicCold: _read(CreHeaderField.resistMagicCold),
    slashing: _read(CreHeaderField.resistSlashing),
    crushing: _read(CreHeaderField.resistCrushing),
    piercing: _read(CreHeaderField.resistPiercing),
    missile: _read(CreHeaderField.resistMissile),
  );

  /// Armour class modifiers by damage type. Signed; negative is better.
  ({int crushing, int missile, int piercing, int slashing})
  get armorClassModifiers => (
    crushing: _read(CreHeaderField.armorClassCrushing),
    missile: _read(CreHeaderField.armorClassMissile),
    piercing: _read(CreHeaderField.armorClassPiercing),
    slashing: _read(CreHeaderField.armorClassSlashing),
  );

  /// The thief skills and Lore, **as the file stores them**.
  ///
  /// ⚠️ **These are allocated points, not the skill the game shows.** Measured
  /// 2026-08-08: a thief storing Move Silently 15 displayed 35, and two
  /// characters both storing Lore 3 displayed 10 and 15. The engine adds
  /// class, race and Dexterity bonuses. Presenting these as the skill would
  /// repeat the hit-point mistake, so the UI labels them.
  ({
    int hideInShadows,
    int detectIllusion,
    int setTraps,
    int lore,
    int lockpicking,
    int moveSilently,
    int findTraps,
    int pickPockets,
  })
  get thiefSkills => (
    hideInShadows: _read(CreHeaderField.hideInShadows),
    detectIllusion: _read(CreHeaderField.detectIllusion),
    setTraps: _read(CreHeaderField.setTraps),
    lore: _read(CreHeaderField.lore),
    lockpicking: _read(CreHeaderField.lockpicking),
    moveSilently: _read(CreHeaderField.moveSilently),
    findTraps: _read(CreHeaderField.findTraps),
    pickPockets: _read(CreHeaderField.pickPockets),
  );

  /// Fatigue (0-100).
  int get fatigue => _read(CreHeaderField.fatigue);

  /// Intoxication (0-100).
  int get intoxication => _read(CreHeaderField.intoxication);

  /// Luck.
  int get luck => _read(CreHeaderField.luck);

  /// Turn undead level.
  int get turnUndeadLevel => _read(CreHeaderField.turnUndeadLevel);

  /// Tracking skill (0-100).
  int get trackingSkill => _read(CreHeaderField.trackingSkill);

  /// The morale at which this creature panics.
  int get moraleBreak => _read(CreHeaderField.moraleBreak);

  /// Ticks before morale recovers.
  int get moraleRecoveryTime => _read(CreHeaderField.moraleRecoveryTime);

  /// The ranger's chosen foe (`RACE.IDS`).
  int get racialEnemy => _read(CreHeaderField.racialEnemy);

  /// Strength (1-25).
  int get strength => _read(CreHeaderField.strength);

  /// Percentile strength bonus, meaningful only at Strength 18.
  int get strengthBonus => _read(CreHeaderField.strengthBonus);

  /// Intelligence (1-25).
  int get intelligence => _read(CreHeaderField.intelligence);

  /// Wisdom (1-25).
  int get wisdom => _read(CreHeaderField.wisdom);

  /// Dexterity (1-25).
  int get dexterity => _read(CreHeaderField.dexterity);

  /// Constitution (1-25).
  int get constitution => _read(CreHeaderField.constitution);

  /// Charisma (1-25).
  int get charisma => _read(CreHeaderField.charisma);

  /// Class, as a `CLASS.IDS` number. `7` is `FIGHTER_MAGE`.
  ///
  /// Reported as the number it is: naming it needs `CLASS.IDS`, which is game
  /// data rather than file layout, so it belongs above a codec.
  int get classId => _read(CreHeaderField.characterClass);

  /// Race, as a `RACE.IDS` number. `2` is `ELF`.
  int get raceId => _read(CreHeaderField.race);

  /// Alignment, as an `ALIGNMEN.IDS` number. `0x21` is `NEUTRAL_GOOD`.
  int get alignmentId => _read(CreHeaderField.alignment);

  /// Gender, as a `GENDER.IDS` number. `1` is `MALE`.
  int get genderId => _read(CreHeaderField.gender);

  /// The kit dword. `0x40000000` means no kit.
  int get kitId => _read(CreHeaderField.kit);

  /// Resref of this creature's dialogue file.
  String get dialogFile => decodeFixedString(
    bytes,
    CreHeaderField.dialogFile.offset,
    CreHeaderField.dialogFile.length,
  );

  /// Raw effect-layout selector: `0` → v1, `1` → v2.
  int get effectVersion => _read(CreHeaderField.effectVersion);

  /// Bytes per effect entry, chosen by [effectVersion].
  ///
  /// Reading this wrong does not produce a slightly-off value; it makes the
  /// section chain miss the end of the file entirely.
  int get effectLength =>
      effectVersion == 0 ? creEffectV1Length : creEffectV2Length;

  /// Offset of the known-spells section, relative to this creature's start.
  int get knownSpellsOffset => _read(CreHeaderField.knownSpellsOffset);

  /// Number of known spells.
  int get knownSpellsCount => _read(CreHeaderField.knownSpellsCount);

  /// Offset of the spell-memorisation info section.
  int get memorizationInfoOffset =>
      _read(CreHeaderField.memorizationInfoOffset);

  /// Number of spell-memorisation info entries.
  int get memorizationInfoCount => _read(CreHeaderField.memorizationInfoCount);

  /// Offset of the memorised-spells section.
  int get memorizedSpellsOffset => _read(CreHeaderField.memorizedSpellsOffset);

  /// Number of memorised spells.
  int get memorizedSpellsCount => _read(CreHeaderField.memorizedSpellsCount);

  /// Offset of the fixed-size item-slot table.
  int get itemSlotsOffset => _read(CreHeaderField.itemSlotsOffset);

  /// Offset of the items section.
  int get itemsOffset => _read(CreHeaderField.itemsOffset);

  /// Number of items.
  int get itemsCount => _read(CreHeaderField.itemsCount);

  /// Offset of the effects section.
  int get effectsOffset => _read(CreHeaderField.effectsOffset);

  /// Number of effects.
  int get effectsCount => _read(CreHeaderField.effectsCount);

  /// This creature's effects, in the order the record stores them.
  ///
  /// Views rather than copies, so walking them costs nothing and each knows
  /// the offset a writer would patch.
  List<Effect> get effects => [
    for (var i = 0; i < effectsCount; i++)
      Effect.at(bytes, effectsOffset + i * effectLength),
  ];

  /// Proficiency pips by `STATS.IDS` index — 89-108 weapons, 111-115 styles.
  ///
  /// ⚠️ **Proficiencies are not header bytes on BG:EE.** IESDP documents them
  /// at `0x6e`-`0x81`, and those bytes are zero on every character in a save
  /// where the game plainly shows pips. They are stored as
  /// [Effect.proficiencyOpcode] effects instead, with the count in
  /// `parameter1` and the proficiency in `parameter2`.
  ///
  /// Verified 2026-08-08: a Fighter/Mage wielding a Battle Axe and a Flail
  /// reads `{114: 2}` — two pips in `PROFICIENCY2WEAPON` — against a record
  /// screen showing "Attacks per Round: 2" and a separate off-hand THAC0.
  ///
  /// Later entries win if an opcode repeats a proficiency, which is what the
  /// engine's own last-write-wins stacking implies; no fixture does it.
  Map<int, int> get proficiencies => {
    for (final effect in effects)
      if (effect.isProficiency) effect.parameter2: effect.parameter1,
  };

  /// Whether this creature has a section at [offset] at all.
  ///
  /// **An offset of `0` means absent, not "at the start of the record".** Two
  /// of the 37 creatures in the fixture carry `knownSpellsOffset == 0`, and
  /// several carry `itemsOffset == 0`. This is the same rule that governs the
  /// GAM's party inventory, and doing arithmetic on such an offset is how the
  /// spike computed a stride of −180.
  static bool hasSection(int offset) => offset != 0;

  /// Whether this creature knows any spells.
  bool get hasKnownSpells => hasSection(knownSpellsOffset);

  /// Whether this creature has memorised spells.
  bool get hasMemorizedSpells => hasSection(memorizedSpellsOffset);

  /// Whether this creature carries any items.
  bool get hasItems => hasSection(itemsOffset);

  /// Where the creature's content ends — its total size, derived.
  ///
  /// Every section is variable-length, so this is computed from the layout
  /// rather than read from a field. On a well-formed creature it equals
  /// [bytes].length exactly, which makes it the strongest single check
  /// available on a CRE: one comparison reconciles all six section pointers,
  /// every entry size, and the effect-version flag.
  ///
  /// Taken as the furthest end over all **present** sections rather than
  /// assuming effects come last — absent sections carry offset `0`, and a
  /// creature with no known spells would otherwise be measured from there.
  ///
  /// **This is also the arithmetic Phase 1's writer must reproduce.** Adding
  /// one item moves everything after it, then the CRE's size in the GAM, then
  /// every GAM offset past that.
  int get contentEnd {
    var end = CreHeaderField.headerSize;
    void consider(int offset, int length) {
      if (!hasSection(offset)) return;
      if (offset + length > end) end = offset + length;
    }

    consider(knownSpellsOffset, knownSpellsCount * creKnownSpellLength);
    consider(
      memorizationInfoOffset,
      memorizationInfoCount * creMemorizationInfoLength,
    );
    consider(
      memorizedSpellsOffset,
      memorizedSpellsCount * creMemorizedSpellLength,
    );
    consider(itemSlotsOffset, creItemSlotsLength);
    consider(itemsOffset, itemsCount * creItemLength);
    consider(effectsOffset, effectsCount * effectLength);
    return end;
  }

  @override
  String toString() =>
      'Cre(${bytes.length} bytes, $itemsCount items, '
      '$effectsCount effects v${effectVersion + 1})';
}
