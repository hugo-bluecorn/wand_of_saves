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

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Everything a palette decides that a [ColorScheme] cannot hold: how it
/// finishes an edge, and how it says *present but unavailable*.
///
/// ⚠️ **This exists so that a palette stays a one-file change.** A handful of
/// radii are written into widgets — a tag's 8, an ability tile's 12 — and a
/// palette with square corners cannot reach them through the colour scheme.
/// Left alone they would be the one part of the spike's identity that did not
/// live in `theme.dart`, and rounded pills on a De Stijl canvas would have
/// been the tell that the palette was a recolour rather than a design.
///
/// A widget therefore asks the theme what its own radius becomes, rather than
/// asking which palette is in force. The rule is not *this palette is square*
/// but *this palette keeps none of a widget's corner*, which is a decision
/// about edges and belongs with the other decisions about edges.
@immutable
class PaletteFinish extends ThemeExtension<PaletteFinish> {
  /// Describes a finish. The defaults are the untouched one: corners as their
  /// widgets asked for them, and no mark of its own for *unavailable*.
  const PaletteFinish({
    this.corner = 1,
    this.cornerMax,
    this.screenInk,
    this.unlitInk,
    this.screenPitch = 4,
    this.screenRadius = 1.15,
  });

  /// The finish [context] is under, or the untouched one outside a Workbench
  /// theme.
  factory PaletteFinish.of(BuildContext context) =>
      Theme.of(context).extension<PaletteFinish>() ?? const PaletteFinish();

  /// How much of a widget's own corner radius survives: 1 keeps it, 0 squares
  /// it. It is a factor rather than a radius because there is a *scale* of
  /// radii here — 16 for a card, 12 for a tile, 8 for a pill — and a palette
  /// squares the whole scale or none of it.
  final double corner;

  /// The largest radius this palette will draw, whatever a widget asked for,
  /// or null to leave the scale alone.
  ///
  /// ⚠️ **A ceiling, not a factor, because the two say different things.**
  /// [corner] scales the whole ladder and keeps its *hierarchy* — a card
  /// rounder than a chip, only less so. A ceiling flattens the hierarchy
  /// instead: every part gets the same small fillet however big it is, which is
  /// what a console panel looks like, because a machined edge is cut with one
  /// tool and does not know how large the panel it is cutting is.
  final double? cornerMax;

  /// The Ben-Day dot colour, at **full opacity**, or null for a palette that
  /// answers *unavailable* some other way.
  ///
  /// ## Why a screen beats a fade
  ///
  /// Flutter's disabled states composite the foreground at **0.38**, which on
  /// this spike's grounds measures 2.25:1 (De Stijl) and 2.55:1 (Pop) — under
  /// even the 3:1 gate for graphics, and unreachable by construction: no
  /// choice of ink fixes it, because the ink is what is being diluted. A
  /// screen dilutes *coverage* instead, so every mark it makes is
  /// full-strength.
  ///
  /// ⚠️ **The ink is fixed from both sides.** The dots have to clear 3:1
  /// against the ground to be seen at all, and body text drawn **over** a dot
  /// has to clear 4.5:1 or the screen has broken the thing it was covering.
  /// Those two constraints pull in opposite directions and between them they
  /// leave very little room: at `#8A8A8A` on newsprint the dots read 3.22:1
  /// and black text over one reads 6.08:1. A darker, more Lichtenstein-like
  /// screen fails the second, which is why this one is grey and his were red.
  final Color? screenInk;

  /// The plate an *unlit* control sits on, at **full opacity**, or null for a
  /// palette that screens or fades instead. At most one of this and
  /// [screenInk] is ever set; the theme is the only place either is.
  ///
  /// ## Why a plate, and what it cannot do
  ///
  /// It is the same argument the screen makes and a different answer to it:
  /// dilute the *ground* rather than the ink, so every mark on top stays
  /// full-strength. A control whose backlight has gone out is exactly that —
  /// still there, still legible, no longer live.
  ///
  /// ⚠️ **The plate cannot be a 3:1 graphic in its own right, and no choice of
  /// colour fixes it.** Going darker on a dark ground is bounded by black: the
  /// panel it sits in is already so near the floor that pure black is only
  /// **1.27:1** below it. Going lighter is bounded by the ink: any plate bright
  /// enough to read as a change puts the second-rank legend and the seam under
  /// their own gates, which caps a lightening at **1.32:1**. Both walls are the
  /// same wall. So the plate is a *dimming* — 1.23:1 in the dark form, 1.83:1
  /// in the light one — and the **word** on the tile carries the state, which
  /// it always did.
  ///
  /// The screen escapes this only because a halftone is a *coverage* rather
  /// than a level: 26 % of full-strength ink can average 3:1 darker while
  /// leaving 74 % of the tile for the text to sit in. A solid plate has no such
  /// freedom, and pretending otherwise is how a 38 % fade gets written.
  final Color? unlitInk;

  /// The distance between dot centres. Alternate rows are offset by half of
  /// it, which is the stagger a real halftone screen has.
  final double screenPitch;

  /// The radius of one dot. With [screenPitch] it fixes the coverage, and
  /// coverage is what the eye reads as tone: π·r²/pitch² is 26 % at 1.15 on 4.
  final double screenRadius;

  /// The radius a widget asking for a [soft] corner actually gets: the scale,
  /// then the ceiling.
  double cornerOf(double soft) {
    final scaled = soft * corner;
    final ceiling = cornerMax;
    return ceiling == null ? scaled : math.min(scaled, ceiling);
  }

  /// What a widget asking for a [soft] corner actually gets.
  BorderRadius radiusOf(double soft) => BorderRadius.circular(cornerOf(soft));

  @override
  PaletteFinish copyWith({
    double? corner,
    double? cornerMax,
    Color? screenInk,
    Color? unlitInk,
    double? screenPitch,
    double? screenRadius,
  }) => PaletteFinish(
    corner: corner ?? this.corner,
    cornerMax: cornerMax ?? this.cornerMax,
    screenInk: screenInk ?? this.screenInk,
    unlitInk: unlitInk ?? this.unlitInk,
    screenPitch: screenPitch ?? this.screenPitch,
    screenRadius: screenRadius ?? this.screenRadius,
  );

  @override
  PaletteFinish lerp(covariant PaletteFinish? other, double t) {
    if (other == null) return this;
    return PaletteFinish(
      corner: lerpDouble(corner, other.corner, t) ?? corner,
      cornerMax: lerpDouble(cornerMax, other.cornerMax, t),
      screenInk: Color.lerp(screenInk, other.screenInk, t),
      unlitInk: Color.lerp(unlitInk, other.unlitInk, t),
      screenPitch: lerpDouble(screenPitch, other.screenPitch, t) ?? screenPitch,
      screenRadius:
          lerpDouble(screenRadius, other.screenRadius, t) ?? screenRadius,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PaletteFinish &&
      other.corner == corner &&
      other.cornerMax == cornerMax &&
      other.screenInk == screenInk &&
      other.unlitInk == unlitInk &&
      other.screenPitch == screenPitch &&
      other.screenRadius == screenRadius;

  @override
  int get hashCode => Object.hash(
    corner,
    cornerMax,
    screenInk,
    unlitInk,
    screenPitch,
    screenRadius,
  );
}
