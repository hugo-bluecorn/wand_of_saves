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

/// Confirmation against the player's own installation, which cannot be
/// committed. The hermetic tests live in `itm_test.dart`; this file checks
/// that the codec agrees with the shipped game, and skips when it is absent.
///
/// ⚠️ **This is the file that earns the `signed: true` on the name strrefs.**
/// A synthetic fixture proves the code runs; only the installation proves it
/// is right, because the shape that matters — an item with no name at all — is
/// one no fixture author would think to write.
library;

import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

void main() {
  final game = _installation();
  final skip = game == null
      ? 'BG:EE not found — set BGEE_GAME_DIR to run this'
      : null;

  group('every ITM the installation ships', () {
    late List<Itm> items;
    late Map<String, Itm> byResref;

    setUpAll(() {
      if (game == null) return;
      final index = KeyIndex.parse(
        File('$game/chitin.key').readAsBytesSync(),
        source: 'chitin.key',
      );
      final archives = <int, BifArchive>{};
      byResref = {};
      for (final resref in index.resrefsOf(ResourceType.item)) {
        final where = index.locate(resref, ResourceType.item)!;
        final relative = index.archives[where.archive].replaceAll(r'\', '/');
        final archive = archives[where.archive] ??= BifArchive.parse(
          File('$game/$relative').readAsBytesSync(),
          source: relative,
        );
        byResref[resref] = ItmCodec.decode(
          archive.resource(where.file),
          source: resref,
        );
      }
      items = byResref.values.toList();
    });

    test('is decodable — signature and version, all of them', () {
      // ItmCodec throws on either, so reaching here is the assertion. What is
      // worth stating is the count, because a silent drop to zero would also
      // pass a "nothing threw" test.
      expect(items, hasLength(1530));
    });

    test(
      '⚠️ carries negative name strrefs, which is why the field is signed',
      () {
        // **The measurement the spec rests on.** IESDP states no signedness for
        // any ITM field, so `signed: true` was earned rather than inherited
        // from SPL. Were this zero the annotation would be unfounded.
        final negatives = items
            .where(
              (i) =>
                  i.identifiedNameStrref == null ||
                  i.unidentifiedNameStrref == null,
            )
            .length;
        expect(
          negatives,
          greaterThan(100),
          reason:
              'measured 195 on 2026-08-12; a drop to zero means the read '
              'went unsigned and -1 became 4,294,967,295',
        );
      },
    );

    test('⚠️ 102 of them name no string at all, and must never be offered', () {
      // `GHOST`, `DEMOGORG`, `ANKHEG1` — a monster's innate attack is an item
      // to the engine. `hasName` is the filter, the same one `wizardSpells`
      // applies to SPL, and this is the number behind it.
      final nameless = items.where((i) => !i.hasName).toList();
      expect(nameless, hasLength(102));
    });

    test('⚠️ five MORE resolve to empty text, which this cannot see', () {
      // **102 here, 107 in the app.** The difference is five items that carry a
      // real strref pointing at empty text, and telling them apart needs the
      // talk table — which this package must never open, because "where is the
      // game installed and which language did the player choose" are facts
      // about a machine, not about a file format (D11).
      //
      // Recorded here rather than left as a discrepancy for somebody to
      // rediscover: **the offerable filter is a two-stage one**, and the second
      // stage belongs above the repository, where the strref is resolved.
      final withStrref = items.where((i) => i.hasName).toList();
      expect(withStrref, hasLength(1530 - 102));
    });

    test('BOOT01 reads exactly as its bytes were measured', () {
      // The oracle the whole offset table was checked against: header 114 plus
      // two 48-byte feature blocks is 210, this file's exact length.
      final boots = byResref['BOOT01']!;
      expect(boots.bytes, hasLength(210));
      expect(boots.unidentifiedNameStrref, 6339); // "Boots"
      expect(boots.identifiedNameStrref, 6823); // "The Paws of the Cheetah"
      expect(boots.itemType, 4); // ITEMCAT.IDS: BOOT
      expect(boots.price, 2300);
      expect(boots.loreToIdentify, 30);
      expect(boots.weight, 4);
      expect(boots.inventoryIcon, 'IBOOT01');
      expect(boots.groundIcon, 'GBOOT01');
      expect(boots.descriptionIcon, 'CBOOT01');
      expect(boots.extendedHeaderCount, 0);
      expect(boots.equippingCount, 2);
      expect(boots.featureBlockOffset, itmHeaderLength);
    });

    test('⚠️ the identified name is not a key — four items share one', () {
      // The fifth time this project has met "a name is not a key", after
      // KIT.IDS, two AXE rows in weapprof.2da, FALLEN_CLERIC, and weapprof's
      // padding band. A picker keyed on the name silently merges these.
      for (final resref in ['BOOT01', 'BOOTDRIZ', 'DASBOOT', 'TROLLBOO']) {
        expect(
          byResref[resref]!.identifiedNameStrref,
          6823,
          reason: '$resref also resolves to "The Paws of the Cheetah"',
        );
      }
    });

    test('the section arithmetic closes on every item', () {
      // ⚠️ The check that catches a wrong offset without needing an oracle per
      // item: the feature pool starts where the header says and the blocks
      // that follow must fit inside the file.
      for (final entry in byResref.entries) {
        final itm = entry.value;
        final end =
            itm.featureBlockOffset +
            (itm.equippingIndex + itm.equippingCount) * itmFeatureBlockLength;
        expect(
          end,
          lessThanOrEqualTo(itm.bytes.length),
          reason: '${entry.key}: equipping features run past the file',
        );
        expect(
          itm.featureBlockOffset,
          greaterThanOrEqualTo(itmHeaderLength),
          reason: '${entry.key}: feature pool overlaps the header',
        );
      }
    });

    test('stacking needs an extended header, not just a stack amount', () {
      // IESDP's rule, asserted against the shipped data rather than restated:
      // no item claims to stack while carrying zero extended headers.
      final claiming = items.where((i) => i.stacks);
      expect(claiming, isNotEmpty, reason: 'arrows and potions stack');
      for (final itm in claiming) {
        expect(itm.extendedHeaderCount, greaterThan(0));
      }
    });
  }, skip: skip);
}

String? _installation() {
  final home = Platform.environment['HOME'] ?? '.';
  const game = "Baldur's Gate Enhanced Edition";
  const steam = 'steamapps/common';
  final roots = [
    ?Platform.environment['BGEE_GAME_DIR'],
    '$home/.local/share/Steam/$steam/$game',
    '$home/.steam/steam/$steam/$game',
    '$home/Library/Application Support/Steam/$steam/$game',
    "$home/GOG Games/Baldur's Gate - Enhanced Edition",
  ];
  for (final root in roots) {
    if (File('$root/chitin.key').existsSync()) return root;
  }
  return null;
}
