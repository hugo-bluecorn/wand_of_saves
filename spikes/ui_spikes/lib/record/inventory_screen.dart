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

/// ⚠️ **There is no screen in this file, and that is the point.**
///
/// Choosing a shape for the inventory is what this whole exercise is for, and
/// this approach's answer is that it is not a destination at all: it is a
/// chapter of the record, read in the same pass as everything else. Removing
/// the place you have to navigate to is the proposal.
///
/// Equipped is a definition list — slot, then what is in it. The backpack is a
/// ruled list. Neither is a grid: the other two approaches own grids, and a
/// list is what lets an item's qualifiers sit beside it in words.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/record/theme.dart';

/// What the character is carrying, as one chapter of the document.
class InventoryChapter extends StatelessWidget {
  /// Creates the chapter body. The head, the rule and the spacing above it
  /// belong to the document, not to this widget.
  const InventoryChapter({
    required this.equipped,
    required this.backpack,
    super.key,
  });

  /// Items in slots.
  final List<DemoItem> equipped;

  /// Items loose in the backpack.
  final List<DemoItem> backpack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (equipped.isNotEmpty) ...[
          Text('Equipped', style: tokens.groupHead),
          const SizedBox(height: 8),
          for (final item in equipped) _EquippedRow(item: item),
          const SizedBox(height: 30),
        ],
        if (backpack.isNotEmpty) ...[
          Text('Backpack', style: tokens.groupHead),
          const SizedBox(height: 10),
          for (final item in backpack) _BackpackRow(item: item),
        ],
        if (equipped.isEmpty && backpack.isEmpty)
          Text('Nothing is carried.', style: tokens.caption),
      ],
    );
  }
}

class _EquippedRow extends StatelessWidget {
  const _EquippedRow({required this.item});

  final DemoItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    final slot = item.slot ?? '';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.rowGap / 2),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: tokens.gutter),
            SizedBox(
              width: 156,
              child: Padding(
                padding: const EdgeInsets.only(top: 5, right: 16),
                child: Text(slot.toUpperCase(), style: tokens.slotName),
              ),
            ),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 14,
                children: [
                  Text(item.name, style: tokens.fieldLabel),
                  if (item.quantity > 1) _Qualifier(text: '×${item.quantity}'),
                  if (item.undroppable) const _Qualifier(text: 'undroppable'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackpackRow extends StatelessWidget {
  const _BackpackRow({required this.item});

  final DemoItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    final charges = item.charges;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.rowGap),
          child: MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: tokens.gutter),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 14,
                    children: [
                      Text(
                        item.name,
                        style: item.identified
                            ? tokens.fieldLabel
                            : tokens.fieldLabelDim,
                      ),
                      if (item.quantity > 1)
                        _Qualifier(text: '×${item.quantity}'),
                      if (charges != null) _Qualifier(text: '$charges charges'),
                      if (!item.identified)
                        const _Qualifier(text: 'unidentified', italic: true),
                      if (item.stolen)
                        const _Qualifier(text: 'stolen', anomalous: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}

/// A short word beside an item, never a badge and never an icon.
class _Qualifier extends StatelessWidget {
  const _Qualifier({
    required this.text,
    this.italic = false,
    this.anomalous = false,
  });

  final String text;
  final bool italic;
  final bool anomalous;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    var style = tokens.caption;
    if (italic) style = style.copyWith(fontStyle: FontStyle.italic);
    if (anomalous) style = style.copyWith(color: tokens.anomalyInk);
    return Text(text, style: style);
  }
}
