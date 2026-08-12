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
import 'package:wand_of_saves/ui/core/palette_finish.dart';

/// *Present, and not available.* Three drawings of one state, chosen by the
/// palette: a halftone plate where it supplies a screen, an **unlit plate**
/// where it supplies an unlit ink, and a fade where it supplies neither.
///
/// One widget for one state, so the palette decides how "unavailable" looks
/// and no caller has to know. ⚠️ **It names no colour**: both inks come from
/// the [PaletteFinish] the theme carries, which is what the extension is for.
/// The class keeps the name the first answer gave it.
///
/// The trade, in numbers, because it is a trade and not a free win. On
/// newsprint the fade puts body text at a flat **8.96:1**; the screen puts it
/// at **19.62:1** between the dots and **6.08:1** where a stroke lands on one.
/// The worst case is therefore lower — and in exchange the state becomes
/// something visible across the room rather than a 28 % difference in ink that
/// has to be compared against a neighbour to be noticed at all.
///
/// The plate makes the opposite trade: it lowers no worst case at all, because
/// it dims the ground and leaves every mark full-strength. On the console the
/// dimmest pairing on an unlit tile is **9.26:1** at night and **4.56:1** by
/// day, where the same tile under the fade below would read 4.57:1 and
/// **4.05:1** — under the gate in the light form, which is how a fade fails:
/// quietly, in one brightness, on the second rank of ink. What the plate gives
/// up is loudness. See [PaletteFinish.unlitInk] for why a solid plate can never
/// be as loud as a screen.
class ScreenTone extends StatelessWidget {
  /// Screens [child] back: a plate of dots behind it, with the content itself
  /// left at full strength.
  const ScreenTone({required Widget this.child, super.key});

  /// The screen or the plate and nothing else, filling whatever space it is
  /// given — for a mark too small to hold content, such as an unfilled
  /// proficiency pip.
  ///
  /// Draws nothing at all under a palette that fades, which is what leaves such
  /// a pip the plain outlined ring it has always been. Under an unlit palette
  /// it becomes what it should have been all along: a dead lens in a bezel.
  const ScreenTone.fill({super.key}) : child = null;

  /// What is being screened back, or null for [ScreenTone.fill].
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final finish = PaletteFinish.of(context);
    final content = child;
    final ink = finish.screenInk;
    if (ink != null) {
      return CustomPaint(
        painter: _Halftone(
          ink: ink,
          pitch: finish.screenPitch,
          radius: finish.screenRadius,
        ),
        child: content,
      );
    }
    final unlit = finish.unlitInk;
    // Behind the content, never over it — the whole point of a plate is that
    // what it is under keeps its own strength.
    if (unlit != null) return ColoredBox(color: unlit, child: content);
    if (content == null) return const SizedBox.shrink();
    return Opacity(opacity: _fade, child: content);
  }
}

/// What a palette without a screen fades to. Measured rather than picked: on
/// this spike's two painted grounds it holds body text at 6.49:1 and 8.96:1,
/// so it is not the defect the screen exists to fix — it is merely quiet.
const double _fade = 0.72;

class _Halftone extends CustomPainter {
  const _Halftone({
    required this.ink,
    required this.pitch,
    required this.radius,
  });

  final Color ink;
  final double pitch;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // ⚠️ `CustomPaint` does not clip, and the lattice deliberately runs past
    // the edge so the screen never looks like it was laid out to fit.
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    final dot = Paint()..color = ink;
    var row = 0;
    for (var y = pitch / 2; y < size.height + pitch; y += pitch) {
      final stagger = row.isEven ? 0.0 : pitch / 2;
      for (var x = stagger; x < size.width + pitch; x += pitch) {
        canvas.drawCircle(Offset(x, y), radius, dot);
      }
      row++;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Halftone oldDelegate) =>
      oldDelegate.ink != ink ||
      oldDelegate.pitch != pitch ||
      oldDelegate.radius != radius;
}
