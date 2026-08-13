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

import 'package:infinity_formats/src/exceptions.dart';
import 'package:infinity_formats/src/spec/itm_v1.dart';
import 'package:infinity_formats/src/text/fixed_field.dart';

/// An item resource, read only as deeply as listing and placing one needs.
///
/// **Deliberately shallow, exactly as `Spl` is.** An item's extended headers
/// and feature blocks are what it *does*; this reads what it *is*, which is
/// what a picker has to show and what an inventory has to store. The feature
/// blocks arrive when armour class needs them.
///
/// Like the other models here, **the bytes are the model** — every accessor
/// reads through [bytes], so there is no parsed copy to drift.
final class Itm {
  /// Wraps [bytes], which must already be validated.
  const Itm.trusted(this.bytes);

  /// The complete resource, exactly as read.
  final Uint8List bytes;

  int _read(ItmHeaderField field) {
    final view = ByteData.sublistView(bytes);
    return switch ((field.length, field.signed)) {
      (1, false) => view.getUint8(field.offset),
      (2, false) => view.getUint16(field.offset, Endian.little),
      (4, false) => view.getUint32(field.offset, Endian.little),
      (4, true) => view.getInt32(field.offset, Endian.little),
      _ => throw InfinityFormatException.unreadableField(
        what: '$field',
        length: field.length,
      ),
    };
  }

  /// An 8-byte resref field, trimmed at its padding.
  ///
  /// ⚠️ **The branch `Spl` does not have.** Its `_read` switches on
  /// `(length, signed)` and covers 1, 2 and 4 only, because a spell header
  /// carries no resref this project reads. An item's three icons do, and the
  /// game pads them to eight bytes with NUL — so a decode that trusts the
  /// declared width carries the padding into the string and every lookup
  /// misses.
  String _text(ItmHeaderField field) =>
      decodeFixedString(bytes, field.offset, field.length);

  /// Strref of the name shown once identified, or `null` when there is none.
  ///
  /// `null` rather than `-1`, the idiom `Spl.nameStrref` established: "this
  /// item has no name" is the question every caller is really asking.
  int? get identifiedNameStrref => _strref(ItmHeaderField.identifiedName);

  /// Strref of the name shown before identification, or `null`.
  ///
  /// ⚠️ **Not a fallback for a search box to ignore.** Ten of the fourteen
  /// items whose name contains "boot" are called simply "Boots" here, and that
  /// is what a player who has not identified one actually sees.
  int? get unidentifiedNameStrref => _strref(ItmHeaderField.unidentifiedName);

  /// Strref of the description shown once identified, or `null`.
  int? get identifiedDescriptionStrref =>
      _strref(ItmHeaderField.identifiedDescription);

  /// Strref of the description shown before identification, or `null`.
  int? get unidentifiedDescriptionStrref =>
      _strref(ItmHeaderField.unidentifiedDescription);

  /// Whether this resource names a string at all.
  ///
  /// ⚠️ **This is what separates an item from engine plumbing**, and it is the
  /// same test `wizardSpells` already applies to `SPL`. **102 of the
  /// installation's 1,530 items name no string in either field** — `GHOST`,
  /// `DEMOGORG`, `ANKHEG1`: a monster's innate attack is an item to the
  /// engine and must never be offered to a player as one.
  ///
  /// ⚠️ **Necessary, not sufficient.** Five more items carry a real strref
  /// pointing at *empty text*, and only the talk table can tell — which this
  /// package must never open (D11). The offerable filter is two-stage, and
  /// the second stage lives above the repository.
  bool get hasName =>
      identifiedNameStrref != null || unidentifiedNameStrref != null;

  /// What kind of item this is, as `ITEMCAT.IDS` numbers it.
  int get itemType => _read(ItmHeaderField.itemType);

  /// Base price in gold.
  int get price => _read(ItmHeaderField.price);

  /// How many of this item fit in one stack.
  int get stackAmount => _read(ItmHeaderField.stackAmount);

  /// Lore score needed to identify it without a spell.
  int get loreToIdentify => _read(ItmHeaderField.loreToIdentify);

  /// Weight in pounds.
  int get weight => _read(ItmHeaderField.weight);

  /// Resref of the `BAM` drawn in the inventory.
  String get inventoryIcon => _text(ItmHeaderField.inventoryIcon);

  /// Resref of the `BAM` drawn on the ground.
  String get groundIcon => _text(ItmHeaderField.groundIcon);

  /// Resref of the `BAM` drawn beside the description.
  String get descriptionIcon => _text(ItmHeaderField.descriptionIcon);

  /// How many extended headers — the item's abilities — it carries.
  int get extendedHeaderCount => _read(ItmHeaderField.extendedHeaderCount);

  /// Absolute offset of the shared feature-block pool.
  int get featureBlockOffset => _read(ItmHeaderField.featureBlockOffset);

  /// Index into the pool at which the equipping features begin.
  int get equippingIndex => _read(ItmHeaderField.equippingIndex);

  /// How many equipping feature blocks this item has.
  int get equippingCount => _read(ItmHeaderField.equippingCount);

  /// Whether the engine will let copies of this item share a slot.
  ///
  /// ⚠️ **Two conditions, and the second is not guessable.** IESDP: "For items
  /// to be stackable, they must contain at least one extension header, even if
  /// it is empty." So a stack amount above one is necessary and not sufficient,
  /// and a picker that offered a quantity on `stackAmount` alone would let a
  /// player build a stack the engine refuses to keep.
  bool get stacks => stackAmount > 1 && extendedHeaderCount > 0;

  int? _strref(ItmHeaderField field) {
    final strref = _read(field);
    return strref < 0 ? null : strref;
  }

  @override
  String toString() => 'Itm(${bytes.length} bytes, type $itemType)';
}

/// Reads `ITM V1` resources.
class ItmCodec {
  const ItmCodec._();

  /// The signature every item resource begins with.
  static const String signature = 'ITM ';

  /// Versions this codec reads.
  static const Set<String> supportedVersions = {'V1  '};

  /// Parses [bytes] as an item.
  ///
  /// ⚠️ **Unlike `SplCodec`, this checks the version, and the difference is
  /// deliberate.** That codec skips the check on the reasoning that refusing an
  /// unfamiliar version "would drop a modded spell from a list rather than show
  /// it" — sound there, because a BG:EE installation has only one `SPL` layout.
  ///
  /// `ITM` has three. IESDP documents **V1.1** for Planescape and **V2.0** for
  /// Icewind Dale II, and they are different layouts at the same offsets. Read
  /// with V1's table, either yields a plausible name strref, a plausible item
  /// type and a plausible price — all wrong. **That is the dangerous kind of
  /// wrong**: dropping an item from a picker is visible, and showing the wrong
  /// name for it is not.
  ///
  /// Throws [InfinityFormatException] if [bytes] is not a `V1` item header.
  static Itm decode(Uint8List bytes, {Object? source}) {
    if (bytes.length < itmHeaderLength) {
      throw InfinityFormatException.truncated(
        what: 'an ITM header',
        expected: itmHeaderLength,
        actual: bytes.length,
        source: source,
      );
    }
    final found = decodeFixedString(bytes, 0, 4);
    if (found != signature) {
      throw InfinityFormatException.badSignature(
        expected: signature,
        found: found,
        source: source,
      );
    }
    final version = decodeFixedString(bytes, 4, 4);
    if (!supportedVersions.contains(version)) {
      throw InfinityFormatException.unsupportedVersion(
        found: version,
        supported: supportedVersions,
        source: source,
      );
    }
    return Itm.trusted(bytes.asUnmodifiableView());
  }
}
