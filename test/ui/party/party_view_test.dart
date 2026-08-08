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
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/ui/party/party_view.dart';

import '../../support/fakes.dart';
import '../../support/synthetic_save.dart';

void main() {
  const slotName = '000000022-last';

  /// The Party save's four members, as the savegame holds them.
  ///
  /// Proficiencies included, and they are the real ones — each matches the
  /// weapon that character is actually carrying, which is what made them a
  /// measurement rather than four readings of the same byte.
  const party = [
    // Aard, and every default in SyntheticCharacter is already his: the
    // protagonist is what every other fixture on this machine holds. He
    // dual-wields, hence Two-Weapon Style.
    SyntheticCharacter(
      saveVersusSpells: 12,
      proficiencies: {114: 2, 100: 2},
    ),
    SyntheticCharacter(
      resref: '*MOEN1',
      displayName: 'Imoen',
      partyOrder: 1,
      classId: 4,
      kitId: 0,
      levelThirdClass: 1,
      moveSilently: 15,
      findTraps: 25,
      lore: 3,
      proficiencies: {91: 1, 105: 1},
    ),
    SyntheticCharacter(
      resref: '*ONTAR',
      displayName: 'Montaron',
      partyOrder: 2,
      classId: 9,
      levelThirdClass: 1,
      hideInShadows: 10,
      moveSilently: 20,
      proficiencies: {91: 2, 107: 2},
    ),
    SyntheticCharacter(
      resref: '*ZAR',
      displayName: 'Xzar',
      partyOrder: 3,
      classId: 1,
      kitId: 0x10000000,
      levelThirdClass: 1,
      saveVersusDeath: 14,
      saveVersusWands: 11,
      saveVersusPolymorph: 13,
      saveVersusBreath: 15,
      saveVersusSpells: 12,
      proficiencies: {96: 1},
    ),
  ];

  /// The party's proficiencies as the player's own `weapprof.2da` holds them.
  ///
  /// **Strrefs, not names, deliberately** — this is what the resource
  /// repository produces, and resolving them through the talk table is the
  /// merge D11 is about. A fixture that carried the finished names would skip
  /// the very step that goes wrong.
  ///
  /// The ceilings are the table's own: a Fighter/Mage caps at 3 in Two-Weapon
  /// Style, which is why Aard at 2 has exactly one pip left to give.
  const proficiencyTable = ProficiencyCatalogue({
    114: ProficiencyEntry(
      id: 114,
      identifier: '2WEAPON',
      nameStrref: 25023,
      maximumByColumn: {'FIGHTER_MAGE': 3},
    ),
    100: ProficiencyEntry(
      id: 100,
      identifier: 'FLAILMORNINGSTAR',
      nameStrref: 25012,
      maximumByColumn: {'FIGHTER_MAGE': 2},
    ),
    91: ProficiencyEntry(
      id: 91,
      identifier: 'SHORTSWORD',
      nameStrref: 25002,
      maximumByColumn: {'THIEF': 1, 'FIGHTER_THIEF': 2},
    ),
    105: ProficiencyEntry(
      id: 105,
      identifier: 'SHORTBOW',
      nameStrref: 25017,
      maximumByColumn: {'THIEF': 1},
    ),
    107: ProficiencyEntry(
      id: 107,
      identifier: 'SLING',
      nameStrref: 25019,
      maximumByColumn: {'FIGHTER_THIEF': 2},
    ),
    96: ProficiencyEntry(
      // No strref, so this one must fall back to its identifier — the step
      // a machine with no talk table takes, on the same screen as the rest.
      id: 96,
      identifier: 'DAGGER',
      maximumByColumn: {'NECROMANCER': 1},
    ),
  });

  /// The strings the player's talk table holds for [proficiencyTable].
  ///
  /// The real numbers, read off this machine's `dialog.tlk`. IESDP's copy of
  /// `weapprof.2da` points at 31138 for Two-Weapon Style, which resolves in a
  /// BG:EE table to a paragraph about temples — that is D11, and these
  /// strrefs are the other half of it.
  const proficiencyStrings = {
    25023: 'Two-Weapon Style',
    25012: 'Flail / Morning Star',
    25002: 'Short Sword',
    25017: 'Shortbow',
    25019: 'Sling',
  };

  ProviderContainer containerWith(List<SyntheticCharacter> members) =>
      ProviderContainer.test(
        overrides: [
          saveGameRepositoryProvider.overrideWithValue(
            FakeSaveGameRepository(
              slots: [fakeSlot('last')],
              gam: GamCodec.decode(buildSave(party: members)),
            ),
          ),
          // Every member here is named in the GAM struct, so the only strrefs
          // resolved are the proficiencies'.
          stringRepositoryProvider.overrideWithValue(
            FakeStringRepository(proficiencyStrings),
          ),
          // ⚠️ **Not optional.** Left to the real one, this reads the
          // machine's own `chitin.key` and a 30 MB archive, and `pumpAndSettle`
          // does not await real file I/O — the widget never settles and the
          // whole file times out rather than failing on an assertion.
          resourceRepositoryProvider.overrideWithValue(
            const FakeResourceRepository(proficiencyTable),
          ),
        ],
      );

  /// Pumps the party shell on a surface big enough for the whole sheet.
  ///
  /// **Tall on purpose.** The pane is a `ListView`, so anything below the
  /// viewport is never built and `find.text` cannot see it — widening the stat
  /// tiles from 190 to 222 was enough to push the last group off a 1200-point
  /// surface and make a passing test start failing. A surface that fits the
  /// sheet keeps these tests about what the panel renders rather than about
  /// where the fold happens to fall.
  Future<void> showParty(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1600, 2200)
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

  testWidgets('a specialist mage is named by his school, not his class', (
    tester,
  ) async {
    // Xzar stores 0x10000000, whose high word is KIT.IDS 0x1000. BG:EE's
    // record screen reads "Necromancer: Level 1" and "Male / Human /
    // Necromancer / Chaotic Evil" -- the kit stands in for the class, and
    // "Mage" appears nowhere.
    await showParty(tester);
    await select(tester, 'Xzar');

    expect(
      find.text('Level 1 · Male · Elf · Necromancer · Neutral Good'),
      findsOneWidget,
    );
    expect(find.textContaining('Mage'), findsNothing);
  });

  group('the rest of the sheet', () {
    testWidgets('shows the saving throws the record screen printed', (
      tester,
    ) async {
      // Xzar's, read off BG:EE on 2026-08-08 as 14/11/13/15/12. The labels are
      // the game's own wording, so a player can put the two screens side by
      // side without translating.
      await showParty(tester);
      await select(tester, 'Xzar');

      for (final label in [
        'Paralysis / Poison / Death',
        'Rod / Staff / Wand',
        'Petrification / Polymorph',
        'Breath Weapon',
        'Spell',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '$label is missing');
      }
    });

    testWidgets('calls the thief skills what they are', (tester) async {
      // ⚠️ The one thing this group must not do is present a base as the
      // skill. Imoen stores Move Silently 15 and the game shows 35, so the
      // heading has to say so — it is the same trap that made 6/7 look wrong
      // beside the game's 8/9.
      await showParty(tester);
      await select(tester, 'Imoen');

      expect(
        find.text('Skills — points allocated, not what the game shows'),
        findsOneWidget,
      );
    });

    testWidgets('resistances are shown like every other group', (tester) async {
      // They used to fold away when all eleven were zero, which is every
      // character in every fixture. Two things were wrong with that.
      //
      // It was not a principle, it was a one-off: the same character's Skills
      // group shows **nine** zeroes and Combat six, and neither folds. And the
      // toggle was broken in exactly the case it existed for — `show` was
      // `_expanded || resists something`, so for a character who *did* resist
      // something the "Hide" button could never take effect. No fixture has a
      // non-zero resistance, so nothing caught it.
      //
      // The page being long is a real problem; tabbing it is the answer, not
      // one bespoke collapsible group.
      await showParty(tester);

      expect(find.text('Resistances'), findsOneWidget);
      expect(find.text('Fire'), findsOneWidget);
      expect(find.text('Missile'), findsOneWidget);
      expect(find.text('Show'), findsNothing);
      expect(find.text('Hide'), findsNothing);
    });

    testWidgets("names each proficiency from the player's own table", (
      tester,
    ) async {
      // ⚠️ **D11 on screen.** These names come from the installation's
      // weapprof.2da resolved through its talk table. IESDP's copy of that
      // file would have labelled this tile with a paragraph about temples.
      await showParty(tester);

      expect(find.text('Two-Weapon Style'), findsOneWidget);
      expect(find.text('Flail / Morning Star'), findsOneWidget);
    });

    testWidgets('shows only the proficiencies a character actually has', (
      tester,
    ) async {
      // Not a row per weapon in the game. A character with no effect for a
      // weapon cannot be given one without resizing the record, so offering
      // the field would be offering an edit this build cannot make.
      await showParty(tester);
      await select(tester, 'Xzar');

      // `DAGGER`, not `Dagger`: this row has no strref in the fixture, so the
      // label falls back to the table's own identifier. Ugly and honest, and
      // the step a machine with no talk table takes for every row.
      expect(find.text('DAGGER'), findsOneWidget);
      expect(find.text('Two-Weapon Style'), findsNothing);
      expect(find.text('Short Sword'), findsNothing);
    });

    testWidgets('a pip edit reaches the savegame and marks it dirty', (
      tester,
    ) async {
      // The second half of the owed in-game run, as far as a test can take
      // it: Aard's Two-Weapon Style from 2 to 3, which is a dword patched
      // inside an effect rather than a header byte.
      await showParty(tester);

      await tester.enterText(
        find.ancestor(
          of: find.text('Two-Weapon Style'),
          matching: find.byType(TextField),
        ),
        '3',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(AppBar, 'last •'),
        findsOneWidget,
        reason: 'the dot is how the shell says there is something to save',
      );
    });

    testWidgets('refuses a pip count above what the class allows', (
      tester,
    ) async {
      // A Fighter/Mage caps at 3 in Two-Weapon Style, and the ceiling is the
      // game's own table rather than a number invented here. Refuse rather
      // than clamp: quietly turning 5 into 3 is what makes an editor
      // untrustworthy.
      await showParty(tester);

      await tester.enterText(
        find.ancestor(
          of: find.text('Two-Weapon Style'),
          matching: find.byType(TextField),
        ),
        '5',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('0–3'), findsOneWidget);
      expect(
        find.widgetWithText(AppBar, 'last •'),
        findsNothing,
        reason: 'a refused value must not reach the savegame',
      );
    });
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
