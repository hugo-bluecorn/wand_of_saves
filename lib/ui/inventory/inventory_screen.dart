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
import 'package:wand_of_saves/ui/inventory/pack_slots.dart';

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
    this.onRemove,
    this.party = const [],
    this.onMoveTo,
    this.onUndo,
    this.onRedo,
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

  /// Takes the item out of the record, or `null` where that is not offered.
  ///
  /// ⚠️ **The one thing this application can do that the game cannot.**
  /// `CreItemFlag.undroppable` says so in its own words — an item so marked
  /// "cannot be removed in game — only from an editor" — and a cursed item
  /// already worn is the same case.
  final void Function(CarriedItem item)? onRemove;

  /// The party, in order, for the *Move to* submenu. Empty for a `.chr`.
  final List<String> party;

  /// Hands the item to the member at that party position.
  ///
  /// ⚠️ **Not redundant with dragging.** The rail cannot auto-scroll while a
  /// drag is in flight, so a member below the fold cannot be reached by drag at
  /// all; this path works whatever is scrolled where.
  final void Function(CarriedItem item, int to)? onMoveTo;

  /// Takes back the last edit, or `null` when there is nothing to take back.
  final VoidCallback? onUndo;

  /// Puts back the last undone edit, or `null` when there is none.
  final VoidCallback? onRedo;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  // ⚠️ On desktop a vertical scroll view does not attach itself to the
  // PrimaryScrollController, so the theme's always-visible Scrollbar must
  // share a controller with the scroll view it measures — without one it
  // has no position and asserts on the first frame.
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
          // ⚠️ **Not decoration, and not optional.** Remove is one click and
          // takes no confirmation, so undo is its only safety net — and a
          // safety net on a *different screen* from the destructive action is
          // not a design.
          if (widget.onUndo != null || widget.onRedo != null) ...[
            IconButton(
              onPressed: widget.onUndo,
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
            ),
            IconButton(
              onPressed: widget.onRedo,
              icon: const Icon(Icons.redo),
              tooltip: 'Redo',
            ),
            const SizedBox(width: 8),
          ],
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

  Widget _body(BuildContext context) => Scrollbar(
    controller: _scroll,
    child: SingleChildScrollView(
      controller: _scroll,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: InventoryPanels(
              character: widget.character,
              onAdd: widget.onAdd,
              partyPosition: widget.partyPosition,
              onRemove: widget.onRemove,
              party: widget.party,
              onMoveTo: widget.onMoveTo,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The inventory itself: the search, what it found, and what is carried.
///
/// **Everything [InventoryScreen] holds except the Scaffold around it**, so an
/// arrangement that puts the inventory in a cell of a grid rather than on a
/// screen of its own reuses these panels instead of drawing new ones. Every
/// rule about what may move, what menu an item gets and where the next item
/// goes lives here, once.
///
/// It scrolls nothing and constrains nothing: whoever places it decides both.
class InventoryPanels extends ConsumerStatefulWidget {
  /// Shows [character]'s inventory, adding through [onAdd].
  const InventoryPanels({
    required this.character,
    required this.onAdd,
    this.partyPosition,
    this.onRemove,
    this.party = const [],
    this.onMoveTo,
    this.groups = CarriedGroup.values,
    this.showSearchField = true,
    this.autofocusSearchField = true,
    super.key,
  });

  /// Whose inventory this is, re-read on every build. See
  /// [InventoryScreen.character] for why it is a callback.
  final Character Function() character;

  /// Called with the resref and the slot to put it in.
  final void Function(String resref, CreItemSlot slot) onAdd;

  /// Where this character sits in the party, or `null` when there is no party.
  final int? partyPosition;

  /// Takes the item out of the record, or `null` where that is not offered.
  final void Function(CarriedItem item)? onRemove;

  /// The party, in order, for the *Move to* submenu. Empty for a `.chr`.
  final List<String> party;

  /// Hands the item to the member at that party position.
  final void Function(CarriedItem item, int to)? onMoveTo;

  /// Which of the three groups of carried items to draw.
  ///
  /// A page that balances two columns puts some of them on one side and the
  /// rest on the other; everything else takes all three.
  final List<CarriedGroup> groups;

  /// Whether to draw the item search box above the results.
  final bool showSearchField;

  /// Whether that box takes focus when it appears.
  ///
  /// ⚠️ **Two boxes on one surface cannot both have it.** A grid with a field
  /// palette and an item search would otherwise start with the focus in
  /// whichever built last, which is not a decision the layout should make by
  /// accident.
  final bool autofocusSearchField;

  @override
  ConsumerState<InventoryPanels> createState() => _InventoryPanelsState();
}

class _InventoryPanelsState extends ConsumerState<InventoryPanels> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<CarriedItem> get _items => widget.character().items;

  ItemCatalogue get _catalogue =>
      ref.read(itemCatalogueProvider).value ?? ItemCatalogue.empty;

  CreItemSlot? get _firstFreePack => firstFreePackSlot(_items);

  /// Whether [item] may be handed to another character at all.
  ///
  /// ⚠️ **Backpack slots only, and equipment is not an oversight.** `MoveItem`
  /// refuses anything else, and the reason it must is recorded: the engine
  /// reads a *stored* effective armour class rather than recomputing it from
  /// what is worn, so taking a worn item off without recalculating leaves the
  /// character carrying its protection while not wearing it. That is a save
  /// that loads and is quietly wrong, which is the failure this project exists
  /// to avoid. Equipping and unequipping wait for "Recalculate Stats".
  bool _movesBetweenCharacters(CarriedItem item) =>
      widget.partyPosition != null &&
      item.isInASlot &&
      CreItemSlot.values[item.slotIndex].isPack &&
      // ⚠️ And not something the engine refuses to move at all — handing
      // `BOW99` on would simply strand it on somebody else instead.
      _catalogue.entries[item.resref]?.isMovable != false;

  /// The menu for [item], or `null` when no action is on offer.
  ///
  /// Built here rather than in the widgets because it is the caller's
  /// capability that decides what exists — the same rule `onSave` and `rail`
  /// already follow.
  Widget? _menuFor(CarriedItem item) {
    final remove = widget.onRemove;
    // ⚠️ **The same predicate the drag uses**, and that is the fix rather than
    // a tidy-up: the menu carried a second copy of this rule and got it wrong,
    // offering a move that `MoveItem` refuses and so threw on the way through.
    final moveTo = _movesBetweenCharacters(item) ? widget.onMoveTo : null;
    final owner = widget.partyPosition;
    final elsewhere = [
      for (final (position, name) in widget.party.indexed)
        if (position != owner) (position, name),
    ];
    if (remove == null && (moveTo == null || elsewhere.isEmpty)) return null;

    return ItemMenu(
      onRemove: remove == null ? null : () => remove(item),
      destinations: moveTo == null ? const [] : elsewhere,
      onMoveTo: moveTo == null ? null : (to) => moveTo(item, to),
    );
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
    final catalogue =
        ref.watch(itemCatalogueProvider).value ?? ItemCatalogue.empty;
    final free = _firstFreePack;
    final results = catalogue.search(_query.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        if (widget.showSearchField)
          ItemSearchField(
            controller: _query,
            onChanged: () => setState(() {}),
            enabled: free != null,
            autofocus: widget.autofocusSearchField,
          ),
        // ⚠️ Only where something could have been added. On a surface drawing
        // one group with no search box, a note explaining why adding is
        // refused explains a control that is not there.
        if (widget.showSearchField && free == null)
          Text(
            'The inventory is full. Nothing can be added until '
            'something is taken out in game.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        if (_query.text.trim().isNotEmpty)
          ItemResults(
            results: results.results,
            withheld: results.withheld,
            onAdd: _add,
          ),
        CarriedSections(
          menu: _menuFor,
          canMove: _movesBetweenCharacters,
          items: _items,
          groups: widget.groups,
          from: widget.partyPosition,
          // ⚠️ Cross-referenced from the catalogue: the creature record says
          // nothing about droppability, so a carried row can only explain
          // itself by asking the item.
          isStuck: (resref) => catalogue.entries[resref]?.isMovable == false,
          describe: (resref) => catalogue.entries[resref],
        ),
      ],
    );
  }
}

/// The box that finds an item in the installation's catalogue.
class ItemSearchField extends StatelessWidget {
  /// Searches through [controller], reporting keystrokes to [onChanged].
  const ItemSearchField({
    required this.controller,
    required this.onChanged,
    required this.enabled,
    this.autofocus = true,
    super.key,
  });

  /// The query being typed.
  final TextEditingController controller;

  /// Called on every keystroke, so results follow the text.
  final VoidCallback onChanged;

  /// Whether there is anywhere to put what it finds.
  final bool enabled;

  /// Whether it takes focus when it appears.
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    onChanged: (_) => onChanged(),
    autofocus: autofocus,
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
class ItemResults extends StatelessWidget {
  /// Draws [results], noting how many were [withheld].
  const ItemResults({
    required this.results,
    required this.withheld,
    required this.onAdd,
    super.key,
  });

  /// What matched, and how each one was reached.
  final List<({ItemEntry entry, ItemMatch how})> results;

  /// How many matches the engine could never move, and so were not offered.
  final int withheld;

  /// Puts the chosen item in the first free backpack slot.
  final void Function(ItemEntry) onAdd;

  /// What to say about the matches that were not offered.
  ///
  /// ⚠️ **Said rather than shown.** Searching "attack" matches sixty items,
  /// every one of them a thing the engine will not release — sixty greyed rows
  /// is wallpaper, and the findings badge that read 13 is this project's
  /// standing lesson about that. But dropping them silently would hide a third
  /// of the catalogue, so the count is stated.
  String get _withheldNote =>
      '$withheld more ${withheld == 1 ? "match was" : "matches were"} '
      'withheld: the game will not let ${withheld == 1 ? "it" : "them"} '
      'be moved or equipped.';

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return PanelCard(
        title: 'Found nothing',
        note: withheld == 0
            ? 'No item answers to that by name, by resref or by description.'
            : _withheldNote,
        children: const [],
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
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // ⚠️ Said, not enforced. Cursed means the item cannot
                        // be taken off once worn — it carries and changes hands
                        // like any other until then, and the game's own shops
                        // sell them.
                        if (entry.isCursed)
                          const Tag('cursed', tone: TagTone.muted),
                        FilledButton.tonal(
                          onPressed: () => onAdd(entry),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        if (withheld > 0)
          Text(
            _withheldNote,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }
}

/// One of the three groups a character's items fall into.
///
/// Named so a surface can draw some of them here and the rest somewhere else —
/// a two-column page balancing its halves has to be able to say which.
enum CarriedGroup {
  /// The sixteen backpack slots, drawn as a grid whether filled or not.
  backpack,

  /// What is worn or held.
  equipped,

  /// Items no slot points at. Legal, observed, and invisible in game.
  inNoSlot,
}

/// What the character carries, wears, and holds in no slot at all.
///
/// ⚠️ **Three panels, because the rows are three different kinds of thing.**
/// Only backpack items can be handed to somebody else, and a list where some
/// rows drag and some do not — with nothing saying why — is an unexplained
/// affordance. The grouping is what justifies the difference.
class CarriedSections extends StatelessWidget {
  /// Draws [items] in their three groups.
  const CarriedSections({
    required this.items,
    required this.isStuck,
    required this.describe,
    required this.menu,
    required this.canMove,
    this.groups = CarriedGroup.values,
    this.from,
    super.key,
  });

  /// Everything the record holds, in whatever slot.
  final List<CarriedItem> items;

  /// Which of the three groups to draw. All of them, unless a surface splits
  /// them across more than one place.
  final List<CarriedGroup> groups;

  /// Whether the engine refuses to move the item with that resref.
  final bool Function(String resref) isStuck;

  /// What the catalogue knows about that resref, or `null` with no game.
  final ItemEntry? Function(String resref) describe;

  /// What can be done with an item, or `null` when nothing is on offer.
  final Widget? Function(CarriedItem item) menu;

  /// Whether an item may be handed to another character.
  ///
  /// ⚠️ **Supplied, not recomputed.** This rule had two copies — one here for
  /// the drag and one in the menu — and only the drag's was right, so the menu
  /// offered a move the command refuses and threw on the way through.
  final bool Function(CarriedItem item) canMove;

  /// The owner's party position, when there is somebody to hand items to.
  final int? from;

  /// Whether [item] can be dragged to another character.
  ///
  /// ⚠️ **Backpack only.** Equipment is not modelled, and taking a worn item
  /// off would change a *stored* effective armour class the engine reads rather
  /// than recomputes — so the sheet would disagree with the game with nothing
  /// on screen to say why.
  bool _movable(CarriedItem item) => canMove(item);

  bool _isPack(CarriedItem item) =>
      item.isInASlot && CreItemSlot.values[item.slotIndex].isPack;

  @override
  Widget build(BuildContext context) {
    final carried = items.where(_isPack).toList();
    final worn = items
        .where((item) => item.isInASlot && !_isPack(item))
        .toList();
    // ⚠️ **Never dropped.** An item no slot points at is legal and observed —
    // 618 across 220 shipped creature records — and this screen's job is to
    // show the record, so it gets a panel of its own rather than vanishing.
    final loose = items.where((item) => !item.isInASlot).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        // ⚠️ **Called *Inventory* because that is what the game calls it.**
        // Asked of the talk table rather than agreed by ear: strrefs 6671,
        // 11292 and 24358 are exactly "Inventory", and "Inventory Full" names
        // the same container. **"Backpack" appears in none of its 34,000
        // strings** — that word was this project's, and so is "pack" in
        // `CreItemSlot.pack`.
        if (groups.contains(CarriedGroup.backpack))
          SlotGrid(
            title: 'Inventory',
            slots: CreItemSlot.pack,
            items: carried,
            row: _row,
            describe: describe,
            menu: menu,
          ),
        // ⚠️ Not a heading the game itself uses — its own screen is a paper
        // doll, not a list — but "equipped" is its word, running right through
        // the item descriptions ("when equipped", "cannot be equipped").
        // Borrowed, not coined.
        //
        // ⚠️ **Drawn whether anything is worn or not**, where the list it
        // replaced appeared only once something was. That inverted with the
        // grid: a list of nothing is nothing, but twenty-two empty cells say
        // *these are the places things go and all of them are free*, which is
        // the same thing the sixteen backpack cells have always said.
        if (groups.contains(CarriedGroup.equipped))
          SlotGrid(
            title: 'Equipped',
            slots: equipmentSlots,
            items: worn,
            row: _row,
            describe: describe,
            menu: menu,
            named: true,
          ),
        if (groups.contains(CarriedGroup.inNoSlot) && loose.isNotEmpty)
          CarriedPanel(
            title: 'In no slot',
            items: loose,
            row: _row,
            isStuck: isStuck,
            describe: describe,
            menu: menu,
            note: 'No slot points at these, so the game will not show them.',
          ),
      ],
    );
  }

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

  /// Which slot holds [item], or `null` when the panel title already says.
  ///
  /// ⚠️ **A backpack row gets nothing.** Under a panel headed *Inventory*, a
  /// subtitle reading "Inventory" on every row is the grouping restating
  /// itself — and this project has already shipped a findings badge whose every
  /// entry repeated the two chips beside it.
  static String? slotTagFor(CarriedItem item) {
    if (!item.isInASlot) return null;
    final slot = CreItemSlot.values[item.slotIndex];
    return slot.isPack ? null : slotLabel(slot);
  }
}

/// What BG:EE calls [slot], rather than what this codebase calls it.
///
/// ⚠️ **`slot.name` used to be printed straight at the reader**, so a real
/// character's inventory said `leftRing`, `quickItem` and `magicWeapon` — enum
/// identifiers, on screen, as user-facing text.
///
/// The words are the game's own, each with the strref it was read from so the
/// source stays recoverable. ⚠️ **Two caveats worth stating rather than
/// glossing:**
///
/// - **The numerals are ours.** The game has no standalone "Weapon" string, so
///   the four weapon slots take its noun and our number.
/// - **Hardcoded English, and that is a localisation gap.** D11 wants anything
///   carrying a strref read from the player's own installation, and these do
///   have strrefs — but **no BG:EE table maps a slot to one** (`itmslots.2da`
///   is PSTEE-only), so the mapping would be this project's either way.
///   Hardcoding is the smaller invention than a strref map that would look
///   authoritative and would not be.
String slotLabel(CreItemSlot slot) => switch (slot) {
  CreItemSlot.helmet => 'Helmet', // 11999
  CreItemSlot.armor => 'Armor', // 11997 — the game's spelling, so it wins here
  CreItemSlot.shield => 'Shield', // 12006 — holds an off-hand weapon too
  CreItemSlot.gloves => 'Gauntlets', // 11998
  // ⚠️ The game's talk table has *Ring* (6348) and nothing distinguishing the
  // hands, so the qualifier is ours — the same honest gap as the numerals
  // below. Both slots sharing one label left a character wearing two rings
  // with two identical rows and no way to tell which was which.
  CreItemSlot.leftRing => 'Left Ring', // 6348 + ours
  CreItemSlot.rightRing => 'Right Ring', // 6348 + ours
  CreItemSlot.amulet => 'Amulet', // 12000
  CreItemSlot.belt => 'Belt', // 12001
  CreItemSlot.boots => 'Boots', // 12005
  CreItemSlot.cloak => 'Cloak', // 12004
  CreItemSlot.weapon1 => 'Weapon 1',
  CreItemSlot.weapon2 => 'Weapon 2',
  CreItemSlot.weapon3 => 'Weapon 3',
  CreItemSlot.weapon4 => 'Weapon 4',
  CreItemSlot.quiver1 => 'Quiver 1', // 12009
  CreItemSlot.quiver2 => 'Quiver 2',
  CreItemSlot.quiver3 => 'Quiver 3',
  // ⚠️ Real, and unreachable from the game's own interface.
  CreItemSlot.quiver4 => 'Quiver 4',
  // The game's own casing — 12012 is exactly "Quick Item".
  CreItemSlot.quick1 => 'Quick Item 1', // 12012
  CreItemSlot.quick2 => 'Quick Item 2',
  CreItemSlot.quick3 => 'Quick Item 3',
  // IESDP's name for it, not a string the game shows: the engine fills this
  // slot itself.
  CreItemSlot.magicWeapon => 'Magic weapon',
  _ => 'Inventory', // 6671 — the sixteen backpack slots
};

/// One titled group of rows.
class CarriedPanel extends StatelessWidget {
  /// Draws [items] under [title].
  const CarriedPanel({
    required this.title,
    required this.items,
    required this.row,
    required this.isStuck,
    required this.describe,
    required this.menu,
    this.note,
    super.key,
  });

  /// The heading.
  final String title;

  /// What to draw under it.
  final List<CarriedItem> items;

  /// Wraps a row in whatever gesture it may take part in.
  final Widget Function(CarriedItem, Widget) row;

  /// Whether the engine refuses to move the item with that resref.
  final bool Function(String resref) isStuck;

  /// What the catalogue knows about that resref, or `null` with no game.
  final ItemEntry? Function(String resref) describe;

  /// What can be done with an item, or `null` when nothing is on offer.
  final Widget? Function(CarriedItem item) menu;

  /// The name the game would draw, or `null` when the catalogue cannot say.
  String? _named(CarriedItem item) =>
      describe(item.resref)?.nameWhen(identified: item.isIdentified);

  /// A qualifier for the panel as a whole.
  ///
  /// ⚠️ **Once, not per row.** A panel that states its own meaning should not
  /// repeat it on every line — the same reasoning that took the redundant
  /// "Inventory" subtitle off the backpack rows.
  final String? note;

  @override
  Widget build(BuildContext context) => PanelCard(
    title: title,
    note: note,
    children: [
      for (final item in items)
        row(
          item,
          ListTile(
            dense: true,
            // ⚠️ **The slot leads, and the warnings trail.** "Which slot" is an
            // identifier; "cannot be moved" is a caveat. Mixed together the eye
            // cannot tell what is describing the row from what is warning about
            // it.
            leading: switch (CarriedSections.slotTagFor(item)) {
              final String where => Tag(where),
              null => null,
            },
            // The name the game would draw, by the same rule the cell uses —
            // shared through the domain rather than copied, because a copy in
            // each surface is how the two came to disagree in the first place.
            // ⚠️ The code is the subtitle only when there is a name above it;
            // with no game installed the row would otherwise say the code
            // twice.
            title: Text(_named(item) ?? item.resref),
            subtitle: _named(item) == null ? null : Text(item.resref),
            trailing: Wrap(
              spacing: 8,
              children: [
                // ⚠️ What explains the row that will not drag. The engine
                // refuses to move it at all — measured on `BOW99`, whose own
                // ITM header has IESDP's Movable bit clear.
                if (isStuck(item.resref))
                  const Tag('cannot be moved', tone: TagTone.muted),
                if (item.quantity > 1)
                  Tag('${item.quantity}', caption: 'quantity'),
                // ⚠️ Stated, not hidden: with the flag clear the game draws the
                // item's plain name, so a reader who sees only a resref here
                // should know why the game will not call it what they expect.
                if (!item.isIdentified)
                  const Tag('unidentified', tone: TagTone.muted),
                ?menu(item),
              ],
            ),
          ),
        ),
    ],
  );
}

/// The twenty-two slots that are not the backpack, in an authored order.
///
/// ⚠️ **Not the record's order.** `CreItemSlot` stores the cloak between the
/// fourth quiver and the first quick item; nobody reads what a person is
/// wearing that way. Worn things first, then the weapons, the quivers, the
/// quick slots, and last the one the engine fills itself.
const List<CreItemSlot> equipmentSlots = [
  CreItemSlot.helmet,
  CreItemSlot.amulet,
  CreItemSlot.armor,
  CreItemSlot.cloak,
  CreItemSlot.gloves,
  CreItemSlot.leftRing,
  CreItemSlot.rightRing,
  CreItemSlot.belt,
  CreItemSlot.boots,
  CreItemSlot.shield,
  CreItemSlot.weapon1,
  CreItemSlot.weapon2,
  CreItemSlot.weapon3,
  CreItemSlot.weapon4,
  CreItemSlot.quiver1,
  CreItemSlot.quiver2,
  CreItemSlot.quiver3,
  CreItemSlot.quiver4,
  CreItemSlot.quick1,
  CreItemSlot.quick2,
  CreItemSlot.quick3,
  CreItemSlot.magicWeapon,
];

/// A named run of slots, as cells rather than as a list of what is in them.
///
/// ⚠️ **Every slot always, and addressed by SLOT rather than by list
/// position.** An item in `pack10` draws in cell 10 with 7 to 9 left empty, and
/// an empty helmet slot draws as an empty cell headed *Helmet*. Holes are
/// ordinary — a real character fills packs 1–7 and 9 — so a grid that packed
/// items leftward would be a prettier lie than the list it replaces, and would
/// hide the one thing a slot grid has to convey: **where a thing can go, and
/// whether anything is there.**
///
/// **Rows of four `Expanded` cells, not a `GridView`.** These land in a
/// `Column` inside a `SingleChildScrollView`, where a `GridView` needs
/// `shrinkWrap` and `NeverScrollableScrollPhysics` and behaves awkwardly. The
/// slot count is fixed, so the rows are deterministic and carry none of that.
class SlotGrid extends StatelessWidget {
  /// Draws every slot of [slots], filling them from [items].
  const SlotGrid({
    required this.title,
    required this.slots,
    required this.items,
    required this.row,
    required this.describe,
    required this.menu,
    this.named = false,
    super.key,
  });

  /// The panel's heading.
  final String title;

  /// Which slots to draw, in the order to draw them.
  final List<CreItemSlot> slots;

  /// What the character holds in them.
  final List<CarriedItem> items;

  /// Wraps a cell in whatever gesture it may take part in.
  final Widget Function(CarriedItem, Widget) row;

  /// What the catalogue knows about that resref, or `null` with no game.
  final ItemEntry? Function(String resref) describe;

  /// What can be done with an item, or `null` when nothing is on offer.
  final Widget? Function(CarriedItem item) menu;

  /// Whether each cell says which slot it is.
  ///
  /// ⚠️ **False for the backpack, and that is not an oversight.** Its sixteen
  /// slots are interchangeable and the game calls every one of them
  /// *Inventory*, so a caption on each would be the panel's own heading said
  /// sixteen more times. An equipment slot is the opposite: *Helmet* is the
  /// only thing that tells an empty cell from the empty cell beside it.
  final bool named;

  static const int _columns = 4;

  @override
  Widget build(BuildContext context) {
    final held = {
      for (final item in items)
        if (item.isInASlot) item.slotIndex: item,
    };

    return PanelCard(
      title: title,
      children: [
        for (var start = 0; start < slots.length; start += _columns)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            // ⚠️ `IntrinsicHeight` rather than `CrossAxisAlignment.stretch`:
            // this Row sits in an unbounded column, where stretch resolves to
            // an infinite height and throws during layout. Four children make
            // the intrinsic pass cheap.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  for (final slot in slots.skip(start).take(_columns))
                    Expanded(
                      child: () {
                        final item = held[slot.index];
                        final cell = InventoryCell(
                          item: item,
                          entry: item == null ? null : describe(item.resref),
                          menu: item == null ? null : menu(item),
                          slotLabel: named ? slotLabel(slot) : null,
                        );
                        return item == null ? cell : row(item, cell);
                      }(),
                    ),
                  // ⚠️ The last row is short unless the count divides by four,
                  // and without these the two cells left over would stretch to
                  // half the panel each.
                  for (var pad = slots.length - start; pad < _columns; pad++)
                    const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One backpack slot, filled or not.
///
/// ⚠️ **Both the name and the code, and both earn their place.** The name is
/// what a person recognises; the code is the only thing that tells items apart,
/// because `BOOT01`, `BOOTDRIZ`, `DASBOOT` and `TROLLBOO` all resolve to "The
/// Paws of the Cheetah" and one of them is the immovable one.
class InventoryCell extends StatelessWidget {
  /// Draws [item], or an empty slot when it is `null`.
  const InventoryCell({
    required this.item,
    required this.entry,
    this.menu,
    this.slotLabel,
    super.key,
  });

  /// What is in the slot, or `null` when nothing is.
  final CarriedItem? item;

  /// What the catalogue knows about it, or `null` with no game installed.
  final ItemEntry? entry;

  /// What can be done with it, or `null` when nothing is on offer.
  final Widget? menu;

  /// Which slot this cell is, or `null` where the slot has no name worth
  /// giving — see [SlotGrid.named].
  ///
  /// ⚠️ **Drawn even when the cell is empty**, because that is the whole point:
  /// an unnamed empty cell says only that something could go somewhere.
  final String? slotLabel;

  /// The name the *game* would draw for [item].
  ///
  /// ⚠️ **`isIdentified` decides it, and getting this wrong states something
  /// the game does not.** With the flag clear the engine shows the plain name —
  /// "Belt", never "Belt of Antipode" — and `Aard1.chr` carries exactly that
  /// case. Falls back to nothing rather than inventing a name when the
  /// catalogue is empty; the code below is always there to read.
  String? get _name {
    final carried = item;
    if (carried == null) return null;
    return entry?.nameWhen(identified: carried.isIdentified);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final carried = item;

    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          // A filled slot is stated; an empty one is a quieter outline, so the
          // remaining capacity reads as space rather than as missing content.
          width: carried == null ? 1 : 1.5,
        ),
        color: carried == null
            ? null
            : theme.colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (slotLabel case final String where) ...[
            Text(
              where,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (carried != null) const SizedBox(height: 4),
          ],
          if (carried != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _name ?? carried.resref,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                ?menu,
              ],
            ),
            if (_name != null)
              Text(
                carried.resref,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                // ⚠️ What explains a cell that will not drag when its
                // neighbours will. `ItemEntry` already carries the answer,
                // read from the ITM header's Movable bit.
                if (entry?.isMovable == false)
                  const Tag('cannot be moved', tone: TagTone.muted),
                if (carried.quantity > 1)
                  Tag('${carried.quantity}', caption: 'quantity'),
                if (!carried.isIdentified)
                  const Tag('unidentified', tone: TagTone.muted),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// What can be done with one item.
///
/// ⚠️ **Two triggers on one menu, and both are needed.** The `…` is the only
/// thing on screen saying the menu exists, so right-click alone would be
/// undiscoverable; but right-click is the desktop gesture people will try, and
/// wiring it costs one callback. `MenuController.open(position:)` driven from
/// `onSecondaryTapDown` is the framework's own recipe.
class ItemMenu extends StatefulWidget {
  /// Offers [onRemove] and, where the party allows, a move to [destinations].
  const ItemMenu({
    required this.onRemove,
    required this.destinations,
    required this.onMoveTo,
    super.key,
  });

  /// Takes the item out of the record, or `null` when that is not offered.
  final VoidCallback? onRemove;

  /// Party members it could go to, as `(position, name)`. Empty for a `.chr`.
  final List<(int, String)> destinations;

  /// Hands it to the member at that party position.
  final void Function(int to)? onMoveTo;

  @override
  State<ItemMenu> createState() => _ItemMenuState();
}

class _ItemMenuState extends State<ItemMenu> {
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final moveTo = widget.onMoveTo;
    return MenuAnchor(
      controller: _controller,
      menuChildren: [
        if (moveTo != null && widget.destinations.isNotEmpty)
          SubmenuButton(
            menuChildren: [
              for (final (position, name) in widget.destinations)
                MenuItemButton(
                  onPressed: () => moveTo(position),
                  child: Text(name),
                ),
            ],
            child: const Text('Move to'),
          ),
        if (widget.onRemove case final VoidCallback remove)
          MenuItemButton(
            onPressed: remove,
            leadingIcon: const Icon(Icons.delete_outline),
            // No confirmation: undo is one click away, and a dialog on every
            // item would be worse than the mistake it guards against.
            child: const Text('Remove'),
          ),
      ],
      builder: (context, controller, _) => GestureDetector(
        onSecondaryTapDown: (details) =>
            controller.open(position: details.localPosition),
        child: IconButton(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.more_horiz),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          tooltip: 'Actions',
        ),
      ),
    );
  }
}
