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

/// The rail that says everything about one row, and edits it.
///
/// A dense table can only be dense because it is not also a form. Everything a
/// row cannot afford to draw — the caveat in full, what `authored` and
/// `derived` mean for whether an edit survives, the reason a field is
/// unavailable, the control itself — lives here, for exactly one row at a
/// time.
///
/// ⚠️ **Never `TextField(enabled: false)`.** A disabled `TextField` draws its
/// own text at M3's 0.38 disabled opacity, refuses selection, and greys out any
/// suffix icon it carries. A value you cannot read and cannot copy is not a
/// value that has been *shown* to you. The read-only case here is a
/// `SelectableText` in a box that looks like a field and behaves like text.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/ledger/ledger_edits.dart';
import 'package:ui_spikes/ledger/ledger_row.dart';

/// Everything about [row], and the control that changes it.
class DetailRail extends StatefulWidget {
  /// Shows [row], reporting edits through [onWrite] and [onReset].
  const DetailRail({
    required this.edits,
    required this.onWrite,
    required this.onReset,
    this.row,
    super.key,
  });

  /// Pending edits, which decide the value shown and whether Reset appears.
  final LedgerEdits edits;

  /// Called with a row id and its new value.
  final void Function(String id, String value) onWrite;

  /// Called with a row id whose edit should be dropped.
  final ValueChanged<String> onReset;

  /// The selected row, or null when nothing is selected.
  final LedgerRow? row;

  @override
  State<DetailRail> createState() => _DetailRailState();
}

class _DetailRailState extends State<DetailRail> {
  final TextEditingController _controller = TextEditingController();

  /// The row the controller currently holds text for.
  String? _syncedId;

  /// The last value this rail put into the world, so that a rebuild caused by
  /// the person's own typing can be told apart from one caused by undo.
  String? _pushed;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant DetailRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// ⚠️ Every path that changes a value comes through here or [_replace], and
  /// neither is reachable from `build`. Setting controller text during a build
  /// is how undo ends up fighting the caret.
  void _sync() {
    final row = widget.row;
    final value = row == null ? null : _editableValue(row, widget.edits);
    if (row == null || value == null) {
      _syncedId = null;
      _pushed = null;
      return;
    }
    if (_syncedId == row.id && value == _pushed) return;
    _syncedId = row.id;
    _pushed = value;
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  /// From the text field: the controller already holds [value], so record it
  /// and leave the caret alone.
  void _typed(String id, String value) {
    _pushed = value;
    widget.onWrite(id, value);
  }

  /// From a stepper or a reset: the controller does *not* hold the new value,
  /// so clear the marker and let [_sync] rewrite it on the next build.
  void _replace(String id, String value) {
    _pushed = null;
    widget.onWrite(id, value);
  }

  void _resetRow(String id) {
    _pushed = null;
    widget.onReset(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = widget.row;
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(left: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: row == null
          ? const _Empty()
          : ListView(
              primary: false,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                switch (row) {
                  final FieldRow field => _FieldDetail(
                    row: field,
                    controller: _controller,
                    changed: widget.edits.isChanged(field.id),
                    onTyped: _typed,
                    onReset: _resetRow,
                  ),
                  final PipRow pip => _PipDetail(
                    row: pip,
                    controller: _controller,
                    pips:
                        int.tryParse(widget.edits[pip.id] ?? '') ??
                        pip.proficiency.pips,
                    changed: widget.edits.isChanged(pip.id),
                    onTyped: _typed,
                    onStep: _replace,
                    onReset: _resetRow,
                  ),
                  final ItemRow item => _ItemDetail(row: item),
                },
              ],
            ),
    );
  }
}

/// The value the rail's text field should hold, or null when the row is not
/// something this spike lets anyone type into.
String? _editableValue(LedgerRow row, LedgerEdits edits) => switch (row) {
  final FieldRow field =>
    field.field.enabled ? edits[row.id] ?? field.field.stored : null,
  final PipRow pip => edits[row.id] ?? '${pip.proficiency.pips}',
  ItemRow() => null,
};

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Select a row to see the whole of it, and to edit it.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _FieldDetail extends StatelessWidget {
  const _FieldDetail({
    required this.row,
    required this.controller,
    required this.changed,
    required this.onTyped,
    required this.onReset,
  });

  final FieldRow row;
  final TextEditingController controller;
  final bool changed;
  final void Function(String id, String value) onTyped;
  final ValueChanged<String> onReset;

  @override
  Widget build(BuildContext context) {
    final field = row.field;
    final unit = field.unit ?? '';
    final arithmetic = row.arithmetic;
    final caveat = row.caveat;
    final derived = field.source == FieldSource.derived;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(text: row.label),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StatCell(
                heading: 'STORED',
                value: '${field.stored}$unit',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCell(
                heading: 'IN GAME',
                value: '${row.inGame ?? field.stored}$unit',
                highlighted: row.differsInGame,
              ),
            ),
          ],
        ),
        if (arithmetic != null) ...[
          const SizedBox(height: 12),
          _Paragraph(text: arithmetic),
        ],
        if (caveat != null) ...[
          const SizedBox(height: 10),
          _Caveat(text: caveat),
        ],
        const SizedBox(height: 10),
        _Paragraph(
          text: derived
              ? 'Derived. The engine recomputes this when the save is loaded, '
                    'so an edit here is provisional until it has been checked '
                    'in game.'
              : 'Authored. The engine leaves this alone, so what you write is '
                    'what the record keeps.',
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        if (field.enabled)
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Stored value',
              suffixText: unit.isEmpty ? null : unit,
              helperText: field.anomalous
                  ? 'The class cannot allocate this, but the record holds it. '
                        'Editable on purpose: a value you cannot touch is one '
                        'you cannot correct.'
                  : null,
            ),
            onChanged: (value) => onTyped(row.id, value),
          )
        else ...[
          _ReadOnlyValue(text: '${field.stored}$unit'),
          const SizedBox(height: 8),
          _Paragraph(
            text: field.available
                ? 'Read-only. Nothing in the file holds this — the engine '
                      'works it out every time it draws the sheet.'
                : 'Read-only. This class cannot allocate the value, and the '
                      'record does not hold one, so there is nothing here to '
                      'correct.',
          ),
        ],
        if (changed) ...[
          const SizedBox(height: 12),
          _ResetLine(
            was: '${field.stored}$unit',
            onReset: () => onReset(row.id),
          ),
        ],
      ],
    );
  }
}

class _PipDetail extends StatelessWidget {
  const _PipDetail({
    required this.row,
    required this.controller,
    required this.pips,
    required this.changed,
    required this.onTyped,
    required this.onStep,
    required this.onReset,
  });

  final PipRow row;
  final TextEditingController controller;
  final int pips;
  final bool changed;
  final void Function(String id, String value) onTyped;
  final void Function(String id, String value) onStep;
  final ValueChanged<String> onReset;

  @override
  Widget build(BuildContext context) {
    final maximum = row.proficiency.maximum;
    final over = pips > maximum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(text: row.label),
        const SizedBox(height: 12),
        _StatCell(
          heading: 'PIPS',
          value: '$pips / $maximum',
          alarming: over,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton.outlined(
              onPressed: pips <= 0 ? null : () => onStep(row.id, '${pips - 1}'),
              tooltip: 'One pip fewer',
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 8),
            // ⚠️ The stepper clamps and the field below does not, and that is
            // the whole point rather than an inconsistency: the ceiling is a
            // rule about what may be *allocated*, not about what a record on
            // disk is allowed to contain.
            IconButton.outlined(
              onPressed: pips >= maximum
                  ? null
                  : () => onStep(row.id, '${pips + 1}'),
              tooltip: 'One pip more',
              icon: const Icon(Icons.add),
            ),
            const Spacer(),
            Text(
              'ceiling $maximum',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Stored pips',
            helperText:
                'The buttons stop at $maximum. This field does not — a record '
                'that already holds more has to be typeable to be fixable.',
          ),
          onChanged: (value) => onTyped(row.id, value),
        ),
        if (over) ...[
          const SizedBox(height: 12),
          _Alarm(text: 'Above the ceiling of $maximum.'),
        ],
        if (changed) ...[
          const SizedBox(height: 12),
          _ResetLine(
            was: '${row.proficiency.pips}',
            onReset: () => onReset(row.id),
          ),
        ],
      ],
    );
  }
}

class _ItemDetail extends StatelessWidget {
  const _ItemDetail({required this.row});

  final ItemRow row;

  @override
  Widget build(BuildContext context) {
    final item = row.item;
    final charges = item.charges;
    final slot = item.slot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(text: item.name),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StatCell(heading: 'QUANTITY', value: '${item.quantity}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCell(
                heading: 'CHARGES',
                value: charges == null ? '—' : '$charges',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Paragraph(
          text: slot == null
              ? 'Loose in the backpack.'
              : 'Equipped in the $slot slot.',
        ),
        if (!item.identified) ...[
          const SizedBox(height: 10),
          const _Caveat(
            text:
                'Unidentified, so the game shows this by its generic name '
                'rather than the one above.',
          ),
        ],
        if (item.stolen) ...[
          const SizedBox(height: 10),
          const _Caveat(text: 'Flagged stolen. Shops will refuse to buy it.'),
        ],
        if (item.undroppable) ...[
          const SizedBox(height: 10),
          const _Caveat(text: 'Undroppable. It cannot be removed in game.'),
        ],
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        // Items are read-only in this spike, and the rail says so rather than
        // offering a control that would not be wired to anything.
        const _Paragraph(
          text:
              'Inventory editing is out of scope for this spike. The point '
              'here is that a slot, a stack and a flag all read in the same '
              'grammar as a stat.',
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// One of the two numbers, big enough to read across a desk.
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.heading,
    required this.value,
    this.highlighted = false,
    this.alarming = false,
  });

  final String heading;
  final String value;
  final bool highlighted;
  final bool alarming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (background, foreground) = switch ((highlighted, alarming)) {
      (_, true) => (colors.errorContainer, colors.onErrorContainer),
      (true, _) => (colors.tertiaryContainer, colors.onTertiaryContainer),
      _ => (colors.surfaceContainerHighest, colors.onSurface),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: theme.textTheme.labelSmall?.copyWith(color: foreground),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The caveat, in full and never truncated — the ⓘ in the table is the same
/// sentence, and this is where it goes when a person wants to keep reading it.
class _Caveat extends StatelessWidget {
  const _Caveat({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.info_outline,
            size: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: _Paragraph(text: text)),
      ],
    );
  }
}

class _Alarm extends StatelessWidget {
  const _Alarm({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.error_outline,
            size: 13,
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

/// A field that can be read and copied but not written.
class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(text, style: theme.textTheme.bodyLarge),
    );
  }
}

class _ResetLine extends StatelessWidget {
  const _ResetLine({required this.was, required this.onReset});

  final String was;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'was $was',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(onPressed: onReset, child: const Text('Reset')),
      ],
    );
  }
}
