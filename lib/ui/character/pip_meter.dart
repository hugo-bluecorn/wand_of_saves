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

import 'package:flutter/material.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';
import 'package:wand_of_saves/ui/core/screen_tone.dart';
import 'package:wand_of_saves/ui/core/tag.dart';

/// A proficiency drawn as pips, with its ceiling shown rather than merely
/// enforced.
///
/// The ceiling is `min(profsmax.FIRST_LEVEL, weapprof[column])`, and a player
/// who cannot see it only learns it exists by being refused. So the meter
/// draws the empty pips up to the ceiling, marks the ceiling itself, and puts
/// the numeral `2/5` beside it.
///
/// ⚠️ **Above the ceiling it stays honest.** A record that holds four pips in
/// a three-pip proficiency draws the surplus in the error role and reads
/// `4/3`. Clamping silently would make that state undrawable and would
/// contradict the rule the rest of this spike is built on: a value you cannot
/// see is a value you cannot correct.
class PipMeter extends StatelessWidget {
  /// Draws [proficiency].
  const PipMeter({
    required this.proficiency,
    this.pending,
    this.onTap,
    this.showName = true,
    super.key,
  });

  /// The proficiency, with its stored pips and its ceiling.
  final SheetProficiency proficiency;

  /// An edit not yet written, drawn in place of the stored pips.
  final int? pending;

  /// Opens this proficiency in the side sheet.
  final VoidCallback? onTap;

  /// Whether to draw the name. The side sheet already has it in its header,
  /// and 420 px is not wide enough to spend twice on the same word.
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pips = pending ?? proficiency.pips;
    final maximum = proficiency.maximum;
    final over = pips > maximum;

    final meter = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (showName) ...[
            Expanded(child: Text(proficiency.name, style: text.bodyLarge)),
            const SizedBox(width: 12),
          ],
          PipRow(pips: pips, maximum: maximum),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              '$pips/$maximum',
              textAlign: TextAlign.end,
              style: text.labelMedium,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 108,
            child: Align(
              alignment: Alignment.centerRight,
              // ⚠️ **A ceiling of zero is not a ceiling reached.** `0` in a
              // `weapprof.2da` class column is how the table says *not this
              // class* — `character_sheet.dart` documents exactly that — so
              // `at ceiling` on a `0/0` row states the opposite of the truth:
              // it reads as a limit spent rather than a row that never applied.
              // Fourteen padding rows made this obvious; it was wrong before
              // them, on any proficiency a class simply cannot take.
              child: switch ((over, maximum == 0, pips == maximum)) {
                (true, _, _) => const Tag(
                  'over ceiling',
                  tone: TagTone.conflict,
                ),
                (false, true, _) => const Tag(
                  'not for this class',
                  tone: TagTone.muted,
                ),
                (false, false, true) => const Tag(
                  'at ceiling',
                  tone: TagTone.muted,
                ),
                (false, false, false) => const SizedBox.shrink(),
              },
            ),
          ),
          if (pending != null) ...[
            const SizedBox(width: 8),
            const Tag('not written yet', tone: TagTone.muted),
          ],
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label:
          '${proficiency.name}, $pips of $maximum pips'
          '${over ? ', above the ceiling' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: meter,
      ),
    );
  }
}

/// The dots on their own: filled up to the pips taken, empty up to the ceiling,
/// surplus beyond it, with the ceiling itself marked.
///
/// ⚠️ **Extracted so the dot language has exactly one copy.** A surface that
/// draws proficiencies compactly — a flowing pill rather than a full-width
/// meter — needs the same dots at a smaller size, and a second rendering of
/// *what a pip means* is the recurring defect this project pays for. The name,
/// the `pips/maximum` numeral and the state word stay with [PipMeter], because
/// those are what a compact surface is trading away.
class PipRow extends StatelessWidget {
  /// Draws [pips] taken out of a ceiling of [maximum].
  const PipRow({
    required this.pips,
    required this.maximum,
    this.pipSize = 13,
    super.key,
  });

  /// How many are taken, including any above the ceiling.
  final int pips;

  /// Where the rules stop.
  final int maximum;

  /// The diameter of one dot. The gaps and the ceiling mark scale with it.
  final double pipSize;

  @override
  Widget build(BuildContext context) {
    final drawn = math.max(pips, maximum);
    final reached = pips >= maximum;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < drawn; i++) ...[
          if (i == maximum) _CeilingMark(reached: reached, pipSize: pipSize),
          _Pip(filled: i < pips, surplus: i >= maximum, size: pipSize),
        ],
        // ⚠️ **A ceiling nothing has passed still gets its mark**, which is how
        // an untouched proficiency says where it would stop. It is also the
        // whole of a `0/0` row: no dots, one mark, nowhere to go.
        if (drawn == maximum) _CeilingMark(reached: reached, pipSize: pipSize),
      ],
    );
  }
}

/// One pip: filled in `primary`, surplus in `error`, empty as an outline ring
/// — and, under a palette that carries one, an empty ring **screened** rather
/// than left hollow.
///
/// A pip is already a dot, so a halftone inside one is the cheapest place in
/// the spike to say *this exists and is not filled* with ink rather than with
/// absence. [ScreenTone.fill] draws nothing where the palette supplies no
/// screen, which leaves the ring exactly as it was.
class _Pip extends StatelessWidget {
  const _Pip({
    required this.filled,
    required this.surplus,
    required this.size,
  });

  final bool filled;
  final bool surplus;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // The ring, and the inset that keeps a screen off it, are fractions of the
    // dot rather than constants — a pip drawn at eight points with a
    // 1.5-point ring is mostly ring.
    final ring = size * 1.5 / 13;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size * 2 / 13),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? (surplus ? colors.error : colors.primary)
              : Colors.transparent,
          border: filled
              ? null
              : Border.all(color: colors.outline, width: ring),
        ),
        // ⚠️ Inset by the ring's own width. `BoxDecoration` paints its border
        // *behind* the child, so a screen drawn edge to edge would punch dots
        // through the ring that is holding the pip together.
        child: filled
            ? null
            : Padding(
                padding: EdgeInsets.all(ring),
                child: const ClipOval(child: ScreenTone.fill()),
              ),
      ),
    );
  }
}

/// The ceiling itself, drawn between the last pip the rules allow and the
/// first one they do not. It fills when the ceiling has been reached, so
/// *"this is as far as this class goes"* is visible without counting.
class _CeilingMark extends StatelessWidget {
  const _CeilingMark({required this.reached, required this.pipSize});

  final bool reached;
  final double pipSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pipSize * 3 / 13),
      child: SizedBox(
        // A hair proud of the dots it stands between, so it reads as a stop
        // rather than as another mark in the row.
        width: math.max(1.5, pipSize * 2 / 13),
        height: pipSize * 15 / 13,
        child: ColoredBox(color: reached ? colors.primary : colors.outline),
      ),
    );
  }
}
