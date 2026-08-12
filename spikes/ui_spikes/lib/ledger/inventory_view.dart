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

/// The Inventory destination: a paper doll, and the backpack as a ledger.
///
/// The argument this screen makes is that **an item is not a different kind of
/// thing from a stat**. A slot, a stack size, a charge count and a flag all go
/// through the same row grammar as `THAC0 (base)` — same gutter, same sticky
/// header, same selection, same detail rail — with only the three column
/// headings changed. If the shape is right for sixty stats it should be right
/// for twenty items, and if it is not, that is worth finding out on a screen
/// rather than in an argument.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/demo/portrait.dart';
import 'package:ui_spikes/ledger/ledger_edits.dart';
import 'package:ui_spikes/ledger/ledger_row.dart';
import 'package:ui_spikes/ledger/ledger_table.dart';

/// The paper doll above, the backpack below, one selection between them.
class InventoryView extends StatelessWidget {
  /// Draws [character]'s equipped slots and backpack.
  const InventoryView({
    required this.character,
    required this.edits,
    required this.onSelect,
    this.selectedId,
    super.key,
  });

  /// Whose inventory this is.
  final DemoCharacter character;

  /// Pending edits, passed through so the backpack shares the row grammar
  /// whole rather than a copy of it with the edit machinery cut out.
  final LedgerEdits edits;

  /// Called with the item a person clicked, in a slot or in the backpack.
  final ValueChanged<LedgerRow> onSelect;

  /// The row the detail rail is showing, if any.
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final equipped = {
      for (final item in character.equipped) item.slot: item,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PaperDoll(
          character: character,
          equipped: equipped,
          onSelect: onSelect,
          selectedId: selectedId,
        ),
        const Divider(),
        Expanded(
          child: LedgerTable(
            columns: LedgerColumns.items,
            edits: edits,
            onSelect: onSelect,
            selectedId: selectedId,
            blocks: [
              LedgerBlock('Backpack', [
                for (var index = 0; index < character.backpack.length; index++)
                  ItemRow(
                    id: 'inventory/pack/$index',
                    item: character.backpack[index],
                  ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// The slots down the left of the doll.
const List<String> _leftSlots = [
  'Helmet',
  'Armour',
  'Gauntlets',
  'Ring',
  'Boots',
];

/// The slots down the right of the doll.
const List<String> _rightSlots = [
  'Amulet',
  'Cloak',
  'Belt',
  'Main hand',
  'Off hand',
];

/// The slots under it.
const List<String> _bottomSlots = ['Ammunition', 'Quiver'];

/// ⚠️ **`Amulet`, `Gauntlets`, `Belt` and `Quiver` are illustrative chrome.**
///
/// The demo data holds eight equipped items and this doll draws twelve slots.
/// The four extra ones are here because **an inventory layout cannot be judged
/// from a doll in which every slot happens to be full** — the empty state is
/// most of what a paper doll is *for*, and a spike that hid it would be
/// showing its best case only. They are a UI decision about how many cells to
/// reserve, not a claim about BG:EE's slot table, and nothing anywhere in this
/// spike reads a number from them.
const Set<String> _illustrativeSlots = {
  'Amulet',
  'Gauntlets',
  'Belt',
  'Quiver',
};

class _PaperDoll extends StatelessWidget {
  const _PaperDoll({
    required this.character,
    required this.equipped,
    required this.onSelect,
    required this.selectedId,
  });

  final DemoCharacter character;
  final Map<String?, DemoItem> equipped;
  final ValueChanged<LedgerRow> onSelect;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SlotColumn(
                  slots: _leftSlots,
                  equipped: equipped,
                  onSelect: onSelect,
                  selectedId: selectedId,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  DemoPortrait(initial: character.name.substring(0, 1)),
                  const SizedBox(height: 6),
                  Text(character.levelLine, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SlotColumn(
                  slots: _rightSlots,
                  equipped: equipped,
                  onSelect: onSelect,
                  selectedId: selectedId,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final slot in _bottomSlots) ...[
                Expanded(
                  child: _SlotCell(
                    slot: slot,
                    item: equipped[slot],
                    selectedId: selectedId,
                    onSelect: onSelect,
                  ),
                ),
                if (slot != _bottomSlots.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotColumn extends StatelessWidget {
  const _SlotColumn({
    required this.slots,
    required this.equipped,
    required this.onSelect,
    required this.selectedId,
  });

  final List<String> slots;
  final Map<String?, DemoItem> equipped;
  final ValueChanged<LedgerRow> onSelect;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slot in slots) ...[
          _SlotCell(
            slot: slot,
            item: equipped[slot],
            selectedId: selectedId,
            onSelect: onSelect,
          ),
          if (slot != slots.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.slot,
    required this.item,
    required this.selectedId,
    required this.onSelect,
  });

  final String slot;
  final DemoItem? item;
  final String? selectedId;
  final ValueChanged<LedgerRow> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final item = this.item;
    final id = 'inventory/slot/$slot';
    final selected = id == selectedId;
    return Card.outlined(
      color: selected ? colors.surfaceContainerHighest : null,
      child: InkWell(
        onTap: item == null
            ? null
            : () => onSelect(ItemRow(id: id, item: item)),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slot.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              if (item == null)
                Row(
                  children: [
                    Icon(
                      Icons.remove,
                      size: 12,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _illustrativeSlots.contains(slot)
                          ? 'empty'
                          : 'nothing equipped',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  item.quantity > 1
                      ? '${item.name}  ×${item.quantity}'
                      : item.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
