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

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/layout.dart';

void main() {
  group('CreItemField', () {
    test('accounts for exactly the 20 bytes of an item entry', () {
      // Dense with no gaps, so the table is self-checking — the same branch
      // GamNpcField uses. A mistranscribed offset leaves a gap or an overlap.
      expect(
        layoutProblems(CreItemField.values, structSize: creItemLength),
        isEmpty,
      );
    });

    test('carries the offsets recorded in the findings', () {
      expect(CreItemField.resref.offset, 0x00);
      expect(CreItemField.resref.length, 8);
      expect(CreItemField.expiration.offset, 0x08);
      expect(CreItemField.quantity1.offset, 0x0a);
      expect(CreItemField.quantity2.offset, 0x0c);
      expect(CreItemField.quantity3.offset, 0x0e);
      expect(CreItemField.flags.offset, 0x10);
      expect(CreItemField.flags.length, 4);
      expect(creItemLength, 20);
    });
  });

  group('CreItemSlot', () {
    test('⚠️ names 38 item slots, not 40', () {
      // The table is 40 words. The last two are *selected weapon* and
      // *selected weapon ability* — state, not item indices. A model that maps
      // all forty corrupts the selection pair the moment it writes.
      expect(CreItemSlot.values, hasLength(38));
      expect(creItemSlotsLength, 80);
      expect(CreItemSlot.selectedWeaponOffset, 38 * 2);
      expect(CreItemSlot.selectedWeaponAbilityOffset, 39 * 2);
    });

    test('places every slot at twice its index', () {
      for (var i = 0; i < CreItemSlot.values.length; i++) {
        expect(CreItemSlot.values[i].index, i);
        expect(CreItemSlot.values[i].byteOffset, i * 2);
      }
    });

    test('carries the BG order IESDP documents', () {
      expect(CreItemSlot.helmet.index, 0);
      expect(CreItemSlot.armor.index, 1);
      expect(CreItemSlot.shield.index, 2);
      expect(CreItemSlot.gloves.index, 3);
      expect(CreItemSlot.leftRing.index, 4);
      expect(CreItemSlot.rightRing.index, 5);
      expect(CreItemSlot.amulet.index, 6);
      expect(CreItemSlot.belt.index, 7);
      expect(CreItemSlot.boots.index, 8);
      expect(CreItemSlot.weapon1.index, 9);
      expect(CreItemSlot.weapon4.index, 12);
      // ⚠️ FOUR quivers. IESDP's fourth is unreachable from the game's own GUI,
      // and a three-quiver model misaligns everything after it by one word.
      expect(CreItemSlot.quiver1.index, 13);
      expect(CreItemSlot.quiver4.index, 16);
      expect(CreItemSlot.cloak.index, 17);
      expect(CreItemSlot.quick1.index, 18);
      expect(CreItemSlot.quick3.index, 20);
      expect(CreItemSlot.pack1.index, 21);
      expect(CreItemSlot.pack16.index, 36);
      expect(CreItemSlot.magicWeapon.index, 37);
    });

    test('knows which slots are the backpack', () {
      expect(CreItemSlot.pack, hasLength(16));
      expect(CreItemSlot.pack.first, CreItemSlot.pack1);
      expect(CreItemSlot.pack.last, CreItemSlot.pack16);
      expect(CreItemSlot.pack1.isPack, isTrue);
      expect(CreItemSlot.boots.isPack, isFalse);
    });
  });

  group('itemEntry', () {
    test('builds a 20-byte entry', () {
      final entry = itemEntry(resref: 'BOOT01');
      expect(entry, hasLength(creItemLength));
    });

    test('writes the resref and reads back clean', () {
      final entry = itemEntry(resref: 'BOOT01');
      expect(
        decodeFixedString(entry, CreItemField.resref.offset, 8),
        'BOOT01',
      );
    });

    test('defaults to identified, quantity one, nothing else set', () {
      // ⚠️ **Identified by default, deliberately.** An item added by an editor
      // has no story of having been found unidentified, and the engine draws
      // the plain name — "Belt" — for anything with the flag clear. Adding a
      // Belt of Antipode that shows as "Belt" would look like a defect.
      final view = ByteData.sublistView(itemEntry(resref: 'BOOT01'));
      expect(view.getUint16(CreItemField.expiration.offset, Endian.little), 0);
      expect(view.getUint16(CreItemField.quantity1.offset, Endian.little), 1);
      expect(view.getUint16(CreItemField.quantity2.offset, Endian.little), 0);
      expect(view.getUint16(CreItemField.quantity3.offset, Endian.little), 0);
      expect(
        view.getUint32(CreItemField.flags.offset, Endian.little),
        CreItemFlag.identified.mask,
      );
    });

    test('takes a quantity and a flag set', () {
      final view = ByteData.sublistView(
        itemEntry(
          resref: 'AROW01',
          quantity: 40,
          flags: {CreItemFlag.identified, CreItemFlag.stolen},
        ),
      );
      expect(view.getUint16(CreItemField.quantity1.offset, Endian.little), 40);
      expect(
        view.getUint32(CreItemField.flags.offset, Endian.little),
        CreItemFlag.identified.mask | CreItemFlag.stolen.mask,
      );
    });

    test('refuses a resref too long for the field', () {
      expect(
        () => itemEntry(resref: 'TOOLONGRESREF'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('CreItemFlag', () {
    test('carries the four bits IESDP documents', () {
      expect(CreItemFlag.identified.mask, 1);
      expect(CreItemFlag.unstealable.mask, 2);
      expect(CreItemFlag.stolen.mask, 4);
      expect(CreItemFlag.undroppable.mask, 8);
    });

    test('reads a stored value back into a set', () {
      // `Aard1.chr` holds SCRL3Z at flags 0x3 — identified and unstealable.
      expect(CreItemFlag.setFrom(0x3), {
        CreItemFlag.identified,
        CreItemFlag.unstealable,
      });
      // ...and BELT16 at 0x0, which is how "not identified" is stored.
      expect(CreItemFlag.setFrom(0), isEmpty);
    });
  });
}
