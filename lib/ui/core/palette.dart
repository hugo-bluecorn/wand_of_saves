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

/// Which palette the Workbench spike is wearing, chosen at **run** time from
/// `SPIKE_PALETTE` in the same way `SPIKE_SCREEN` chooses a screen.
///
/// ⚠️ **A palette is a one-file change and must stay one.** The whole claim
/// this spike makes about itself is that its visual identity lives in
/// `theme.dart`; nothing downstream of the theme may ask which of these is in
/// force, and no widget may name a colour. A palette that needed a branch in a
/// widget would have disproved the claim rather than exercised it.
///
/// The three alternates are not recolours. Each changes the colour, the corner
/// radius, the rule weight and the elevation **together**, because that
/// combination is what makes each one the thing it is named after — a De Stijl
/// canvas with round corners and a drop shadow would be neither.
enum WorkbenchPalette {
  /// The original, and the control in the comparison: a bronze seed run
  /// through `ColorScheme.fromSeed` at `contrastLevel: 0.5`, with the four
  /// surface rungs, 16-to-8 px radii, hairline rules and lifted overlays.
  ///
  /// ⚠️ **Held still.** It exists to be compared against, so nothing added for
  /// the other two may move a pixel of it.
  bronze,

  /// Mondrian. Three unrelated hues at full chroma, a black grid, a warm
  /// ground, square corners and no shadow anywhere.
  deStijl,

  /// Lichtenstein. The same idea printed rather than painted: CMYK-derived
  /// inks, pure black contours at three pixels, newsprint, and a Ben-Day dot
  /// screen where the other palettes would reach for transparency.
  pop,

  /// *Star Trek: Strange New Worlds* — Pike's bridge, and **not LCARS**.
  ///
  /// The rounded elbow brackets, the black ground and the peach-and-lavender
  /// set belong to *The Next Generation*, eighty in-universe years later. This
  /// one is deliberately pre-LCARS: brushed pewter structure, warm amber
  /// backlighting, deep blue-teal display surfaces, and physical jewel-like
  /// controls. Softly rounded, because the panels are machined parts.
  ///
  /// ⚠️ **It is the one palette whose *light* form is the invention.** The
  /// other two are white-ground systems whose night had to be designed; a
  /// bridge console is a dark-ground system, so the mirror holds and it is the
  /// day that had to be. See `theme.dart`.
  starfleet,
}
