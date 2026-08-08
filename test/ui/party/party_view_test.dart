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

/// What the character panel actually renders, for the two things a
/// one-character party could never show.
///
/// The party built here mirrors `000000100-Party` field for field — Aard the
/// Fighter/Mage, Imoen the Thief, Montaron the Fighter/Thief and Xzar the
/// Necromancer, each with the level bytes and kit dword the real save holds.
/// Both defects this covers were invisible to every existing test and to code
/// review, and visible the moment four members were on screen at once.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/ui/party/party_view.dart';

import '../../support/fakes.dart';
import '../../support/synthetic_save.dart';

void main() {
  const slotName = '000000022-last';

  /// The Party save's four members, as the savegame holds them.
  const party = [
    // Aard, and every default in SyntheticCharacter is already his: the
    // protagonist is what every other fixture on this machine holds.
    SyntheticCharacter(),
    SyntheticCharacter(
      resref: '*MOEN1',
      displayName: 'Imoen',
      partyOrder: 1,
      classId: 4,
      kitId: 0,
      levelThirdClass: 1,
    ),
    SyntheticCharacter(
      resref: '*ONTAR',
      displayName: 'Montaron',
      partyOrder: 2,
      classId: 9,
      levelThirdClass: 1,
    ),
    SyntheticCharacter(
      resref: '*ZAR',
      displayName: 'Xzar',
      partyOrder: 3,
      classId: 1,
      kitId: 0x10000000,
      levelThirdClass: 1,
    ),
  ];

  ProviderContainer containerWith(List<SyntheticCharacter> members) =>
      ProviderContainer.test(
        overrides: [
          saveGameRepositoryProvider.overrideWithValue(
            FakeSaveGameRepository(
              slots: [fakeSlot('last')],
              gam: GamCodec.decode(buildSave(party: members)),
            ),
          ),
          // Every member here is named in the GAM struct, so no strref is
          // ever resolved and the table can be empty.
          stringRepositoryProvider.overrideWithValue(FakeStringRepository()),
        ],
      );

  /// Pumps the party shell on a surface big enough for the rail and the pane.
  Future<void> showParty(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1600, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = containerWith(party);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: PartyView(slotDirectoryName: slotName),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Selects [name] in the portrait rail by its label.
  Future<void> select(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('every party member is on the rail', (tester) async {
    await showParty(tester);

    for (final name in ['Aard', 'Imoen', 'Montaron', 'Xzar']) {
      // The selected member is named twice -- once on the rail, once as the
      // pane's heading -- so this is "at least once", not "exactly once".
      expect(find.text(name), findsWidgets, reason: '$name is missing');
    }
  });

  testWidgets('a single class shows one level, not the junk slots', (
    tester,
  ) async {
    // Imoen is a THIEF whose record stores 1/1/1, and the panel used to print
    // "Level 1/1/1" for her. The slot count comes from CLASS.IDS.
    await showParty(tester);
    await select(tester, 'Imoen');

    expect(
      find.text('Level 1 · Male · Elf · Thief · Neutral Good'),
      findsOneWidget,
    );
  });

  testWidgets('a two-class name shows two levels from the same bytes', (
    tester,
  ) async {
    // Montaron stores exactly what Imoen stores. Only his class differs.
    await showParty(tester);
    await select(tester, 'Montaron');

    expect(
      find.textContaining('Level 1/1 · '),
      findsOneWidget,
      reason: 'FIGHTER_THIEF uses two of the three slots',
    );
  });

  testWidgets('the player character was already right and stays right', (
    tester,
  ) async {
    // Aard stores 1/1/0, where the old rule and the new one agree — which is
    // exactly why the bug survived a one-character fixture.
    await showParty(tester);

    expect(
      find.text('Level 1/1 · Male · Elf · Fighter / Mage · Neutral Good'),
      findsOneWidget,
    );
  });

  testWidgets('a specialist mage is named by his school', (tester) async {
    // Xzar stores 0x10000000, whose high word is KIT.IDS 0x1000.
    await showParty(tester);
    await select(tester, 'Xzar');

    expect(
      find.text('Level 1 · Male · Elf · Mage (Necromancer) · Neutral Good'),
      findsOneWidget,
    );
  });

  testWidgets('no character is ever labelled a generalist mage', (
    tester,
  ) async {
    // The precise regression. Aard stores 0x40000000 and Imoen stores 0, both
    // meaning no kit; the parser bug turned the first of those into
    // MAGESCHOOL_GENERALIST, which would have put "(Generalist)" on a
    // Fighter/Thief. Checked on every member, since the wrong name would have
    // reached three of the four.
    await showParty(tester);

    for (final name in ['Imoen', 'Montaron', 'Xzar', 'Aard']) {
      if (name != 'Aard') await select(tester, name);
      expect(
        find.textContaining('Generalist'),
        findsNothing,
        reason: "$name should carry no kit name but Xzar's own",
      );
    }
  });
}
