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

/// The home screen: two sections in one column, and the one operation in this
/// app that removes something.
///
/// ⚠️ **A real router, not a bare `MaterialApp`.** The screen this replaced was
/// tested with `MaterialApp(home: …)`, which cannot execute a `context.go` at
/// all — so no test ever tapped a card, and the one card whose tap did nothing
/// was invisible to the suite for as long as it shipped. Every card's tap is
/// asserted here by the route it lands on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/ui/saves/home_screen.dart';

import '../../support/fakes.dart';

void main() {
  late FakeRecycleService recycler;

  Future<void> showHome(
    WidgetTester tester, {
    bool withSaves = true,
    bool withCharacters = true,
    bool hasDeleted = false,
  }) async {
    // Tall enough that a single column of cards needs no scrolling to be
    // tapped: `SingleChildScrollView` builds its children whether they are on
    // screen or not, so `find` would succeed where `tap` would not.
    tester.view
      ..physicalSize = const Size(1400, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    recycler = FakeRecycleService()..hasRecycled = hasDeleted;
    final container = ProviderContainer.test(
      overrides: [
        saveGameRepositoryProvider.overrideWithValue(
          FakeSaveGameRepository(
            slots: withSaves ? [fakeSlot('last'), fakeSlot('start')] : const [],
          ),
        ),
        characterFileRepositoryProvider.overrideWithValue(
          FakeCharacterFileRepository(
            // The helper's own defaults, which the assertions below name:
            // `Aard1.chr` holding a character called `Aard`, a Fighter/Mage at
            // 1/1. Passing them again would only restate them.
            files: withCharacters ? [fakeCharacterFile()] : const [],
          ),
        ),
        recycleServiceProvider.overrideWithValue(recycler),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'save/:slot',
              builder: (_, state) => Scaffold(
                body: Text('opened save ${state.pathParameters['slot']}'),
              ),
            ),
            GoRoute(
              path: 'character/:file',
              builder: (_, state) => Scaffold(
                body: Text('opened character ${state.pathParameters['file']}'),
              ),
            ),
            GoRoute(
              path: 'new-character',
              builder: (_, _) =>
                  const Scaffold(body: Text('opened the creation flow')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startSelecting(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
  }

  group('two sections, one column', () {
    testWidgets('both headings show, and characters come first', (
      tester,
    ) async {
      await showHome(tester);

      expect(
        tester.getTopLeft(find.text('Characters')).dy,
        lessThan(tester.getTopLeft(find.text('Saves')).dy),
      );
    });

    testWidgets('every card shares one left edge and one width', (
      tester,
    ) async {
      // ⚠️ **The single-column directive, asserted rather than assumed.** The
      // screen this came from laid both sections out as grids, so a card's left
      // edge and its width both moved with the window and with the card's index
      // in its row — and the two sections deliberately sized their cards
      // differently. One column means one x and one width for every card in
      // both sections, which is a property a set can state in one line.
      await showHome(tester);

      final cards = find.byType(Card);
      expect(
        cards,
        findsNWidgets(4),
        reason: 'one character, the ＋ card, and two saves',
      );

      final edges = <double>{};
      final widths = <double>{};
      for (var i = 0; i < 4; i++) {
        edges.add(tester.getTopLeft(cards.at(i)).dx);
        widths.add(tester.getSize(cards.at(i)).width);
      }

      expect(edges, hasLength(1));
      expect(widths, hasLength(1));
    });

    testWidgets('cards are stacked, not placed side by side', (tester) async {
      await showHome(tester);

      expect(
        tester.getTopLeft(find.text('start')).dy,
        greaterThan(tester.getTopLeft(find.text('last')).dy),
        reason: 'the second save sits below the first, not beside it',
      );
    });

    testWidgets('a heading stays when its section is empty', (tester) async {
      // ⚠️ A Characters heading that appears only once a character exists is a
      // feature nobody discovers — and the empty section is exactly where the
      // ＋ card has to be, since making one is how it stops being empty.
      await showHome(tester, withCharacters: false);

      expect(find.text('Characters'), findsOneWidget);
      expect(find.textContaining('No characters yet'), findsOneWidget);
      expect(find.text('New character'), findsOneWidget);
    });

    testWidgets('with nothing at all, still offers to make a character', (
      tester,
    ) async {
      // ⚠️ **This is a defect the app shipped**: with both lists empty the
      // whole screen was replaced by a "nothing found" message, and the ＋ card
      // lives *inside* the characters section — so emptying the app removed the
      // only way to fill it again.
      await showHome(tester, withSaves: false, withCharacters: false);

      expect(find.text('New character'), findsOneWidget);
      expect(find.textContaining('No characters yet'), findsOneWidget);
      expect(
        find.textContaining('No Baldur’s Gate saves found'),
        findsOneWidget,
      );
    });

    testWidgets('the ＋ card is last, after the characters', (tester) async {
      await showHome(tester);

      expect(
        tester.getTopLeft(find.text('New character')).dy,
        greaterThan(tester.getTopLeft(find.text('Aard')).dy),
      );
    });

    testWidgets('the ＋ card goes away during selection', (tester) async {
      // There is nothing to tick on a card that is not a document, and a tick
      // box on it would claim otherwise.
      await showHome(tester);
      await startSelecting(tester);

      expect(find.text('New character'), findsNothing);
    });
  });

  group('what a card says', () {
    testWidgets('a character card names the character and its file', (
      tester,
    ) async {
      // ⚠️ Two names, and they really do differ on disk: `Aard1.chr` holds a
      // character called `Aard`. A player with two exports of one character has
      // only the file name to tell them apart.
      await showHome(tester);

      expect(find.text('Aard'), findsOneWidget);
      expect(find.text('Aard1'), findsOneWidget);
    });

    testWidgets('a character card says the level and the class', (
      tester,
    ) async {
      // The fixture is a Fighter/Mage at 1/1, which is what makes the level
      // label interesting: a single number would not have caught `Level 1/1/1`
      // on a single-class thief.
      await showHome(tester);

      expect(find.textContaining('Level 1/1'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Fighter / Mage'), findsOneWidget);
    });

    testWidgets('a character card carries its identity as chips', (
      tester,
    ) async {
      await showHome(tester);

      expect(find.widgetWithText(Chip, 'Male'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Elf'), findsOneWidget);
    });

    testWidgets('a save card says its label, party, gold and area', (
      tester,
    ) async {
      // ⚠️ The nine-digit index the game prefixes is plumbing the player never
      // sees, so `000000022-last` shows as `last`.
      await showHome(tester);

      expect(find.text('last'), findsOneWidget);
      expect(find.text('start'), findsOneWidget);
      expect(find.textContaining('1 character'), findsWidgets);
      expect(find.textContaining('161 gold'), findsWidgets);
      expect(find.textContaining('AR2600'), findsWidgets);
    });

    testWidgets('a save with no screenshot says so, not that it broke', (
      tester,
    ) async {
      // ⚠️ **Found by the user asking "why are there missing images?"** Two of
      // their saves genuinely have no `BALDUR.bmp`, and the card drew an "image
      // not supported" icon — which announces a failure over a save that is
      // merely plain.
      await showHome(tester);

      expect(find.text('No screenshot'), findsWidgets);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });
  });

  group('opening a document', () {
    testWidgets('tapping a save card opens that save', (tester) async {
      // ⚠️ **The tap the spike left dead.** Its save card carried
      // `onTap: () {}` — a control that does nothing on the application's front
      // door — and no test could have caught it, because the suite never had a
      // router to land on.
      await showHome(tester);

      await tester.tap(find.text('last'));
      await tester.pumpAndSettle();

      expect(find.text('opened save 000000022-last'), findsOneWidget);
    });

    testWidgets('tapping a character card opens that character', (
      tester,
    ) async {
      await showHome(tester);

      await tester.tap(find.text('Aard'));
      await tester.pumpAndSettle();

      expect(find.text('opened character Aard1.chr'), findsOneWidget);
    });

    testWidgets('the ＋ card opens the creation flow', (tester) async {
      // ⚠️ **A route, not a pair of dialogs.** A character created by the two
      // dialogs this replaced was stuck as whatever `CHARBASE` is — no gender,
      // race, class or alignment could be chosen at all.
      await showHome(tester);

      await tester.tap(find.text('New character'));
      await tester.pumpAndSettle();

      expect(find.text('opened the creation flow'), findsOneWidget);
    });

    testWidgets('a tap ticks rather than opens while selecting', (
      tester,
    ) async {
      // Changing what a tap means is the whole hazard of a selection mode, so
      // the mode is explicit and nothing opens from inside it.
      await showHome(tester);
      await startSelecting(tester);

      await tester.tap(find.text('last'));
      await tester.pumpAndSettle();

      expect(find.text('opened save 000000022-last'), findsNothing);
      expect(find.text('1 selected'), findsOneWidget);
    });
  });

  group('deleting', () {
    testWidgets('no tick boxes until selection is turned on', (tester) async {
      await showHome(tester);

      expect(find.byType(Checkbox), findsNothing);

      await startSelecting(tester);

      expect(
        find.byType(Checkbox),
        findsNWidgets(3),
        reason: 'one character and two saves -- the ＋ card is not one',
      );
    });

    testWidgets('the bar counts what is ticked', (tester) async {
      await showHome(tester);
      await startSelecting(tester);

      expect(find.text('0 selected'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('one selection spans both sections', (tester) async {
      await showHome(tester);
      await startSelecting(tester);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('the confirm names what will move, and where', (tester) async {
      // ⚠️ A dialog that lists what it is about to move is a dialog you can
      // check. "Are you sure?" is one nobody reads.
      await showHome(tester);
      await startSelecting(tester);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('· Aard1.chr'), findsOneWidget);
      expect(find.textContaining('Nothing is erased'), findsOneWidget);
      expect(find.textContaining('move them back'), findsOneWidget);
    });

    testWidgets('confirming moves the selected documents', (tester) async {
      await showHome(tester);
      await startSelecting(tester);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(recycler.recycledCharacters, hasLength(1));
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('cancelling the dialog moves nothing', (tester) async {
      await showHome(tester);
      await startSelecting(tester);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(recycler.recycledCharacters, isEmpty);
      expect(recycler.recycledSaves, isEmpty);
    });

    testWidgets('leaving selection mode moves nothing', (tester) async {
      await showHome(tester);
      await startSelecting(tester);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(recycler.recycledSaves, isEmpty);
    });

    testWidgets('Delete cannot be pressed with nothing ticked', (tester) async {
      await showHome(tester);
      await startSelecting(tester);

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Delete'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('selecting is not offered with nothing to select', (
      tester,
    ) async {
      await showHome(tester, withSaves: false, withCharacters: false);

      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.delete_outline),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('emptying', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
    }

    testWidgets('is not offered when there is nothing to empty', (
      tester,
    ) async {
      // ⚠️ An irreversible command that does nothing is worse than an absent
      // one — and this greyed out over a *full* bin once, because the save root
      // was recognised by counting the slots inside it.
      await showHome(tester);
      await openMenu(tester);

      expect(
        tester
            .widget<MenuItemButton>(
              find.widgetWithText(MenuItemButton, 'Empty deleted items…'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('says plainly that it cannot be undone', (tester) async {
      // ⚠️ The only place in the app where that sentence is true.
      await showHome(tester, hasDeleted: true);
      await openMenu(tester);

      await tester.tap(find.text('Empty deleted items…'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(recycler.emptied, isFalse);
    });

    testWidgets('erases only after the confirm', (tester) async {
      await showHome(tester, hasDeleted: true);
      await openMenu(tester);
      await tester.tap(find.text('Empty deleted items…'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Erase for good'));
      await tester.pumpAndSettle();

      expect(recycler.emptied, isTrue);
    });
  });

  group('looking again', () {
    testWidgets('re-reads both directories', (tester) async {
      await showHome(tester);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      // Still there, and read a second time rather than served from the first.
      expect(find.text('Aard'), findsOneWidget);
      expect(find.text('last'), findsOneWidget);
    });
  });
}
