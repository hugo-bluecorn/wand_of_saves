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

/// The row grammar every Ledger screen reuses.
///
/// ## The columns are the thesis
///
/// ```text
/// │ ▎⚠ │ THAC0 (base)                    │ STORED │ IN GAME │ OWNER   │ ⓘ │
/// │    │   stored 15, −3 from Strength 19│     15 │  ⟨ 12 ⟩ │ derived │   │
/// ```
///
/// A savegame stores *base* values and the engine draws something else. That
/// is the one fact this application exists to make safe to act on, so it is
/// the **column structure** rather than a hint, a hover or a paragraph. Both
/// numbers are on screen at all times and cannot be confused for each other:
/// when they differ, the drawn one is a `tertiaryContainer` pill — an M3
/// container pair, so ≥4.5:1 comes for free — and when they agree it is the
/// same figure in `onSurfaceVariant`.
///
/// ## Three states, and none of them is an opacity
///
/// | state | gutter | label | second line |
/// |---|---|---|---|
/// | normal | — | `onSurface` | the arithmetic, wrapped |
/// | unavailable | — | `onSurfaceVariant` | `— unavailable to this class` |
/// | anomalous | 3 px `error` bar | `onSurface`, full | `⚠ held anyway` |
///
/// ⚠️ **Dimming is by role, never by opacity.** M3's 0.38 disabled opacity is
/// precisely the contrast failure that makes a greyed field unreadable rather
/// than merely inactive, and an unavailable row here is still a row a person
/// has to be able to read — that is how they find out *why* it is grey.
///
/// Colour never carries a state on its own either: every one of the three says
/// what it is in words, on the row's own second line.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/ledger/ledger_edits.dart';
import 'package:ui_spikes/ledger/ledger_row.dart';

/// A scrolling table of [blocks] under one sticky column header.
class LedgerTable extends StatelessWidget {
  /// Draws [blocks] with [columns] as the headings for the three value cells.
  const LedgerTable({
    required this.blocks,
    required this.columns,
    required this.edits,
    required this.onSelect,
    this.selectedId,
    super.key,
  });

  /// What to draw.
  final List<LedgerBlock> blocks;

  /// What the three trailing columns mean.
  final LedgerColumns columns;

  /// Pending edits, which decide each row's shown value and gutter dot.
  final LedgerEdits edits;

  /// Called with the row a person clicked.
  final ValueChanged<LedgerRow> onSelect;

  /// The row the detail rail is showing, if any.
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final widths = _widthsFor(context, columns);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Outside the ListView on purpose: a header that scrolls away is a
        // header that stops answering "which column is this?" after one turn
        // of the wheel, which on a fifty-row table is immediately.
        _ColumnHeader(columns: columns, widths: widths),
        const Divider(),
        Expanded(
          child: ListView(
            primary: false,
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              for (final block in blocks) ...[
                _BlockHeading(block: block),
                for (final row in block.rows)
                  _RowTile(
                    row: row,
                    widths: widths,
                    selected: row.id == selectedId,
                    pending: edits[row.id],
                    onTap: () => onSelect(row),
                  ),
                const Divider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The width of the three trailing cells, already text-scaled.
typedef _Widths = ({double first, double second, double third});

const double _gutterWidth = 14;
const double _infoWidth = 26;
const double _selectionBar = 2;

/// ⚠️ Scaled by the text scaler rather than fixed. A numeric column at a fixed
/// 64 px clips its own figures the moment someone turns the system text size
/// up, and the label column beside it is `Expanded` so it absorbs the loss.
_Widths _widthsFor(BuildContext context, LedgerColumns columns) {
  final scaler = MediaQuery.textScalerOf(context);
  return switch (columns) {
    LedgerColumns.fields => (
      first: scaler.scale(64),
      second: scaler.scale(88),
      third: scaler.scale(78),
    ),
    LedgerColumns.items => (
      first: scaler.scale(52),
      second: scaler.scale(72),
      third: scaler.scale(132),
    ),
  };
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.columns, required this.widths});

  final LedgerColumns columns;
  final _Widths widths;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final fields = columns == LedgerColumns.fields;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _selectionBar + _gutterWidth,
        10,
        8,
        6,
      ),
      child: Row(
        children: [
          Expanded(child: Text(fields ? 'FIELD' : 'ITEM', style: style)),
          _HeaderCell(width: widths.first, label: columns.first, style: style),
          _HeaderCell(
            width: widths.second,
            label: columns.second,
            style: style,
            // The one sentence this whole spike is an argument for, put where
            // the argument is actually being made.
            caveat: fields
                ? 'A savegame stores base values; the engine draws something '
                      'else. Both columns are always filled, so neither number '
                      'is ever the one you did not see.'
                : null,
          ),
          _HeaderCell(width: widths.third, label: columns.third, style: style),
          const SizedBox(width: _infoWidth),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.width,
    required this.label,
    required this.style,
    this.caveat,
  });

  final double width;
  final String label;
  final TextStyle? style;
  final String? caveat;

  @override
  Widget build(BuildContext context) {
    final caveat = this.caveat;
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(label, style: style, textAlign: TextAlign.end),
          ),
          if (caveat != null) ...[
            const SizedBox(width: 3),
            _Info(caveat: caveat, size: 12),
          ],
        ],
      ),
    );
  }
}

class _BlockHeading extends StatelessWidget {
  const _BlockHeading({required this.block});

  final LedgerBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = block.note;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _selectionBar + _gutterWidth,
        16,
        12,
        6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.title.toUpperCase(), style: theme.textTheme.titleSmall),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 24),
              child: Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dispatches on the row kind. Exhaustive over the sealed hierarchy, so a
/// fourth kind of row is a compile error here rather than a blank cell.
class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.row,
    required this.widths,
    required this.selected,
    required this.onTap,
    this.pending,
  });

  final LedgerRow row;
  final _Widths widths;
  final bool selected;
  final VoidCallback onTap;
  final String? pending;

  @override
  Widget build(BuildContext context) => switch (row) {
    final FieldRow field => _FieldRowTile(
      row: field,
      widths: widths,
      selected: selected,
      onTap: onTap,
      pending: pending,
    ),
    final PipRow pip => _PipRowTile(
      row: pip,
      widths: widths,
      selected: selected,
      onTap: onTap,
      pending: pending,
    ),
    final ItemRow item => _ItemRowTile(
      row: item,
      widths: widths,
      selected: selected,
      onTap: onTap,
    ),
  };
}

class _FieldRowTile extends StatelessWidget {
  const _FieldRowTile({
    required this.row,
    required this.widths,
    required this.selected,
    required this.onTap,
    this.pending,
  });

  final FieldRow row;
  final _Widths widths;
  final bool selected;
  final VoidCallback onTap;
  final String? pending;

  @override
  Widget build(BuildContext context) {
    final field = row.field;
    final unit = field.unit ?? '';
    final stored = '${pending ?? field.stored}$unit';
    final inGame = '${row.inGame ?? pending ?? field.stored}$unit';
    final derived = field.source == FieldSource.derived;
    final greyed = !field.available && !field.anomalous;
    return _RowShell(
      widths: widths,
      selected: selected,
      anomalous: field.anomalous,
      changed: pending != null,
      onTap: onTap,
      caveat: row.caveat,
      semanticLabel: [
        row.label,
        'stored $stored',
        'in game $inGame',
        if (derived) 'derived by the engine' else 'authored',
        if (field.anomalous) 'anomalous, still editable',
        if (greyed) 'unavailable to this class',
        if (pending != null) 'edited, not yet saved',
      ].join(', '),
      title: _FieldLabel(row: row, selected: selected),
      first: _Figure(
        text: stored,
        tone: greyed ? _FigureTone.muted : _FigureTone.normal,
        strong: pending != null,
      ),
      // The pill is computed against the *pending* value, not the stored one,
      // so editing THAC0 to 12 makes it vanish. That is the honest answer:
      // there is no longer a difference to point at.
      second: inGame == stored
          ? _Figure(text: inGame, tone: _FigureTone.muted)
          : _Pill(text: inGame, tone: _PillTone.inGame),
      third: derived
          ? const _Pill(text: 'derived', tone: _PillTone.derived)
          : const _Caption(text: 'authored'),
    );
  }
}

class _PipRowTile extends StatelessWidget {
  const _PipRowTile({
    required this.row,
    required this.widths,
    required this.selected,
    required this.onTap,
    this.pending,
  });

  final PipRow row;
  final _Widths widths;
  final bool selected;
  final VoidCallback onTap;
  final String? pending;

  @override
  Widget build(BuildContext context) {
    final maximum = row.proficiency.maximum;
    final pips = int.tryParse(pending ?? '') ?? row.proficiency.pips;
    final over = pips > maximum;
    return _RowShell(
      widths: widths,
      selected: selected,
      anomalous: over,
      changed: pending != null,
      onTap: onTap,
      // ⚠️ The ceiling is *stated*, never merely enforced. `2/3` says what is
      // possible; a stepper that silently refuses a fourth press does not.
      caveat: over
          ? 'Above the ceiling of $maximum. The stepper will not go here, but '
                'the rail will, because a value you cannot type is a value you '
                'cannot correct.'
          : null,
      semanticLabel: [
        row.label,
        '$pips of $maximum pips',
        if (over) 'above the ceiling',
        if (pending != null) 'edited, not yet saved',
      ].join(', '),
      title: _PipLabel(name: row.label, pips: pips, maximum: maximum),
      first: _Figure(
        text: '$pips/$maximum',
        tone: over ? _FigureTone.error : _FigureTone.normal,
        strong: pending != null,
      ),
      second: const _Figure(text: '—', tone: _FigureTone.muted),
      third: const _Caption(text: 'authored'),
    );
  }
}

class _ItemRowTile extends StatelessWidget {
  const _ItemRowTile({
    required this.row,
    required this.widths,
    required this.selected,
    required this.onTap,
  });

  final ItemRow row;
  final _Widths widths;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = row.item;
    final flags = [
      if (!item.identified) 'unidentified',
      if (item.stolen) 'stolen',
      if (item.undroppable) 'undroppable',
    ];
    final charges = item.charges;
    return _RowShell(
      widths: widths,
      selected: selected,
      anomalous: false,
      changed: false,
      onTap: onTap,
      semanticLabel: [
        row.label,
        if (item.slot != null) 'in the ${item.slot} slot',
        '${item.quantity} carried',
        if (charges != null) '$charges charges',
        ...flags,
      ].join(', '),
      title: _ItemLabel(item: item, selected: selected),
      first: _Figure(text: '${item.quantity}'),
      second: _Figure(
        text: charges == null ? '—' : '$charges',
        tone: charges == null ? _FigureTone.muted : _FigureTone.normal,
      ),
      third: _Caption(text: flags.isEmpty ? '—' : flags.join(', ')),
    );
  }
}

/// The shape every row shares: selection, gutter, label, three cells, ⓘ.
class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.widths,
    required this.selected,
    required this.anomalous,
    required this.changed,
    required this.onTap,
    required this.semanticLabel,
    required this.title,
    required this.first,
    required this.second,
    required this.third,
    this.caveat,
  });

  final _Widths widths;
  final bool selected;
  final bool anomalous;
  final bool changed;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget title;
  final Widget first;
  final Widget second;
  final Widget third;
  final String? caveat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final caveat = this.caveat;
    // ⚠️ One sentence for the whole row, not four orphan cells. A screen
    // reader stepping down this table should hear "THAC0 (base), stored 15,
    // in game 12, derived" rather than "THAC0 (base)" … "15" … "12".
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colors.surfaceContainerHighest : null,
            // Always allocated so that selecting a row never shifts its text.
            // Low-chroma on purpose: the two provenance pills are the only
            // saturated marks in the table and nothing else may compete.
            border: Border(
              left: BorderSide(
                color: selected ? colors.primary : Colors.transparent,
                width: _selectionBar,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 5, 8, 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Gutter(anomalous: anomalous, changed: changed),
                Expanded(child: title),
                SizedBox(
                  width: widths.first,
                  child: Align(alignment: Alignment.centerRight, child: first),
                ),
                SizedBox(
                  width: widths.second,
                  child: Align(alignment: Alignment.centerRight, child: second),
                ),
                SizedBox(
                  width: widths.third,
                  child: Align(alignment: Alignment.centerRight, child: third),
                ),
                SizedBox(
                  width: _infoWidth,
                  child: caveat == null ? null : _Info(caveat: caveat),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Gutter extends StatelessWidget {
  const _Gutter({required this.anomalous, required this.changed});

  final bool anomalous;
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: _gutterWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 3,
            height: 15,
            child: anomalous
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.error,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: SizedBox(
              width: 6,
              height: 6,
              child: changed
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.row, required this.selected});

  final FieldRow row;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final field = row.field;
    final greyed = !field.available && !field.anomalous;
    final arithmetic = row.arithmetic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            // Role, not opacity. See the library doc comment.
            color: greyed ? colors.onSurfaceVariant : colors.onSurface,
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
        if (field.anomalous)
          const _StatusLine(
            icon: Icons.error_outline,
            text: 'the record holds it anyway — still editable',
            tone: _StatusTone.error,
          )
        else if (greyed)
          const _StatusLine(
            icon: Icons.remove,
            text: 'unavailable to this class',
            tone: _StatusTone.muted,
          ),
        if (arithmetic != null) _Arithmetic(text: arithmetic),
      ],
    );
  }
}

class _PipLabel extends StatelessWidget {
  const _PipLabel({
    required this.name,
    required this.pips,
    required this.maximum,
  });

  final String name;
  final int pips;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: theme.textTheme.bodyMedium),
        _PipMarks(pips: pips, maximum: maximum),
      ],
    );
  }
}

class _ItemLabel extends StatelessWidget {
  const _ItemLabel({required this.item, required this.selected});

  final DemoItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slot = item.slot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
        if (slot != null)
          _StatusLine(
            icon: Icons.check_circle_outline,
            text: 'equipped, $slot',
            tone: _StatusTone.muted,
          ),
      ],
    );
  }
}

/// The pips, drawn as slots so that the ceiling is a thing you can see rather
/// than a rule you find out about by being refused.
class _PipMarks extends StatelessWidget {
  const _PipMarks({required this.pips, required this.maximum});

  final int pips;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          for (var slot = 0; slot < maximum; slot++)
            _Pip(color: slot < pips ? colors.primary : null),
          // Over the cap the extra pips are drawn past the ceiling mark rather
          // than hidden or clamped away — the record holds them, and a record
          // this app will not show is a record it cannot help anyone fix.
          if (pips > maximum) ...[
            SizedBox(
              width: 1,
              height: 11,
              child: ColoredBox(color: colors.error),
            ),
            const SizedBox(width: 3),
            for (var extra = maximum; extra < pips; extra++)
              _Pip(color: colors.error),
          ],
        ],
      ),
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: SizedBox(
        width: 9,
        height: 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            border: color == null
                ? Border.all(color: Theme.of(context).colorScheme.outline)
                : null,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// The sum, on the row, always visible.
class _Arithmetic extends StatelessWidget {
  const _Arithmetic({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ⚠️ No `maxLines`, no `overflow`. The application's own helper line
    // ellipsises — a capture shows `stored 12, +4/level from Constit…` — and a
    // sum that cannot be read is worse than no sum at all, because it looks as
    // though the question has been answered.
    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 16),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

enum _StatusTone { error, muted }

/// A glyph and a word, because a colour on its own is not a state.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.text,
    required this.tone,
  });

  final IconData icon;
  final String text;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (tone) {
      _StatusTone.error => theme.colorScheme.error,
      _StatusTone.muted => theme.colorScheme.onSurfaceVariant,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

enum _FigureTone { normal, muted, error }

/// A number in the value columns. Tabular figures come from the text theme,
/// which is what turns a stack of these into a column.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.text,
    this.tone = _FigureTone.normal,
    this.strong = false,
  });

  final String text;
  final _FigureTone tone;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (tone) {
      _FigureTone.normal => theme.colorScheme.onSurface,
      _FigureTone.muted => theme.colorScheme.onSurfaceVariant,
      _FigureTone.error => theme.colorScheme.error,
    };
    return Text(
      text,
      textAlign: TextAlign.end,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: color,
        fontWeight: strong ? FontWeight.w600 : null,
      ),
    );
  }
}

/// A word rather than a number — `authored`, or an item's flags.
class _Caption extends StatelessWidget {
  const _Caption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.end,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

enum _PillTone { inGame, derived }

/// An M3 container pair, which is where the ≥4.5:1 comes from: the pairs are
/// generated to satisfy it, so no colour here was hand-picked and checked.
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.tone});

  final String text;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (background, foreground) = switch (tone) {
      _PillTone.inGame => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      _PillTone.derived => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          text,
          textAlign: TextAlign.end,
          style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

/// The caveat, and only ever the caveat.
class _Info extends StatelessWidget {
  const _Info({required this.caveat, this.size = 14});

  final String caveat;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: caveat,
      child: Icon(
        Icons.info_outline,
        size: size,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
