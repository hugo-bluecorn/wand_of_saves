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

/// The Ledger spike's whole visual identity, in one place.
///
/// ## The seed is deliberately not the app's bronze
///
/// The application seeds from `0xFF8C6A3F`, a warm bronze, and the other two
/// spikes keep it. This one seeds from **`0xFF3D5A73`, a low-chroma steel
/// blue**, and the reason is structural rather than decorative.
///
/// `ColorScheme.fromSeed` tints *every* surface with the seed's hue. A bronze
/// seed therefore puts warmth into the ground the numbers sit on, and warm
/// greys read as paper — a document you are meant to look *at*. A ledger is a
/// thing you look *through*: the only saturated marks on screen should be the
/// three that carry meaning — the `tertiaryContainer` pill that says the engine
/// draws something else, the `secondaryContainer` pill that says a field is
/// derived, and the `error` bar that says the record holds an anomaly. Against
/// a warm ground those compete with the chrome; against a cool near-neutral one
/// they are the only chroma in the frame and cannot be missed.
///
/// The cost is stated too: the app shows BioWare's portraits, and a cool ground
/// will sit less comfortably behind them than bronze does. That is the trade
/// this spike is making, and it is a fair thing to reject it on.
///
/// ## `contrastLevel: 0.5`
///
/// M3 specs `outlineVariant` at **1.0:1** against its surface — a line that is,
/// by definition, invisible. Lifting the whole scheme fixes it at the source
/// instead of hand-picking colours per widget. Anything genuinely structural
/// here uses `outline` (3.0:1) regardless; see [ThemeData.dividerTheme].
///
/// ## Twelve component-theme slots, against the app's one
///
/// Every default this spike disagrees with is changed **once**, in a component
/// theme, rather than restated at each call site. The rule the widgets follow
/// is the corollary: no widget names a `ColorScheme` or `TextTheme` role for
/// something a component theme could carry. The roles that *are* read in widget
/// code — the two provenance pills, the anomaly bar, the pip dots — are read
/// because they are semantic choices, not defaults being repeated.
library;

import 'package:flutter/material.dart';

/// The Ledger spike's light and dark themes.
abstract final class LedgerTheme {
  /// A cool, low-chroma ground. See the library doc comment for why it is not
  /// the application's bronze.
  static const Color seed = Color(0xFF3D5A73);

  /// The light theme.
  static ThemeData get light => _themeFor(Brightness.light);

  /// The dark theme.
  static ThemeData get dark => _themeFor(Brightness.dark);
}

ThemeData _themeFor(Brightness brightness) {
  final colors = ColorScheme.fromSeed(
    seedColor: LedgerTheme.seed,
    brightness: brightness,
    // Lifts outlineVariant off its spec'd 1.0:1. See the library doc comment.
    contrastLevel: 0.5,
  );
  final base = ThemeData(colorScheme: colors);
  final text = _textThemeFrom(base.textTheme);

  return base.copyWith(
    textTheme: text,
    // `space: 1` rather than the default 16: a rule between two ledger rows is
    // a hairline, not a gap. `outline`, not `outlineVariant` — see the library
    // doc comment.
    dividerTheme: DividerThemeData(
      color: colors.outline,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarThemeData(
      toolbarHeight: 44,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      titleTextStyle: text.titleLarge,
      shape: Border(bottom: BorderSide(color: colors.outline)),
    ),
    // `scrollable: true` is set on the rail itself; everything else that makes
    // it usable at 76 px lives here.
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colors.surfaceContainerLow,
      elevation: 0,
      labelType: NavigationRailLabelType.all,
      minWidth: 76,
      useIndicator: true,
      indicatorColor: colors.secondaryContainer,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      selectedIconTheme: IconThemeData(size: 20, color: colors.onSurface),
      unselectedIconTheme: IconThemeData(
        size: 20,
        color: colors.onSurfaceVariant,
      ),
      selectedLabelTextStyle: text.labelSmall?.copyWith(
        color: colors.onSurface,
      ),
      unselectedLabelTextStyle: text.labelSmall?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      minTileHeight: 32,
      minVerticalPadding: 2,
      horizontalTitleGap: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      selectedTileColor: colors.secondaryContainer,
      selectedColor: colors.onSecondaryContainer,
    ),
    // Recovers roughly 8 px of height on every field. On a rail that shows one
    // field at a time that is small; the point is that the same theme serves a
    // dozen fields on a screen without any of them asking.
    inputDecorationTheme: InputDecorationThemeData(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(minHeight: 32),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
      labelStyle: text.bodySmall,
      helperStyle: text.bodySmall,
      helperMaxLines: 4,
    ),
    // A ledger that scrolls has to say where you are, so the thumb is always
    // visible rather than fading out after a second.
    scrollbarTheme: const ScrollbarThemeData(
      thumbVisibility: WidgetStatePropertyAll(true),
      thickness: WidgetStatePropertyAll<double>(8),
      radius: Radius.circular(4),
      interactive: true,
    ),
    // M3 exempts IconButton from VisualDensity and gives it a 48 px target,
    // which is a phone rule. `shrinkWrap` is the only way past it.
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        padding: const EdgeInsets.all(6),
        iconSize: 18,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    // ⚠️ The default `waitDuration` is `Duration.zero`. On a table with fifty
    // rows and an ⓘ on a dozen of them, that fires tooltips faster than a
    // person can read one. `showDuration` is long because a caveat is a
    // sentence, and `constraints` keeps it from stretching across a 1920 px
    // window as a single line.
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      showDuration: const Duration(seconds: 8),
      preferBelow: false,
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      textStyle: text.bodySmall?.copyWith(color: colors.onInverseSurface),
      decoration: BoxDecoration(
        color: colors.inverseSurface,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
    // ⚠️ `Card` resolves `shape` as a whole property, so a `shape` given here
    // without an explicit `side` silently erases the *only* thing that makes
    // `Card.outlined` outlined. Every empty paper-doll slot in this spike is
    // one of those, so the border is not optional.
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outline),
      ),
    ),
    // One `ButtonStyle` for all three, and deliberately *colourless*: it names
    // only geometry and type, so each button still resolves its own M3 colours.
    // A `styleFrom` per button would have had to restate them.
    filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(text)),
    textButtonTheme: TextButtonThemeData(style: _buttonStyle(text)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle(text)),
  );
}

/// The one shape every button in this spike takes: 32 px high, radius 6, and
/// our own `labelLarge` rather than M3's 14 px phone label.
ButtonStyle _buttonStyle(TextTheme text) {
  return ButtonStyle(
    textStyle: WidgetStatePropertyAll(text.labelLarge),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 14),
    ),
    minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),
  );
}

/// M3's body scale is the **phone** scale — `bodyLarge` is 16 px on 0.5
/// tracking — and it is why `Paralysis / Poison / Death` needed a 222 px tile
/// in the application. Every role below is retuned against the M3 token
/// database for a desktop instrument: smaller, tracking near zero, and figures
/// tabular so that a column of numbers reads as a column instead of as ragged
/// text that happens to be digits.
TextTheme _textThemeFrom(TextTheme base) {
  return base.copyWith(
    // Row labels. M3: 14 / 0.25.
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 13, letterSpacing: 0),
    // Every number on screen. M3: 16 / 0.5.
    bodyLarge: base.bodyLarge?.copyWith(
      fontSize: 14.5,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    // The arithmetic line, and the caveat in the rail. M3: 12 / 0.4.
    bodySmall: base.bodySmall?.copyWith(fontSize: 11.5, letterSpacing: 0.1),
    // Column headers, and the rail's destination labels. M3: 11 / 0.5.
    labelSmall: base.labelSmall?.copyWith(
      fontSize: 10.5,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
    ),
    // Buttons. M3: 14 / 0.1.
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 12.5,
      letterSpacing: 0.1,
      fontWeight: FontWeight.w500,
    ),
    // Block headings. M3: 14 / 0.1.
    titleSmall: base.titleSmall?.copyWith(
      fontSize: 12.5,
      letterSpacing: 0.4,
      fontWeight: FontWeight.w600,
    ),
    // The app bar and the character's name. M3: 22 / 0.
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w500,
    ),
  );
}
