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

/// One thing, opened — the surface every edit is actually made on.
///
/// The sheet behind it is a **read-only summary**: sixty rows, each saying what
/// it holds and what the engine draws instead. Tapping one opens this, where
/// there is exactly one subject and the room to say why its number is strange.
///
/// ⚠️ **Nothing here is staged.** The spike this came from kept a pending map
/// because it had no ViewModel; the application applies through `EditSession`,
/// which already gives undo, redo and a dirty marker. So the two apply
/// callbacks are fire-and-forget: the draft lives in this
/// widget only until `Apply`, and one press is one command rather than one per
/// keystroke.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wand_of_saves/ui/character/findings.dart';
import 'package:wand_of_saves/ui/character/pip_meter.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';
import 'package:wand_of_saves/ui/character/value_readout.dart';
import 'package:wand_of_saves/ui/core/arithmetic_line.dart';
import 'package:wand_of_saves/ui/core/tag.dart';

/// How far past the ceiling the stepper reaches once the rules check is off.
///
/// Headroom rather than a rule: it is what makes the surplus state the pip
/// meter can already draw *reachable*, and D16's whole point is that "beyond
/// the rules" is a place the player may deliberately go.
const int _beyondCeiling = 2;

/// The editor for one [Subject].
class SideSheet extends StatefulWidget {
  /// Opens [subject].
  const SideSheet({
    required this.subject,
    required this.character,
    required this.rulesBind,
    required this.onApplyField,
    required this.onApplyPips,
    required this.onClose,
    super.key,
  });

  /// What was opened.
  final Subject subject;

  /// The record it belongs to, read to keep [subject] from going stale.
  final SheetCharacter character;

  /// Whether the rules bind. Off, a value the rules would never produce is
  /// written anyway and marked — which is the reason a save editor exists.
  final bool rulesBind;

  /// Writes a field edit straight through. There is no staging step.
  final void Function(FieldEntry entry, String value) onApplyField;

  /// Writes a new pip count straight through.
  final void Function(SheetProficiency proficiency, int pips) onApplyPips;

  /// Closes the sheet.
  final VoidCallback onClose;

  @override
  State<SideSheet> createState() => _SideSheetState();
}

class _SideSheetState extends State<SideSheet> {
  /// ⚠️ Built once and disposed. The panel this replaces built one inside
  /// `build()` and leaked one per rebuild — defect A7 of the UI review.
  late final TextEditingController _value;
  late String _draft;
  late int _pips;

  @override
  void initState() {
    super.initState();
    _draft = _storedText;
    _pips = _storedPips;
    _value = TextEditingController(text: _draft);
  }

  @override
  void didUpdateWidget(SideSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ⚠️ A different subject in the same widget. A parent that keeps one sheet
    // and changes what it holds would otherwise aim the previous field's draft
    // at the new field.
    if (_identityOf(widget.subject) != _identityOf(oldWidget.subject)) {
      _draft = _storedText;
      _pips = _storedPips;
      _value.text = _draft;
    }
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  /// [SideSheet.subject], resolved against the record as it now stands.
  ///
  /// ⚠️ **A subject is a snapshot and the document moves under it.** An apply
  /// writes immediately, so a parent holding the [Subject] it opened would
  /// redraw this sheet from the values that were there before the write.
  /// Resolving by key — the one thing a label is not — keeps the sheet and the
  /// record the same fact.
  Subject get _subject => switch (widget.subject) {
    FieldSubject(:final entry) => FieldSubject(_liveEntry(entry)),
    ProficiencySubject(:final proficiency) => ProficiencySubject(
      _liveProficiency(proficiency),
    ),
  };

  FieldEntry _liveEntry(FieldEntry wanted) {
    for (final entry in indexOf(widget.character)) {
      if (entry.key == wanted.key) return entry;
    }
    return wanted;
  }

  SheetProficiency _liveProficiency(SheetProficiency wanted) {
    for (final proficiency in widget.character.proficiencies) {
      if (proficiency.id == wanted.id) return proficiency;
    }
    return wanted;
  }

  String get _storedText => switch (_subject) {
    FieldSubject(:final entry) => entry.field.stored,
    ProficiencySubject() => '',
  };

  int get _storedPips => switch (_subject) {
    ProficiencySubject(:final proficiency) => proficiency.pips,
    FieldSubject() => 0,
  };

  /// Why this value may not leave the sheet, or null when it may.
  ///
  /// ⚠️ **The keystroke is never refused, only the commit.** The field takes
  /// whatever is typed; this decides whether it may be written. Above the
  /// engine's own ceiling it is refused in *both* modes — that is not a choice
  /// a save editor gets to offer, it is a corrupt byte. That is D16: three
  /// kinds of wrong, and only one of them is a hard stop.
  String? _refusalFor(SheetField field) {
    if (field.impossible(_draft)) {
      return 'The game will not take a value above ${field.gameMaximum}.';
    }
    if (widget.rulesBind && field.beyondRules(_draft)) {
      return 'Beyond anything the rules produce — they reach '
          '${field.rulesMaximum}. Turn the rules check off to keep it.';
    }
    return null;
  }

  void _apply(Subject subject) {
    switch (subject) {
      case FieldSubject(:final entry):
        if (_refusalFor(entry.field) != null) return;
        if (!entry.field.enabledUnder(rulesBind: widget.rulesBind)) return;
        widget.onApplyField(entry, _draft);
      case ProficiencySubject(:final proficiency):
        widget.onApplyPips(proficiency, _pips);
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final subject = _subject;
    final field = switch (subject) {
      FieldSubject(:final entry) => entry.field,
      ProficiencySubject() => null,
    };
    final refusal = field == null ? null : _refusalFor(field);
    final canApply =
        refusal == null &&
        (field == null || field.enabledUnder(rulesBind: widget.rulesBind));

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHeader(
              subject: subject,
              rulesBind: widget.rulesBind,
              onClose: widget.onClose,
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                children: [
                  switch (subject) {
                    FieldSubject(:final entry) => _FieldBody(
                      entry: entry,
                      draft: _draft,
                      controller: _value,
                      rulesBind: widget.rulesBind,
                      error: refusal,
                      onChanged: (value) => setState(() => _draft = value),
                      onSubmitted: () => _apply(subject),
                    ),
                    ProficiencySubject(:final proficiency) => _ProficiencyBody(
                      proficiency: proficiency,
                      pips: _pips,
                      rulesBind: widget.rulesBind,
                      onChanged: (pips) => setState(() => _pips = pips),
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
                    onPressed: canApply ? () => _apply(subject) : null,
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

/// A key unique across the sheet, which a label is not.
String _identityOf(Subject subject) => switch (subject) {
  FieldSubject(:final entry) => entry.key,
  ProficiencySubject(:final proficiency) => 'proficiency ${proficiency.id}',
};

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.subject,
    required this.rulesBind,
    required this.onClose,
  });

  final Subject subject;
  final bool rulesBind;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final (String where, Tag? state) = switch (subject) {
      FieldSubject(:final entry) => (
        entry.where,
        stateTagFor(entry.field, rulesBind: rulesBind),
      ),
      ProficiencySubject() => ('Proficiencies', null),
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
                    if (state != null) ...[const SizedBox(width: 10), state],
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

/// The field being edited, with its verdict on the input itself.
///
/// ⚠️ **The mark belongs on the field, not only on the button.** A greyed
/// `Apply` says *something is wrong somewhere*; an `errorText` under the input
/// says *this value, and here is why* — and it arrives as the value is typed
/// rather than waiting for the commit.
class _FieldBody extends StatelessWidget {
  const _FieldBody({
    required this.entry,
    required this.draft,
    required this.controller,
    required this.rulesBind,
    required this.onChanged,
    required this.onSubmitted,
    this.error,
  });

  final FieldEntry entry;
  final String draft;
  final TextEditingController controller;

  /// Whether the class restriction binds. Off, a field the class cannot have
  /// becomes editable — which is what the mode is for.
  final bool rulesBind;
  final ValueChanged<String> onChanged;

  /// Enter commits, refused by the same rule that greys Apply.
  final VoidCallback onSubmitted;

  /// Why this value cannot be kept, drawn in the input's error role.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final field = entry.field;
    final arithmetic = field.arithmetic;
    final explanation = _explain(field, rulesBind: rulesBind);
    final editable = field.enabledUnder(rulesBind: rulesBind);
    final pending = draft == field.stored ? null : draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The caveat rides this readout's ⓘ. The arithmetic gets a line of its
        // own, which wraps and never ellipsises.
        ValueReadout(field: field, pending: pending, showState: false),
        if (field.source == FieldSource.derived) ...[
          const SizedBox(height: 10),
          const Tag('derived', tone: TagTone.muted),
        ],
        if (arithmetic != null) ...[
          const SizedBox(height: 10),
          ArithmeticLine(arithmetic),
        ],
        const SizedBox(height: 20),
        if (editable)
          _NumberField(
            controller: controller,
            unit: field.unit,
            error: error,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          )
        else
          _ReadOnlyValue(field: field),
        if (field.valueMeanings case final Map<int, String> meanings) ...[
          const SizedBox(height: 16),
          _ValueChoices(
            meanings: meanings,
            selected: int.tryParse(controller.text),
            onPicked: editable ? onChanged : null,
          ),
        ],
        if (explanation != null) ...[
          const SizedBox(height: 16),
          Text(explanation, style: text.bodyLarge),
        ],
      ],
    );
  }
}

/// Why the field looks the way it does, composed from the record rather than
/// authored per field — so a data change can never leave it lying.
///
/// The order mirrors [SheetField.enabledUnder], because these sentences are
/// explaining that method's answer and any other order would explain a
/// different one.
String? _explain(SheetField field, {required bool rulesBind}) {
  if (field.anomalous) {
    return 'The class table gives this class none of it and the record holds a '
        'value anyway. It stays editable in both modes, because a value you '
        'cannot touch is a value you cannot correct.';
  }
  if (!field.editable) {
    return 'The engine works this out from other fields, so there is nothing '
        'to write. It is here to be read against them.';
  }
  if (!field.available) {
    if (rulesBind) {
      return 'The class table gives this class none of it. Turn the rules '
          'check off to write a value here anyway.';
    }
    return 'The class table gives this class none of it. The rules check is '
        'off, so a value written here is kept — whether the game shows it is '
        'up to the engine.';
  }
  if (field.source == FieldSource.derived) {
    return 'The engine owns this one: it recomputes the field when the save is '
        'loaded, so an edit here is provisional.';
  }
  return null;
}

/// A value nothing can write, shown as **selectable text**.
///
/// Deliberately not a disabled [TextField]: that draws at 0.38 opacity and
/// refuses selection, so the value cannot be copied out of the one place it is
/// legible. The header already carries the state word.
class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({required this.field});

  final SheetField field;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      '${field.stored}${field.unit ?? ''}',
      style: Theme.of(context).textTheme.headlineSmall,
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
    required this.onChanged,
  });

  final SheetProficiency proficiency;
  final int pips;

  /// Whether the ceiling binds — **and never below what the record already
  /// holds**, or a surplus pip could not be taken away again.
  final bool rulesBind;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = pips > proficiency.maximum;
    final reach = math.max(pips, proficiency.maximum);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ⚠️ No `pending`. There is no staging here, and the tag it draws
        // ("not written yet") is 14 characters in an unflexed `Row` — under
        // `flutter test`'s full-em-square font that overflows the 420 px
        // drawer and fails the suite for a reason that has nothing to do with
        // the behaviour under test. The draft is legible in the stepper's own
        // numeral 20 px below, in `headlineSmall`.
        PipMeter(proficiency: proficiency, showName: false),
        const SizedBox(height: 16),
        const _Aside(
          'The ceiling is the lower of what the class allows and what the '
          'proficiency itself allows, which is why it is not the same number '
          'for every weapon.',
        ),
        const SizedBox(height: 20),
        _Stepper(
          value: pips,
          maximum: rulesBind ? reach : reach + _beyondCeiling,
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

/// A standing sentence about the subject, set off by a rule rather than a fill
/// — a fifth surface tone inside a card is where a shipped defect came from.
class _Aside extends StatelessWidget {
  const _Aside(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

/// A numeric stepper that reports its bounds rather than silently obeying them
/// where the record is allowed to disagree with the rules.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.maximum,
    required this.onChanged,
  });

  final int value;
  final int maximum;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
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

/// Every value a coded field can hold, with what the game draws for it.
///
/// ⚠️ **For a field whose bytes are a code rather than a quantity.** `Attacks
/// per round` stores `0`–`5` as whole attacks and `6`–`10` as halves, so a
/// stored `10` draws as `9/2` — and a player who wants two attacks a round has
/// to run that encoding backwards to find out they should type `2`. Reported as
/// exactly that: *"can we have a side number, because I would like to set
/// attacks to 2 or 3"*.
///
/// So the values are **offered**. Picking one writes the byte; the label says
/// what the game will draw. Nothing here converts a displayed value back into a
/// stored one — the editor still edits the record's own number, and the choice
/// is only a way of naming it.
class _ValueChoices extends StatelessWidget {
  const _ValueChoices({
    required this.meanings,
    required this.selected,
    required this.onPicked,
  });

  /// Stored value to what the game draws for it.
  final Map<int, String> meanings;

  /// The value in the input, when it is one of these.
  final int? selected;

  /// Called with the picked value as text, or `null` when the field is inert.
  final ValueChanged<String>? onPicked;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final entries = meanings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What each value means',
          style: text.labelLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              ChoiceChip(
                label: Text(
                  // `2 → 2` says nothing, so the arrow is dropped where the
                  // value and its meaning are the same number.
                  entry.value == '${entry.key}'
                      ? '${entry.key}'
                      : '${entry.key} → ${entry.value}',
                ),
                selected: entry.key == selected,
                onSelected: onPicked == null
                    ? null
                    : (_) => onPicked!('${entry.key}'),
              ),
          ],
        ),
      ],
    );
  }
}
