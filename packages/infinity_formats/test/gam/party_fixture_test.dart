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

/// The first fixture with more than one party member, and what it settled.
///
/// Every other save on the developer's machine holds a **one-character**
/// party, where array index, party order and portrait number are all `0` and
/// therefore indistinguishable — the same blind spot that hid the spike's
/// stride of −180 and that let "Level 1/1/1" reach the screen.
/// `000000100-Party` carries Aard, Imoen, Montaron and Xzar, and the facts
/// asserted here are what four members made visible.
///
/// ⚠️ **This fixture is a copy of a live save that the app itself edits**, so
/// it is a moving target. Nothing here may assert a field
/// `CharacterStat` can change — hit points, experience, gold, THAC0, armour
/// class and every ability score are all out of bounds, and Constitution has
/// already been rewritten once to arm an in-game run. What is asserted is
/// structure and identity, which editing does not touch.
library;

import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  const slot = '000000100-Party';
  final directory = fixtureSaveSlot(slot);
  final skip = directory == null
      ? 'no fixtures: run `fvm dart run tool/dev/sync_fixtures.dart` '
            'from the repository root'
      : null;

  Gam gamOf() => GamCodec.decode(
    File('$directory${Platform.pathSeparator}$gamFileName').readAsBytesSync(),
  );

  List<Cre> creaturesOf() => [
    for (final npc in gamOf().partyMembers)
      CreCodec.decode(npc.creBytes, source: npc.creResref),
  ];

  group('the four-member party', () {
    test(
      'has four members and 33 companions left to recruit',
      () {
        // Recruiting MOVES the struct between the two arrays rather than
        // flipping a flag on it: the one-character saves hold 1 and 36, this
        // one holds 4 and 33, and the three who moved are exactly the three
        // who joined. Both arrays resize, which is Phase 1's problem.
        final gam = gamOf();

        expect(gam.partyMembers, hasLength(4));
        expect(gam.nonPartyMembers, hasLength(33));
      },
      skip: skip,
    );

    test(
      'party order is the array index, and only the party has one',
      () {
        // This is what settles the PORTRT<n> reading. The two candidates --
        // "the n-th slot in the array" and "the character whose party order
        // is n" -- agree here, so the code cannot be wrong either way.
        final gam = gamOf();

        expect(
          [for (final npc in gam.partyMembers) npc.partyOrder],
          [0, 1, 2, 3],
        );
        expect(
          {for (final npc in gam.nonPartyMembers) npc.partyOrder},
          {0xFFFF},
          reason: 'every non-party struct marks itself absent',
        );
      },
      skip: skip,
    );

    test(
      'there is exactly one portrait file per party slot',
      () {
        // The game writes PORTRT0..PORTRT<count-1> beside the savegame, and
        // bakes each character's hit points into the image -- which is how
        // the mapping was fingerprinted: 39/42, 8/8, 9/9 and 4/4 each match
        // one member's stored hit points plus that member's own Constitution
        // bonus, and no two of them are the same number.
        final count = gamOf().partyMembers.length;
        final separator = Platform.pathSeparator;

        for (var i = 0; i < count; i++) {
          expect(
            File('$directory${separator}PORTRT$i.bmp').existsSync(),
            isTrue,
            reason: 'party slot $i has no portrait',
          );
        }
        expect(
          File('$directory${separator}PORTRT$count.bmp').existsSync(),
          isFalse,
          reason: 'a portrait past the last slot would break the 1:1 reading',
        );
      },
      skip: skip,
    );
  });

  group('identity fields four members made visible', () {
    test(
      'the engine overwrites the first byte of every resref with an asterisk',
      () {
        // CHARBASE -> *HARBASE, IMOEN1 -> *MOEN1, XZAR -> *ZAR. Replacement,
        // not a prefix: *ZAR occupies four bytes where a prefix would need
        // five. So the resref is NOT a usable identity key -- one character
        // of it is simply gone, and the dialogue file is what survives.
        final gam = gamOf();

        expect(
          [for (final npc in gam.partyMembers) npc.creResref],
          ['*HARBASE', '*MOEN1', '*ONTAR', '*ZAR'],
        );
        for (final npc in gam.nonPartyMembers) {
          expect(
            npc.creResref,
            startsWith('*'),
            reason: 'the mark is on unrecruited companions too',
          );
        }
      },
      skip: skip,
    );

    test(
      'the dialogue file survives intact where the resref does not',
      () {
        // The protagonist has none; the three recruited companions carry
        // theirs, which is the only unmangled name in the record.
        expect(
          [for (final cre in creaturesOf()) cre.dialogFile],
          ['', 'IMOEN2', 'MONTAJ', 'XZARJ'],
        );
      },
      skip: skip,
    );

    test(
      'both legs of the display name occur in this one save',
      () {
        // The protagonist is named in the GAM struct and has no strref; the
        // companions are the other way round. Until this fixture the two legs
        // had never been seen side by side in real data.
        final gam = gamOf();
        final creatures = creaturesOf();

        expect(creatures.first.longNameStrref, -1);
        expect(gam.partyMembers.first.displayName, 'Aard');

        for (var i = 1; i < creatures.length; i++) {
          expect(creatures[i].longNameStrref, greaterThan(0));
          expect(gam.partyMembers[i].displayName, isEmpty);
        }
      },
      skip: skip,
    );
  });

  group('what only a mixed party could show', () {
    test(
      'the kit dword carries the KIT.IDS key in its high word',
      () {
        // Xzar proves the shift: 0x10000000 >> 16 is 0x1000, which KIT.IDS
        // numbers MAGESCHOOL_NECROMANCER, and Xzar is a Necromancer. Montaron
        // proves the other half: a Fighter/Thief has no mage component, so
        // his 0x40000000 cannot be a school -- it is KIT.IDS's TRUECLASS.
        // Imoen shows that "no kit" also has a second encoding, plain zero.
        expect(
          [for (final cre in creaturesOf()) cre.kitId],
          [0x40000000, 0x00000000, 0x40000000, 0x10000000],
        );
      },
      skip: skip,
    );

    test(
      'unused class-level slots hold 1 in an NPC record and 0 in the player',
      () {
        // The reason "Level 1/1/1" reached the screen for a plain Thief. Only
        // the player's own record zeroes what it does not use, and every
        // one-character fixture was the player's own record.
        expect(creaturesOf().map((cre) => cre.levels).toList(), [
          (1, 1, 0),
          (1, 1, 1),
          (1, 1, 1),
          (1, 1, 1),
        ]);
      },
      skip: skip,
    );

    test(
      'the classes are what makes those slots readable',
      () {
        // CLASS.IDS: FIGHTER_MAGE, THIEF, FIGHTER_THIEF, MAGE -- two, one,
        // two, one. Nothing in the level bytes says that.
        expect(
          [for (final cre in creaturesOf()) cre.classId],
          [7, 4, 9, 1],
        );
      },
      skip: skip,
    );

    test(
      'the party CRE blobs chain without a gap',
      () {
        // The same check the 36-link non-party chain gives, now on the array
        // that actually changed size when three companions joined.
        final party = gamOf().partyMembers;

        for (var i = 1; i < party.length; i++) {
          expect(
            party[i].creOffset,
            party[i - 1].creOffset + party[i - 1].creLength,
            reason:
                'chain breaks between ${party[i - 1].creResref} '
                'and ${party[i].creResref}',
          );
        }
      },
      skip: skip,
    );
  });
}
