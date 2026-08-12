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

/// The Record spike's theme: one Material 3 scheme, a retuned type scale, and
/// the document tokens the rest of `lib/record` draws with.
///
/// **The seed is unchanged from the baseline.** This approach is judged against
/// the same application and the same portrait art, so moving the hue would
/// confound the comparison. What it changes is *type and contrast*, and the
/// bronze already reads as warm paper at Material 3's neutral tones.
///
/// No widget in this spike names a colour-scheme or text-theme role for
/// document styling. It asks [RecordTokens] instead, reached through
/// [RecordTokensContext].
library;

import 'package:flutter/material.dart';

/// Weathered bronze, the same seed the baseline application uses.
const Color _seed = Color(0xFF8C6A3F);

/// Installed on this machine, checked with `fc-match`, so a font miss degrades
/// rather than breaks.
const List<String> _serifFallback = ['Noto Serif', 'DejaVu Serif'];
const List<String> _sansFallback = ['Noto Sans', 'Cantarell'];

TextStyle _serifStyle({
  required double size,
  required double height,
  required double spacing,
  FontWeight weight = FontWeight.w400,
}) {
  return TextStyle(
    fontFamily: 'IBM Plex Serif',
    fontFamilyFallback: _serifFallback,
    fontSize: size,
    height: height,
    letterSpacing: spacing,
    fontWeight: weight,
  );
}

TextStyle _sansStyle({
  required double size,
  required double height,
  required double spacing,
  FontWeight weight = FontWeight.w400,
}) {
  return TextStyle(
    fontFamily: 'IBM Plex Sans',
    fontFamilyFallback: _sansFallback,
    fontSize: size,
    height: height,
    letterSpacing: spacing,
    fontWeight: weight,
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

ButtonStyle _flatButton(TextTheme text) {
  return ButtonStyle(
    textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 36)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: 16),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

/// The two themes this spike renders in, and everything the components need.
///
/// Twelve component slots are filled where the baseline application fills one,
/// because a document is mostly made of the parts nobody themes: rules, input
/// affordances, scrollbars, tooltips and icon targets.
abstract final class RecordTheme {
  /// The document in daylight.
  static ThemeData get light => _build(Brightness.light);

  /// The same document at night.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    // `outlineVariant` is spec'd at 1.0:1 at the default contrast level, and
    // rules are this approach's primary structural device — so the scheme is
    // built at a raised contrast level rather than the dividers being
    // recoloured one by one. The variant is Material 3's own default.
    final colors = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      contrastLevel: 0.5,
    );
    final text = _textTheme();
    final tokens = RecordTokens._from(colors, text);

    return ThemeData(
      colorScheme: colors,
      textTheme: text,
      extensions: [tokens],
      // Ink splashes on document text read as a form. Hover is the affordance.
      splashFactory: NoSplash.splashFactory,
      // A document fades; it does not slide up from a phone.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      // `visualDensity` is deliberately left alone: on Linux it already
      // resolves to `compact`. `cardTheme` is left alone too — this spike uses
      // no cards, and setting a shape without a side silently erases the only
      // border an outlined card has.
      appBarTheme: AppBarThemeData(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleSpacing: 24,
        titleTextStyle: text.titleLarge?.copyWith(color: colors.onSurface),
        actionsPadding: const EdgeInsets.only(right: 20),
        shape: Border(bottom: BorderSide(color: colors.outline)),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outline,
        thickness: 1,
        // Spacing around a rule is typographic here, set by the widget that
        // draws it, never by the rule's own reserved band.
        space: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll<bool>(true),
        thickness: const WidgetStatePropertyAll<double>(8),
        thumbColor: WidgetStatePropertyAll<Color>(colors.outline),
        radius: const Radius.circular(4),
        crossAxisMargin: 4,
        interactive: true,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.22),
        selectionHandleColor: colors.primary,
      ),
      // The defaults give 32px of vertical padding and a 48px floor, which is
      // a form. A value that becomes editable in place must not move.
      inputDecorationTheme: InputDecorationThemeData(
        border: InputBorder.none,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        // Unbounded on purpose: any constraints at all replace the decorator's
        // own floor, and this one imposes nothing in its place.
        constraints: const BoxConstraints(),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        constraints: const BoxConstraints(maxWidth: 320),
        preferBelow: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: text.bodySmall?.copyWith(color: colors.onInverseSurface),
        decoration: ShapeDecoration(
          color: colors.inverseSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ),
      // Material 3 exempts icon buttons from visual density, so without this
      // every ⓘ in the document would reserve a 48px square.
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          iconSize: const WidgetStatePropertyAll<double>(18),
          iconColor: WidgetStatePropertyAll<Color>(colors.onSurfaceVariant),
          minimumSize: const WidgetStatePropertyAll<Size>(Size(32, 32)),
          fixedSize: const WidgetStatePropertyAll<Size>(Size(32, 32)),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.zero,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      iconTheme: IconThemeData(size: 18, color: colors.onSurfaceVariant),
      filledButtonTheme: FilledButtonThemeData(style: _flatButton(text)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _flatButton(text)),
      textButtonTheme: TextButtonThemeData(style: _flatButton(text)),
      checkboxTheme: const CheckboxThemeData(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  /// Material 3's phone scale retuned for a 760px reading measure.
  ///
  /// The stock scale tracks `body-large` at 0.5, which is a phone number; a
  /// serif at this measure wants roughly none. Serif carries the reading, sans
  /// carries labels, rail and chrome.
  static TextTheme _textTheme() {
    return TextTheme(
      // The name on the cover.
      displaySmall: _serifStyle(
        size: 40,
        height: 1.08,
        spacing: -0.6,
        weight: FontWeight.w300,
      ),
      // The name in the running head.
      titleLarge: _serifStyle(
        size: 21,
        height: 1.25,
        spacing: 0,
        weight: FontWeight.w500,
      ),
      // Group heads.
      titleMedium: _sansStyle(
        size: 15,
        height: 1.4,
        spacing: 0.1,
        weight: FontWeight.w600,
      ),
      // Chapter heads, in tracked caps.
      titleSmall: _sansStyle(
        size: 12,
        height: 1.2,
        spacing: 1.4,
        weight: FontWeight.w700,
      ),
      // The reading size.
      bodyLarge: _serifStyle(size: 17, height: 1.62, spacing: 0.05),
      // The arithmetic line.
      bodyMedium: _serifStyle(size: 14, height: 1.55, spacing: 0.05),
      // Captions.
      bodySmall: _sansStyle(size: 12.5, height: 1.5, spacing: 0.15),
      // Buttons.
      labelLarge: _sansStyle(
        size: 14,
        height: 1.4,
        spacing: 0.2,
        weight: FontWeight.w500,
      ),
      // Rail entries.
      labelMedium: _sansStyle(
        size: 13,
        height: 1.35,
        spacing: 0.25,
        weight: FontWeight.w500,
      ),
      // `in game`, `stored`, slot names.
      labelSmall: _sansStyle(
        size: 11,
        height: 1.3,
        spacing: 0.9,
        weight: FontWeight.w600,
      ),
    );
  }
}

/// Everything the document draws that no component theme owns.
///
/// Dimming here is always a **role change**, never an opacity wrapper, so no
/// ink in this spike drops below its specified contrast. Body ink is the
/// surface's own; dimmed ink is the variant role at 4.5:1; derived ink and
/// anomaly ink are two further roles, both raised again by the scheme's
/// contrast level.
@immutable
class RecordTokens extends ThemeExtension<RecordTokens> {
  /// Creates a token set. [RecordTheme] builds the only one this spike uses.
  const RecordTokens({
    required this.coverName,
    required this.identityLine,
    required this.identityLineStrong,
    required this.chapterHead,
    required this.groupHead,
    required this.fieldLabel,
    required this.fieldLabelDim,
    required this.storedValue,
    required this.derivedValue,
    required this.derivedTag,
    required this.arithmetic,
    required this.caveat,
    required this.caption,
    required this.railEntry,
    required this.railEntryActive,
    required this.slotName,
    required this.rule,
    required this.derivedInk,
    required this.anomalyInk,
    required this.changeInk,
    required this.pipInk,
    required this.pipEmptyInk,
    required this.measure,
    required this.valueColumn,
    required this.gutter,
    required this.chapterGap,
    required this.rowGap,
    required this.railWidth,
  });

  factory RecordTokens._from(ColorScheme colors, TextTheme text) {
    final ink = colors.onSurface;
    final dim = colors.onSurfaceVariant;
    final stored = text.bodyLarge!.copyWith(
      color: ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return RecordTokens(
      coverName: text.displaySmall!.copyWith(color: ink),
      identityLine: text.bodyLarge!.copyWith(color: dim),
      identityLineStrong: text.bodyLarge!.copyWith(color: ink),
      chapterHead: text.titleSmall!.copyWith(color: dim),
      groupHead: text.titleMedium!.copyWith(color: ink),
      fieldLabel: text.bodyLarge!.copyWith(color: ink),
      fieldLabelDim: text.bodyLarge!.copyWith(color: dim),
      storedValue: stored,
      derivedValue: stored.copyWith(color: colors.tertiary),
      derivedTag: text.labelSmall!.copyWith(color: colors.tertiary),
      arithmetic: text.bodyMedium!.copyWith(
        color: dim,
        fontStyle: FontStyle.italic,
      ),
      caveat: text.bodyMedium!.copyWith(color: dim),
      caption: text.bodySmall!.copyWith(color: dim),
      railEntry: text.labelMedium!.copyWith(color: dim),
      railEntryActive: text.labelMedium!.copyWith(
        color: colors.primary,
        fontWeight: FontWeight.w700,
      ),
      slotName: text.labelSmall!.copyWith(color: dim),
      rule: colors.outline,
      derivedInk: colors.tertiary,
      anomalyInk: colors.error,
      changeInk: colors.primary,
      pipInk: colors.primary,
      pipEmptyInk: colors.outlineVariant,
      measure: 760,
      valueColumn: 132,
      gutter: 14,
      chapterGap: 56,
      rowGap: 7,
      railWidth: 216,
    );
  }

  /// The character's name on the cover.
  final TextStyle coverName;

  /// One of the four facts the engine stacks under the portrait.
  final TextStyle identityLine;

  /// The one of those four that carries the class, in full ink.
  final TextStyle identityLineStrong;

  /// A chapter head, set in tracked caps.
  final TextStyle chapterHead;

  /// A bare-word run heading inside a chapter.
  final TextStyle groupHead;

  /// A field's name.
  final TextStyle fieldLabel;

  /// A field's name when the class cannot have it.
  final TextStyle fieldLabelDim;

  /// What the file holds, in tabular figures so columns of digits line up.
  final TextStyle storedValue;

  /// What the engine draws instead.
  final TextStyle derivedValue;

  /// The words `In game` beside a derived value.
  final TextStyle derivedTag;

  /// The always-visible helper line. It wraps; it is never shortened.
  final TextStyle arithmetic;

  /// The one thing no number can say, revealed by the ⓘ.
  final TextStyle caveat;

  /// A short qualifier under a value or an item.
  final TextStyle caption;

  /// An index entry.
  final TextStyle railEntry;

  /// The index entry the reader is currently inside.
  final TextStyle railEntryActive;

  /// An equipment slot's name.
  final TextStyle slotName;

  /// The ink every rule in the document is drawn in.
  final Color rule;

  /// The ink for values the engine owns.
  final Color derivedInk;

  /// The ink for a record that holds something its class cannot.
  final Color anomalyInk;

  /// The ink for the change bar beside an edited row.
  final Color changeInk;

  /// A taken proficiency pip.
  final Color pipInk;

  /// A pip the character could still take.
  final Color pipEmptyInk;

  /// The reading measure the document is centred in.
  final double measure;

  /// The right-hand column every stored value is set in.
  final double valueColumn;

  /// The always-reserved left band, so nothing shifts when a row is edited.
  final double gutter;

  /// The space above a chapter head.
  final double chapterGap;

  /// The leading that separates rows, which are not ruled.
  final double rowGap;

  /// The index rail's natural width.
  final double railWidth;

  @override
  RecordTokens copyWith({
    TextStyle? coverName,
    TextStyle? identityLine,
    TextStyle? identityLineStrong,
    TextStyle? chapterHead,
    TextStyle? groupHead,
    TextStyle? fieldLabel,
    TextStyle? fieldLabelDim,
    TextStyle? storedValue,
    TextStyle? derivedValue,
    TextStyle? derivedTag,
    TextStyle? arithmetic,
    TextStyle? caveat,
    TextStyle? caption,
    TextStyle? railEntry,
    TextStyle? railEntryActive,
    TextStyle? slotName,
    Color? rule,
    Color? derivedInk,
    Color? anomalyInk,
    Color? changeInk,
    Color? pipInk,
    Color? pipEmptyInk,
    double? measure,
    double? valueColumn,
    double? gutter,
    double? chapterGap,
    double? rowGap,
    double? railWidth,
  }) {
    return RecordTokens(
      coverName: coverName ?? this.coverName,
      identityLine: identityLine ?? this.identityLine,
      identityLineStrong: identityLineStrong ?? this.identityLineStrong,
      chapterHead: chapterHead ?? this.chapterHead,
      groupHead: groupHead ?? this.groupHead,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      fieldLabelDim: fieldLabelDim ?? this.fieldLabelDim,
      storedValue: storedValue ?? this.storedValue,
      derivedValue: derivedValue ?? this.derivedValue,
      derivedTag: derivedTag ?? this.derivedTag,
      arithmetic: arithmetic ?? this.arithmetic,
      caveat: caveat ?? this.caveat,
      caption: caption ?? this.caption,
      railEntry: railEntry ?? this.railEntry,
      railEntryActive: railEntryActive ?? this.railEntryActive,
      slotName: slotName ?? this.slotName,
      rule: rule ?? this.rule,
      derivedInk: derivedInk ?? this.derivedInk,
      anomalyInk: anomalyInk ?? this.anomalyInk,
      changeInk: changeInk ?? this.changeInk,
      pipInk: pipInk ?? this.pipInk,
      pipEmptyInk: pipEmptyInk ?? this.pipEmptyInk,
      measure: measure ?? this.measure,
      valueColumn: valueColumn ?? this.valueColumn,
      gutter: gutter ?? this.gutter,
      chapterGap: chapterGap ?? this.chapterGap,
      rowGap: rowGap ?? this.rowGap,
      railWidth: railWidth ?? this.railWidth,
    );
  }

  @override
  RecordTokens lerp(ThemeExtension<RecordTokens>? other, double t) {
    if (other is! RecordTokens) return this;
    return RecordTokens(
      coverName: TextStyle.lerp(coverName, other.coverName, t)!,
      identityLine: TextStyle.lerp(identityLine, other.identityLine, t)!,
      identityLineStrong: TextStyle.lerp(
        identityLineStrong,
        other.identityLineStrong,
        t,
      )!,
      chapterHead: TextStyle.lerp(chapterHead, other.chapterHead, t)!,
      groupHead: TextStyle.lerp(groupHead, other.groupHead, t)!,
      fieldLabel: TextStyle.lerp(fieldLabel, other.fieldLabel, t)!,
      fieldLabelDim: TextStyle.lerp(fieldLabelDim, other.fieldLabelDim, t)!,
      storedValue: TextStyle.lerp(storedValue, other.storedValue, t)!,
      derivedValue: TextStyle.lerp(derivedValue, other.derivedValue, t)!,
      derivedTag: TextStyle.lerp(derivedTag, other.derivedTag, t)!,
      arithmetic: TextStyle.lerp(arithmetic, other.arithmetic, t)!,
      caveat: TextStyle.lerp(caveat, other.caveat, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      railEntry: TextStyle.lerp(railEntry, other.railEntry, t)!,
      railEntryActive: TextStyle.lerp(
        railEntryActive,
        other.railEntryActive,
        t,
      )!,
      slotName: TextStyle.lerp(slotName, other.slotName, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
      derivedInk: Color.lerp(derivedInk, other.derivedInk, t)!,
      anomalyInk: Color.lerp(anomalyInk, other.anomalyInk, t)!,
      changeInk: Color.lerp(changeInk, other.changeInk, t)!,
      pipInk: Color.lerp(pipInk, other.pipInk, t)!,
      pipEmptyInk: Color.lerp(pipEmptyInk, other.pipEmptyInk, t)!,
      measure: _lerp(measure, other.measure, t),
      valueColumn: _lerp(valueColumn, other.valueColumn, t),
      gutter: _lerp(gutter, other.gutter, t),
      chapterGap: _lerp(chapterGap, other.chapterGap, t),
      rowGap: _lerp(rowGap, other.rowGap, t),
      railWidth: _lerp(railWidth, other.railWidth, t),
    );
  }
}

/// Reaches the document's [RecordTokens] from a build context.
///
/// An extension rather than a static factory: a static method returning its own
/// enclosing type is exactly the shape the analyzer reports, and reading
/// `context.recordTokens` at the top of a build method is shorter than either.
extension RecordTokensContext on BuildContext {
  /// This spike's document tokens.
  RecordTokens get recordTokens => Theme.of(this).extension<RecordTokens>()!;

  /// A metric scaled by the reader's text scale, with a 1.6× ceiling so a very
  /// large setting widens the chrome without swallowing the page.
  double scaledByText(double base) =>
      base * MediaQuery.textScalerOf(this).scale(1).clamp(1, 1.6).toDouble();
}
