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

/// A stand-in portrait, drawn rather than loaded.
///
/// The game's portraits are BioWare's art and none is copied into this repo.
/// What matters for judging a layout is the **shape**: BG:EE's medium portrait
/// is 84 × 132, an aspect of about 0.636, and a spike that reserves a square
/// or a circle for it has designed for a picture the app will never receive.
library;

import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';

/// The aspect ratio of a BG:EE medium portrait — 84 × 132.
const double portraitAspect = 84 / 132;

/// The file named [baseName] in `SPIKE_ART`, if it is there, else null.
///
/// ⚠️ **Why this exists.** Every palette was first judged against a procedural
/// gradient, and the one claim they all make is about how they frame *the
/// game's own art*. A gradient cannot test that. Point `SPIKE_ART` at a
/// directory and the real thing is drawn instead.
///
/// ⚠️ **And the first look overturned the premise.** The art was assumed to be
/// warm, painterly and brown-and-gold; Aard's portrait is cool blue-grey.
/// BG:EE's portraits vary widely in temperature, so any chrome that commits to
/// one will disagree with roughly half of them — which is an argument for a
/// neutral mount, and it could only be found by looking.
///
/// ⚠️ **Nothing is committed.** BioWare's artwork stays out of the repository,
/// the same distribution decision `docs/findings/screens/` already makes. A
/// character with no file falls back to the gradient, which is useful in
/// itself: both states appear side by side in one lineup.
File? demoArt(String baseName, {String extension = 'png'}) {
  final directory = Platform.environment['SPIKE_ART'];
  if (directory == null || baseName.isEmpty) return null;
  final file = File('$directory/$baseName.$extension');
  return file.existsSync() ? file : null;
}

/// A savegame's screenshot — the engine's own `BALDUR.bmp`.
///
/// ⚠️ **A missing file is an ordinary state, not a failure.** One of the three
/// real slots has no `BALDUR.bmp` at all, so its screenshot name is null and
/// this draws a plain, quiet placeholder. The real application shipped a
/// broken-image icon here once, which read as *something went wrong* over a
/// save that was simply written before there was a screen worth keeping.
class DemoScreenshot extends StatelessWidget {
  /// Draws the screenshot named [name], or a placeholder when it is absent.
  const DemoScreenshot({required this.name, super.key});

  /// The base name in `SPIKE_ART`, or null when the slot has none.
  final String? name;

  /// The aspect the engine writes: 239 × 180.
  static const double aspect = 239 / 180;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final file = name == null ? null : demoArt(name!, extension: 'bmp');
    return AspectRatio(
      aspectRatio: aspect,
      child: file != null
          ? Image.file(file, fit: BoxFit.cover)
          : ColoredBox(
              color: colors.surfaceContainerHighest,
              child: Center(
                child: Text(
                  'No screenshot',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
    );
  }
}

/// A drawn stand-in for a character portrait.
class DemoPortrait extends StatelessWidget {
  /// Creates a portrait of [width], at [portraitAspect].
  const DemoPortrait({
    required this.initial,
    this.width = 84,
    this.radius = 6,
    super.key,
  });

  /// The letter shown in place of a face.
  final String initial;

  /// How wide to draw it; the height follows from [portraitAspect].
  final double width;

  /// Corner radius, so a spike can make it sharp, soft or round.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final art = demoArt(initial.toLowerCase());
    if (art != null) {
      return SizedBox(
        width: width,
        height: width / portraitAspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(art, fit: BoxFit.cover),
        ),
      );
    }
    return SizedBox(
      width: width,
      height: width / portraitAspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primaryContainer,
              colors.tertiaryContainer,
            ],
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }
}
