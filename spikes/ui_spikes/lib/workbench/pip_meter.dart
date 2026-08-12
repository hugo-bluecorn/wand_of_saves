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
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/workbench/screen_tone.dart';
import 'package:ui_spikes/workbench/tag.dart';

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
  final DemoProficiency proficiency;

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
    final drawn = math.max(pips, maximum);
    final over = pips > maximum;

    final meter = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (showName) ...[
            Expanded(child: Text(proficiency.name, style: text.bodyLarge)),
            const SizedBox(width: 12),
          ],
          for (var i = 0; i < drawn; i++) ...[
            if (i == maximum) _CeilingMark(reached: pips >= maximum),
            _Pip(filled: i < pips, surplus: i >= maximum),
          ],
          if (drawn == maximum) _CeilingMark(reached: pips >= maximum),
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
              child: switch ((over, pips == maximum)) {
                (true, _) => const Tag('over ceiling', tone: TagTone.conflict),
                (false, true) => const Tag('at ceiling', tone: TagTone.muted),
                (false, false) => const SizedBox.shrink(),
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

/// One pip: filled in `primary`, surplus in `error`, empty as an outline ring
/// — and, under a palette that carries one, an empty ring **screened** rather
/// than left hollow.
///
/// A pip is already a dot, so a halftone inside one is the cheapest place in
/// the spike to say *this exists and is not filled* with ink rather than with
/// absence. [ScreenTone.fill] draws nothing where the palette supplies no
/// screen, which leaves the ring exactly as it was.
class _Pip extends StatelessWidget {
  const _Pip({required this.filled, required this.surplus});

  final bool filled;
  final bool surplus;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? (surplus ? colors.error : colors.primary)
              : Colors.transparent,
          border: filled ? null : Border.all(color: colors.outline, width: 1.5),
        ),
        // ⚠️ Inset by the ring's own width. `BoxDecoration` paints its border
        // *behind* the child, so a screen drawn edge to edge would punch dots
        // through the ring that is holding the pip together.
        child: filled
            ? null
            : const Padding(
                padding: EdgeInsets.all(1.5),
                child: ClipOval(child: ScreenTone.fill()),
              ),
      ),
    );
  }
}

/// The ceiling itself, drawn between the last pip the rules allow and the
/// first one they do not. It fills when the ceiling has been reached, so
/// *"this is as far as this class goes"* is visible without counting.
class _CeilingMark extends StatelessWidget {
  const _CeilingMark({required this.reached});

  final bool reached;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(
        width: 2,
        height: 15,
        child: ColoredBox(color: reached ? colors.primary : colors.outline),
      ),
    );
  }
}
