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

import 'package:flutter/material.dart';
import 'package:ui_spikes/workbench/palette.dart';
import 'package:ui_spikes/workbench/palette_finish.dart';

/// The Workbench spike's theme: four palettes, a surface ladder, a desktop
/// type scale and eighteen component slots.
///
/// **Why the bronze seed is the same as the other spikes.** The loudest
/// content this application will ever draw is BioWare's own portrait art, so
/// the chrome stays quiet; and holding the hue constant across the three
/// spikes means the choice between them is about **structure**, not about
/// which one picked a prettier colour. The identity comes from the ladder,
/// the type scale and the components.
///
/// `contrastLevel: 0.5` is set on the bronze scheme because `outlineVariant`
/// is spec'd `ContrastCurve(1, 1, 3, 4.5)` — 1.0:1 against its surface at the
/// default level, which is not a line anyone can see. Structural lines here
/// use [ColorScheme.outline] (3.0:1) regardless. The three written-out
/// palettes take neither problem: they specify `outlineVariant` as the same
/// ink as `outline`, so the framework default cannot reach the screen at all.
///
/// ## The surface ladder, and the rule it exists to state
///
/// > *Every step of the ladder must move the **same direction** in both
/// > brightnesses, and no surface may share a token with the surface it sits
/// > on.*
///
/// | role | light (tone) | dark (tone) |
/// |---|---|---|
/// | page | `surfaceContainer` (94) | `surface` (6) |
/// | card | `surface` (98) | `surfaceContainerLow` (10) |
/// | floating | `surfaceContainerLowest` (100) | `surfaceContainer` (12) |
/// | field fill | `surfaceContainerHigh` (92) | `surfaceContainerHigh` (17) |
///
/// *Floating* is the drawer, the search view, the search bar and the menu.
///
/// Light runs 94 → 98 → 100 ascending, with the fill at 92 below all three.
/// Dark runs 6 → 10 → 12 ascending, with the fill at 17 above all three.
/// Every nesting is legible either way.
///
/// The obvious-looking choice fails the first clause:
/// `surfaceContainerLowest` is the **brightest** token in light (tone 100)
/// and the **darkest** in dark (tone 4), so a floating sheet painted with it
/// is in front in one theme and behind in the other. The current application
/// already carries the second clause's failure — its `_NoScreenshot` and
/// `_NoPortrait` placeholders paint `surfaceContainerHighest`, which is also
/// the container colour of the filled card they sit inside, so the "nothing
/// here" states are invisible in exactly the place they are needed. Both are
/// the same defect, and the ladder is that defect's fix stated once.
///
/// Beyond those four there is **no fifth surface**. An inset region inside a
/// card carries no fill at all — it is separated by an [ColorScheme.outline]
/// hairline or a left rule. Meaning-bearing fills use *role* colours
/// (`tertiaryContainer`, `errorContainer`), never another surface tone.
///
/// ⚠️ **Under the two flat palettes the ladder collapses to one rung, and none
/// of the four expressions below changes to do it.** Every surface token in
/// those schemes is the ground, so `page`, `card`, `floating` and `fill` all
/// resolve to it and separation comes entirely from the rule. The invariant is
/// not abandoned, it is restated: *no surface may sit on another without a rule
/// between them* — which every container this spike paints already carries,
/// because the theme puts a `side` on all of them. See [_deStijlDay] for why
/// that is the interesting part of the exercise rather than a shortcut.
///
/// **Which makes three answers to one question, and the fourth palette gives
/// the third.** Bronze tints four rungs and lets tone do the separating; De
/// Stijl and Pop keep one rung and let the rule do it; [_starfleetNight] keeps
/// four rungs **and** rules every one of them, because a console is a set of
/// discrete panels — each lit to its own level *and* seamed against its
/// neighbour. The rung differences there are deliberately small (1.14:1 from
/// the hull to a panel) and are not asked to carry meaning on their own; the
/// lit edge is.
abstract final class WorkbenchTheme {
  /// The bronze seed, shared with the other two spikes on purpose.
  static const Color seed = Color(0xFF8C6A3F);

  /// The light theme in [palette].
  static ThemeData light(WorkbenchPalette palette) =>
      _themeFor(palette, Brightness.light);

  /// The dark theme in [palette].
  static ThemeData dark(WorkbenchPalette palette) =>
      _themeFor(palette, Brightness.dark);
}

ThemeData _themeFor(WorkbenchPalette palette, Brightness brightness) {
  final light = brightness == Brightness.light;
  final colors = switch (palette) {
    WorkbenchPalette.bronze => ColorScheme.fromSeed(
      seedColor: WorkbenchTheme.seed,
      brightness: brightness,
      contrastLevel: 0.5,
    ),
    WorkbenchPalette.deStijl => light ? _deStijlDay : _deStijlNight,
    WorkbenchPalette.pop => light ? _popDay : _popNight,
    WorkbenchPalette.starfleet => light ? _starfleetDay : _starfleetNight,
  };

  // Geometry is part of a palette, not a separate decision. Neither a De Stijl
  // canvas nor a comic panel has a rounded corner or a drop shadow, and both
  // draw a band where this spike draws a hairline; a console panel has a
  // fillet and is flush-mounted, so it takes the corner and refuses the shadow.
  // ⚠️ What the three alternates share is only that none of them *floats*.
  final alternate = palette != WorkbenchPalette.bronze;
  // The contour: what bounds a card, a field, a chip, a sheet.
  final stroke = switch (palette) {
    WorkbenchPalette.bronze => 1.0,
    WorkbenchPalette.deStijl => 2.0,
    WorkbenchPalette.pop => 3.0,
    // A seam between two panels, lit along its length. Heavier than a hairline
    // because in this palette the edge is a *component* — it is what the light
    // is on — and lighter than a band because the surfaces differ as well.
    WorkbenchPalette.starfleet => 1.5,
  };
  // The interior rule: what separates one value row from the next. ⚠️ Not the
  // same decision, and the two artists answer it differently. A Composition's
  // bands are one weight throughout, so De Stijl's rule *is* its contour; a
  // comic's panel border is heavier than anything drawn inside it, so Pop's
  // contour is three and its rule is two. Six dividers at the contour weight
  // in one card would have been a fence rather than a table.
  final rule = switch (palette) {
    WorkbenchPalette.bronze => 1.0,
    WorkbenchPalette.deStijl => 2.0,
    WorkbenchPalette.pop => 2.0,
    // An etched line between two rows of legends, not a seam between two
    // parts. It is the one place this palette draws something *lighter* than
    // its contour, because the panel is one piece and the rows are printed on
    // it.
    WorkbenchPalette.starfleet => 1.0,
  };
  // ⚠️ The finish also travels to the widgets that hold a radius of their own
  // — the tag's 8, the ability tile's 12 — which the colour scheme cannot
  // reach. See [PaletteFinish].
  final finish = PaletteFinish(
    corner: switch (palette) {
      WorkbenchPalette.bronze || WorkbenchPalette.starfleet => 1,
      WorkbenchPalette.deStijl || WorkbenchPalette.pop => 0,
    },
    // 6, and the same 6 for a card as for a chip. See [PaletteFinish.cornerMax]
    // for why a ceiling rather than a factor, and [_starfleetNight] for why the
    // number is small: an elbow bracket is the wrong show.
    cornerMax: switch (palette) {
      WorkbenchPalette.starfleet => 6,
      WorkbenchPalette.bronze ||
      WorkbenchPalette.deStijl ||
      WorkbenchPalette.pop => null,
    },
    screenInk: switch (palette) {
      WorkbenchPalette.pop => light ? _popScreen : _popNightScreen,
      WorkbenchPalette.bronze ||
      WorkbenchPalette.deStijl ||
      WorkbenchPalette.starfleet => null,
    },
    unlitInk: switch (palette) {
      WorkbenchPalette.starfleet => light ? _snwDayUnlit : _snwVoid,
      WorkbenchPalette.bronze ||
      WorkbenchPalette.deStijl ||
      WorkbenchPalette.pop => null,
    },
  );
  double corner(double soft) => finish.cornerOf(soft);
  double lift(double raised) => alternate ? 0 : raised;

  // The four rungs. Nothing in this spike paints a surface that is not one of
  // these, and no rung shares a token with the rung it sits on — except under
  // the two flat palettes, where all four are the ground and the rules
  // separate them instead.
  final page = light ? colors.surfaceContainer : colors.surface;
  final card = light ? colors.surface : colors.surfaceContainerLow;
  final floating = light
      ? colors.surfaceContainerLowest
      : colors.surfaceContainer;
  final fill = colors.surfaceContainerHigh;

  final line = BorderSide(color: colors.outline, width: stroke);
  final text = _textThemeFor(colors);

  // ⚠️ Flutter draws a disabled control's label at **0.38 opacity** over a
  // plate of the same ink at 0.12, which on these light grounds measures
  // 2.25:1 (De Stijl) and 2.55:1 (Pop) — below the 3:1 gate for graphics, let
  // alone the 4.5:1 for text, and unfixable by choice of ink because the ink
  // is what is being diluted. At boot this spike shows three of them at once:
  // Undo, Redo and Save. Every alternate keeps the plate and replaces the
  // diluted label with an opaque one, which takes the four painted cases to
  // 5.42:1, 5.95:1, 6.29:1 and 5.58:1. Bronze is left alone, being the control.
  //
  // A palette that already owns a colour for *unlit* uses it here rather than
  // blending one: a disabled button and an unavailable tile are the same claim
  // about the same console, and drawing them differently would have been the
  // theme disagreeing with itself. 9.26:1 and 4.56:1.
  final disabledPlate =
      finish.unlitInk ??
      Color.alphaBlend(
        colors.onSurface.withValues(alpha: 0.12),
        colors.surface,
      );
  final disabledInk = alternate ? colors.onSurfaceVariant : null;

  return ThemeData(
    colorScheme: colors,
    textTheme: text,
    scaffoldBackgroundColor: page,
    // `visualDensity` is deliberately not set: on Linux `ThemeData` already
    // resolves it to `compact`, and naming it again only invites drift.

    // The two decisions a `ColorScheme` cannot carry: the corner scale, and
    // whether "unavailable" is a screen, an unlit plate or a fade. Pop supplies
    // the screen and Starfleet the plate; supplying neither is what leaves
    // `ScreenTone` the bronze behaviour unchanged.
    extensions: [finish],

    // 1 — cards. ⚠️ The side is the whole point. `Card` resolves `shape` as a
    // whole property, so a shape without a side erases the outlined card's
    // only border. Setting it here means every card in the spike carries a
    // 3.0:1 hairline rather than the 1.0:1 `outlineVariant` default — and
    // under a flat palette it is the *only* thing separating the card from the
    // page behind it.
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corner(16)),
        side: line,
      ),
    ),

    // 2 — the command bar. A rounded rectangle, deliberately not the stadium:
    // this is a command bar, not a pill.
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll<double>(0),
      backgroundColor: WidgetStatePropertyAll<Color>(floating),
      side: WidgetStatePropertyAll<BorderSide>(line),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(corner(14))),
      ),
      // ⚠️ `SearchBar` applies this padding twice, outer and inner, so it is
      // half of what the eye is being aimed at.
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 10),
      ),
      constraints: const BoxConstraints(
        minWidth: 360,
        maxWidth: 720,
        minHeight: 52,
      ),
      textStyle: WidgetStatePropertyAll<TextStyle?>(text.titleMedium),
      hintStyle: WidgetStatePropertyAll<TextStyle?>(
        text.titleMedium?.copyWith(color: colors.onSurfaceVariant),
      ),
    ),

    // 3 — the palette itself. Sized so it opens exactly as wide as the bar and
    // drops straight down from it.
    searchViewTheme: SearchViewThemeData(
      backgroundColor: floating,
      elevation: lift(4),
      side: line,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corner(16)),
      ),
      headerHeight: 60,
      headerTextStyle: text.titleMedium,
      headerHintStyle: text.titleMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
      dividerColor: colors.outline,
      constraints: const BoxConstraints(
        minWidth: 620,
        maxWidth: 720,
        minHeight: 360,
        maxHeight: 620,
      ),
    ),

    // 4 — the app bar's overflow menu.
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(floating),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        elevation: WidgetStatePropertyAll<double>(lift(3)),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(vertical: 6),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(corner(12)),
            side: line,
          ),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        textStyle: text.bodyMedium,
        minimumSize: const Size(0, 40),
      ),
    ),

    // 5 — chips carry identity, so they are outlines rather than fills.
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      side: line,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corner(8)),
      ),
      labelStyle: text.labelMedium,
      labelPadding: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      elevation: 0,
      pressElevation: 0,
    ),

    // 6 — the side sheet. ⚠️ `endShape`, not `shape`: `Drawer` never reads
    // `shape` for an end drawer.
    drawerTheme: DrawerThemeData(
      backgroundColor: floating,
      width: 420,
      elevation: lift(1),
      endShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(corner(16)),
        ),
        side: line,
      ),
      scrimColor: colors.scrim.withValues(alpha: 0.4),
    ),

    // 7 — fields. Fixes the default 32 px of vertical padding and the 48 px
    // height floor, both of which are phone numbers.
    inputDecorationTheme: InputDecorationThemeData(
      isDense: true,
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(minHeight: 40),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(corner(10)),
        borderSide: line,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(corner(10)),
        borderSide: line,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(corner(10)),
        borderSide: BorderSide(color: colors.primary, width: stroke + 1),
      ),
    ),

    // 8 — the ⓘ caveats. The default wait is `Duration.zero`, which makes a
    // tooltip fire at anything the pointer crosses.
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      showDuration: const Duration(seconds: 6),
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.inverseSurface,
        borderRadius: BorderRadius.circular(corner(8)),
      ),
      textStyle: text.bodySmall?.copyWith(color: colors.onInverseSurface),
    ),

    // 9 — `IconButton` is exempt from visual density and would stay 48 px.
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        padding: const EdgeInsets.all(6),
        iconSize: 20,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        disabledForegroundColor: disabledInk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(corner(8)),
        ),
      ),
    ),

    // 10 — so is `Checkbox`.
    checkboxTheme: CheckboxThemeData(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: colors.outline, width: 1.5),
    ),

    // 11 — one hairline colour, used everywhere a rule is drawn. Under a
    // banded palette it is not a hairline: `space` follows `thickness` so a
    // two- or three-pixel band still occupies exactly its own height.
    dividerTheme: DividerThemeData(
      color: colors.outline,
      thickness: rule,
      space: rule,
    ),

    // 12 — the app bar sits on the page rung and is separated by a line, not
    // by a tint or a shadow.
    appBarTheme: AppBarThemeData(
      backgroundColor: page,
      foregroundColor: colors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 60,
      titleTextStyle: text.titleLarge,
      shape: Border(
        bottom: BorderSide(color: colors.outline, width: stroke),
      ),
    ),

    // 13–15 — buttons, at a desktop height rather than a thumb's.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: text.labelLarge,
        disabledForegroundColor: disabledInk,
        disabledBackgroundColor: alternate ? disabledPlate : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(corner(10)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: text.labelLarge,
        disabledForegroundColor: disabledInk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(corner(10)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: text.labelLarge,
        side: line,
        disabledForegroundColor: disabledInk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(corner(10)),
        ),
      ),
    ),

    // 16 — rows in the palette and the pickers.
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corner(10)),
      ),
      minVerticalPadding: 10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    ),

    // 17 — a desktop scrollbar is always visible, because a long document
    // that hides its own length is a document you cannot judge.
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll<bool>(true),
      thickness: const WidgetStatePropertyAll<double>(8),
      radius: Radius.circular(corner(4)),
    ),

    // 18 — icons are chrome, so they sit at the variant weight by default.
    iconTheme: IconThemeData(size: 20, color: colors.onSurfaceVariant),
  );
}

/// The M3 phone scale retuned for a desktop window: smaller, tighter, and with
/// a line height that lets a wrapping caveat read as a paragraph.
TextTheme _textThemeFor(ColorScheme colors) {
  const body = TextStyle(height: 1.35);
  return TextTheme(
    displaySmall: const TextStyle(fontSize: 30, fontWeight: FontWeight.w300),
    headlineSmall: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.2,
    ),
    titleLarge: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
    titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    titleSmall: const TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    bodyLarge: body.copyWith(fontSize: 14.5, letterSpacing: 0.1),
    bodyMedium: body.copyWith(fontSize: 13.5, letterSpacing: 0.1),
    bodySmall: body.copyWith(fontSize: 12.5, letterSpacing: 0.15),
    labelLarge: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
    labelMedium: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
    labelSmall: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    ),
    // Without this every unstyled slot falls back to `black87`, which in the
    // dark theme is unreadable and in the light theme is not `onSurface`.
  ).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface);
}

// ---------------------------------------------------------------------------
// De Stijl
// ---------------------------------------------------------------------------

/// The canvas. Warm, because his grounds are — a linen white, never `#FFFFFF`.
const Color _dsCanvas = Color(0xFFF4F1E8);

/// The grid line, and also the letter: in this palette they are one ink.
const Color _dsInk = Color(0xFF1A1A1A);

/// The blue block. 8.41:1 on the canvas, and 8.41:1 the other way round, so
/// one value serves as the ink *and* as the plate a label sits on.
const Color _dsBlue = Color(0xFF003DA5);

/// The red block, **darkened**. See [_deStijlDay].
const Color _dsRed = Color(0xFFD02419);

/// The yellow block. Only ever a block.
const Color _dsYellow = Color(0xFFFFD100);

/// The yellow's hue at the darkest tone that can carry text. See [_deStijlDay].
const Color _dsOchre = Color(0xFF806A00);

/// The one grey the system admits, for the second rank of text. Grey is not a
/// concession — Mondrian and Van Doesburg both painted grey blocks.
const Color _dsGrey = Color(0xFF55524A);

/// The white block, which is a different colour from the canvas and is meant
/// to be. Used where the spike wants a plate rather than a ground.
const Color _white = Color(0xFFFFFFFF);

/// The invented night ground: the canvas' own warmth, inverted.
const Color _dsNight = Color(0xFF181713);

/// The blue, raised until it clears the night ground. 5.42:1.
const Color _dsNightBlue = Color(0xFF5C8CE6);

/// The red, raised until it clears the night ground. 4.91:1.
const Color _dsNightRed = Color(0xFFF04A3E);

/// The night's second-rank grey, tinted toward the linen. 8.20:1.
const Color _dsNightGrey = Color(0xFFB4AFA3);

/// De Stijl, light: three unrelated hues at full chroma, a black grid, and a
/// warm ground that is nearly all of the screen.
///
/// **Why this is written out rather than seeded.** `ColorScheme.fromSeed`
/// defaults to `SchemeTonalSpot`, which keeps only the seed's *hue* and then
/// fixes chroma per role — primary 36, secondary 16, tertiary 24 at hue + 60°,
/// neutral 6. De Stijl is three **unrelated** hues at full chroma plus black
/// and white, which is structurally not a tonal scheme: no seed produces it,
/// and `fromSeed(...).copyWith(...)` would have to override every role that
/// matters and would still leave the surfaces, the containers and the fixed
/// roles tinted by a hue this palette does not contain. The raw constructor
/// was chosen for a second reason too — its fallbacks are plain aliases
/// (`surfaceContainer` falls back to `surface`, not to a tonal step), which is
/// exactly what lets the ladder collapse by omission below.
///
/// **The mapping is onto function, not decoration.** This spike had already
/// given these roles meaning, so the vocabulary lands on them without being
/// pushed: the black grid is [ColorScheme.outline] because Mondrian's
/// structure *is* the black line and this spike separates surfaces by rule;
/// blue is `primary` because it is the accent, the action and the selection;
/// yellow is `tertiaryContainer` because that is the `in game` chip — the
/// engine's own number; and red is `error`, which was free, because red
/// already means error in Material 3.
///
/// **⚠️ Yellow cannot carry text, so it is only ever a block.** `#FFD100` on
/// this canvas measures **1.29:1**. As `tertiaryContainer` with the ink on it
/// (11.91:1) it is perfect and it is the loudest thing on the screen. But the
/// spike also uses `tertiary` as a *foreground* — the notice dot on a finding
/// card, and the "3 things to look at" line on the lineup — so `tertiary`
/// cannot be that yellow. It is the same hue (49°, measured to match) driven
/// down to the darkest tone that clears 4.5:1: `#806A00`, **4.67:1**. That
/// tone is an ochre and **there is no ochre in De Stijl**. It is the palette's
/// second concession to legibility, and it is needed only in the light theme:
/// on the night ground the painted yellow measures 12.28:1 and is used
/// unaltered.
///
/// **⚠️ Red is an alarm here, not a field.** In a Composition red is often
/// the largest and calmest area on the canvas; in this application `error`
/// means *the record holds something the rules do not allow*. So red appears
/// on conflicts and nowhere else — never as a decorative block — which costs
/// the palette its most characteristic gesture and is nevertheless correct.
/// It is also **darkened**: `#DA291C` measures 4.31:1 on the canvas, under the
/// gate in *both* directions, so neither the ink nor a label on it would pass.
/// `#D02419` reaches **4.71:1** and does both jobs, so this palette has one
/// red rather than two.
///
/// **⚠️ Ground dominant, structure black, colour rare.** A Composition works
/// because colour is a small fraction of a mostly-white canvas held together
/// by heavy black bands. Fifty-three fields at full chroma would be
/// unusable, so what is inherited is the *discipline* and not the look: the
/// canvas is nearly everything, the black band does all the separating, and a
/// hue appears only where a role already carries meaning. That is also just
/// good practice for a dense screen.
///
/// **⚠️ The surface ladder collapses, and that is the most interesting thing
/// here.** Every surface token is omitted, so each falls back to `surface` and
/// the four rungs — page, card, floating, field fill — all resolve to the
/// canvas. Nothing is layered by tone any more; a card is a card because it is
/// inside a two-pixel black rectangle. The theme needed no branch to do it,
/// which is the evidence that the ladder was a property of the *scheme* and
/// not of the components.
const ColorScheme _deStijlDay = ColorScheme(
  brightness: Brightness.light,
  primary: _dsBlue,
  onPrimary: _dsCanvas,
  // ⚠️ The portrait placeholder gradients `primaryContainer` into
  // `tertiaryContainer` and letters it in `onPrimaryContainer`, so one end of
  // that ramp is pinned to the yellow. The letter must therefore be dark at
  // both ends, which forces the other end light. A white block running into a
  // yellow one, lettered in the grid ink, is both the legible answer and two
  // of his own blocks meeting.
  primaryContainer: _white,
  onPrimaryContainer: _dsInk,
  secondary: _dsInk,
  onSecondary: _dsCanvas,
  secondaryContainer: _dsCanvas,
  onSecondaryContainer: _dsInk,
  tertiary: _dsOchre,
  onTertiary: _dsCanvas,
  tertiaryContainer: _dsYellow,
  onTertiaryContainer: _dsInk,
  error: _dsRed,
  onError: _dsCanvas,
  errorContainer: _dsRed,
  onErrorContainer: _dsCanvas,
  surface: _dsCanvas,
  onSurface: _dsInk,
  onSurfaceVariant: _dsGrey,
  outline: _dsInk,
  outlineVariant: _dsInk,
  inverseSurface: _dsInk,
  onInverseSurface: _dsCanvas,
  inversePrimary: _dsNightBlue,
  surfaceTint: _dsCanvas,
  shadow: _dsInk,
  scrim: _dsInk,
);

/// De Stijl, dark — **and this one is an invention, not a translation.**
///
/// De Stijl is a white-ground, black-line system. Mondrian never painted its
/// inversion and there is no source to be faithful to, so the honest thing is
/// to say that this was designed rather than derived, and to say what the
/// design is:
///
/// * the ground and the line **swap ranks**. The night ground keeps the
///   canvas' warmth rather than going neutral black, and the grid is drawn in
///   the canvas colour itself — so the two inks of the light palette are the
///   same two inks here, with their jobs exchanged;
/// * the three hues keep their **identity** and change their **tone**, each
///   raised only as far as its gate requires: blue to 5.42:1, red to 4.91:1;
/// * the yellow does not move. On this ground `#FFD100` measures **12.28:1**,
///   so the one hue that could never be a foreground in the light palette is
///   one here, and `tertiary` is the painted yellow rather than an ochre. The
///   constraint inverted along with the ground;
/// * every block letters itself in the **ground colour**, which is the exact
///   inversion of the light palette, where blue and red take the canvas and
///   only yellow takes the ink.
///
/// ⚠️ `primaryContainer` stays light in both brightnesses, alone among the
/// roles. It is the portrait plate, standing in for BioWare's art — and
/// artwork does not invert when the chrome does.
const ColorScheme _deStijlNight = ColorScheme(
  brightness: Brightness.dark,
  primary: _dsNightBlue,
  onPrimary: _dsNight,
  primaryContainer: _white,
  onPrimaryContainer: _dsInk,
  secondary: _dsCanvas,
  onSecondary: _dsNight,
  secondaryContainer: _dsNight,
  onSecondaryContainer: _dsCanvas,
  tertiary: _dsYellow,
  onTertiary: _dsNight,
  tertiaryContainer: _dsYellow,
  onTertiaryContainer: _dsNight,
  error: _dsNightRed,
  onError: _dsNight,
  errorContainer: _dsNightRed,
  onErrorContainer: _dsNight,
  surface: _dsNight,
  onSurface: _dsCanvas,
  onSurfaceVariant: _dsNightGrey,
  outline: _dsCanvas,
  outlineVariant: _dsCanvas,
  inverseSurface: _dsCanvas,
  onInverseSurface: _dsNight,
  inversePrimary: _dsBlue,
  surfaceTint: _dsNight,
  shadow: _dsInk,
  scrim: _dsInk,
);

// ---------------------------------------------------------------------------
// Pop
// ---------------------------------------------------------------------------

/// Newsprint. Cooler and lighter than the linen canvas, and still not white.
const Color _popGround = Color(0xFFFBF7EC);

/// The contour. Pure black, because a printed line is not a painted one.
const Color _popInk = Color(0xFF000000);

/// Process blue. 6.42:1 on newsprint, both directions.
const Color _popBlue = Color(0xFF0057B8);

/// The printed red, as a **block only**: black letters on it read 4.79:1.
const Color _popRed = Color(0xFFED1C24);

/// The printed red as **ink**, one step down. See [_popDay] for why one red
/// cannot be both.
const Color _popRedInk = Color(0xFFE01920);

/// Process yellow — greener and brighter than the painted one, and therefore
/// even less able to carry text: 1.09:1.
const Color _popYellow = Color(0xFFFFF200);

/// The yellow's hue at the darkest tone that can carry text. 4.66:1.
const Color _popOlive = Color(0xFF787200);

/// Second-rank text. 8.28:1 on newsprint.
const Color _popGrey = Color(0xFF4A4A4A);

/// The Ben-Day ink. Fixed from both sides — see [PaletteFinish].
const Color _popScreen = Color(0xFF8A8A8A);

/// The invented night ground: press black.
const Color _popNightGround = Color(0xFF121212);

/// The blue, raised to 6.64:1 on the night ground.
const Color _popNightBlue = Color(0xFF4D9BFF);

/// The red, raised to 5.28:1 on the night ground.
const Color _popNightRed = Color(0xFFFF3B30);

/// The night's second-rank text. 7.70:1.
const Color _popNightGrey = Color(0xFFA6A6A6);

/// The Ben-Day ink for the night ground: 3.26:1 against it, with white text
/// over a dot at 5.74:1.
const Color _popNightScreen = Color(0xFF666666);

/// Pop, light: the same three colours, **printed** instead of painted.
///
/// Everything said about [_deStijlDay] applies — written out rather than
/// seeded, ground dominant, red alarm-only, the ladder collapsed to one rung —
/// and three things differ, all of them consequences of ink on paper rather
/// than paint on canvas.
///
/// **The contour is pure black and three pixels wide.** Lichtenstein's line is
/// a printed contour, not a painted band, and it is heavier relative to the
/// forms it holds than Mondrian's is. This is the only palette where `stroke`
/// is 3.
///
/// **⚠️ Two reds, because one is impossible.** A red that black lettering can
/// sit on needs a relative luminance of at least 0.175; a red that can be read
/// *as* lettering on newsprint needs at most 0.168. No colour satisfies both,
/// which is a fact about the gate and not about the palette. So the printed
/// `#ED1C24` is the block — black on it reads **4.79:1**, and black is what a
/// comic letters in anyway — and `#E01920`, one step down, is the ink at
/// **4.53:1**. De Stijl's darker red needed no such split.
///
/// **⚠️ The yellow is worse, not better.** Process yellow is greener and
/// brighter than the painted one: `#FFF200` on newsprint measures **1.09:1**,
/// against the painted yellow's 1.29:1. As a block with black on it that is a
/// virtue (17.95:1, the brightest pairing in either palette); as a foreground
/// it is hopeless, and `tertiary` is the same hue at 4.66:1.
///
/// **And it is the one palette that answers "unavailable" with a screen.**
/// See [PaletteFinish]. That is Lichtenstein's contribution, and it is
/// deliberately not shared with De Stijl: a halftone is an artefact of
/// *printing*, and grafting it onto a painted palette would have made the two
/// alternates the same idea in two colourways.
const ColorScheme _popDay = ColorScheme(
  brightness: Brightness.light,
  primary: _popBlue,
  onPrimary: _popGround,
  primaryContainer: _white,
  onPrimaryContainer: _popInk,
  secondary: _popInk,
  onSecondary: _popGround,
  secondaryContainer: _popGround,
  onSecondaryContainer: _popInk,
  tertiary: _popOlive,
  onTertiary: _popGround,
  tertiaryContainer: _popYellow,
  onTertiaryContainer: _popInk,
  error: _popRedInk,
  onError: _popGround,
  errorContainer: _popRed,
  onErrorContainer: _popInk,
  surface: _popGround,
  onSurface: _popInk,
  onSurfaceVariant: _popGrey,
  outline: _popInk,
  outlineVariant: _popInk,
  inverseSurface: _popInk,
  onInverseSurface: _popGround,
  inversePrimary: _popNightBlue,
  surfaceTint: _popGround,
  shadow: _popInk,
  scrim: _popInk,
);

/// Pop, dark — **also an invention.** There is no dark newsprint; a comic is
/// ink on paper and the paper is the light.
///
/// It follows the same three rules the De Stijl night follows — ground and
/// contour swap, hues keep identity and change tone, every block letters
/// itself in the ground — with one addition of its own: the **screen inverts
/// too**, from a grey lighter than the ground to one darker than the text, so
/// that "screened back" still reads as texture rather than as a stain.
const ColorScheme _popNight = ColorScheme(
  brightness: Brightness.dark,
  primary: _popNightBlue,
  onPrimary: _popNightGround,
  primaryContainer: _white,
  onPrimaryContainer: _popInk,
  secondary: _white,
  onSecondary: _popNightGround,
  secondaryContainer: _popNightGround,
  onSecondaryContainer: _white,
  tertiary: _popYellow,
  onTertiary: _popNightGround,
  tertiaryContainer: _popYellow,
  onTertiaryContainer: _popNightGround,
  error: _popNightRed,
  onError: _popNightGround,
  errorContainer: _popNightRed,
  onErrorContainer: _popNightGround,
  surface: _popNightGround,
  onSurface: _white,
  onSurfaceVariant: _popNightGrey,
  outline: _white,
  outlineVariant: _white,
  inverseSurface: _white,
  onInverseSurface: _popNightGround,
  inversePrimary: _popBlue,
  surfaceTint: _popNightGround,
  shadow: _popInk,
  scrim: _popInk,
);

// ---------------------------------------------------------------------------
// Starfleet — *Star Trek: Strange New Worlds*
//
// ⚠️ Night first. The other two palettes are written day first because their
// day is the source; this one is a dark-ground system, so the order is the
// mirror too. Read [_starfleetNight] before [_starfleetDay].
// ---------------------------------------------------------------------------

/// The hull, and most of the screen. Deep blue-black with a little warmth in
/// it: a bridge is dark, and it is never a black void.
const Color _snwHull = Color(0xFF0C1218);

/// A panel, sitting off the hull and lit from within.
const Color _snwPanel = Color(0xFF16202A);

/// A panel in front of the panels — the side sheet, the command palette, a
/// menu.
const Color _snwRaised = Color(0xFF1C2833);

/// The recess a field is cut into. The brightest rung, so the place you type is
/// the place the light is.
const Color _snwInset = Color(0xFF22303C);

/// Brushed pewter, with the light along its edge. 3.24:1 against the brightest
/// rung and 4.53:1 against the hull, so a seam is a seam wherever it lands.
const Color _snwEdge = Color(0xFF628096);

/// A legend, silk-screened on the panel. 10.65:1 at its worst.
const Color _snwLegend = Color(0xFFDCE6EC);

/// The second rank of legend, at **full strength** — 6.17:1 at its worst. This
/// palette has no diluted ink anywhere; where something is quieter it is
/// because it is a different colour, not because it is a thinner one.
const Color _snwLegendDim = Color(0xFF9FB2BF);

/// **Command gold.** 6.32:1 at its worst as a legend; as a lamp it carries its
/// own legend at 8.82:1. Both brightnesses use it as the lamp.
const Color _snwGold = Color(0xFFE0A83C);

/// **Science blue.** 5.23:1 as a legend, 7.30:1 carrying one. Both
/// brightnesses use it as the lamp — it is the `in game` chip.
const Color _snwBlue = Color(0xFF5AA9DC);

/// **Operations red, as a legend** — and lifted well off the uniform's brick to
/// get there. 4.61:1. See [_starfleetNight] for what that cost.
const Color _snwRed = Color(0xFFFF6355);

/// The alert plate: operations red as a *lamp*, which is a different colour
/// from operations red as a legend for the same reason Pop needed two of them.
/// A near-white legend on it reads 4.71:1.
const Color _snwAlert = Color(0xFFB03B31);

/// Nothing behind it. The unlit lens, the plate under a dead control, and the
/// scrim — one colour, because they are one idea.
const Color _snwVoid = Color(0xFF04060A);

/// The brightest panel — whatever is in front of the others — and the ink the
/// three deep day colours letter themselves in.
const Color _snwDayLifted = Color(0xFFFAFCFD);

/// A panel under the work lights.
const Color _snwDayPanel = Color(0xFFEDF1F4);

/// The deck the panels are set into.
const Color _snwDayGround = Color(0xFFDCE3E8);

/// The recess a field is cut into — **below** all three panels in this
/// brightness, where at night it was above them. See [_starfleetDay].
const Color _snwDayInset = Color(0xFFCFD8DE);

/// The seam, unlit: the shadow a machined edge casts instead of the light it
/// carries at night. 4.89:1, well past the 3:1 it was asked for.
const Color _snwDayGroove = Color(0xFF465B6C);

/// A legend cut into daylit metal. 12.38:1 at its worst.
const Color _snwDayInk = Color(0xFF101820);

/// The second rank of legend, in daylight. 6.56:1 at its worst.
const Color _snwDayInkDim = Color(0xFF364855);

/// Command gold with the backlight off — an amber the depth of the metal
/// rather than the depth of the light. 4.61:1.
const Color _snwDayGold = Color(0xFF7E5400);

/// Science blue, likewise. 4.58:1.
const Color _snwDayBlue = Color(0xFF0F6290);

/// Operations red, likewise. 4.78:1.
const Color _snwDayRed = Color(0xFFA13429);

/// Bare metal with no light behind it. 1.83:1 against the panel it dims, which
/// is as far as the gates allow — see [PaletteFinish.unlitInk].
const Color _snwDayUnlit = Color(0xFFADB5BA);

/// Starfleet, night — Pike's bridge, and **this is the source, not the
/// invention**.
///
/// ## ⚠️ It is not LCARS, and the difference is eighty years
///
/// The rounded elbow bracket, the black ground and the peach-lavender-salmon
/// set are *The Next Generation*, 1987, and in-universe they postdate this
/// bridge by about eighty years. *Strange New Worlds* is deliberately
/// **pre**-LCARS — a retro-futurist upgrade of the 1966 set — and everything
/// here follows from that: brushed pewter structure rather than black voids,
/// warm backlighting rather than emissive flat colour, deep blue-teal display
/// surfaces rather than pure black, and physical jewel-like controls. If a
/// corner here starts to look like a bracket, it has drifted into the wrong
/// show; the ceiling in [PaletteFinish.cornerMax] is what holds it.
///
/// **And it is not sci-fi chrome either.** No glow, no bloom, no chamfers, no
/// sweeps, no hex grids. Those are this palette's scanlines — the thing that
/// makes a screenshot *look* like the reference while telling a reader nothing.
/// What transfers is the colour semantics, the backlit surface ladder and the
/// instrument hierarchy.
///
/// ## The mapping, which is the reason the show suits the application
///
/// Starfleet's departments already mean things, and what they mean lands on
/// roles this spike had already given meaning:
///
/// * **Command gold** is `primary` — actions, links, selection. What you can
///   command.
/// * **Science blue** is `tertiaryContainer`, which in this spike is the
///   `in game` chip. Literally *what the sensors report*: a derived value is a
///   reading of the engine's own state rather than of the record's.
/// * **Operations red** is `error`. Red alert, and free, exactly as red was
///   free for the other two palettes.
/// * **Brushed pewter** is `outline` — the structure, which here is lit.
///
/// ## The ladder, and what each rung is for
///
/// This is the only palette that keeps all four rungs *and* rules them.
/// [_snwHull] is the page; [_snwPanel] is a card; [_snwRaised] is anything in
/// front of a card; [_snwInset] is the one recess, the interior of a field. The
/// rungs are close together on purpose — 1.14:1 from hull to panel, 1.40:1
/// end to end — because a console is lit *evenly*; the seam is what separates
/// two panels, and the rung only says which of them is nearer.
///
/// ⚠️ **Every foreground is measured against [_snwInset], not against the
/// ground.** The recess is the extreme rung in both brightnesses — above all
/// three panels at night, below all three by day — so it is the worst case for
/// a legend either way, and gating on it is the one rule that does not need
/// restating when the lights come up.
///
/// ## What legibility cost the reference
///
/// ⚠️ **Operations red as a *legend* is a coral, not the uniform's brick.**
/// `#C8453B` measures 2.81:1 on the recess and 3.92:1 on the hull: it cannot
/// carry text anywhere on this console. The gate forces it up to `#FF6355`,
/// which is a lit indicator rather than a tunic. The tunic red survives as the
/// alert *plate* — [_snwAlert], a hair darker than the reference so a legend
/// fits on it — so the palette has two reds for exactly the reason Pop does,
/// and neither of them is quite the one the eye remembers.
///
/// ⚠️ **The lamps do not invert; only the metal does.** [_snwGold], [_snwBlue]
/// and [_snwAlert] are the same three values in both brightnesses, with the
/// same legends on them. A backlit jewel is the colour of its own light
/// whatever the room is doing, and this is the [_deStijlDay] portrait rule
/// generalised: the thing that emits does not care which theme it is in. The
/// portrait plate comes free with it — that gradient runs `primaryContainer`
/// into `tertiaryContainer`, so here it is one lamp into another and it is the
/// same picture in both brightnesses.
///
/// ⚠️ **And "unavailable" is a control whose backlight has gone out**, not a
/// screen and not a fade: an unlit plate under full-strength legends, which
/// makes an unfilled proficiency pip a dead lens in a bezel. It is the one
/// answer of the three that cannot be loud, and
/// [PaletteFinish.unlitInk] states the arithmetic that forbids it — a dark
/// ground leaves nothing below the panel to reach for.
const ColorScheme _starfleetNight = ColorScheme(
  brightness: Brightness.dark,
  primary: _snwGold,
  onPrimary: _snwHull,
  primaryContainer: _snwGold,
  onPrimaryContainer: _snwHull,
  secondary: _snwLegendDim,
  onSecondary: _snwHull,
  secondaryContainer: _snwRaised,
  onSecondaryContainer: _snwLegend,
  tertiary: _snwBlue,
  onTertiary: _snwHull,
  tertiaryContainer: _snwBlue,
  onTertiaryContainer: _snwHull,
  error: _snwRed,
  onError: _snwHull,
  errorContainer: _snwAlert,
  onErrorContainer: _snwLegend,
  surface: _snwHull,
  surfaceContainerLow: _snwPanel,
  surfaceContainer: _snwRaised,
  surfaceContainerHigh: _snwInset,
  onSurface: _snwLegend,
  onSurfaceVariant: _snwLegendDim,
  outline: _snwEdge,
  outlineVariant: _snwEdge,
  inverseSurface: _snwDayGround,
  onInverseSurface: _snwDayInk,
  inversePrimary: _snwDayGold,
  surfaceTint: _snwHull,
  shadow: _snwVoid,
  scrim: _snwVoid,
);

/// Starfleet, day — **and this one is the invention.**
///
/// The symmetry is worth saying out loud, because it is the whole reason this
/// palette earns its place beside the other two. De Stijl and Pop are
/// white-ground systems: paint and ink both need paper, so their *night* had to
/// be designed and there was no source to be faithful to. A bridge console is a
/// dark-ground system — it is lit from within, and a room with the lights up is
/// not what it is for — so here it is the **day** that had to be designed. Two
/// inventions in one direction, one in the other, and the same discipline for
/// all three: say that it was designed, and say what the design is.
///
/// * **The metal inverts and the light does not.** The hull becomes daylit
///   aluminium, the legends turn from silk-screen white to cut black, and the
///   three lamps — [_snwGold], [_snwBlue], [_snwAlert] — do not move at all.
/// * **The lit edge becomes a machined groove.** An edge cannot be *lit* on a
///   bright ground; what a seam does in daylight is cast a shadow. So
///   [_snwEdge] is replaced by [_snwDayGroove], which is dark where its
///   counterpart was bright and is the same object.
/// * **The recess changes ends of the ladder.** [_snwInset] is the brightest
///   rung at night, because a lit surface is lit; [_snwDayInset] is the darkest
///   by day, because a recess in daylight is in shade. This is the ladder rule
///   at the top of this file — *every step must move the same direction in both
///   brightnesses* — bent as far as it goes and not broken: the recess is below
///   all three panels here and above all three there, so it is the extreme in
///   both and nothing nests wrongly.
/// * **The colours keep their identity and change their depth**, each moved
///   only as far as its gate requires: gold to 4.61:1, blue to 4.58:1, red to
///   4.78:1.
///
/// ⚠️ **Command gold in daylight is the one place this palette brushes against
/// the bronze control.** A gold dark enough to letter on aluminium is an amber
/// — `#7E5400` — and the control's seed is `#8C6A3F`. They are not the same
/// colour: the amber is a third darker (relative luminance 0.108 against 0.162)
/// and has **no blue in it at all** where the bronze is a quarter blue, so it
/// reads as a deep gold where the other reads as a warm grey. It is still the
/// closest any two palettes come in this spike, and it is worth knowing before
/// judging a capture of it.
///
/// ⚠️ **The dark inks are stronger than their gates ask.** The groove is 4.89:1
/// where 3:1 was required and the second-rank legend is 6.56:1 where 4.5:1 was.
/// That is not conservatism: the unlit plate has to sit *under* both of them
/// and stay legible, so every step those two take toward their gate is a step
/// the plate has to give back. Buying margin here is what bought the plate its
/// 1.83:1, against the night's 1.23:1.
const ColorScheme _starfleetDay = ColorScheme(
  brightness: Brightness.light,
  primary: _snwDayGold,
  onPrimary: _snwDayLifted,
  primaryContainer: _snwGold,
  onPrimaryContainer: _snwHull,
  secondary: _snwDayInkDim,
  onSecondary: _snwDayLifted,
  secondaryContainer: _snwDayInset,
  onSecondaryContainer: _snwDayInk,
  tertiary: _snwDayBlue,
  onTertiary: _snwDayLifted,
  tertiaryContainer: _snwBlue,
  onTertiaryContainer: _snwHull,
  error: _snwDayRed,
  onError: _snwDayLifted,
  errorContainer: _snwAlert,
  onErrorContainer: _snwLegend,
  surface: _snwDayPanel,
  surfaceContainerLowest: _snwDayLifted,
  surfaceContainer: _snwDayGround,
  surfaceContainerHigh: _snwDayInset,
  onSurface: _snwDayInk,
  onSurfaceVariant: _snwDayInkDim,
  outline: _snwDayGroove,
  outlineVariant: _snwDayGroove,
  inverseSurface: _snwPanel,
  onInverseSurface: _snwLegend,
  inversePrimary: _snwGold,
  surfaceTint: _snwDayPanel,
  shadow: _snwVoid,
  scrim: _snwVoid,
);
