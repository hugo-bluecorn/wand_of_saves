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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/layout.dart';

void main() {
  /// A CRE with only its fixed header — enough to exercise validation.
  Uint8List bareCre({
    String signature = 'CRE ',
    String version = 'V1.0',
    int effectVersion = 1,
    int? truncateTo,
  }) {
    final out = Uint8List(CreHeaderField.headerSize)
      ..setRange(0, 4, ascii.encode(signature))
      ..setRange(4, 8, ascii.encode(version));
    out[CreHeaderField.effectVersion.offset] = effectVersion;
    return truncateTo == null ? out : Uint8List.sublistView(out, 0, truncateTo);
  }

  group('the layout table', () {
    test('has no overlapping fields', () {
      // No struct size: this is a verified subset of IESDP's 126-field BGEE
      // branch, not the whole table, so gaps are expected. Overlaps are not.
      expect(layoutProblems(CreHeaderField.values), isEmpty);
    });

    test('ends where the header does', () {
      const last = CreHeaderField.dialogFile;

      expect(last.offset + last.length, CreHeaderField.headerSize);
    });
  });

  group('validation', () {
    test('accepts a well-formed CRE V1.0', () {
      expect(CreCodec.decode(bareCre()).effectVersion, 1);
    });

    test('rejects a wrong signature, naming what it found', () {
      expect(
        () => CreCodec.decode(bareCre(signature: 'GAME')),
        throwsA(
          isA<InfinityFormatException>().having(
            (e) => e.message,
            'message',
            contains('GAME'),
          ),
        ),
      );
    });

    test('rejects an unsupported version, naming what it found', () {
      // CRE V9.0 is IWD; D3 scopes this build to BG1EE.
      expect(
        () => CreCodec.decode(bareCre(version: 'V9.0')),
        throwsA(
          isA<InfinityFormatException>().having(
            (e) => e.message,
            'message',
            contains('V9.0'),
          ),
        ),
      );
    });

    test('rejects a record too short for its fixed header', () {
      expect(
        () => CreCodec.decode(bareCre(truncateTo: 100)),
        throwsA(isA<InfinityFormatException>()),
      );
    });
  });

  group('effect layout selection', () {
    test('version 0 selects 48-byte effects', () {
      expect(CreCodec.decode(bareCre(effectVersion: 0)).effectLength, 48);
    });

    test('version 1 selects 264-byte effects', () {
      expect(CreCodec.decode(bareCre()).effectLength, 264);
    });
  });

  group('the real save', () {
    final path = fixtureGam('000000022-last');
    final skip = path == null
        ? 'no fixtures: run `fvm dart run tool/dev/sync_fixtures.dart` '
              'from the repository root'
        : null;

    List<GamNpc> everyone() {
      final gam = GamCodec.decode(File(path!).readAsBytesSync());
      return [...gam.partyMembers, ...gam.nonPartyMembers];
    }

    test(
      'every creature in the save parses',
      () {
        final all = everyone();

        expect(all, hasLength(37));
        for (final npc in all) {
          expect(
            () => CreCodec.decode(npc.creBytes),
            returnsNormally,
            reason: npc.creResref,
          );
        }
      },
      skip: skip,
    );

    test(
      'the first present section begins exactly where the header ends',
      () {
        // Confirms headerSize from data rather than from my transcription --
        // 724 on all 37, with no exact-fit check needed.
        //
        // "Present" matters: two creatures in this save have no known-spells
        // section at all, and an absent section carries offset 0. Asserting
        // knownSpellsOffset == 724 unconditionally is what first failed here,
        // and it was the test that was wrong, not the data.
        for (final npc in everyone()) {
          final cre = CreCodec.decode(npc.creBytes);
          final firstPresent = [
            cre.knownSpellsOffset,
            cre.memorizationInfoOffset,
            cre.memorizedSpellsOffset,
            cre.itemSlotsOffset,
            cre.itemsOffset,
            cre.effectsOffset,
          ].where(Cre.hasSection).reduce((a, b) => a < b ? a : b);

          expect(
            firstPresent,
            CreHeaderField.headerSize,
            reason: npc.creResref,
          );
        }
      },
      skip: skip,
    );

    test(
      'creatures without a section report it as absent, not at offset zero',
      () {
        final withoutSpells = everyone()
            .map((n) => CreCodec.decode(n.creBytes))
            .where((c) => !c.hasKnownSpells);

        expect(
          withoutSpells,
          isNotEmpty,
          reason: 'the fixture is expected to contain such creatures',
        );
        for (final cre in withoutSpells) {
          expect(cre.knownSpellsOffset, 0);
        }
      },
      skip: skip,
    );

    test(
      'the section chain closes exactly on every creature',
      () {
        // The strongest check available on a CRE. It reconciles all six
        // section pointers, every entry size, and the effect-version flag in
        // one comparison -- and against data nobody wrote for the purpose.
        //
        // It is also precisely the arithmetic Phase 1's writer has to
        // reproduce, since adding a single item moves everything after it.
        for (final npc in everyone()) {
          final cre = CreCodec.decode(npc.creBytes);

          expect(
            cre.contentEnd,
            cre.bytes.length,
            reason:
                '${npc.creResref}: sections end at ${cre.contentEnd} but the '
                'record is ${cre.bytes.length} bytes '
                '(${cre.itemsCount} items, ${cre.effectsCount} effects '
                'v${cre.effectVersion + 1})',
          );
        }
      },
      skip: skip,
    );

    test(
      'the sections run in order without overlapping',
      () {
        for (final npc in everyone()) {
          final cre = CreCodec.decode(npc.creBytes);
          final boundaries = [
            CreHeaderField.headerSize,
            cre.knownSpellsOffset,
            cre.memorizationInfoOffset,
            cre.memorizedSpellsOffset,
            cre.itemSlotsOffset,
            cre.itemsOffset,
            cre.effectsOffset,
          ].where(Cre.hasSection).toList();

          for (var i = 1; i < boundaries.length; i++) {
            expect(
              boundaries[i],
              greaterThanOrEqualTo(boundaries[i - 1]),
              reason:
                  '${npc.creResref}: section $i starts before section '
                  '${i - 1}',
            );
          }
        }
      },
      skip: skip,
    );

    test(
      'the protagonist matches the values in the findings document',
      () {
        final cre = CreCodec.decode(everyone().first.creBytes);

        expect(cre.experience, 325);
        expect(cre.currentHitPoints, 6);
        expect(cre.maximumHitPoints, 7);
        expect(cre.thac0, 20);
        expect(cre.levels, (1, 1, 0));
        expect(cre.strength, 18);
        expect(cre.strengthBonus, 100);
        expect(cre.intelligence, 18);
        expect(cre.wisdom, 9);
        expect(cre.dexterity, 17);
        expect(cre.constitution, 16);
        expect(cre.charisma, 9);
      },
      skip: skip,
    );

    test(
      'reputation is stored times ten',
      () {
        // Recorded as "Unverified" in the findings document until now. The
        // field reads 110 where the game shows 11.0, and BG1 reputation only
        // ranges 0-20, so 110 cannot be a raw value.
        expect(CreCodec.decode(everyone().first.creBytes).reputation, 11.0);
      },
      skip: skip,
    );

    test(
      "the protagonist's name is not in dialog.tlk",
      () {
        // 0xFFFFFFFF. The displayed name comes from the GAM NPC struct -- the
        // spike's second known bug was rendering this as '<invalid ...>'.
        expect(
          CreCodec.decode(everyone().first.creBytes).longNameStrref,
          0xFFFFFFFF,
        );
      },
      skip: skip,
    );
  });
}
