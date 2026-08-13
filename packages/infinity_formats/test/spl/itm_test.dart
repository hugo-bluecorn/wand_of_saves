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
import 'package:test/test.dart';

import '../support/layout.dart';
import '../support/synthetic_itm.dart';

void main() {
  group('ItmHeaderField', () {
    test('is a well-formed layout', () {
      // No struct size: a verified subset, so the gaps between these are real
      // fields nothing here reads yet. Overlaps are still forbidden.
      expect(layoutProblems(ItmHeaderField.values), isEmpty);
    });

    test('carries the offsets checked against BOOT01', () {
      // ⚠️ Derived from IESDP's own width rules, then confirmed against a real
      // item's bytes: header 114 + 2 feature blocks x 48 = 210, which is that
      // file's exact length. Read, not recalled.
      expect(ItmHeaderField.unidentifiedName.offset, 0x08);
      expect(ItmHeaderField.identifiedName.offset, 0x0c);
      expect(ItmHeaderField.itemType.offset, 0x1c);
      expect(ItmHeaderField.price.offset, 0x34);
      expect(ItmHeaderField.stackAmount.offset, 0x38);
      expect(ItmHeaderField.inventoryIcon.offset, 0x3a);
      expect(ItmHeaderField.inventoryIcon.length, 8);
      expect(ItmHeaderField.loreToIdentify.offset, 0x42);
      expect(ItmHeaderField.groundIcon.offset, 0x44);
      expect(ItmHeaderField.weight.offset, 0x4c);
      expect(itmHeaderLength, 114);
    });

    test('⚠️ models usability as four separate bytes, not one dword', () {
      // IESDP presents it as a Bit x Byte-1..4 grid, which is the giveaway.
      // Read little-endian as a dword the class restrictions scramble: "Mage"
      // is byte 3 bit 2, and a dword read puts that bit nowhere near it.
      expect(ItmHeaderField.usability1.offset, 0x1e);
      expect(ItmHeaderField.usability1.length, 1);
      expect(ItmHeaderField.usability2.offset, 0x1f);
      expect(ItmHeaderField.usability3.offset, 0x20);
      expect(ItmHeaderField.usability4.offset, 0x21);
    });

    test('⚠️ names the feature-block pointer at its unaligned offset', () {
      // 0x6a is a dword at a non-4-aligned offset. Anything that assumes
      // natural struct alignment reads it two bytes early.
      expect(ItmHeaderField.extendedHeaderOffset.offset, 0x64);
      expect(ItmHeaderField.extendedHeaderCount.offset, 0x68);
      expect(ItmHeaderField.featureBlockOffset.offset, 0x6a);
      expect(ItmHeaderField.featureBlockOffset.length, 4);
      expect(ItmHeaderField.equippingIndex.offset, 0x6e);
      expect(ItmHeaderField.equippingCount.offset, 0x70);
    });

    test('⚠️ declares both name strrefs signed', () {
      // Measured, not inherited from SPL: `-1` is how the format says "no
      // name", and reading it unsigned yields 4,294,967,295 — a strref no talk
      // table has, which resolves to nothing and looks like a missing string
      // rather than a wrong read.
      expect(ItmHeaderField.unidentifiedName.signed, isTrue);
      expect(ItmHeaderField.identifiedName.signed, isTrue);
      expect(ItmHeaderField.unidentifiedDescription.signed, isTrue);
      expect(ItmHeaderField.identifiedDescription.signed, isTrue);
    });
  });

  group('Itm', () {
    test('reads the header of an item shaped like BOOT01', () {
      final itm = Itm.trusted(buildItm());

      expect(itm.identifiedNameStrref, 6823);
      expect(itm.unidentifiedNameStrref, 6339);
      expect(itm.itemType, 4);
      expect(itm.price, 2300);
      expect(itm.stackAmount, 1);
      expect(itm.loreToIdentify, 30);
      expect(itm.weight, 4);
    });

    test('⚠️ reads an 8-byte resref, which Spl has no branch for', () {
      // The one genuinely new piece of reading. `Spl._read` switches on
      // (length, signed) and handles 1, 2 and 4 only; an icon is a resref.
      final itm = Itm.trusted(buildItm());
      expect(itm.inventoryIcon, 'IBOOT01');
      expect(itm.groundIcon, 'GBOOT01');
      expect(itm.descriptionIcon, 'CBOOT01');
    });

    test('trims a resref at its NUL, not at its declared width', () {
      // The game pads to eight bytes with NUL, so a naive decode carries the
      // padding into the string and every lookup misses.
      final itm = Itm.trusted(buildItm(inventoryIcon: 'IRING01'));
      expect(itm.inventoryIcon, 'IRING01');
      expect(itm.inventoryIcon.length, 7);
    });

    test('⚠️ answers null for a name the item does not have', () {
      // `null` rather than `-1`, the idiom `Spl.nameStrref` established: "this
      // item has no name" is the question every caller is really asking, and
      // it is what separates an item from a monster's innate attack. 102 of
      // the installation's items name no string at either strref.
      final itm = Itm.trusted(
        buildItm(unidentifiedName: -1, identifiedName: -1),
      );
      expect(itm.identifiedNameStrref, isNull);
      expect(itm.unidentifiedNameStrref, isNull);
      expect(itm.hasName, isFalse);
    });

    test('an item with only an unidentified name still has a name', () {
      final itm = Itm.trusted(buildItm(identifiedName: -1));
      expect(itm.identifiedNameStrref, isNull);
      expect(itm.unidentifiedNameStrref, 6339);
      expect(itm.hasName, isTrue);
    });

    test('⚠️ reports whether it can stack, which needs BOTH conditions', () {
      // IESDP: "For items to be stackable, they must contain at least one
      // extension header, even if it is empty." So a stack amount above one is
      // not sufficient on its own, and a predicate that checked only the
      // number would offer stacking on items the engine refuses to stack.
      expect(Itm.trusted(buildItm(stackAmount: 40)).stacks, isFalse);
      expect(
        Itm.trusted(buildItm(stackAmount: 40, extendedHeaderCount: 1)).stacks,
        isTrue,
      );
      expect(
        Itm.trusted(buildItm(extendedHeaderCount: 1)).stacks,
        isFalse,
      );
    });

    test('locates its equipping feature blocks', () {
      // Phase F reads these for armour class. The header gives a pool offset,
      // an index into it and a count — not a start and an end.
      final itm = Itm.trusted(buildItm());
      expect(itm.featureBlockOffset, itmHeaderLength);
      expect(itm.equippingCount, 2);
      expect(itm.equippingIndex, 0);
    });
  });

  group('ItmCodec', () {
    test('accepts a well-formed item', () {
      expect(() => ItmCodec.decode(buildItm()), returnsNormally);
    });

    test('refuses a file that is not an item', () {
      expect(
        () => ItmCodec.decode(buildItm(signature: 'SPL ')),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('refuses a version it has not verified', () {
      expect(
        () => ItmCodec.decode(buildItm(version: 'V2.0')),
        throwsA(isA<InfinityFormatException>()),
      );
    });

    test('refuses a file too short to hold a header', () {
      expect(
        () => ItmCodec.decode(buildItm(truncateTo: 60)),
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });
}
