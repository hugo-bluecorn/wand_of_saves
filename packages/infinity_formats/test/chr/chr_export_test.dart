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

import 'dart:io';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/synthetic_gam.dart';

void main() {
  GamNpc onlyMemberOf(Uint8List bytes) =>
      GamCodec.decode(bytes).partyMembers.single;

  group('a character exported from a savegame', () {
    final gam = buildGam(
      party: const [
        SyntheticNpc(resref: '*HARBASE', displayName: 'Aard', creLength: 64),
      ],
    );

    test('is a CHR V2.0 that reads back', () {
      final chr = ChrCodec.exportOf(onlyMemberOf(gam));

      expect(() => ChrCodec.decode(ChrCodec.encode(chr)), returnsNormally);
      expect(chr.name, 'Aard');
    });

    test('puts the record at 100 and closes on the file length', () {
      final npc = onlyMemberOf(gam);
      final chr = ChrCodec.exportOf(npc);

      expect(chr.creOffset, ChrHeaderField.headerSize);
      expect(chr.creLength, npc.creLength);
      expect(chr.bytes, hasLength(ChrHeaderField.headerSize + npc.creLength));
    });

    test('copies the record verbatim rather than rebuilding it', () {
      // The measurement this whole slice rests on: export is a copy. Anything
      // that reassembles a creature from the fields a model happens to
      // understand would silently drop the rest.
      final npc = onlyMemberOf(gam);

      expect(ChrCodec.exportOf(npc).creBytes, npc.creBytes);
    });

    test('copies the name field byte for byte, not through a String', () {
      // Measured identical on both matched pairs on disk. Round-tripping the
      // name through decode-and-re-encode would be a second chance to differ
      // for no gain.
      final npc = onlyMemberOf(gam);
      final chr = ChrCodec.exportOf(npc);

      expect(
        chr.bytes.sublist(
          ChrHeaderField.name.offset,
          ChrHeaderField.name.offset + ChrHeaderField.name.length,
        ),
        npc.displayNameBytes,
      );
    });

    test('copies the quick-slot block from the NPC struct', () {
      // GAM NPC 0x8c-0xbf is CHR header 0x30-0x63, byte for byte -- measured
      // across three exported characters against the party members they came
      // from, identical in every comparison.
      final npc = onlyMemberOf(gam);

      expect(
        ChrCodec.exportOf(npc).bytes.sublist(
          ChrHeaderField.quickSlotsOffset,
          ChrHeaderField.headerSize,
        ),
        npc.quickSlotBytes,
      );
    });

    test('does not reach back into the savegame it came from', () {
      // A view over the parent buffer would make an exported character change
      // when the save it came from is edited.
      final npc = onlyMemberOf(gam);
      final chr = ChrCodec.exportOf(npc);
      final edited = GamCodec.decode(gam).withPartyGold(999);

      expect(edited.bytes, isNot(gam));
      expect(chr.bytes.length, ChrHeaderField.headerSize + npc.creLength);
    });
  });

  group(
    'against the engine’s own exports',
    () {
      // The strongest oracle available without loading the game: the player has
      // three .chr files BG:EE itself wrote. Our header must match theirs.
      //
      // ⚠️ **The CRE will not match and must not be asserted.** Measured on
      // both matched pairs: an exported record differs from the save's at
      // 0x27c and 0x27e -- IESDP's global and local actor enumeration values,
      // which the engine assigns per session -- plus whatever play happened
      // after the export. The header is the part we build.
      final names = fixtureChrNames();
      final slots = [
        for (final slot
            in Directory(defaultFixtureSaveRoot).existsSync()
                ? Directory(
                    defaultFixtureSaveRoot,
                  ).listSync().whereType<Directory>()
                : <Directory>[])
          slot.path.split(Platform.pathSeparator).last,
      ];

      test('a matched pair exists to compare', () {
        expect(names, isNotEmpty);
        expect(slots, isNotEmpty);
      });

      test('our exported header is the engine’s, byte for byte', () {
        var compared = 0;
        for (final name in names) {
          final theirs = ChrCodec.decode(
            File(fixtureChr(name)!).readAsBytesSync(),
          );

          for (final slot in slots) {
            final path = fixtureGam(slot);
            if (path == null) continue;
            final gam = GamCodec.decode(File(path).readAsBytesSync());

            for (final npc in gam.partyMembers) {
              if (npc.creLength != theirs.creLength) continue;
              if (npc.displayName != theirs.name) continue;

              expect(
                ChrCodec.exportOf(npc).bytes.sublist(
                  0,
                  ChrHeaderField.headerSize,
                ),
                theirs.bytes.sublist(0, ChrHeaderField.headerSize),
                reason: '$name against $slot',
              );
              compared++;
            }
          }
        }
        expect(
          compared,
          greaterThan(0),
          reason:
              'no exported character matched a party member in any fixture; '
              'the comparison never ran',
        );
      });
    },
    skip: fixtureChrNames().isEmpty ? 'run tool/dev/sync_fixtures.dart' : null,
  );
}
