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
import 'package:ui_spikes/workbench/palette_finish.dart';

/// The role a [Tag] paints itself in.
///
/// This is one of only two places in the spike where a widget names a
/// `ColorScheme` role directly, and it does so because the mapping is
/// **semantic** rather than stylistic: a tone says what kind of thing the tag
/// is reporting. Every tone also carries a *word*, so none of them relies on
/// colour to be understood.
enum TagTone {
  /// A stored value, a slot, a count. An outline, no fill.
  neutral,

  /// What the engine draws instead of what is stored. Tertiary container.
  inGame,

  /// Something this class cannot have, or a value nothing can write.
  muted,

  /// Something wrong with the record. Error container.
  conflict,

  /// Past what the rules produce, and allowed on purpose. Secondary.
  enhanced,
}

/// A small pill carrying an optional caption and a value.
///
/// `stored 12` and `in game 18` are the same widget in two tones, which is
/// what makes the pair readable as a pair wherever it appears.
class Tag extends StatelessWidget {
  /// Creates a tag reading [label].
  const Tag(
    this.label, {
    this.caption,
    this.tone = TagTone.neutral,
    super.key,
  });

  /// The value, in `labelMedium`.
  final String label;

  /// What the value is, in `labelSmall` before it.
  final String? caption;

  /// Which role to paint.
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (Color? background, Color foreground) = switch (tone) {
      TagTone.neutral => (null, colors.onSurface),
      TagTone.inGame => (colors.tertiaryContainer, colors.onTertiaryContainer),
      TagTone.muted => (null, colors.onSurfaceVariant),
      TagTone.conflict => (colors.errorContainer, colors.onErrorContainer),
      TagTone.enhanced => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
    };
    final captionText = caption;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        // The corner is asked for, not stated: a palette that squares its
        // edges squares these too, and this widget never learns which one it
        // is wearing. See [PaletteFinish].
        borderRadius: PaletteFinish.of(context).radiusOf(8),
        border: background == null ? Border.all(color: colors.outline) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (captionText != null) ...[
              Text(
                captionText,
                style: text.labelSmall?.copyWith(color: foreground),
              ),
              const SizedBox(width: 6),
            ],
            Text(label, style: text.labelMedium?.copyWith(color: foreground)),
          ],
        ),
      ),
    );
  }
}

/// The one word that says what state [field] is in, or null when it is
/// ordinary.
///
/// The order is the point. `anomalous` is checked **first**, because a field
/// the class cannot have but the record holds anyway is a conflict rather
/// than an absence — and this project's own rule is that a value you cannot
/// touch is a value you cannot correct.
Tag? stateTagFor(DemoField field, {bool rulesBind = true}) {
  if (field.anomalous) {
    return const Tag('conflict', tone: TagTone.conflict);
  }
  if (!field.available) {
    // ⚠️ The same fact, but not the same news. While the rules bind it is a
    // lock; with the check off the class still cannot have it and you are
    // allowed to give it anyway, so the word has to stop reading as a refusal.
    return rulesBind
        ? const Tag('not for this class', tone: TagTone.muted)
        : const Tag('beyond the class', tone: TagTone.enhanced);
  }
  if (!field.editable) {
    return const Tag('read-only', tone: TagTone.muted);
  }
  return null;
}
