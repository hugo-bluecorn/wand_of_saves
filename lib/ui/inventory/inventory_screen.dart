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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/carried_item.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/item_catalogue.dart';
import 'package:wand_of_saves/ui/core/panel_card.dart';
import 'package:wand_of_saves/ui/core/save_button.dart';
import 'package:wand_of_saves/ui/core/tag.dart';
import 'package:wand_of_saves/ui/inventory/item_drag.dart';

/// A character's inventory: what they carry, and a search that adds to it.
///
/// **A pushed route, not a panel**, which is the shape the winning spike had —
/// thirty-four slots and a picker would swamp the single-column sheet.
///
/// ⚠️ **Parameterised over the document rather than the screen.** Both editors
/// push this: a savegame and an exported character take the same edits, and a
/// `.chr` being the less capable surface would invert every other feature here.
/// The caller supplies [onAdd]; this widget never touches a view model.
class InventoryScreen extends ConsumerStatefulWidget {
  /// Shows [character]'s inventory, adding through [onAdd].
  const InventoryScreen({
    required this.character,
    required this.onAdd,
    this.isDirty = false,
    this.onSave,
    this.rail,
    this.partyPosition,
    super.key,
  });

  /// Whose inventory this is, re-read on every build.
  ///
  /// ⚠️ **A callback, not a value, and that was a real defect.** Pushed with a
  /// `Character` snapshot the screen showed the inventory as it stood when the
  /// route opened: adding an item applied the edit and changed nothing on
  /// screen, which is the invisible-behaviour failure this project has shipped
  /// three times. The caller watches its own view model and this asks again.
  final Character Function() character;

  /// Called with the resref and the slot to put it in.
  final void Function(String resref, CreItemSlot slot) onAdd;

  /// Whether the document has edits it has not written yet.
  final bool isDirty;

  /// Writes the document, or `null` to leave this surface without a Save.
  ///
  /// ⚠️ **Supplied, not reached for.** The two documents have different view
  /// models, and this screen serves both — see [character] for the same reason.
  final VoidCallback? onSave;

  /// The party, drawn down the left-hand side.
  ///
  /// ⚠️ **Null for an exported character, and that is a decision.** A `.chr` is
  /// one character with no party, so there is nothing for a rail to show; a
  /// one-member rail would be decoration, and a control that does nothing is a
  /// defect in this application rather than a nicety.
  final Widget? rail;

  /// Where this character sits in the party, or `null` when there is no party.
  ///
  /// ⚠️ **What makes a row draggable, and a position rather than an offset.**
  /// Handing an item over shrinks this character's record and moves every
  /// record after it, so an offset captured when the drag began would be stale
  /// by the time the drop lands. `null` for a `.chr`: nobody to give it to.
  final int? partyPosition;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<CarriedItem> get _items => widget.character().items;

  /// The first backpack slot nothing points at.
  ///
  /// ⚠️ **Scans rather than counts.** Holes are legal — a real character fills
  /// packs 1–7 and 9, leaving 8 empty — so the item count is not the index of
  /// the next free slot, and using it would overwrite what is already there.
  CreItemSlot? get _firstFreePack {
    final taken = {
      for (final item in _items)
        if (item.isInASlot) item.slotIndex,
    };
    for (final slot in CreItemSlot.pack) {
      if (!taken.contains(slot.index)) return slot;
    }
    return null;
  }

  void _add(ItemEntry entry) {
    final slot = _firstFreePack;
    if (slot == null) return;
    widget.onAdd(entry.resref, slot);
    _query.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.character().name} · Inventory'
          // The same marker both editors put beside the document's name.
          '${widget.isDirty ? ' •' : ''}',
        ),
        actions: [
          if (widget.onSave != null) ...[
            SaveButton(isDirty: widget.isDirty, onSave: widget.onSave),
            const SizedBox(width: 12),
          ],
        ],
      ),
      // ⚠️ **The same shape the character sheet uses**, so the two read as one
      // editor rather than two screens: rail, divider, then the content.
      body: Row(
        children: [
          if (widget.rail case final Widget rail) ...[
            rail,
            const VerticalDivider(width: 1),
          ],
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final catalogue =
        ref.watch(itemCatalogueProvider).value ?? ItemCatalogue.empty;
    final free = _firstFreePack;
    final results = catalogue.search(_query.text);

    return Scrollbar(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  _Search(
                    controller: _query,
                    onChanged: () => setState(() {}),
                    enabled: free != null,
                  ),
                  if (free == null)
                    Text(
                      'The inventory is full. Nothing can be added until '
                      'something is taken out in game.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  if (_query.text.trim().isNotEmpty)
                    _Results(results: results, onAdd: _add),
                  _Carried(items: _items, from: widget.partyPosition),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({
    required this.controller,
    required this.onChanged,
    required this.enabled,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    onChanged: (_) => onChanged(),
    autofocus: true,
    decoration: const InputDecoration(
      labelText: 'Find an item',
      hintText: 'a name, or a resref like BOOT01',
      prefixIcon: Icon(Icons.search),
      border: OutlineInputBorder(),
    ),
  );
}

/// Search results, in three labelled tiers.
///
/// ⚠️ **The description tier is why the feature works at all.** "Boots of
/// Speed" matches no item *name* in BG:EE — the game calls it "The Paws of the
/// Cheetah" — and three item *descriptions*. But "speed" alone hits 238
/// descriptions, so they are grouped under their own heading rather than mixed
/// in, and a reader can always see why a row appeared.
class _Results extends StatelessWidget {
  const _Results({required this.results, required this.onAdd});

  final List<({ItemEntry entry, ItemMatch how})> results;
  final void Function(ItemEntry) onAdd;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const PanelCard(
        title: 'Found nothing',
        note: 'No item answers to that by name, by resref or by description.',
        children: [],
      );
    }

    final byTier = <ItemMatch, List<ItemEntry>>{};
    for (final result in results) {
      (byTier[result.how] ??= []).add(result.entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (final tier in ItemMatch.values)
          if (byTier[tier] case final List<ItemEntry> found)
            PanelCard(
              title: switch (tier) {
                ItemMatch.resref => 'That resref',
                ItemMatch.name => 'By name',
                ItemMatch.description => 'Only in the description',
              },
              note: tier == ItemMatch.description
                  ? 'The name does not match; the item’s own description does.'
                  : null,
              children: [
                for (final entry in found)
                  ListTile(
                    title: Text(entry.label),
                    subtitle: Text(entry.resref),
                    trailing: FilledButton.tonal(
                      onPressed: () => onAdd(entry),
                      child: const Text('Add'),
                    ),
                  ),
              ],
            ),
      ],
    );
  }
}

/// What the character is already carrying.
/// What the character is carrying.
///
/// ⚠️ **Called *Inventory* because that is what the game calls it.** Asked of
/// the talk table rather than agreed by ear: strrefs 6671, 11292 and 24358 are
/// exactly "Inventory", and "Inventory Full" names the same container.
/// **"Backpack" appears nowhere in it** — that word is this project's, and so
/// is "pack" in `CreItemSlot.pack`.
class _Carried extends StatelessWidget {
  const _Carried({required this.items, this.from});

  final List<CarriedItem> items;

  /// The owner's party position, when there is somebody to hand items to.
  final int? from;

  /// Whether [item] can be dragged to another character.
  ///
  /// ⚠️ **Backpack only.** Equipment is not modelled, and taking a worn item
  /// off would change a *stored* effective armour class the engine reads rather
  /// than recomputes — so the sheet would disagree with the game with nothing
  /// on screen to say why.
  bool _movable(CarriedItem item) =>
      from != null &&
      item.isInASlot &&
      CreItemSlot.values[item.slotIndex].isPack;

  @override
  Widget build(BuildContext context) => PanelCard(
    title: 'Inventory',
    note: items.isEmpty ? 'Nothing yet.' : null,
    trailing: Tag('${items.length}', caption: 'items'),
    children: [
      for (final item in items)
        _row(
          item,
          ListTile(
            dense: true,
            title: Text(item.resref),
            subtitle: Text(_where(item)),
            trailing: Wrap(
              spacing: 8,
              children: [
                if (item.quantity > 1)
                  Tag('${item.quantity}', caption: 'quantity'),
                // ⚠️ Stated, not hidden: with the flag clear the game draws the
                // item's plain name, so a reader who sees only a resref here
                // should know why the game will not call it what they expect.
                if (!item.isIdentified)
                  const Tag('unidentified', tone: TagTone.muted),
              ],
            ),
          ),
        ),
    ],
  );

  /// [row] made draggable, when the item may be handed to somebody else.
  ///
  /// ⚠️ **`affinity: Axis.horizontal`, and the suite would not have caught
  /// this.** Flutter's own documentation on the parameter: a draggable with
  /// null or vertical affinity "will out-compete the Scrollable for vertical
  /// gestures" — which would leave this list unscrollable, with every attempt
  /// to scroll picking an item up instead. Horizontal keeps both alive, and it
  /// is the natural direction anyway: the portraits are to the LEFT of here.
  Widget _row(CarriedItem item, Widget row) {
    if (!_movable(item)) return row;
    return Draggable<ItemDrag>(
      affinity: Axis.horizontal,
      data: ItemDrag(
        from: from!,
        itemIndex: item.index,
        resref: item.resref,
      ),
      feedback: ItemDragFeedback(resref: item.resref),
      childWhenDragging: Opacity(opacity: 0.4, child: row),
      child: row,
    );
  }

  static String _where(CarriedItem item) {
    if (!item.isInASlot) return 'in no slot — the game will not show it';
    final slot = CreItemSlot.values[item.slotIndex];
    return slot.isPack ? 'backpack' : slot.name;
  }
}
