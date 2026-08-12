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

/// One line of the record, which is where this approach's design risk lives.
///
/// ⚠️ **Nothing here is ever shortened.** The label, the helper line and the
/// caveat all wrap to a second line instead. That is not a preference: the
/// live application truncates its own always-visible helper line today —
/// `stored 12, +4/level from Constit…` — and that is the third time a fixed
/// tile width has cut a string this project needed to read. A row that wraps
/// cannot fail that way at any width.
///
/// The shape reproduces the engine's own record screen, where a base value and
/// the value derived from it sit on adjacent lines of one list rather than in
/// separate places.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/record/theme.dart';

/// One field of the record: name, stored value, the arithmetic behind it, and
/// what the engine will draw instead.
class FieldRow extends StatefulWidget {
  /// Creates a row for [field].
  const FieldRow({
    required this.field,
    required this.value,
    required this.edited,
    required this.onChanged,
    this.arithmetic,
    this.inGame,
    super.key,
  });

  /// What is being shown. Its `enabled`, `available` and `anomalous` flags are
  /// already computed; this widget reads them and never re-derives them.
  final DemoField field;

  /// The value as it stands, which is the edited one once the reader types.
  final String value;

  /// Whether [value] has moved off what the file holds. Draws the change bar.
  final bool edited;

  /// Called with the committed text when the reader leaves the field.
  final ValueChanged<String> onChanged;

  /// The always-visible helper line, already composed with any revision mark.
  final String? arithmetic;

  /// What the engine draws, when that differs from what is stored.
  final String? inGame;

  @override
  State<FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<FieldRow> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _editing = false;
  bool _showCaveat = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focus = FocusNode()..addListener(_onFocusChanged);
    // An anomaly announces itself rather than waiting to be found. Every other
    // caveat starts folded away behind the ⓘ.
    _showCaveat = widget.field.anomalous && widget.field.caveat != null;
  }

  @override
  void didUpdateWidget(FieldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus && _editing) _commit(_controller.text);
  }

  void _commit(String text) {
    setState(() => _editing = false);
    final trimmed = text.trim();
    if (trimmed.isNotEmpty && trimmed != widget.value) {
      widget.onChanged(trimmed);
    }
  }

  void _beginEdit() {
    if (!widget.field.enabled) return;
    setState(() => _editing = true);
    _controller
      ..text = widget.value
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.value.length,
      );
  }

  Color? _gutterInk(RecordTokens tokens) {
    if (widget.field.anomalous) return tokens.anomalyInk;
    if (widget.edited) return tokens.changeInk;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    final field = widget.field;
    final caveat = field.caveat;
    final arithmetic = widget.arithmetic;
    final inGame = widget.inGame;
    final dimmed = !field.enabled;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.rowGap / 2),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Gutter(ink: _gutterInk(tokens)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2, right: 8),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: field.label),
                                if (field.anomalous)
                                  TextSpan(
                                    text: ' †',
                                    style: TextStyle(
                                      color: tokens.anomalyInk,
                                    ),
                                  ),
                              ],
                            ),
                            style: dimmed
                                ? tokens.fieldLabelDim
                                : tokens.fieldLabel,
                          ),
                        ),
                      ),
                      // Always reserved, so a row with a caveat and a row
                      // without one keep the same rhythm.
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: caveat == null
                            ? null
                            : _CaveatButton(
                                caveat: caveat,
                                expanded: _showCaveat,
                                onPressed: () => setState(
                                  () => _showCaveat = !_showCaveat,
                                ),
                              ),
                      ),
                      SizedBox(
                        width: tokens.valueColumn,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _ValueSlot(
                            field: field,
                            value: widget.value,
                            editing: _editing,
                            controller: _controller,
                            focusNode: _focus,
                            onBeginEdit: _beginEdit,
                            onSubmitted: _commit,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (arithmetic != null) _ArithmeticLine(text: arithmetic),
                  if (_showCaveat && caveat != null) _CaveatLine(text: caveat),
                  if (inGame != null) _DerivedLine(value: inGame),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The left band. Always reserved, so nothing shifts when a row is edited.
class _Gutter extends StatelessWidget {
  const _Gutter({required this.ink});

  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    final ink = this.ink;
    return SizedBox(
      width: tokens.gutter,
      child: ink == null
          ? null
          : Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(
                  width: 2,
                  height: 17,
                  child: ColoredBox(color: ink),
                ),
              ),
            ),
    );
  }
}

/// The value itself, in one of four states — and none of them is a disabled
/// text field, which would drop to 0.38 opacity and refuse to be selected.
class _ValueSlot extends StatefulWidget {
  const _ValueSlot({
    required this.field,
    required this.value,
    required this.editing,
    required this.controller,
    required this.focusNode,
    required this.onBeginEdit,
    required this.onSubmitted,
  });

  final DemoField field;
  final String value;
  final bool editing;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onBeginEdit;
  final ValueChanged<String> onSubmitted;

  @override
  State<_ValueSlot> createState() => _ValueSlotState();
}

class _ValueSlotState extends State<_ValueSlot> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    final field = widget.field;
    final text = '${widget.value}${field.unit ?? ''}';

    if (widget.editing) {
      return TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofocus: true,
        textAlign: TextAlign.right,
        style: tokens.storedValue,
        onSubmitted: widget.onSubmitted,
      );
    }

    // The engine owns it, so it is shown in the derived ink and never typed in.
    if (!field.editable) {
      return Text(
        text,
        style: tokens.derivedValue,
        textAlign: TextAlign.right,
      );
    }

    // The class cannot have it and the file does not hold one either. Dimmed
    // by a role change, not by an opacity wrapper, so it stays legible.
    if (!field.enabled) {
      return Text(
        text,
        style: tokens.storedValue.copyWith(color: tokens.fieldLabelDim.color),
        textAlign: TextAlign.right,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onBeginEdit,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _hovering ? tokens.changeInk : Colors.transparent,
              ),
            ),
          ),
          child: Text(
            text,
            style: tokens.storedValue,
            textAlign: TextAlign.right,
          ),
        ),
      ),
    );
  }
}

/// The always-visible helper line. It wraps; it is never cut short.
class _ArithmeticLine extends StatelessWidget {
  const _ArithmeticLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 1, 24, 1),
      child: Text(text, style: context.recordTokens.arithmetic),
    );
  }
}

/// The one thing no number can say, revealed rather than hovered for.
class _CaveatButton extends StatelessWidget {
  const _CaveatButton({
    required this.caveat,
    required this.expanded,
    required this.onPressed,
  });

  final String caveat;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      // Also the screen-reader label, which a hover-only tooltip is not.
      tooltip: caveat,
      icon: Icon(
        expanded ? Icons.info : Icons.info_outline,
        size: 16,
        color: expanded ? context.recordTokens.changeInk : null,
      ),
    );
  }
}

/// The caveat set inline, one short indented line behind a rule.
class _CaveatLine extends StatelessWidget {
  const _CaveatLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 24, 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: tokens.rule, width: 2)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(text, style: tokens.caveat),
        ),
      ),
    );
  }
}

/// What the engine draws, directly under what the file holds — the adjacency
/// the record screen itself uses for base and derived values.
class _DerivedLine extends StatelessWidget {
  const _DerivedLine({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(child: Text('In game', style: tokens.derivedTag)),
        // Matches the reserved ⓘ column above, so the two values line up.
        const SizedBox(width: 32),
        SizedBox(
          width: tokens.valueColumn,
          child: Text(
            value,
            style: tokens.derivedValue,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
