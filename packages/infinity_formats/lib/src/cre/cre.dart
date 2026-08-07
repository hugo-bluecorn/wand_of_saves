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

  int _u8(CreHeaderField f) => _view.getUint8(f.offset);
  int _u16(CreHeaderField f) => _view.getUint16(f.offset, Endian.little);
  int _i16(CreHeaderField f) => _view.getInt16(f.offset, Endian.little);
  int _u32(CreHeaderField f) => _view.getUint32(f.offset, Endian.little);
  int _i32(CreHeaderField f) => _view.getInt32(f.offset, Endian.little);

  /// Strref of this creature's long name, or `-1` when there is none.
  ///
  /// `-1` for the protagonist, whose name is not in `dialog.tlk` — it comes
  /// from the GAM NPC struct instead.
  ///
  /// Read **signed**, so the engine's "no string" sentinel arrives as the `-1`
  /// every consumer is written around rather than as `4294967295`. `Tlk.get`
  /// documents its contract in terms of a negative strref; an unsigned read
  /// satisfied it only by accident of the bounds check.
  int get longNameStrref => _i32(CreHeaderField.longName);

  /// This character's experience points.
  ///
  /// The same field means "power level" for summoned creatures; see
  /// [CreHeaderField.experience].
  int get experience => _u32(CreHeaderField.experience);

  /// Gold carried by this creature specifically, not the shared party purse.
  int get gold => _u32(CreHeaderField.gold);

  /// Current hit points.
  int get currentHitPoints => _u16(CreHeaderField.currentHitPoints);

  /// Maximum hit points.
  int get maximumHitPoints => _u16(CreHeaderField.maximumHitPoints);

  /// THAC0.
  ///
  /// Unsigned, and verified as such rather than assumed: IESDP gives this one
  /// as "1 (byte)" with a range of 1-25, while the armour class fields two
  /// rows above it are explicitly signed.
  int get thac0 => _u8(CreHeaderField.thac0);

  /// Effective armour class — what the character actually defends at.
  ///
  /// **Signed**, per IESDP's "2 (signed word)". Plate and shield reaches AC
  /// −2, and an unsigned read renders that as 65534. Nothing in the fixture
  /// catches this: all 37 creatures there sit at AC 10.
  int get armorClass => _i16(CreHeaderField.armorClassEffective);

  /// Natural armour class, before equipment.
  int get armorClassNatural => _i16(CreHeaderField.armorClassNatural);

  /// Reputation, as displayed — the stored value divided by ten.
  ///
  /// The field holds `110` where the game shows 11.0. Confirmed rather than
  /// assumed: BG1 reputation only ranges 0-20, so a stored 110 cannot be raw.
  double get reputation => _u8(CreHeaderField.reputation) / 10;

  /// Levels in each of the three class slots.
  (int, int, int) get levels => (
    _u8(CreHeaderField.levelFirstClass),
    _u8(CreHeaderField.levelSecondClass),
    _u8(CreHeaderField.levelThirdClass),
  );

  /// Strength (1-25).
  int get strength => _u8(CreHeaderField.strength);

  /// Percentile strength bonus, meaningful only at Strength 18.
  int get strengthBonus => _u8(CreHeaderField.strengthBonus);

  /// Intelligence (1-25).
  int get intelligence => _u8(CreHeaderField.intelligence);

  /// Wisdom (1-25).
  int get wisdom => _u8(CreHeaderField.wisdom);

  /// Dexterity (1-25).
  int get dexterity => _u8(CreHeaderField.dexterity);

  /// Constitution (1-25).
  int get constitution => _u8(CreHeaderField.constitution);

  /// Charisma (1-25).
  int get charisma => _u8(CreHeaderField.charisma);

  /// Resref of this creature's dialogue file.
  String get dialogFile => decodeFixedString(
    bytes,
    CreHeaderField.dialogFile.offset,
    CreHeaderField.dialogFile.length,
  );

  /// Raw effect-layout selector: `0` → v1, `1` → v2.
  int get effectVersion => _u8(CreHeaderField.effectVersion);

  /// Bytes per effect entry, chosen by [effectVersion].
  ///
  /// Reading this wrong does not produce a slightly-off value; it makes the
  /// section chain miss the end of the file entirely.
  int get effectLength =>
      effectVersion == 0 ? creEffectV1Length : creEffectV2Length;

  /// Offset of the known-spells section, relative to this creature's start.
  int get knownSpellsOffset => _u32(CreHeaderField.knownSpellsOffset);

  /// Number of known spells.
  int get knownSpellsCount => _u32(CreHeaderField.knownSpellsCount);

  /// Offset of the spell-memorisation info section.
  int get memorizationInfoOffset => _u32(CreHeaderField.memorizationInfoOffset);

  /// Number of spell-memorisation info entries.
  int get memorizationInfoCount => _u32(CreHeaderField.memorizationInfoCount);

  /// Offset of the memorised-spells section.
  int get memorizedSpellsOffset => _u32(CreHeaderField.memorizedSpellsOffset);

  /// Number of memorised spells.
  int get memorizedSpellsCount => _u32(CreHeaderField.memorizedSpellsCount);

  /// Offset of the fixed-size item-slot table.
  int get itemSlotsOffset => _u32(CreHeaderField.itemSlotsOffset);

  /// Offset of the items section.
  int get itemsOffset => _u32(CreHeaderField.itemsOffset);

  /// Number of items.
  int get itemsCount => _u32(CreHeaderField.itemsCount);

  /// Offset of the effects section.
  int get effectsOffset => _u32(CreHeaderField.effectsOffset);

  /// Number of effects.
  int get effectsCount => _u32(CreHeaderField.effectsCount);

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
