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
import 'package:flutter/services.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/workbench/arithmetic_line.dart';
import 'package:ui_spikes/workbench/findings.dart';
import 'package:ui_spikes/workbench/pip_meter.dart';
import 'package:ui_spikes/workbench/tag.dart';
import 'package:ui_spikes/workbench/value_readout.dart';

/// One thing, opened. The side sheet is where an edit is made, and it is the
/// **one place a caveat is shown in full as text** rather than behind an ⓘ.
///
/// The reasoning: on the sheet a caveat competes with sixty other values, so
/// it belongs behind an affordance. Here there is exactly one subject and the
/// player has already said this is the thing they came for — so the sentence
/// that explains why the number is strange gets the room to be read.
///
/// The sheet also carries the spike's editing model, felt rather than
/// described: an edit is *staged*, not written. It shows as `stored 25 → 0`
/// everywhere that field appears, it bumps the app bar's pending count, and
/// where it resolves a finding that finding flips to *will be corrected*.
///
/// For a slot, the sheet **is** the picker: the item, its flags, a quantity
/// stepper and one filter field over the backpack. The predecessor spent a
/// modal dialog and fifty-one controls on that job.
class SideSheet extends StatefulWidget {
  /// Opens [subject].
  const SideSheet({
    required this.subject,
    required this.character,
    required this.rulesBind,
    required this.slotsLeft,
    required this.onApplyField,
    required this.onApplyPips,
    required this.onApplyItem,
    required this.onClose,
    this.pendingText,
    this.pendingPips,
    super.key,
  });

  /// What was opened.
  final Subject subject;

  /// The record it belongs to, which the picker needs to list a backpack.
  final DemoCharacter character;

  /// Stages a new value for a field.
  /// Whether the rules bind. The sheet refuses Apply on a value they would
  /// not produce; with the check off the same value is applied and marked.
  final bool rulesBind;

  /// Proficiency slots still unspent, so the stepper here obeys the same
  /// budget the panel does. Enforcing it on one surface and not the other
  /// would let the sheet quietly overspend what the sheet behind it refuses.
  final int slotsLeft;

  /// Commits a field edit.
  final void Function(FieldEntry entry, String value) onApplyField;

  /// Stages a new pip count, which is allowed to exceed the ceiling.
  final void Function(DemoProficiency proficiency, int pips) onApplyPips;

  /// Stages a slot's replacement and quantity.
  final void Function(DemoItem item, DemoItem? replacement, int quantity)
  onApplyItem;

  /// Closes the sheet.
  final VoidCallback onClose;

  /// An edit already staged for this field, if there is one.
  final String? pendingText;

  /// A pip count already staged for this proficiency, if there is one.
  final int? pendingPips;

  @override
  State<SideSheet> createState() => _SideSheetState();
}

class _SideSheetState extends State<SideSheet> {
  late final TextEditingController _value;
  late final TextEditingController _filter;
  late String _draft;
  late int _pips;
  late int _quantity;
  DemoItem? _replacement;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _draft =
        widget.pendingText ??
        switch (widget.subject) {
          FieldSubject(:final entry) => entry.field.stored,
          ProficiencySubject() => '',
          ItemSubject() => '',
        };
    _pips =
        widget.pendingPips ??
        switch (widget.subject) {
          ProficiencySubject(:final proficiency) => proficiency.pips,
          FieldSubject() => 0,
          ItemSubject() => 0,
        };
    _quantity = switch (widget.subject) {
      ItemSubject(:final item) => item.quantity,
      FieldSubject() => 1,
      ProficiencySubject() => 1,
    };
    _value = TextEditingController(text: _draft);
    _filter = TextEditingController();
  }

  @override
  void dispose() {
    _value.dispose();
    _filter.dispose();
    super.dispose();
  }

  /// Why Apply is refused, or null when it is not.
  ///
  /// ⚠️ **The keystroke is never refused, only the commit.** The field takes
  /// whatever you type; this decides whether it may leave the sheet. Above the
  /// engine's own ceiling it is refused in *both* modes — that is not a choice
  /// a save editor gets to offer, it is a corrupt byte.
  String? get _refusal {
    if (widget.subject case FieldSubject(:final entry)) {
      if (entry.field.impossible(_draft)) {
        return 'The game will not take a value above '
            '${entry.field.gameMaximum}.';
      }
      if (widget.rulesBind && entry.field.beyondRules(_draft)) {
        return 'Beyond anything the rules produce — they reach '
            '${entry.field.rulesMaximum}. Turn the rules check off to keep it.';
      }
    }
    return null;
  }

  void _apply() {
    if (_refusal != null) return;
    switch (widget.subject) {
      case FieldSubject(:final entry):
        widget.onApplyField(entry, _draft);
      case ProficiencySubject(:final proficiency):
        widget.onApplyPips(proficiency, _pips);
      case ItemSubject(:final item):
        widget.onApplyItem(item, _replacement, _quantity);
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHeader(subject: subject, onClose: widget.onClose),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                children: [
                  switch (subject) {
                    FieldSubject(:final entry) => _FieldBody(
                      entry: entry,
                      draft: _draft,
                      pending: widget.pendingText,
                      controller: _value,
                      error: _refusal,
                      rulesBind: widget.rulesBind,
                      onChanged: (value) => setState(() => _draft = value),
                      onSubmitted: _apply,
                    ),
                    ProficiencySubject(:final proficiency) => _ProficiencyBody(
                      proficiency: proficiency,
                      pips: _pips,
                      rulesBind: widget.rulesBind,
                      slotsLeft: widget.slotsLeft,
                      onChanged: (pips) => setState(() => _pips = pips),
                    ),
                    ItemSubject(:final item) => _ItemBody(
                      item: item,
                      character: widget.character,
                      controller: _filter,
                      query: _query,
                      quantity: _quantity,
                      replacement: _replacement,
                      onQuery: (query) => setState(() => _query = query),
                      onQuantity: (value) => setState(() => _quantity = value),
                      onReplacement: (item) =>
                          setState(() => _replacement = item),
                    ),
                  },
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text('Discard'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _refusal == null ? _apply : null,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.subject, required this.onClose});

  final Subject subject;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final (String where, Tag? state) = switch (subject) {
      FieldSubject(:final entry) => (entry.where, stateTagFor(entry.field)),
      ProficiencySubject() => ('Proficiencies', null),
      ItemSubject(:final item) => (
        item.slot == null ? 'Inventory · Backpack' : 'Inventory · ${item.slot}',
        null,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(subject.title, style: text.headlineSmall),
                    ),
                    if (state != null) ...[
                      const SizedBox(width: 10),
                      state,
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  where,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: 'Close',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// The field being edited, with the rules check on the input itself.
///
/// ⚠️ **The mark belongs on the field, not only on the button.** A greyed
/// `Apply` says *something is wrong somewhere*; an `errorText` under the input
/// says *this value, and here is why*. Material draws the red border and the
/// message for free once the decoration carries it — and it appears as the
/// value is typed rather than waiting for the commit, so the answer arrives
/// while the finger is still on the key that caused it.
class _FieldBody extends StatelessWidget {
  const _FieldBody({
    required this.entry,
    required this.draft,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.rulesBind,
    this.pending,
    this.error,
  });

  final FieldEntry entry;
  final String draft;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Enter commits, and is refused by the same rule that greys Apply.
  final VoidCallback onSubmitted;

  /// Whether the class restriction binds. Off, a field the class cannot have
  /// becomes editable — which is what the mode is for.
  final bool rulesBind;
  final String? pending;

  /// Why this value cannot be kept, shown under the input in the error role.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final field = entry.field;
    final caveat = field.caveat;
    final arithmetic = field.arithmetic;
    final explanation = _explain(field);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueReadout(field: field, pending: pending, showState: false),
        if (field.source == FieldSource.derived) ...[
          const SizedBox(height: 10),
          const Tag('derived', tone: TagTone.muted),
        ],
        if (arithmetic != null) ...[
          const SizedBox(height: 10),
          ArithmeticLine(arithmetic),
        ],
        if (caveat != null) ...[
          const SizedBox(height: 16),
          _CaveatBlock(caveat),
        ],
        const SizedBox(height: 20),
        if (!field.enabledUnder(rulesBind: rulesBind))
          _ReadOnlyValue(field: field)
        else if (field.label == 'Strength')
          _Stepper(
            value: int.tryParse(draft) ?? 0,
            minimum: 3,
            maximum: 25,
            onChanged: (value) => onChanged('$value'),
          )
        else
          _NumberField(
            controller: controller,
            unit: field.unit,
            error: error,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        // ⚠️ Under the control, not only inside the text field's decoration.
        // Strength is a stepper and the rest are text fields, so an `errorText`
        // alone marked some fields and silently skipped the one people most
        // often come here to change.
        if (error case final String why) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  why,
                  style: text.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (explanation != null) ...[
          const SizedBox(height: 12),
          Text(explanation, style: text.bodyLarge),
        ],
      ],
    );
  }
}

/// Why the field looks the way it does, derived from the record rather than
/// written out per field — so a data change can never leave it lying.
String? _explain(DemoField field) {
  if (field.anomalous) {
    return 'This field is greyed because the class table gives it nothing. '
        'It stays editable because the record holds a value anyway, and a '
        'value you cannot touch is one you cannot correct.';
  }
  if (!field.available) {
    return 'The class table gives this class none of it, and the record '
        'holds nothing, so there is nothing here to write.';
  }
  if (!field.editable) {
    return 'The engine works this out from other fields, so there is nothing '
        'to write. It is here to be read against them.';
  }
  if (field.source == FieldSource.derived) {
    return 'The engine owns this one: it recomputes the field when the save '
        'is loaded, so an edit here is provisional.';
  }
  return null;
}

/// A value nothing can write, shown as **selectable text**.
///
/// Deliberately not a disabled [TextField]: that draws at 0.38 opacity,
/// refuses selection, and takes its own suffix ⓘ down with it.
class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({required this.field});

  final DemoField field;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SelectableText(
          '${field.stored}${field.unit ?? ''}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(width: 12),
        const Tag('read-only', tone: TagTone.muted),
      ],
    );
  }
}

class _CaveatBlock extends StatelessWidget {
  const _CaveatBlock(this.caveat);

  final String caveat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.outline, width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Text(
          caveat,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    this.unit,
    this.error,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final String? unit;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Wider when it has to carry a sentence: an `errorText` under a 180 px
      // field wraps to four lines and shoves the rest of the sheet down.
      width: error == null ? 180 : 340,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted(),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: Theme.of(context).textTheme.titleMedium,
        decoration: InputDecoration(
          suffixText: unit,
          errorText: error,
          errorMaxLines: 3,
        ),
      ),
    );
  }
}

class _ProficiencyBody extends StatelessWidget {
  const _ProficiencyBody({
    required this.proficiency,
    required this.pips,
    required this.rulesBind,
    required this.slotsLeft,
    required this.onChanged,
  });

  final DemoProficiency proficiency;
  final int pips;

  /// Whether the ceiling binds. The same rule the fields follow: while the
  /// rules hold, the stepper stops at the cap — **unless the record already
  /// holds a surplus**, in which case it must reach far enough to take one
  /// away again.
  final bool rulesBind;

  /// Slots unspent elsewhere. Adding a pip here spends one of them.
  final int slotsLeft;

  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = pips > proficiency.maximum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PipMeter(proficiency: proficiency, pending: pips, showName: false),
        const SizedBox(height: 16),
        const _CaveatBlock(
          'The ceiling is the lower of what the class allows and what the '
          'proficiency itself allows, which is why it is not the same number '
          'for every weapon.',
        ),
        const SizedBox(height: 20),
        // ⚠️ The ceiling binds only while the rules do — and never below what
        // the record already holds, or a surplus pip could not be taken off.
        _Stepper(
          value: pips,
          // Two ceilings at once: this row's own, and what the budget can
          // still afford. Never below what is already taken, or a pip could
          // not be given back.
          maximum: rulesBind
              ? math.max(pips, math.min(proficiency.maximum, pips + slotsLeft))
              : proficiency.maximum + 2,
          onChanged: onChanged,
        ),
        if (over) ...[
          const SizedBox(height: 12),
          Text(
            'Above the ceiling of ${proficiency.maximum}. The game will not '
            'honour the surplus, and the record is allowed to show it anyway '
            'so a record that already holds one can be corrected.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemBody extends StatelessWidget {
  const _ItemBody({
    required this.item,
    required this.character,
    required this.controller,
    required this.query,
    required this.quantity,
    required this.onQuery,
    required this.onQuantity,
    required this.onReplacement,
    this.replacement,
  });

  final DemoItem item;
  final DemoCharacter character;
  final TextEditingController controller;
  final String query;
  final int quantity;
  final ValueChanged<String> onQuery;
  final ValueChanged<int> onQuantity;
  final ValueChanged<DemoItem?> onReplacement;
  final DemoItem? replacement;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final chosen = replacement;
    final needle = query.trim().toLowerCase();
    final offered = [
      for (final candidate in character.backpack)
        if (needle.isEmpty || candidate.name.toLowerCase().contains(needle))
          candidate,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Tag(item.name, caption: 'in the slot'),
            if (!item.identified)
              const Tag('unidentified', tone: TagTone.muted),
            if (item.stolen) const Tag('stolen', tone: TagTone.conflict),
            if (item.undroppable)
              const Tag('cannot be dropped', tone: TagTone.muted),
          ],
        ),
        const SizedBox(height: 20),
        Text('Quantity', style: text.titleSmall),
        const SizedBox(height: 8),
        _Stepper(value: quantity, minimum: 1, onChanged: onQuantity),
        const SizedBox(height: 24),
        Text('Put something else here', style: text.titleSmall),
        const SizedBox(height: 4),
        Text(
          'One field over the backpack. The application this replaces spent '
          'a modal dialog and fifty-one controls on the same job.',
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          onChanged: onQuery,
          decoration: const InputDecoration(
            hintText: 'Filter the backpack…',
            prefixIcon: Icon(Icons.filter_alt_outlined),
          ),
        ),
        const SizedBox(height: 8),
        for (final candidate in offered)
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(candidate.name, style: text.bodyLarge),
            subtitle: candidate.quantity > 1
                ? Text('${candidate.quantity} of them', style: text.bodySmall)
                : null,
            trailing: identical(candidate, chosen)
                ? const Icon(Icons.check)
                : null,
            selected: identical(candidate, chosen),
            onTap: () =>
                onReplacement(identical(candidate, chosen) ? null : candidate),
          ),
        if (offered.isEmpty)
          Text(
            'Nothing in the backpack answers to that.',
            style: text.bodyLarge,
          ),
      ],
    );
  }
}

/// A numeric stepper that reports its bounds but does not silently obey them
/// where the record is allowed to disagree with the rules.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onChanged,
    this.minimum = 0,
    this.maximum = 99,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int minimum;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          onPressed: value > minimum ? () => onChanged(value - 1) : null,
          tooltip: 'One less',
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 64,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        IconButton.outlined(
          onPressed: value < maximum ? () => onChanged(value + 1) : null,
          tooltip: 'One more',
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
