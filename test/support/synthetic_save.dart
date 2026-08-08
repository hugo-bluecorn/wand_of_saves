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

/// Builds savegames with real embedded creature records, so the app's suite
/// needs no game data.
///
/// `packages/infinity_formats` has a GAM builder of its own, but its creature
/// blobs are an eight-byte marker — enough to prove the party stride, not
/// enough to read a stat out of. This one writes the full 724-byte CRE header.
///
/// **Every fixture on the developer's machine is a one-character party**, which
/// is the same blind spot that let the spike's stride of −180 go unnoticed. So
/// the multi-member cases live here, where a party of any size can be built.
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
  });

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
}

/// Builds a `BALDUR.gam` image holding [party].
Uint8List buildSave({
  List<SyntheticCharacter> party = const [SyntheticCharacter()],
  int partyGold = 161,
  int gameTime = 4791,
  String area = 'AR2600',
  String signature = 'GAME',
}) {
  final creAt = syntheticPartyOffset + party.length * GamNpcField.structSize;
  final out = Uint8List(creAt + party.length * CreHeaderField.headerSize);
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

  for (var i = 0; i < party.length; i++) {
    final character = party[i];
    final struct = syntheticPartyOffset + i * GamNpcField.structSize;
    final cre = creAt + i * CreHeaderField.headerSize;

    void npcField(GamNpcField field, int value) =>
        data.setUint32(struct + field.offset, value, Endian.little);

    data.setUint16(
      struct + GamNpcField.partyOrder.offset,
      character.partyOrder,
      Endian.little,
    );
    npcField(GamNpcField.creOffset, cre);
    npcField(GamNpcField.creLength, CreHeaderField.headerSize);
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
  }
  return out;
}

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
  u8(CreHeaderField.effectVersion, 1);
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

  // An empty first section starting exactly where the header ends, so
  // `Cre.contentEnd` closes on the record's length as it does on a real one.
  i32(CreHeaderField.knownSpellsOffset, CreHeaderField.headerSize);
}

void _putString(Uint8List out, int offset, int width, String text) {
  final bytes = utf8.encode(text);
  out.setRange(
    offset,
    offset + (bytes.length < width ? bytes.length : width),
    bytes,
  );
}
