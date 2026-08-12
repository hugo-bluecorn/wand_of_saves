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
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/workbench/tag.dart';

/// What a field holds, what the engine draws instead, what state it is in and
/// — behind an ⓘ — the one thing no number can say.
///
/// A savegame stores *base* values, so `stored` and `in game` are different
/// facts about the same field and both have to be on screen at once. They are
/// the same widget in two tones, always captioned, and never collapsed into
/// one number with a footnote.
class ValueReadout extends StatelessWidget {
  /// Reads out [field].
  const ValueReadout({
    required this.field,
    this.pending,
    this.showState = true,
    super.key,
    this.rulesBind = true,
  });

  /// The field being reported.
  final DemoField field;

  /// An edit not yet written, which makes the stored tag read `25 → 0`.
  final String? pending;

  /// Whether the class restriction is binding, which decides whether the
  /// state word reads as a lock or as a deliberate override.
  final bool rulesBind;

  /// Whether to append the `conflict` / `not for this class` / `read-only`
  /// tag. The side sheet draws that in its own header instead.
  final bool showState;

  @override
  Widget build(BuildContext context) {
    final unit = field.unit ?? '';
    final pendingValue = pending;
    final inGame = field.inGame;
    final caveat = field.caveat;
    final state = showState
        ? stateTagFor(field, rulesBind: rulesBind)
        : null;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tag(
          pendingValue == null
              ? '${field.stored}$unit'
              : '${field.stored}$unit → $pendingValue$unit',
          caption: 'stored',
        ),
        if (pendingValue != null)
          const Tag('not written yet', tone: TagTone.muted),
        if (field.differsInGame && inGame != null)
          Tag('$inGame$unit', caption: 'in game', tone: TagTone.inGame),
        ?state,
        if (caveat != null) _CaveatButton(caveat),
      ],
    );
  }
}

/// The ⓘ. A 500 ms hover, its own semantics from [Tooltip], and a caveat that
/// is one short line rather than a paragraph on the surface.
class _CaveatButton extends StatelessWidget {
  const _CaveatButton(this.caveat);

  final String caveat;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: caveat,
      child: Icon(
        Icons.info_outline,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
