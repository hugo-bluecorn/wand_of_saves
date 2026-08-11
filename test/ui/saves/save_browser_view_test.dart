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

/// The home screen: two sections, and the one operation in this app that
/// removes something.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/ui/saves/save_browser_view.dart';

import '../../support/fakes.dart';

void main() {
  late FakeRecycleService recycler;

  Future<void> showBrowser(
    WidgetTester tester, {
    bool withSaves = true,
    bool withCharacters = true,
    bool hasDeleted = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1400, 1200)
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
            files: withCharacters
                ? [fakeCharacterFile(fileName: 'aurel.chr', name: 'Aurel')]
                : const [],
          ),
        ),
        recycleServiceProvider.overrideWithValue(recycler),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SaveBrowserView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startSelecting(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
  }

  group('two sections', () {
    testWidgets('both headings show, and characters come first', (
      tester,
    ) async {
      await showBrowser(tester);

      final characters = tester.getTopLeft(find.text('Characters')).dy;
      final saves = tester.getTopLeft(find.text('Saves')).dy;

      expect(characters, lessThan(saves));
    });

    testWidgets('a heading stays when its section is empty', (tester) async {
      // ⚠️ A Characters heading that appears only once a character exists is a
      // feature nobody discovers — and the empty section is exactly where the
      // ＋ card has to be, since making one is how it stops being empty.
      await showBrowser(tester, withCharacters: false);

      expect(find.text('Characters'), findsOneWidget);
      expect(find.textContaining('No characters yet'), findsOneWidget);
      expect(find.text('New character'), findsOneWidget);
    });

    testWidgets('the ＋ card is last, after the characters', (tester) async {
      await showBrowser(tester);

      expect(
        tester.getTopLeft(find.text('New character')).dx,
        greaterThan(tester.getTopLeft(find.text('Aurel')).dx),
      );
    });

    testWidgets('the ＋ card goes away during selection', (tester) async {
      // There is nothing to tick on a card that is not a document, and a
      // tick box on it would claim otherwise.
      await showBrowser(tester);
      await startSelecting(tester);

      expect(find.text('New character'), findsNothing);
    });

    testWidgets('with nothing at all, still offers to make a character', (
      tester,
    ) async {
      // ⚠️ **This test used to assert the opposite**, and what it pinned was a
      // defect: with both lists empty the whole screen was replaced by a
      // "nothing found" message, and the ＋ card is *inside* the characters
      // section — so emptying the app removed the only way to fill it again.
      // Reported from the running app after deleting every save and character.
      //
      // The good empty state was already written and was being shadowed: each
      // section says its own piece, and the saves one already carries the only
      // advice the replaced message had.
      await showBrowser(tester, withSaves: false, withCharacters: false);

      expect(find.text('New character'), findsOneWidget);
      expect(find.textContaining('No characters yet'), findsOneWidget);
      expect(
        find.textContaining('No Baldur’s Gate saves found'),
        findsOneWidget,
      );
    });
  });

  group('a save with no screenshot', () {
    testWidgets('says so, rather than looking broken', (tester) async {
      // ⚠️ **Found by the user asking "why are there missing images?"** Two of
      // their saves genuinely have no `BALDUR.bmp` — hand-made copies that took
      // the savegame and left the picture — and the card drew an "image not
      // supported" icon, which announces a failure. A save without a screenshot
      // is ordinary; the card now says which of the two it is.
      await showBrowser(tester);

      expect(find.text('No screenshot'), findsWidgets);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });
  });

  group('deleting', () {
    testWidgets('no tick boxes until selection is turned on', (tester) async {
      // Outside selection a card behaves exactly as it always did; changing
      // what a tap means without saying so is the hazard of a selection mode.
      await showBrowser(tester);

      expect(find.byType(Checkbox), findsNothing);

      await startSelecting(tester);

      expect(
        find.byType(Checkbox),
        findsNWidgets(3),
        reason: 'one character and two saves -- the ＋ card is not one',
      );
    });

    testWidgets('the bar counts what is ticked', (tester) async {
      await showBrowser(tester);
      await startSelecting(tester);

      expect(find.text('0 selected'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('one selection spans both sections', (tester) async {
      await showBrowser(tester);
      await startSelecting(tester);

      // The first box is the character's, the rest are saves'.
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('the confirm names what will move, and where', (tester) async {
      // ⚠️ A dialog that lists three saves by label is a dialog you can check.
      // "Are you sure?" is one nobody reads.
      await showBrowser(tester);
      await startSelecting(tester);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('· aurel.chr'), findsOneWidget);
      expect(find.textContaining('Nothing is erased'), findsOneWidget);
      expect(find.textContaining('move them back'), findsOneWidget);
    });

    testWidgets('confirming moves the selected documents', (tester) async {
      await showBrowser(tester);
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
      await showBrowser(tester);
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
      await showBrowser(tester);
      await startSelecting(tester);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(recycler.recycledSaves, isEmpty);
    });

    testWidgets('Delete cannot be pressed with nothing ticked', (tester) async {
      await showBrowser(tester);
      await startSelecting(tester);

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Delete'))
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
      // An irreversible command that does nothing is worse than an absent one.
      await showBrowser(tester);
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
      await showBrowser(tester, hasDeleted: true);
      await openMenu(tester);

      await tester.tap(find.text('Empty deleted items…'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(recycler.emptied, isFalse);
    });

    testWidgets('erases only after the confirm', (tester) async {
      await showBrowser(tester, hasDeleted: true);
      await openMenu(tester);
      await tester.tap(find.text('Empty deleted items…'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Erase for good'));
      await tester.pumpAndSettle();

      expect(recycler.emptied, isTrue);
    });
  });
}
