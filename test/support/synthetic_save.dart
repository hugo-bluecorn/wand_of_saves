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

/// Builds savegames and exported characters with real embedded creature
/// records, so the app's suite needs no game data.
///
/// `packages/infinity_formats` has a GAM builder of its own, but its creature
/// blobs are an eight-byte marker — enough to prove the party stride, not
/// enough to read a stat out of. This one writes the full 724-byte CRE header.
///
/// **Every fixture on the developer's machine is a one-character party**, which
/// is the same blind spot that let the spike's stride of −180 go unnoticed. So
/// the multi-member cases live here, where a party of any size can be built.
///
/// Both document types are built from one [SyntheticCharacter] writer, which is
/// the point: a `.chr` is a 100-byte header around exactly the record a
/// savegame embeds, so a test that reads a stat must not care which it came
/// from.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';

/// Where the party NPC structs begin, matching the real saves.
const int syntheticPartyOffset = 180;

/// One character for [buildSave] to emit, with defaults taken from the
/// protagonist of `000000022-last` as recorded in the findings document.
final class SyntheticCharacter {
  /// Describes a character to write into a savegame.
  const SyntheticCharacter({
    this.resref = '*HARBASE',
    this.displayName = 'Aard',
    this.nameStrref = -1,
    this.partyOrder = 0,
    this.currentHitPoints = 6,
    this.maximumHitPoints = 7,
    this.experience = 325,
    this.gold = 0,
    this.thac0 = 20,
    this.armorClass = 10,
    this.levelFirstClass = 1,
    this.levelSecondClass = 1,
    this.levelThirdClass = 0,
    this.reputationTimesTen = 110,
    this.strength = 18,
    this.strengthBonus = 100,
    this.dexterity = 17,
    this.constitution = 16,
    this.intelligence = 18,
    this.wisdom = 9,
    this.charisma = 9,
    this.classId = 7,
    this.raceId = 2,
    this.alignmentId = 0x21,
    this.genderId = 1,
    this.kitId = 0x40000000,
    this.creSignature = 'CRE ',
    this.saveVersusDeath = 0,
    this.saveVersusWands = 0,
    this.saveVersusPolymorph = 0,
    this.saveVersusBreath = 0,
    this.saveVersusSpells = 0,
    this.resistFire = 0,
    this.resistMagic = 0,
    this.armorClassCrushing = 0,
    this.armorClassMissile = 0,
    this.hideInShadows = 0,
    this.moveSilently = 0,
    this.findTraps = 0,
    this.lore = 0,
    this.numberOfAttacks = 1,
    this.morale = 10,
    this.moraleBreak = 0,
    this.luck = 0,
    this.fatigue = 0,
    this.intoxication = 0,
    this.turnUndeadLevel = 0,
    this.trackingSkill = 0,
    this.proficiencies = const {},
    this.effectVersion = 1,
  });

  /// The engine's own `CHARBASE`, as far as its effects section goes.
  ///
  /// ⚠️ **The template stores `effectVersion` 0 and no effects at all**, where
  /// every character BG:EE has finished making stores 1. Measured against the
  /// real file, not assumed. This shape exists because the default above is 1,
  /// which is true of every *played* character and of nothing a new one is
  /// built from — and that gap hid a defect for a whole slice.
  static const SyntheticCharacter template = SyntheticCharacter(
    effectVersion: 0,
  );

  /// The CRE resref, written to `GamNpcField.creResref`.
  final String resref;

  /// The player-visible name in the GAM struct. Empty for a character who has
  /// not joined the party — that is how all 36 companions are stored.
  final String displayName;

  /// Strref of the name in `dialog.tlk`; `-1` for the protagonist.
  final int nameStrref;

  /// Position in the party.
  final int partyOrder;

  /// Current hit points.
  final int currentHitPoints;

  /// Maximum hit points.
  final int maximumHitPoints;

  /// Experience points.
  final int experience;

  /// Personal gold.
  final int gold;

  /// THAC0.
  final int thac0;

  /// Effective armour class, which may be negative.
  final int armorClass;

  /// Level in the first class slot.
  final int levelFirstClass;

  /// Level in the second class slot.
  final int levelSecondClass;

  /// Level in the third class slot.
  final int levelThirdClass;

  /// Reputation as stored — ten times the displayed value.
  final int reputationTimesTen;

  /// Strength.
  final int strength;

  /// Percentile strength.
  final int strengthBonus;

  /// Dexterity.
  final int dexterity;

  /// Constitution.
  final int constitution;

  /// Intelligence.
  final int intelligence;

  /// Wisdom.
  final int wisdom;

  /// Charisma.
  final int charisma;

  /// `CLASS.IDS` number. The fixture's `7` is `FIGHTER_MAGE`.
  final int classId;

  /// `RACE.IDS` number. The fixture's `2` is `ELF`.
  final int raceId;

  /// `ALIGNMEN.IDS` number, written in hex there. `0x21` is `NEUTRAL_GOOD`.
  final int alignmentId;

  /// `GENDER.IDS` number. The fixture's `1` is `MALE`.
  final int genderId;

  /// The kit dword. `0x40000000` is what a character with no kit carries.
  final int kitId;

  /// Overridable so a damaged creature can be built deliberately.
  final String creSignature;

  /// Save versus death — the record screen's "Paralysis / Poison / Death".
  final int saveVersusDeath;

  /// Save versus wands.
  final int saveVersusWands;

  /// Save versus polymorph.
  final int saveVersusPolymorph;

  /// Save versus breath attacks.
  final int saveVersusBreath;

  /// Save versus spells.
  final int saveVersusSpells;

  /// Fire resistance, as a percentage.
  final int resistFire;

  /// Magic resistance, as a percentage.
  final int resistMagic;

  /// Armour class modifier against crushing attacks. **Signed.**
  final int armorClassCrushing;

  /// Armour class modifier against missile attacks. **Signed.**
  final int armorClassMissile;

  /// Hide in Shadows, as points allocated.
  final int hideInShadows;

  /// Move Silently, as points allocated.
  final int moveSilently;

  /// Find Traps, as points allocated.
  final int findTraps;

  /// Lore, as points allocated.
  final int lore;

  /// Attacks per round.
  final int numberOfAttacks;

  /// Morale.
  final int morale;

  /// The morale at which this creature panics.
  final int moraleBreak;

  /// Luck.
  final int luck;

  /// Fatigue.
  final int fatigue;

  /// Intoxication.
  final int intoxication;

  /// Turn undead level.
  final int turnUndeadLevel;

  /// Tracking skill.
  final int trackingSkill;

  /// Pips per proficiency, keyed by the `STATS.IDS` index opcode 233 uses.
  ///
  /// Written as real 264-byte v2 effect records in an effects section, because
  /// that is where BG:EE keeps them — the header bytes IESDP documents at
  /// `0x6e`-`0x81` are zero on every character in a real save. A synthetic
  /// creature that put them in the header would test the wrong thing.
  final Map<int, int> proficiencies;

  /// What `CreHeaderField.effectVersion` holds: `0` for v1, `1` for v2.
  ///
  /// Defaults to `1`, which is what BG:EE writes for every character in a save
  /// — and what [proficiencies] needs, since it writes 264-byte v2 records.
  /// Set it to `0` for a template-shaped record; see [template].
  final int effectVersion;
}

/// Builds a `BALDUR.gam` image holding [party].
Uint8List buildSave({
  List<SyntheticCharacter> party = const [SyntheticCharacter()],
  int partyGold = 161,
  int gameTime = 4791,
  String area = 'AR2600',
  String signature = 'GAME',
  // ×10, as the file stores it. Defaults to the fixture's 11.0 — and
  // deliberately *not* the same as `SyntheticCharacter.reputationTimesTen`,
  // because the two really do disagree in a real save.
  int partyReputationTimesTen = 110,
}) {
  final creAt = syntheticPartyOffset + party.length * GamNpcField.structSize;
  // Creature records are **not** all one size: proficiencies are effects, so a
  // character who has any carries a longer record. Laying them out at a fixed
  // stride is precisely the assumption Phase 1's layout pass must not make.
  final creLengths = [for (final c in party) _creLength(c)];
  final out = Uint8List(creAt + creLengths.fold(0, (a, b) => a + b));
  final data = ByteData.sublistView(out);

  out
    ..setRange(0, 4, ascii.encode(signature))
    ..setRange(4, 8, ascii.encode('V2.0'));
  _putString(
    out,
    GamHeaderField.currentArea.offset,
    GamHeaderField.currentArea.length,
    area,
  );
  data
    ..setUint32(GamHeaderField.gameTime.offset, gameTime, Endian.little)
    ..setUint32(GamHeaderField.partyGold.offset, partyGold, Endian.little)
    ..setUint32(
      GamHeaderField.reputation.offset,
      partyReputationTimesTen,
      Endian.little,
    )
    ..setUint32(
      GamHeaderField.partyNpcOffset.offset,
      syntheticPartyOffset,
      Endian.little,
    )
    ..setUint32(
      GamHeaderField.partyNpcCount.offset,
      party.length,
      Endian.little,
    )
    // Absent on every real BG1EE save; recorded here so tests inherit the
    // shape that produced the spike's stride of -180.
    ..setUint32(GamHeaderField.partyInventoryOffset.offset, 0, Endian.little);

  var cre = creAt;
  for (var i = 0; i < party.length; i++) {
    final character = party[i];
    final struct = syntheticPartyOffset + i * GamNpcField.structSize;

    void npcField(GamNpcField field, int value) =>
        data.setUint32(struct + field.offset, value, Endian.little);

    data.setUint16(
      struct + GamNpcField.partyOrder.offset,
      character.partyOrder,
      Endian.little,
    );
    npcField(GamNpcField.creOffset, cre);
    npcField(GamNpcField.creLength, creLengths[i]);
    _putString(
      out,
      struct + GamNpcField.creResref.offset,
      GamNpcField.creResref.length,
      character.resref,
    );
    _putString(
      out,
      struct + GamNpcField.displayName.offset,
      GamNpcField.displayName.length,
      character.displayName,
    );

    _writeCre(out, cre, character);
    cre += creLengths[i];
  }
  return out;
}

/// Builds a `.chr` image: a 100-byte header wrapped around [character].
///
/// [name] is the CHR header's own 32-byte name, which is **the only name an
/// exported character has** — the embedded record carries neither a dialogue
/// resref nor a name strref. It is deliberately not defaulted from
/// [SyntheticCharacter.displayName]: that field belongs to the GAM struct, and
/// keeping them separate is what lets a test prove the header is where the
/// name was read from.
Uint8List buildCharacterFile({
  SyntheticCharacter character = const SyntheticCharacter(),
  String name = 'Aard',
  String signature = 'CHR ',
  String version = 'V2.0',
}) {
  final creLength = _creLength(character);
  final out = Uint8List(ChrHeaderField.headerSize + creLength)
    ..setRange(0, 4, ascii.encode(signature))
    ..setRange(4, 8, ascii.encode(version));
  _putString(
    out,
    ChrHeaderField.name.offset,
    ChrHeaderField.name.length,
    name,
  );
  ByteData.sublistView(out)
    ..setUint32(
      ChrHeaderField.creOffset.offset,
      ChrHeaderField.headerSize,
      Endian.little,
    )
    ..setUint32(ChrHeaderField.creLength.offset, creLength, Endian.little);

  _writeCre(out, ChrHeaderField.headerSize, character);
  return out;
}

/// Writes [chr] into [root] as `<name>.chr` and returns its path.
///
/// [withBiography] writes the `.bio` sidecar the game puts beside every
/// exported character — one document in two files, which is why deletion has to
/// move both.
String writeCharacterFile(
  Directory root,
  String name, {
  Uint8List? chr,
  bool withBiography = false,
}) {
  final separator = Platform.pathSeparator;
  root.createSync(recursive: true);
  final path = '${root.path}$separator$name.chr';
  File(path).writeAsBytesSync(chr ?? buildCharacterFile());
  if (withBiography) {
    File('${root.path}$separator$name.bio').writeAsStringSync('A biography.');
  }
  return path;
}

/// Bytes one synthetic creature occupies: header, slot table, then effects.
///
/// ⚠️ **The slot table is not optional, and leaving it out was a fixture that
/// did not have the installation's shape.** `CHARBASE` is 804 bytes — a
/// 724-byte header plus the 80-byte table — with every word empty and no items
/// section, and every record the engine writes carries one. A creature built
/// without it cannot take an item, and the test that found this failed for the
/// right reason.
int _creLength(SyntheticCharacter character) =>
    CreHeaderField.headerSize +
    creItemSlotsLength +
    character.proficiencies.length * creEffectV2Length;

/// Writes a savegame slot directory under [root] and returns its path.
///
/// [portraits] names the `PORTRT<n>.bmp` files to create — the game writes one
/// per party slot, and a save missing one has to degrade rather than break.
String writeSaveSlot(
  Directory root,
  String name, {
  Uint8List? gam,
  List<int> portraits = const [],
  bool withScreenshot = false,
}) {
  final separator = Platform.pathSeparator;
  final dir = Directory('${root.path}$separator$name')
    ..createSync(recursive: true);
  File(
    '${dir.path}${separator}BALDUR.gam',
  ).writeAsBytesSync(gam ?? buildSave());
  for (final index in portraits) {
    File(
      '${dir.path}${separator}PORTRT$index.bmp',
    ).writeAsBytesSync([0x42, 0x4d]);
  }
  if (withScreenshot) {
    File('${dir.path}${separator}BALDUR.bmp').writeAsBytesSync([0x42, 0x4d]);
  }
  return dir.path;
}

void _writeCre(Uint8List out, int base, SyntheticCharacter character) {
  final data = ByteData.sublistView(out);
  out
    ..setRange(base, base + 4, ascii.encode(character.creSignature))
    ..setRange(base + 4, base + 8, ascii.encode('V1.0'));

  void u8(CreHeaderField field, int value) => out[base + field.offset] = value;
  void i16(CreHeaderField field, int value) =>
      data.setInt16(base + field.offset, value, Endian.little);
  void u16(CreHeaderField field, int value) =>
      data.setUint16(base + field.offset, value, Endian.little);
  void i32(CreHeaderField field, int value) =>
      data.setInt32(base + field.offset, value, Endian.little);

  i32(CreHeaderField.longName, character.nameStrref);
  i32(CreHeaderField.experience, character.experience);
  i32(CreHeaderField.gold, character.gold);
  u16(CreHeaderField.currentHitPoints, character.currentHitPoints);
  u16(CreHeaderField.maximumHitPoints, character.maximumHitPoints);
  u8(CreHeaderField.effectVersion, character.effectVersion);
  u8(CreHeaderField.reputation, character.reputationTimesTen);
  i16(CreHeaderField.armorClassNatural, character.armorClass);
  i16(CreHeaderField.armorClassEffective, character.armorClass);
  u8(CreHeaderField.thac0, character.thac0);
  u8(CreHeaderField.levelFirstClass, character.levelFirstClass);
  u8(CreHeaderField.levelSecondClass, character.levelSecondClass);
  u8(CreHeaderField.levelThirdClass, character.levelThirdClass);
  u8(CreHeaderField.strength, character.strength);
  u8(CreHeaderField.strengthBonus, character.strengthBonus);
  u8(CreHeaderField.intelligence, character.intelligence);
  u8(CreHeaderField.wisdom, character.wisdom);
  u8(CreHeaderField.dexterity, character.dexterity);
  u8(CreHeaderField.constitution, character.constitution);
  u8(CreHeaderField.charisma, character.charisma);
  u8(CreHeaderField.characterClass, character.classId);
  u8(CreHeaderField.race, character.raceId);
  u8(CreHeaderField.alignment, character.alignmentId);
  u8(CreHeaderField.gender, character.genderId);
  i32(CreHeaderField.kit, character.kitId);

  u8(CreHeaderField.saveVersusDeath, character.saveVersusDeath);
  u8(CreHeaderField.saveVersusWands, character.saveVersusWands);
  u8(CreHeaderField.saveVersusPolymorph, character.saveVersusPolymorph);
  u8(CreHeaderField.saveVersusBreath, character.saveVersusBreath);
  u8(CreHeaderField.saveVersusSpells, character.saveVersusSpells);
  u8(CreHeaderField.resistFire, character.resistFire);
  u8(CreHeaderField.resistMagic, character.resistMagic);
  i16(CreHeaderField.armorClassCrushing, character.armorClassCrushing);
  i16(CreHeaderField.armorClassMissile, character.armorClassMissile);
  u8(CreHeaderField.hideInShadows, character.hideInShadows);
  u8(CreHeaderField.moveSilently, character.moveSilently);
  u8(CreHeaderField.findTraps, character.findTraps);
  u8(CreHeaderField.lore, character.lore);
  u8(CreHeaderField.numberOfAttacks, character.numberOfAttacks);
  u8(CreHeaderField.morale, character.morale);
  u8(CreHeaderField.moraleBreak, character.moraleBreak);
  u8(CreHeaderField.luck, character.luck);
  u8(CreHeaderField.fatigue, character.fatigue);
  u8(CreHeaderField.intoxication, character.intoxication);
  u8(CreHeaderField.turnUndeadLevel, character.turnUndeadLevel);
  u8(CreHeaderField.trackingSkill, character.trackingSkill);

  // An empty first section starting exactly where the header ends, so
  // `Cre.contentEnd` closes on the record's length as it does on a real one.
  i32(CreHeaderField.knownSpellsOffset, CreHeaderField.headerSize);

  // Proficiencies live here, in the effects section, exactly as BG:EE stores
  // them. The offset is relative to the creature, not to the savegame.
  // The slot table sits between the header and the effects, which is the
  // order every real `.chr` uses — slots before items, items before effects.
  i32(CreHeaderField.itemSlotsOffset, CreHeaderField.headerSize);
  for (var i = 0; i < 40; i++) {
    data.setUint16(
      base + CreHeaderField.headerSize + i * 2,
      CreItemSlot.empty,
      Endian.little,
    );
  }
  // ⚠️ The two trailing words are selection state, not slots. The engine
  // writes 0 there, and a reader that treated them as item indices would say
  // "item 0 is equipped here" twice.
  data
    ..setUint16(
      base + CreHeaderField.headerSize + CreItemSlot.selectedWeaponOffset,
      0,
      Endian.little,
    )
    ..setUint16(
      base +
          CreHeaderField.headerSize +
          CreItemSlot.selectedWeaponAbilityOffset,
      0,
      Endian.little,
    );

  i32(
    CreHeaderField.effectsOffset,
    CreHeaderField.headerSize + creItemSlotsLength,
  );
  i32(CreHeaderField.effectsCount, character.proficiencies.length);
  var effect = base + CreHeaderField.headerSize + creItemSlotsLength;
  for (final entry in character.proficiencies.entries) {
    void field(EffectV2Field f, int value) =>
        data.setUint32(effect + f.offset, value, Endian.little);

    field(EffectV2Field.opcode, Effect.proficiencyOpcode);
    field(EffectV2Field.parameter1, entry.value);
    field(EffectV2Field.parameter2, entry.key);
    effect += creEffectV2Length;
  }
}

void _putString(Uint8List out, int offset, int width, String text) {
  final bytes = utf8.encode(text);
  out.setRange(
    offset,
    offset + (bytes.length < width ? bytes.length : width),
    bytes,
  );
}
