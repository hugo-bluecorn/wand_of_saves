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

/// ⚠️ **THROWAWAY** — see `grid_spike_host.dart`.
///
/// G1's pinned band, drawn compactly, and **the one thing in these spikes that
/// was not in the brief.** The brief pinned the Combat, Resistances and
/// Condition panels as the sheet already draws them; measured, those three come
/// to about 1,700 points — roughly twice the whole window, before the item
/// search and the backpack start. So the band could not exist as specified, and
/// the user chose this: the same rows, one line each, without the sum line and
/// the ⓘ.
///
/// ⚠️ **A second rendering, and deliberately not a second copy.** R1 of the
/// study forbids a summary strip, and the reason it gives is duplication — a
/// strip showing armour class beside a Combat panel also showing armour class.
/// On G1 these three panels appear **nowhere else**: the slow bench holds
/// Character, Abilities, Skills and Proficiencies and nothing more. The number
/// still exists exactly once, and it sits where the items are, which is what R1
/// actually asks for.
///
/// The rows are read out of [indexOf] rather than authored, so a field added to
/// the projection appears here without this file being touched.
library;

import 'package:flutter/material.dart';
import 'package:wand_of_saves/ui/character/findings.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';
import 'package:wand_of_saves/ui/core/panel_card.dart';
import 'package:wand_of_saves/ui/core/screen_tone.dart';
import 'package:wand_of_saves/ui/core/tag.dart';

/// How densely a panel's numbers are drawn.
enum CompactStyle {
  /// One number per line, with room for what the engine draws instead.
  lines,

  /// Every number as a captioned pill, flowing across and wrapping.
  ///
  /// For a panel whose rows are a **set of the same kind of thing** — eleven
  /// resistances, two condition counters — where the label is one word and the
  /// value is one number. A line each would spend three hundred points saying
  /// `0%` eleven times.
  flowing,
}

/// The named panels of [character]'s record, drawn as densely as each allows.
class CompactNumbers extends StatelessWidget {
  /// Draws each panel of [panels] in the style it names, in that order.
  const CompactNumbers({
    required this.character,
    required this.panels,
    required this.rulesBind,
    required this.onOpen,
    super.key,
  });

  /// Whose record this is.
  final SheetCharacter character;

  /// Which panels to draw, by the group title the projection gives them, and
  /// how dense each one may be.
  final Map<String, CompactStyle> panels;

  /// Whether a value past the rules is an error or a deliberate enhancement.
  final bool rulesBind;

  /// Called when a row is opened for editing.
  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
    final index = indexOf(character);
    final flagged = <String, Finding>{
      for (final finding in findingsFor(character))
        if (finding.subject case FieldSubject(:final entry)) entry.key: finding,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (final MapEntry(key: title, value: style) in panels.entries)
          if ([
                for (final entry in index)
                  if (entry.group.title == title) entry,
              ]
              case final List<FieldEntry> rows when rows.isNotEmpty)
            PanelCard(
              title: title,
              children: switch (style) {
                CompactStyle.lines => [
                  for (final entry in rows)
                    _CompactRow(
                      entry: entry,
                      finding: flagged[entry.key],
                      rulesBind: rulesBind,
                      onTap: () => onOpen(FieldSubject(entry)),
                    ),
                ],
                CompactStyle.flowing => [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final entry in rows)
                        _CompactPill(
                          entry: entry,
                          finding: flagged[entry.key],
                          onTap: () => onOpen(FieldSubject(entry)),
                        ),
                    ],
                  ),
                ],
              },
            ),
      ],
    );
  }
}

/// One number as a pill: what it is called, and what is stored.
class _CompactPill extends StatelessWidget {
  const _CompactPill({
    required this.entry,
    required this.onTap,
    this.finding,
  });

  final FieldEntry entry;
  final VoidCallback onTap;
  final Finding? finding;

  @override
  Widget build(BuildContext context) {
    final field = entry.field;
    final unit = field.unit ?? '';
    return InkWell(
      onTap: onTap,
      child: Wrap(
        spacing: 6,
        children: [
          Tag(
            '${field.stored}$unit',
            caption: field.label,
            tone: finding == null ? TagTone.neutral : TagTone.conflict,
          ),
          // ⚠️ Never dropped for density. None of the fields drawn this way
          // has an in-game value today, and one that gained one would have the
          // whole reason this row exists hidden by the layout.
          if (field.differsInGame)
            Tag(
              '${field.inGame}$unit',
              caption: 'in game',
              tone: TagTone.inGame,
            ),
        ],
      ),
    );
  }
}

/// One number, on one line: what it is called, what is stored, and what the
/// engine draws when that differs.
///
/// ⚠️ **What is dropped is what the full row says in a second line** — the
/// arithmetic, the two limits, the finding's sentence. All of it is still one
/// tap away in the editor, which is where somebody who cares about *why*
/// already goes. What must not be dropped is the value and the disagreement,
/// because those are the two things an equip is supposed to move.
class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.entry,
    required this.rulesBind,
    required this.onTap,
    this.finding,
  });

  final FieldEntry entry;
  final bool rulesBind;
  final VoidCallback onTap;
  final Finding? finding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final field = entry.field;
    final unit = field.unit ?? '';
    final mark = finding;
    final tone = mark?.severity == Severity.conflict
        ? colors.error
        : colors.tertiary;
    final live = field.enabledUnder(rulesBind: rulesBind);

    final line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              field.label,
              style: text.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text('${field.stored}$unit', style: text.labelLarge),
          if (field.differsInGame) ...[
            const SizedBox(width: 6),
            Tag(
              '${field.inGame}$unit',
              caption: 'in game',
              tone: TagTone.inGame,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      label: '${field.label}, stored ${field.stored}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: mark == null
              ? null
              : BoxDecoration(
                  border: Border(left: BorderSide(color: tone, width: 3)),
                ),
          padding: EdgeInsets.only(left: mark == null ? 0 : 8),
          child: live ? line : ScreenTone(child: line),
        ),
      ),
    );
  }
}
