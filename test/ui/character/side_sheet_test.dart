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

/// The editing surface, and the three kinds of wrong it has to tell apart.
///
/// ⚠️ **What is asserted here is refusal and permission, not layout.** Every
/// case below turns on which of `impossible`, `beyondRules` and `available` a
/// value trips, because that distinction is D16 and getting it backwards either
/// writes a corrupt byte or locks the one field the rules check is complaining
/// about.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/ui/character/findings.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';
import 'package:wand_of_saves/ui/character/side_sheet.dart';
import 'package:wand_of_saves/ui/core/theme.dart';

void main() {
  late List<(String, String)> appliedFields;
  late List<(String, int)> appliedPips;
  late int closes;

  setUp(() {
    appliedFields = [];
    appliedPips = [];
    closes = 0;
  });

  SheetCharacter characterOf({
    List<SheetField> fields = const [],
    List<SheetProficiency> proficiencies = const [],
  }) => SheetCharacter(
    name: 'Aurel',
    fileName: 'aurel.chr',
    levelLine: 'Level 2/1',
    identity: const ['Male', 'Elf', 'Fighter / Mage', 'Neutral Good'],
    experienceLine: '4,000 experience',
    sections: [
      SheetSection('Combat', Icons.shield_outlined, [
        SheetGroup('To hit', fields),
      ]),
    ],
    proficiencies: proficiencies,
    creOffset: 0,
  );

  Future<void> openField(
    WidgetTester tester,
    SheetField field, {
    bool rulesBind = true,
  }) async {
    tester.view
      ..physicalSize = const Size(1000, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final character = characterOf(fields: [field]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SideSheet(
            subject: FieldSubject(indexOf(character).single),
            character: character,
            rulesBind: rulesBind,
            onApplyField: (entry, value) =>
                appliedFields.add((entry.field.label, value)),
            onApplyPips: (proficiency, pips) =>
                appliedPips.add((proficiency.name, pips)),
            onClose: () => closes++,
          ),
        ),
      ),
    );
  }

  Future<void> openProficiency(
    WidgetTester tester,
    SheetProficiency proficiency, {
    bool rulesBind = true,
  }) async {
    tester.view
      ..physicalSize = const Size(1000, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final character = characterOf(proficiencies: [proficiency]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SideSheet(
            subject: ProficiencySubject(proficiency),
            character: character,
            rulesBind: rulesBind,
            onApplyField: (entry, value) =>
                appliedFields.add((entry.field.label, value)),
            onApplyPips: (p, pips) => appliedPips.add((p.name, pips)),
            onClose: () => closes++,
          ),
        ),
      ),
    );
  }

  bool applyEnabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
          .onPressed !=
      null;

  // ⚠️ Not `find.byTooltip` — that finder matches the `Tooltip` widget, and
  // `tester.widget<IconButton>` on it throws a type error. `IconButton` is the
  // Tooltip's ancestor, so find the button by the icon it contains.
  bool stepEnabled(WidgetTester tester, IconData icon) =>
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, icon))
          .onPressed !=
      null;

  const thac0 = SheetField(
    'THAC0',
    '15',
    stat: CharacterStat.thac0,
    rulesMaximum: 20,
    gameMaximum: 25,
  );

  group('a value past the engine', () {
    testWidgets('is refused on the input and never written', (tester) async {
      await openField(tester, thac0);
      await tester.enterText(find.byType(TextField), '30');
      await tester.pump();

      expect(
        find.text('The game will not take a value above 25.'),
        findsOneWidget,
      );
      expect(applyEnabled(tester), isFalse);
      expect(appliedFields, isEmpty);
    });

    testWidgets('is refused with the rules check off as well', (tester) async {
      await openField(tester, thac0, rulesBind: false);
      await tester.enterText(find.byType(TextField), '30');
      await tester.pump();

      expect(
        find.text('The game will not take a value above 25.'),
        findsOneWidget,
      );
      expect(applyEnabled(tester), isFalse);
    });

    testWidgets('is not committed by pressing Enter either', (tester) async {
      await openField(tester, thac0);
      await tester.enterText(find.byType(TextField), '30');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(appliedFields, isEmpty);
      expect(closes, 0);
    });
  });

  group('a value beyond the rules', () {
    testWidgets('is refused while the rules bind', (tester) async {
      await openField(tester, thac0);
      await tester.enterText(find.byType(TextField), '22');
      await tester.pump();

      expect(
        find.textContaining('Beyond anything the rules produce'),
        findsOneWidget,
      );
      expect(applyEnabled(tester), isFalse);
      expect(appliedFields, isEmpty);
    });

    testWidgets('is written once the check is off', (tester) async {
      await openField(tester, thac0, rulesBind: false);
      await tester.enterText(find.byType(TextField), '22');
      await tester.pump();

      expect(
        find.textContaining('Beyond anything the rules produce'),
        findsNothing,
      );
      expect(applyEnabled(tester), isTrue);

      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pump();

      expect(appliedFields, [('THAC0', '22')]);
      expect(closes, 1);
    });

    testWidgets('a value inside the rules is written', (tester) async {
      await openField(tester, thac0);
      await tester.enterText(find.byType(TextField), '18');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pump();

      expect(appliedFields, [('THAC0', '18')]);
    });
  });

  group('a field the class cannot have', () {
    const anomalous = SheetField(
      'Pick pockets',
      '25',
      stat: CharacterStat.pickPockets,
      available: false,
      anomalous: true,
      unit: '%',
    );

    testWidgets('stays editable while the rules bind', (tester) async {
      await openField(tester, anomalous);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('conflict'), findsOneWidget);
      expect(
        find.textContaining('a value you cannot touch'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pump();

      expect(appliedFields, [('Pick pockets', '0')]);
    });

    testWidgets('is read-only when the record holds nothing', (tester) async {
      const absent = SheetField(
        'Set traps',
        '0',
        stat: CharacterStat.setTraps,
        available: false,
        unit: '%',
      );
      await openField(tester, absent);

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('not for this class'), findsOneWidget);
      expect(
        find.textContaining('Turn the rules check off'),
        findsOneWidget,
      );
      expect(applyEnabled(tester), isFalse);
    });

    testWidgets('becomes editable once the check is off', (tester) async {
      const absent = SheetField(
        'Set traps',
        '0',
        stat: CharacterStat.setTraps,
        available: false,
        unit: '%',
      );
      await openField(tester, absent, rulesBind: false);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('beyond the class'), findsOneWidget);
      expect(applyEnabled(tester), isTrue);
    });
  });

  testWidgets('a value the engine owns cannot be written at all', (
    tester,
  ) async {
    const owned = SheetField(
      'Gold',
      '120',
      stat: CharacterStat.gold,
      editable: false,
      source: FieldSource.derived,
    );
    await openField(tester, owned, rulesBind: false);

    expect(find.byType(TextField), findsNothing);
    expect(find.text('read-only'), findsOneWidget);
    expect(applyEnabled(tester), isFalse);
  });

  testWidgets('the arithmetic is on screen and the caveat is behind an ⓘ', (
    tester,
  ) async {
    const explained = SheetField(
      'Maximum hit points',
      '12',
      stat: CharacterStat.maximumHitPoints,
      inGame: '18',
      arithmetic: 'stored 12, +6 from Constitution 18 over 1.5 levels',
      caveat: 'The engine adds the Constitution bonus at display time.',
    );
    await openField(tester, explained);

    expect(
      find.text('stored 12, +6 from Constitution 18 over 1.5 levels'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(
      find.text('The engine adds the Constitution bonus at display time.'),
      findsNothing,
    );
  });

  testWidgets('changing the subject reloads the draft', (tester) async {
    await openField(tester, thac0);
    await tester.enterText(find.byType(TextField), '19');
    await tester.pump();

    const luck = SheetField('Luck', '7', stat: CharacterStat.luck);
    await openField(tester, luck);

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '7',
    );
    expect(appliedFields, isEmpty);
  });

  testWidgets('Discard closes without writing anything', (tester) async {
    await openField(tester, thac0);
    await tester.enterText(find.byType(TextField), '19');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pump();

    expect(appliedFields, isEmpty);
    expect(closes, 1);
  });

  group('a field whose bytes are a code', () {
    // `Attacks per round`: 0-5 are whole attacks, 6-10 are halves, so a stored
    // 10 draws as 9/2. The real projection fills all eleven.
    const attacks = SheetField(
      'Attacks per round',
      '10',
      stat: CharacterStat.numberOfAttacks,
      inGame: '9/2',
      valueMeanings: {
        0: '0',
        1: '1',
        2: '2',
        3: '3',
        4: '4',
        5: '5',
        6: '1/2',
        7: '3/2',
        8: '5/2',
        9: '7/2',
        10: '9/2',
      },
    );

    testWidgets('offers every value with what the game draws for it', (
      tester,
    ) async {
      // ⚠️ **The encoding runs one way and the player needs it the other.**
      // Reported as "can we have a side number, because I would like to set
      // attacks to 2 or 3" — from `9/2` there is no way to reach the `2` that
      // means two attacks a round.
      await openField(tester, attacks);
      await tester.pumpAndSettle();

      expect(find.text('What each value means'), findsOneWidget);
      // Where the value and its meaning are the same number, no arrow.
      expect(find.widgetWithText(ChoiceChip, '2'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '8 → 5/2'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '10 → 9/2'), findsOneWidget);
    });

    testWidgets('picking two attacks a round writes the byte that means it', (
      tester,
    ) async {
      await openField(tester, attacks);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, '2'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      // ⚠️ **The stored byte, not the displayed value.** Nothing converts a
      // drawn `2` back into a byte; the choice only names the number.
      expect(appliedFields, [('Attacks per round', '2')]);
    });

    testWidgets('an ordinary field offers no such list', (tester) async {
      await openField(
        tester,
        const SheetField('Luck', '7', stat: CharacterStat.luck),
      );
      await tester.pumpAndSettle();

      expect(find.text('What each value means'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });

  group('proficiency pips', () {
    testWidgets('cannot be raised at the ceiling while the rules bind', (
      tester,
    ) async {
      await openProficiency(
        tester,
        const SheetProficiency(89, 'Long Sword', 2, 2, effectOffset: 100),
      );

      expect(stepEnabled(tester, Icons.add), isFalse);
      expect(stepEnabled(tester, Icons.remove), isTrue);
    });

    testWidgets('can be raised past the ceiling with the check off', (
      tester,
    ) async {
      await openProficiency(
        tester,
        const SheetProficiency(89, 'Long Sword', 2, 2, effectOffset: 100),
        rulesBind: false,
      );

      expect(stepEnabled(tester, Icons.add), isTrue);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pump();

      expect(find.textContaining('Above the ceiling of 2.'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pump();

      expect(appliedPips, [('Long Sword', 3)]);
      expect(closes, 1);
    });

    testWidgets('a surplus the record already holds can be taken away', (
      tester,
    ) async {
      await openProficiency(
        tester,
        const SheetProficiency(89, 'Long Sword', 4, 2, effectOffset: 100),
      );

      expect(find.textContaining('Above the ceiling of 2.'), findsOneWidget);
      expect(stepEnabled(tester, Icons.add), isFalse);
      expect(stepEnabled(tester, Icons.remove), isTrue);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.remove));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pump();

      expect(appliedPips, [('Long Sword', 3)]);
    });

    testWidgets('raising one below the ceiling is written', (tester) async {
      await openProficiency(
        tester,
        const SheetProficiency(90, 'Flail / Morning Star', 1, 3),
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pump();

      expect(appliedPips, [('Flail / Morning Star', 2)]);
    });
  });
}
