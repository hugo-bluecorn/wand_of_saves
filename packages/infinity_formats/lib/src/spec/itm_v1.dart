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

/// Bytes of an `ITM V1` header, before the feature-block pool.
///
/// IESDP: "Header: Size = 114 Bytes". ⚠️ **Confirmed against a real item**
/// rather than taken on trust: `BOOT01` carries no extended headers and two
/// equipping feature blocks, and 114 + 2 × 48 = 210 is its exact length.
const int itmHeaderLength = 114;

/// Bytes in one feature block, extended header or equipping.
const int itmFeatureBlockLength = 48;

/// The fields of an `ITM V1` header this project reads.
///
/// **A verified subset**, like `SplHeaderField`, so the layout check runs
/// without a struct size — the gaps are real fields nothing here needs, and
/// the exact-fit rule would be wrong to apply.
///
/// Offsets derived from `../iesdp/_data/file_formats/itm_v1/header.yml` by
/// IESDP's own width rules, which the site's build asserts against five
/// anchors it names in the page (`0x10`, `0x24`, `0x38`, `0x44`, `0x60`) and a
/// hard `offset: 0x70` on the last field. Then checked against the bytes of a
/// real item, because a derivation nobody compared to data is still a guess.
///
/// ⚠️ **`ITM` and `SPL` headers are both 114 bytes and IESDP says they have a
/// similar structure. They are not interchangeable** — every field below sits
/// somewhere `SplHeaderField` does not name.
enum ItmHeaderField implements FormatField {
  /// Strref of the name shown before the item is identified.
  ///
  /// **Signed** — `-1` means there is none. ⚠️ Measured rather than inherited
  /// from `SPL`: **195 of the installation's 1,530 items** carry a negative
  /// value in one of the two name fields, and reading it unsigned yields
  /// 4,294,967,295 — a strref no talk table holds, which then looks like a
  /// missing *string* rather than a wrong *read*.
  unidentifiedName(0x08, 4, signed: true),

  /// Strref of the name shown once the item is identified.
  ///
  /// ⚠️ **This is the one a player searches for, and it is not a key.**
  /// `BOOT01`, `BOOTDRIZ`, `DASBOOT` and `TROLLBOO` all resolve to "The Paws of
  /// the Cheetah". The resref is the key.
  identifiedName(0x0c, 4, signed: true),

  /// Item flags — unsellable, two-handed, droppable, cursed and the rest.
  flags(0x18, 4),

  /// What kind of item this is, as `ITEMCAT.IDS` numbers it. `4` is boots.
  ///
  /// ⚠️ **It is also the only thing deciding which slot an item may go in**,
  /// and no BG:EE table states the mapping: `itmslots.2da` is PSTEE-only, and
  /// the installation's own `itemtype.2da` gives `SLOT = -1` for every
  /// everyday type — boots, helmets, rings, shields, cloaks.
  itemType(0x1c, 2),

  /// Usability, byte 1 of 4 — alignment, plus bard and cleric.
  ///
  /// ⚠️ **Four separate bytes, deliberately, and not one dword.** IESDP
  /// presents this as a Bit × Byte-1..4 grid, which is the giveaway that byte
  /// order matters. Read little-endian as a dword the meanings scramble —
  /// "Mage and Sorcerer" is byte 3 bit 2, which a dword read puts elsewhere.
  usability1(0x1e, 1),

  /// Usability, byte 2 of 4 — the dual-class combinations and Fighter.
  usability2(0x1f, 1),

  /// Usability, byte 3 of 4 — Mage is bit 2 here.
  usability3(0x20, 1),

  /// Usability, byte 4 of 4 — race, plus Monk and Druid/Shaman.
  usability4(0x21, 1),

  /// Base price in gold.
  price(0x34, 4),

  /// How many of this item fit in one stack.
  ///
  /// ⚠️ **Not sufficient on its own to say the item stacks** — see
  /// [extendedHeaderCount].
  stackAmount(0x38, 2),

  /// Resref of the `BAM` drawn in the inventory.
  inventoryIcon(0x3a, 8),

  /// Lore score needed to identify the item without a spell.
  loreToIdentify(0x42, 2),

  /// Resref of the `BAM` drawn where the item lies on the ground.
  groundIcon(0x44, 8),

  /// Weight in pounds.
  weight(0x4c, 4),

  /// Strref of the description shown before identification. Signed.
  unidentifiedDescription(0x50, 4, signed: true),

  /// Strref of the description shown after identification. Signed.
  ///
  /// ⚠️ **Worth more than it looks for a search box.** "Boots of Speed" matches
  /// no item *name* in BG:EE and three item *descriptions*.
  identifiedDescription(0x54, 4, signed: true),

  /// Resref of the `BAM` drawn beside the description.
  descriptionIcon(0x58, 8),

  /// Absolute offset to the extended headers — the item's abilities.
  extendedHeaderOffset(0x64, 4),

  /// How many extended headers there are.
  ///
  /// ⚠️ **Load-bearing for stacking**, and not obviously so. IESDP: "For items
  /// to be stackable, they must contain at least one extension header, even if
  /// it is empty." So `stackAmount > 1` alone is not the predicate.
  extendedHeaderCount(0x68, 2),

  /// Absolute offset to the feature-block pool.
  ///
  /// ⚠️ **A dword at a non-4-aligned offset.** Anything that assumes natural
  /// struct alignment reads it two bytes early. The pool is shared: extended
  /// headers point into it too, so [equippingIndex] and [equippingCount] select
  /// the window that applies while the item is worn.
  featureBlockOffset(0x6a, 4),

  /// Index into the pool at which this item's equipping features begin.
  equippingIndex(0x6e, 2),

  /// How many equipping feature blocks this item has.
  ///
  /// These are what an item *does* while worn — armour class among them, which
  /// is why Phase F of the inventory plan reads them.
  equippingCount(0x70, 2);

  const ItmHeaderField(this.offset, this.length, {this.signed = false});

  @override
  final int offset;

  @override
  final int length;

  @override
  final bool signed;
}
