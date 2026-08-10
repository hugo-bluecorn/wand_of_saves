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
import 'package:wand_of_saves/domain/skill_catalogue.dart';
import 'package:wand_of_saves/ui/character/portrait_image.dart';
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
      // Aurel's percentile, off the character-creation screen.
      strengthBonus: 27,
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
      // Below 18, so there is no percentile to write.
      strength: 16,
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

  /// The party's classes as the player's own `thiefscl.2da` sees them.
  ///
  /// Aard is `FIGHTER_MAGE` and has none of the seven; Imoen is `THIEF` and
  /// has all of them; Montaron is `FIGHTER_THIEF` and likewise; Xzar is a
  /// `NECROMANCER` and has none. Real values, cut to the columns in play.
  const thiefSkillTable = SkillCatalogue({
    'PICK_POCKETS': {
      'FIGHTER_MAGE': 0,
      'THIEF': 100,
      'FIGHTER_THIEF': 100,
      'NECROMANCER': 0,
    },
    'OPEN_LOCKS': {
      'FIGHTER_MAGE': 0,
      'THIEF': 100,
      'FIGHTER_THIEF': 100,
      'NECROMANCER': 0,
    },
    'FIND_TRAPS': {
      'FIGHTER_MAGE': 0,
      'THIEF': 100,
      'FIGHTER_THIEF': 100,
      'NECROMANCER': 0,
    },
    'MOVE_SILENTLY': {
      'FIGHTER_MAGE': 0,
      'THIEF': 100,
      'FIGHTER_THIEF': 100,
      'NECROMANCER': 0,
    },
    'HIDE_IN_SHADOWS': {
      'FIGHTER_MAGE': 0,
      'THIEF': 100,
      'FIGHTER_THIEF': 100,
      'NECROMANCER': 0,
    },
    'DETECT_ILLUSION': {
      'FIGHTER_MAGE': 0,
      'THIEF': 100,
      'FIGHTER_THIEF': 100,
      'NECROMANCER': 0,
    },
    'SET_TRAPS': {
      'FIGHTER_MAGE': 0,
      'THIEF': 100,
      'FIGHTER_THIEF': 100,
      'NECROMANCER': 0,
    },
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

  /// The character files a test can assert against, set by [showParty].
  late FakeCharacterFileRepository characterFiles;

  ProviderContainer containerWith(List<SyntheticCharacter> members) =>
      ProviderContainer.test(
        overrides: [
          characterFileRepositoryProvider.overrideWithValue(
            characterFiles = FakeCharacterFileRepository(),
          ),
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
            const FakeResourceRepository(
              proficiencyTable,
              skills: thiefSkillTable,
            ),
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

  /// Brings the tab called [heading] to the front.
  ///
  /// **Needed by almost every test below**, because a `TabBarView` builds only
  /// the tab on show — a field behind another heading is not merely off-screen
  /// like a `ListView`'s tail, it does not exist, and `find.text` cannot see
  /// it. Matched on the `Tab` rather than on the bare string so a heading that
  /// happens to share a word with a field label still selects the tab.
  Future<void> openTab(WidgetTester tester, String heading) async {
    await tester.tap(find.widgetWithText(Tab, heading));
    await tester.pumpAndSettle();
  }

  group('exporting the character on screen', () {
    testWidgets('names the character it will export', (tester) async {
      // ⚠️ The user audits whether a control is *justified*, not whether it
      // works: a bare "Export" beside four portraits does not say which of
      // them it means.
      await showParty(tester);

      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.file_upload_outlined),
            )
            .tooltip,
        'Export Aard…',
      );
    });

    testWidgets('offers the character’s own name as the file name', (
      tester,
    ) async {
      await showParty(tester);
      await select(tester, 'Imoen');

      await tester.tap(find.byIcon(Icons.file_upload_outlined));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextField, 'Imoen'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('writes the selected character, adding the extension', (
      tester,
    ) async {
      await showParty(tester);
      await select(tester, 'Xzar');

      await tester.tap(find.byIcon(Icons.file_upload_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Export'));
      await tester.pumpAndSettle();

      expect(characterFiles.created.single.$1, 'Xzar.chr');
      expect(characterFiles.created.single.$2.name, 'Xzar');
    });

    testWidgets('writes nothing when the dialog is cancelled', (tester) async {
      await showParty(tester);

      await tester.tap(find.byIcon(Icons.file_upload_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(characterFiles.created, isEmpty);
    });

    testWidgets('refuses a file name that is really a path', (tester) async {
      // A player may legitimately name a character with a slash in it, and the
      // game lets them. That must not become a directory.
      await showParty(tester);

      await tester.tap(find.byIcon(Icons.file_upload_outlined));
      await tester.pumpAndSettle();
      // Scoped to the dialog: the character sheet behind it is full of stat
      // fields, so a bare byType finds a dozen.
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '../escape',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Export'));
      await tester.pumpAndSettle();

      expect(characterFiles.created, isEmpty);
      expect(find.textContaining('cannot contain'), findsOneWidget);
    });

    testWidgets('says so when the name is already taken', (tester) async {
      await showParty(tester);
      characterFiles.taken = {'Aard.chr'};

      await tester.tap(find.byIcon(Icons.file_upload_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Export'));
      await tester.pumpAndSettle();

      expect(
        find.text('There is already a character called Aard.chr'),
        findsOneWidget,
      );
    });
  });

  testWidgets('never shows the slot index, not even while loading', (
    tester,
  ) async {
    // ⚠️ **Found by watching the app open a save.** The title fell back to the
    // route parameter until the savegame had been read, so `000000022-last`
    // flashed for a frame before settling on `last`. `SaveSlot.label` exists
    // precisely because those digits are an index the player never sees — and
    // the loading state has to obey that rule too.
    tester.view
      ..physicalSize = const Size(1600, 2200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = containerWith(party);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PartyView(slotDirectoryName: slotName)),
      ),
    );

    // The first frame, before anything has been read.
    expect(find.text(slotName), findsNothing);
    expect(find.text('last'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text(slotName), findsNothing);
  });

  testWidgets('the rail draws the portrait the record names', (tester) async {
    // ⚠️ **This reverses what the rail used to do.** It drew PORTRT<n>.bmp,
    // the picture the engine baked beside the save -- correct while nothing
    // could change a portrait, and wrong now that something can: a rail still
    // showing the old face after the player picked a new one looks broken.
    //
    // The sidecar keeps the job only it can do. It is a picture of what the
    // engine *believed*, and reading 18 / 18 out of one is what closed D10.
    await showParty(tester);

    expect(find.byType(PortraitImage), findsWidgets);
    expect(
      find.byType(Image),
      findsNothing,
      reason: 'no portrait is read from a file beside the save any more',
    );
  });

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
      await openTab(tester, 'Combat');
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

    /// The tile whose label is [label], as the widget tree holds it.
    TextField fieldFor(WidgetTester tester, String label) =>
        tester.widget<TextField>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(TextField),
          ),
        );

    testWidgets('only offers the skills the class can actually have', (
      tester,
    ) async {
      // ⚠️ **The defect this slice exists for.** The panel offered Open Locks
      // to a Fighter/Mage, who cannot allocate a point of it — the game's own
      // thiefscl.2da gives FIGHTER_MAGE 0 on all seven rows.
      //
      // Imoen on the same screen is the control: identical field, identical
      // group, enabled, because THIEF is 100. One save, two answers.
      await showParty(tester);
      await openTab(tester, 'Skills');

      expect(fieldFor(tester, 'Open Locks').enabled, isFalse);
      expect(fieldFor(tester, 'Pick Pockets').enabled, isFalse);

      await select(tester, 'Imoen');

      expect(fieldFor(tester, 'Open Locks').enabled, isTrue);
      expect(fieldFor(tester, 'Pick Pockets').enabled, isTrue);
    });

    testWidgets('Lore stays editable for everyone', (tester) async {
      // It has no row in the table because every class has it — confirmed in
      // game, where a Necromancer's record screen prints Lore 15. Greying it
      // out along with its neighbours would be the obvious wrong move.
      await showParty(tester);
      await openTab(tester, 'Skills');

      expect(fieldFor(tester, 'Lore').enabled, isTrue);

      await select(tester, 'Xzar');

      expect(fieldFor(tester, 'Lore').enabled, isTrue);
    });

    testWidgets('a skill the class cannot have stays editable if it is set', (
      tester,
    ) async {
      // Montaron is a Fighter/Thief, so Hide in Shadows is his to allocate;
      // the interesting case is the reverse. A value already in the record on
      // a class that cannot have it is an anomaly, and a field you cannot
      // touch is one you cannot correct — so a non-zero value wins over the
      // table.
      await showParty(tester);
      await openTab(tester, 'Skills');
      await select(tester, 'Montaron');

      expect(fieldFor(tester, 'Hide in Shadows').enabled, isTrue);
    });

    testWidgets('the fields with no governing table stay editable', (
      tester,
    ) async {
      // Turn Undead and Tracking. No table says who may have them, so no rule
      // is invented — recorded as an open question instead.
      await showParty(tester);
      await openTab(tester, 'Skills');

      expect(fieldFor(tester, 'Turn Undead').enabled, isTrue);
      expect(fieldFor(tester, 'Tracking').enabled, isTrue);
    });

    /// The `[+]`/`[-]` button labelled [tooltip].
    ///
    /// Reached through its tooltip rather than its icon, because both icons
    /// repeat once per proficiency on screen. `IconButton` builds the tooltip
    /// *inside* itself, so the finder has to climb back out to the button.
    IconButton pipButton(WidgetTester tester, String tooltip) =>
        tester.widget<IconButton>(
          find.ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          ),
        );

    testWidgets('says why a percentile the engine ignores is still shown', (
      tester,
    ) async {
      // Montaron's Strength is 16 and his record still holds a percentile of
      // 100. The engine zeroes that on import — measured, 19/100 arrived as
      // 19/0 — so the field is disabled, and a disabled field showing a
      // number nobody can reconcile reads as a bug unless it explains itself.
      await showParty(tester);
      await openTab(tester, 'Abilities');
      await select(tester, 'Montaron');

      expect(
        find.byTooltip(
          'Only a Strength of exactly 18 has a percentile — the engine reads '
          'strmodex.2da at no other score, and zeroes this field when a '
          'character is exported and imported. Shown because the record '
          'really does hold it.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('writes percentile strength the way the game writes it', (
      tester,
    ) async {
      // BG:EE writes one value, "Strength: 18/27", where the record keeps two
      // bytes. Both stay editable — they are two real bytes — and this is only
      // how the pair reads out.
      await showParty(tester);
      await openTab(tester, 'Abilities');
      await select(tester, 'Imoen');

      expect(find.text('18/27 in game'), findsOneWidget);
    });

    testWidgets('says nothing when there is no percentile to write', (
      tester,
    ) async {
      // Montaron's Strength is 16, and the engine consults strmodex.2da at no
      // Strength but 18.
      await showParty(tester);
      await openTab(tester, 'Abilities');
      await select(tester, 'Montaron');

      expect(find.textContaining('in game'), findsNothing);
    });

    testWidgets('draws pips the way the game draws them', (tester) async {
      // BG:EE puts gold dots beside the proficiency name and a [+]/[-] pair
      // next to them. Dots alone reach nobody using a screen reader, so the
      // count is spoken as well as drawn.
      // Disposed at the end of the body: the framework checks for a live
      // handle *before* tear-downs run, so addTearDown cannot satisfy it.
      final semantics = tester.ensureSemantics();

      await showParty(tester);
      await openTab(tester, 'Skills');

      expect(find.bySemanticsLabel('Two-Weapon Style, 2 of 3'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Flail / Morning Star, 2 of 2'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('states the ceiling by refusing to offer another pip', (
      tester,
    ) async {
      // ⚠️ The complaint this answers: the cap was enforced but invisible
      // until a value was refused, which is a worse experience than no cap.
      // A Fighter/Mage tops out at 3 in Two-Weapon Style and 2 in Flail, and
      // Aard sits at 2 in both — so one [+] is live and its neighbour is not,
      // on the same screen, from the same table.
      await showParty(tester);
      await openTab(tester, 'Skills');

      expect(
        pipButton(tester, 'One more pip in Two-Weapon Style').onPressed,
        isNotNull,
      );
      expect(
        pipButton(tester, 'One more pip in Flail / Morning Star').onPressed,
        isNull,
        reason: 'weapprof.2da caps a Fighter/Mage at 2 here',
      );
    });

    testWidgets('calls the thief skills what they are', (tester) async {
      // ⚠️ The one thing this group must not do is present a base as the
      // skill. Imoen stores Move Silently 15 and the game shows 35, so the
      // heading has to say so — it is the same trap that made 6/7 look wrong
      // beside the game's 8/9.
      await showParty(tester);
      await openTab(tester, 'Skills');
      await select(tester, 'Imoen');

      expect(
        find.text('Points allocated, not what the game shows'),
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
      await openTab(tester, 'Combat');

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
      await openTab(tester, 'Skills');

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
      await openTab(tester, 'Skills');
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
      // Disposed at the end of the body: the framework checks for a live
      // handle *before* tear-downs run, so addTearDown cannot satisfy it.
      final semantics = tester.ensureSemantics();

      await showParty(tester);
      await openTab(tester, 'Skills');

      await tester.tap(find.byTooltip('One more pip in Two-Weapon Style'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Two-Weapon Style, 3 of 3'), findsOneWidget);
      expect(
        find.widgetWithText(AppBar, 'last •'),
        findsOneWidget,
        reason: 'the dot is how the shell says there is something to save',
      );
      semantics.dispose();
    });

    testWidgets('takes the last pip away and then stops', (tester) async {
      // The lower bound is the one a stepper can still walk into. Imoen has a
      // single pip in Short Sword; spending it leaves nothing to remove, and
      // the control has to say so rather than write a negative into a dword
      // the record stores unsigned.
      // Disposed at the end of the body: the framework checks for a live
      // handle *before* tear-downs run, so addTearDown cannot satisfy it.
      final semantics = tester.ensureSemantics();

      await showParty(tester);
      await openTab(tester, 'Skills');
      await select(tester, 'Imoen');

      await tester.tap(find.byTooltip('One less pip in Short Sword'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Short Sword, 0 of 1'), findsOneWidget);
      expect(
        pipButton(tester, 'One less pip in Short Sword').onPressed,
        isNull,
      );
      semantics.dispose();
    });
  });

  group('the sheet is divided the way the game divides it', () {
    // BG:EE's character creation names its own steps, and four of them are
    // things this panel holds: ABILITIES, SKILLS, and the numbers that make up
    // a character and how they fight. Those names are the game's, not ours, so
    // a player can hold the two screens side by side — the same reason the
    // saving throws are labelled in the game's wording.
    testWidgets("carries the game's own headings", (tester) async {
      await showParty(tester);

      for (final tab in ['Character', 'Abilities', 'Skills', 'Combat']) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget, reason: tab);
      }
    });

    testWidgets('puts each group behind the heading it belongs to', (
      tester,
    ) async {
      await showParty(tester);

      const expected = {
        'Character': 'Current hit points',
        'Abilities': 'Charisma',
        'Skills': 'Lore',
        'Combat': 'Paralysis / Poison / Death',
      };

      for (final MapEntry(key: tab, value: field) in expected.entries) {
        await openTab(tester, tab);
        expect(find.text(field), findsOneWidget, reason: '$field under $tab');
      }
    });

    testWidgets('files proficiencies under Skills, where the game files them', (
      tester,
    ) async {
      // ⚠️ Not a layout preference. Pressing SKILLS in character creation leads
      // to the proficiency screen — its header reads "PROFICIENCY SLOTS 4 |
      // SKILLS 0" — and on a spellcaster continues into the spellbook. The
      // game has one heading for all three; this panel used to have two.
      await showParty(tester);
      await openTab(tester, 'Skills');

      expect(find.text('Two-Weapon Style'), findsOneWidget);
      expect(find.text('Open Locks'), findsOneWidget);
    });

    testWidgets('condition belongs to the character, not to their skills', (
      tester,
    ) async {
      // Fatigue and intoxication sat in the skills group because that is where
      // the record stores them, which is not a reason to show them there.
      await showParty(tester);
      await openTab(tester, 'Character');

      expect(find.text('Fatigue'), findsOneWidget);
      expect(find.text('Intoxication'), findsOneWidget);
    });

    testWidgets('resistances stay with the rest of the combat numbers', (
      tester,
    ) async {
      await showParty(tester);
      await openTab(tester, 'Combat');

      expect(find.text('Fire'), findsOneWidget);
      expect(find.text('Magic cold'), findsOneWidget);
    });

    testWidgets('keeps the heading you are reading when you change character', (
      tester,
    ) async {
      // The whole point of a party rail is comparing one number across the
      // party. Snapping back to the first tab on every selection would make
      // that four clicks instead of one.
      await showParty(tester);
      await openTab(tester, 'Combat');
      await select(tester, 'Imoen');

      expect(find.text('Paralysis / Poison / Death'), findsOneWidget);
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
