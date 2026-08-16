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
/// G1's record, drawn compactly, and **the one thing in these spikes that was
/// not in the brief.** The brief pinned the Combat, Resistances and Condition
/// panels as the sheet already draws them; measured, those three come to about
/// 1,700 points — roughly twice the whole window, before the item search and
/// the backpack start. So the band could not exist as specified, and the user
/// chose this: the same rows, one line each, without the sum line and the ⓘ.
///
/// ⚠️ **The pin is long gone, and the page is now compact everywhere.** For a
/// day the page carried two densities — Combat and the Resistances drawn this
/// way, everything around them at full height — which read as an accident
/// rather than as a decision. The user's resolution was to make it one: **every
/// panel on the merged page comes through this file**, Proficiencies included.
///
/// ⚠️ **What that spends, knowingly.** A full row carries a second line — the
/// arithmetic *with its amount*, the two limits, the ⓘ, the finding's own
/// sentence — and this project's recorded preference is that a sum belongs on
/// screen. Compact keeps the value and the disagreement and moves the rest
/// **one tap away, into the editor**, which is where somebody asking *why*
/// already goes. Spent, not overlooked.
///
/// ⚠️ **A second rendering, and deliberately not a second copy.** R1 of the
/// study forbids a summary strip, and the reason it gives is duplication — a
/// strip showing armour class beside a Combat panel also showing armour class.
/// Nothing on the merged page is drawn twice: this *is* the page's rendering of
/// the record, not a précis sitting above one.
///
/// The rows are read out of [indexOf] rather than authored, so a field added to
/// the projection appears here without this file being touched.
library;

import 'package:flutter/material.dart';
import 'package:wand_of_saves/ui/character/findings.dart';
import 'package:wand_of_saves/ui/character/pip_meter.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';
import 'package:wand_of_saves/ui/core/palette_finish.dart';
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
    this.inlineEditor,
    this.foldInto = const {},
    this.columns = 1,
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

  /// What to draw beneath a row that is open, the same hook `sheetPanelsOf`
  /// takes — so a number edits where it lives, exactly as a full row does.
  final Widget? Function(Subject subject)? inlineEditor;

  /// Groups that join another panel's rows instead of getting a panel of their
  /// own, exactly as `sheetPanelsOf` means it.
  ///
  /// `{'Condition': 'Character'}` puts fatigue and intoxication at the end of
  /// the Character panel and leaves no Condition panel at all. Empty by
  /// default.
  final Map<String, String> foldInto;

  /// How many columns a [CompactStyle.lines] panel splits its rows across.
  ///
  /// One by default. More is for a panel drawn across the full width of a page
  /// rather than inside one of its columns: Combat is eighteen rows, which is
  /// a very long single file under a page that is twice as wide as it is.
  ///
  /// ⚠️ **Split in reading order, not balanced by height.** The rows go 1–6,
  /// 7–12, 13–18 down each column in turn; nothing measures anything. An
  /// algorithm balancing them is D17's zigzag, which this project has paid for
  /// once already.
  final int columns;

  @override
  Widget build(BuildContext context) {
    final index = indexOf(character);
    final flagged = <String, Finding>{
      for (final finding in findingsFor(character))
        if (finding.subject case FieldSubject(:final entry)) entry.key: finding,
    };

    // ⚠️ Gathered before anything is drawn, because folding means one panel
    // can hold more than one group's worth of rows.
    final gathered = <String, List<FieldEntry>>{};
    final notes = <String, String?>{};
    for (final entry in index) {
      final panel = foldInto[entry.group.title] ?? entry.group.title;
      if (!panels.containsKey(panel)) continue;
      (gathered[panel] ??= []).add(entry);
      notes[panel] ??= entry.group.note;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (final MapEntry(key: title, value: style) in panels.entries)
          if (gathered[title] case final List<FieldEntry> rows
              when rows.isNotEmpty)
            PanelCard(
              title: title,
              // ⚠️ The group's own qualifier is kept. It is not arithmetic and
              // it is not per row — it says what a whole panel means, and
              // dropping it for density would silently take a sentence off the
              // page rather than move it behind a tap.
              note: notes[title],
              children: switch (style) {
                CompactStyle.lines => _lines(rows, flagged),
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
                  // ⚠️ Under the whole run rather than under one pill: these
                  // flow across and wrap, so "beneath the row" has no meaning
                  // for a pill that shares its line with five others.
                  for (final entry in rows)
                    ?inlineEditor?.call(FieldSubject(entry)),
                ],
              },
            ),
      ],
    );
  }

  /// [rows] as lines, in one column or split across [columns] of them.
  List<Widget> _lines(List<FieldEntry> rows, Map<String, Finding> flagged) {
    final cells = [
      for (final entry in rows)
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CompactRow(
              entry: entry,
              finding: flagged[entry.key],
              rulesBind: rulesBind,
              onTap: () => onOpen(FieldSubject(entry)),
            ),
            ?inlineEditor?.call(FieldSubject(entry)),
          ],
        ),
    ];
    if (columns <= 1) return cells;

    final perColumn = (cells.length / columns).ceil();
    return [
      Row(
        // ⚠️ `start`, so a column with fewer rows — or one with an editor open
        // in it — does not stretch its neighbours to match.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var column = 0; column < columns; column++) ...[
            if (column > 0) const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells
                    .skip(column * perColumn)
                    .take(perColumn)
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    ];
  }
}

/// Every proficiency the tables know, as pills that flow across and wrap.
///
/// ⚠️ **The dot language survives the compaction; the numeral does not.** A
/// pip meter is a picture — filled, empty, ceiling, surplus — and replacing
/// twenty-four of them with `2/5` twenty-four times would trade the one
/// rendering on this page that is read at a glance for the one thing a glance
/// cannot do, which is arithmetic. So the dots are the same dots
/// ([PipRow], one copy), drawn small.
///
/// **What each pill drops** is what the full meter says in words beside the
/// dots: `at ceiling`, `not for this class`, the `pips/maximum` numeral. Two of
/// those the dots already state — a row with no dots at all is a proficiency
/// with nowhere to go, and a row whose dots are all filled is one at its
/// ceiling. The third, `over ceiling`, is a **conflict**, so it keeps its word:
/// it is the one state a reader must not have to infer.
class CompactProficiencies extends StatelessWidget {
  /// Draws [character]'s proficiencies.
  const CompactProficiencies({
    required this.character,
    required this.onOpen,
    this.inlineEditor,
    super.key,
  });

  /// Whose record this is.
  final SheetCharacter character;

  /// Called when a pill is opened for editing.
  final ValueChanged<Subject> onOpen;

  /// What to draw beneath the run when one of them is open.
  final Widget? Function(Subject subject)? inlineEditor;

  @override
  Widget build(BuildContext context) {
    final all = character.proficiencies;
    if (all.isEmpty) return const SizedBox.shrink();

    return PanelCard(
      title: 'Proficiencies',
      trailing: Tag('${all.length}', caption: 'all editable'),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final proficiency in all)
              _ProficiencyPill(
                proficiency: proficiency,
                onTap: () => onOpen(ProficiencySubject(proficiency)),
              ),
          ],
        ),
        // Under the whole run, for the same reason the flowing numbers do it:
        // "beneath the row" means nothing to a pill sharing its line with five
        // others.
        for (final proficiency in all)
          ?inlineEditor?.call(ProficiencySubject(proficiency)),
      ],
    );
  }
}

/// One proficiency as a pill: its name, and its pips as dots.
class _ProficiencyPill extends StatelessWidget {
  const _ProficiencyPill({required this.proficiency, required this.onTap});

  final SheetProficiency proficiency;
  final VoidCallback onTap;

  /// How big a dot is here. The full meter draws 13; this is a pill in a
  /// wrapping run, and the name beside it is `labelMedium`.
  static const double _pipSize = 8;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final over = proficiency.pips > proficiency.maximum;
    // ⚠️ **A ceiling of zero is not a ceiling reached** — it is how
    // `weapprof.2da` says *not this class*. Muted, and drawn with no dots at
    // all, which is the dot language's own way of saying there is nowhere to
    // go. Drawing the ceiling mark alone would read as a spent limit.
    final unavailable = proficiency.maximum == 0 && !over;
    final ink = switch ((over, unavailable)) {
      (true, _) => colors.error,
      (false, true) => colors.onSurfaceVariant,
      (false, false) => colors.onSurface,
    };

    return Semantics(
      button: true,
      label:
          '${proficiency.name}, ${proficiency.pips} of '
          '${proficiency.maximum} pips${over ? ', above the ceiling' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: PaletteFinish.of(context).radiusOf(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // The same outline-and-corner a neutral `Tag` wears, so a
            // proficiency reads as one of the page's pills rather than as a
            // control of its own kind.
            borderRadius: PaletteFinish.of(context).radiusOf(8),
            border: Border.all(color: over ? colors.error : colors.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ⚠️ **Flexible, and the measurement harness is what caught
                // it.** A `Wrap` hands each child the run's full width and no
                // less, so a pill wider than the column overflows rather than
                // wrapping — and *Scimitar / Wakizashi / Ninjatō* is a real
                // proficiency name twenty-nine characters long. The dots must
                // never be the thing that gives way, so the name is.
                Flexible(
                  child: Text(
                    proficiency.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(color: ink),
                  ),
                ),
                if (!unavailable) ...[
                  const SizedBox(width: 6),
                  PipRow(
                    pips: proficiency.pips,
                    maximum: proficiency.maximum,
                    pipSize: _pipSize,
                  ),
                ],
                if (over) ...[
                  const SizedBox(width: 6),
                  const Tag('over ceiling', tone: TagTone.conflict),
                ],
              ],
            ),
          ),
        ),
      ),
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
