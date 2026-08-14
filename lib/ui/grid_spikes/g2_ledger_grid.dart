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
/// **G2 — "Ledger grid", audit-biased.** A full-width band across the top, and
/// three record columns beneath it, each scrolling on its own. Fixed widths,
/// authored positions, no `MediaQuery` and no `LayoutBuilder`.
///
/// - **The band**: who this is, the party as a **horizontal** switcher, ONE
///   unified find over the record *and* the catalogue, and the chrome.
/// - **Column 1**: Character, Abilities, Skills. The side sheet slides over
///   **this column only** — never over the numbers, never over the items.
/// - **Column 2**: Proficiencies, Combat, Resistances, Condition — the numbers
///   equipment moves, one column from the items.
/// - **Column 3**: what the find turned up, the backpack, Equipped, In no slot.
///
/// Its bet against G1 is that three columns visible at once make the whole
/// record readable in one pass, and that one search box beats two.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/domain/item_catalogue.dart';
import 'package:wand_of_saves/ui/character/character_sheet_view.dart';
import 'package:wand_of_saves/ui/character/findings.dart';
import 'package:wand_of_saves/ui/character/side_sheet.dart';
import 'package:wand_of_saves/ui/grid_spikes/grid_spike_host.dart';
import 'package:wand_of_saves/ui/grid_spikes/member_switcher.dart';
import 'package:wand_of_saves/ui/grid_spikes/unified_find.dart';
import 'package:wand_of_saves/ui/inventory/inventory_screen.dart';
import 'package:wand_of_saves/ui/inventory/pack_slots.dart';

const List<String> _columnOne = ['Character', 'Abilities', 'Skills'];
const List<String> _columnTwo = [
  'Proficiencies',
  'Combat',
  'Resistances',
  'Condition',
];

/// Column 1's width, which is also the side sheet's — the drawer theme states
/// 420, and the sheet is authored to cover this column exactly.
const double _columnOneWidth = 420;
const double _columnTwoWidth = 460;

/// G2 over the savegame in [slotDirectoryName].
class G2LedgerGrid extends StatelessWidget {
  /// Opens the spike on that save slot.
  const G2LedgerGrid({required this.slotDirectoryName, super.key});

  /// The save slot directory the entry point picked.
  final String slotDirectoryName;

  @override
  Widget build(BuildContext context) => GridSpikeHost(
    slotDirectoryName: slotDirectoryName,
    builder: (context, model) => _G2Body(model: model),
  );
}

class _G2Body extends ConsumerStatefulWidget {
  const _G2Body({required this.model});

  final GridSpikeModel model;

  @override
  ConsumerState<_G2Body> createState() => _G2BodyState();
}

class _G2BodyState extends ConsumerState<_G2Body> {
  final SearchController _find = SearchController();
  final ScrollController _first = ScrollController();
  final ScrollController _second = ScrollController();
  final ScrollController _third = ScrollController();

  /// What the unified find last looked for, so column 3 keeps showing it after
  /// the suggestion view has closed.
  final TextEditingController _itemQuery = TextEditingController();

  Subject? _editing;

  @override
  void dispose() {
    _find.dispose();
    _first.dispose();
    _second.dispose();
    _third.dispose();
    _itemQuery.dispose();
    super.dispose();
  }

  /// Where an item chosen in the band would land, or `null` when it is full.
  ///
  /// ⚠️ Asked of the shared rule rather than worked out here — holes in the
  /// backpack are ordinary, so the item count is not the answer.
  CreItemSlot? get _freeSlot => firstFreePackSlot(widget.model.character.items);

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final panels = sheetPanelsOf(
      character: model.sheet,
      rulesBind: model.rulesBind,
      onOpen: (subject) => setState(() => _editing = subject),
    );
    final editing = _editing;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _find.openView,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            _TopBand(
              model: model,
              find: _find,
              canAdd: _freeSlot != null,
              onSubject: (subject) => setState(() => _editing = subject),
              onItem: (entry) {
                if (_freeSlot case final CreItemSlot slot) {
                  model.addItem(entry.resref, slot);
                }
              },
              onQuery: (query) => setState(() => _itemQuery.text = query),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: _columnOneWidth,
                    // ⚠️ **The sheet covers this column and nothing else.**
                    // That is the whole authored constraint: editing a field
                    // may hide the slow half of the record, never the numbers
                    // and never the items.
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _RecordColumn(
                            titles: _columnOne,
                            panels: panels,
                            scroll: _first,
                          ),
                        ),
                        if (editing != null)
                          Positioned.fill(
                            child: SideSheet(
                              key: ValueKey<String>(subjectKey(editing)),
                              subject: editing,
                              character: model.sheet,
                              rulesBind: model.rulesBind,
                              onApplyField: model.applyField,
                              onApplyPips: model.applyPips,
                              onClose: () => setState(() => _editing = null),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: _columnTwoWidth,
                    child: _RecordColumn(
                      titles: _columnTwo,
                      panels: panels,
                      scroll: _second,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Scrollbar(
                      controller: _third,
                      child: SingleChildScrollView(
                        controller: _third,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        child: InventoryPanels(
                          character: () => model.character,
                          onAdd: model.addItem,
                          partyPosition: model.state.selectedIndex,
                          onRemove: model.removeItem,
                          party: [
                            for (final member in model.state.members)
                              member.name,
                          ],
                          onMoveTo: (item, to) => model.moveItem(
                            from: model.state.selectedIndex,
                            to: to,
                            itemIndex: item.index,
                            resref: item.resref,
                          ),
                          // ⚠️ **No box of its own.** G2's bet is one find, so
                          // the results here answer the band's query rather
                          // than a second search nobody asked for.
                          query: _itemQuery,
                          showSearchField: false,
                        ),
                      ),
                    ),
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

/// The full-width band: identity, the switcher, the one find, and the chrome.
class _TopBand extends StatelessWidget {
  const _TopBand({
    required this.model,
    required this.find,
    required this.canAdd,
    required this.onSubject,
    required this.onItem,
    required this.onQuery,
  });

  final GridSpikeModel model;
  final SearchController find;
  final bool canAdd;
  final ValueChanged<Subject> onSubject;
  final ValueChanged<ItemEntry> onItem;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheet = model.sheet;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sheet.name, style: theme.textTheme.titleLarge),
                Text(
                  [sheet.levelLine, ...sheet.identity].join('  ·  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  sheet.experienceLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          MemberSwitcher(
            state: model.state,
            slotDirectoryName: model.slotDirectoryName,
            onItemDropped: (drag, to) => model.moveItem(
              from: drag.from,
              to: to,
              itemIndex: drag.itemIndex,
              resref: drag.resref,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: UnifiedFind(
              controller: find,
              character: sheet,
              canAdd: canAdd,
              onSubject: onSubject,
              onItem: onItem,
              onQuery: onQuery,
            ),
          ),
          const SizedBox(width: 12),
          ...spikeChrome(context, model, onFindings: find.openView),
        ],
      ),
    );
  }
}

/// One of the three record columns, scrolling on its own.
class _RecordColumn extends StatelessWidget {
  const _RecordColumn({
    required this.titles,
    required this.panels,
    required this.scroll,
  });

  final List<String> titles;
  final Map<String, Widget> panels;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: scroll,
    child: SingleChildScrollView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final title in titles)
              if (panels[title] case final Widget panel) ...[
                panel,
                const SizedBox(height: 16),
              ],
          ],
        ),
      ),
    ),
  );
}
