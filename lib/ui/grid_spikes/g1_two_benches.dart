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
/// **G1, as the user has reshaped it: the party, and one column.**
///
/// - **Left, the party**: portraits that accept a dropped item, the identity,
///   and the chrome.
/// - **Right, the record**: the field palette, then Character, Abilities,
///   Skills and Proficiencies, then the **inventory**, then the numbers
///   equipment moves — Combat, Resistances, Condition. One scroll, one authored
///   order, nothing rearranging on resize.
///
/// Editing is **inline** wherever a row lives: the selected row expands the
/// editor beneath itself, and the side sheet does not appear. Finds stay
/// **split**: Ctrl+K over the record, the item search over the catalogue.
///
/// ⚠️ **The name is historical.** This is still the G1 the study drew and the
/// one D19 refers to, but there are no longer two benches and the numbers are
/// no longer pinned. Three changes, all the user's, all made after looking at
/// the built spike, and none of them what the paper derived:
///
/// 1. **The party column moved from the right edge to the left.** The study put
///    it on the right so the dominant drag — pack → member — travelled one
///    column instead of the window. It now travels the window. That was G1's
///    margin on the **W-A2** script.
/// 2. **The numbers stopped being pinned.** Measured, the band cost ~750 points
///    and left 78 for the backpack at 1280 × 860 — so R1's pin was bought at
///    the price of the thing it sat above. **W-A6** is a scroll again.
/// 3. **The two content columns became one.** Which lands this on the shape
///    `inventory-merge-review.md` §7 called **option A** — inventory joining
///    the sheet's single column as panels — reached by building rather than by
///    argument. **D15's single column, extended**, with a party rail beside it.
///
/// The one thing left over from the pin is the **compact** rendering of the
/// last three panels: it was what made a pinned band possible at all, and the
/// user chose it. In one column it now sits under four panels drawn at full
/// height, which is a difference a capture will show.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wand_of_saves/ui/character/character_sheet_view.dart';
import 'package:wand_of_saves/ui/character/command_palette.dart';
import 'package:wand_of_saves/ui/character/findings.dart';
import 'package:wand_of_saves/ui/character/portrait_rail.dart';
import 'package:wand_of_saves/ui/character/side_sheet.dart';
import 'package:wand_of_saves/ui/grid_spikes/compact_numbers.dart';
import 'package:wand_of_saves/ui/grid_spikes/grid_spike_host.dart';
import 'package:wand_of_saves/ui/inventory/inventory_screen.dart';

/// The panels that sit beside the items because equipment moves them, and how
/// dense each may be. ⚠️ **Combat keeps a line per number** — its rows carry
/// what the engine draws instead, which is the comparison they are here for.
const Map<String, CompactStyle> _numbers = {
  'Combat': CompactStyle.lines,
  'Resistances': CompactStyle.flowing,
  'Condition': CompactStyle.flowing,
};

/// The panels the column leads with, in the sheet's own order.
const List<String> _record = [
  'Character',
  'Abilities',
  'Skills',
  'Proficiencies',
];

/// How wide the party column is. **Authored, not computed.**
const double _partyColumnWidth = 232;

/// How wide the record column runs before it stops growing with the window.
///
/// ⚠️ **900, which is the inventory's number rather than the sheet's 820.** The
/// merge review lists reconciling those two as a constraint, and this is the
/// first surface where both are in the same column: the 4 × 4 backpack is what
/// wants the extra width, and eighty points does not hurt a row of text.
const double _recordColumnWidth = 900;

/// G1 over the savegame in [slotDirectoryName].
class G1TwoBenches extends StatelessWidget {
  /// Opens the spike on that save slot.
  const G1TwoBenches({required this.slotDirectoryName, super.key});

  /// The save slot directory the entry point picked.
  final String slotDirectoryName;

  @override
  Widget build(BuildContext context) => GridSpikeHost(
    slotDirectoryName: slotDirectoryName,
    builder: (context, model) => _G1Body(model: model),
  );
}

class _G1Body extends StatefulWidget {
  const _G1Body({required this.model});

  final GridSpikeModel model;

  @override
  State<_G1Body> createState() => _G1BodyState();
}

class _G1BodyState extends State<_G1Body> {
  final SearchController _palette = SearchController();
  final ScrollController _scroll = ScrollController();

  /// What is open for editing, or `null` when nothing is.
  Subject? _editing;

  @override
  void dispose() {
    _palette.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _open(Subject subject) => setState(() => _editing = subject);

  void _close() => setState(() => _editing = null);

  /// The editor for [subject], when that is what is open.
  ///
  /// **One answer for every row on the page.** With one scrolling column there
  /// is no cell whose height may not change, so nothing has to open anywhere
  /// but under the row it belongs to.
  Widget? _editorFor(Subject subject) {
    final editing = _editing;
    if (editing == null) return null;
    if (subjectKey(editing) != subjectKey(subject)) return null;
    return _InlineEditor(
      model: widget.model,
      subject: subject,
      onClose: _close,
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;

    return Row(
      children: [
        SizedBox(
          width: _partyColumnWidth,
          child: _PartyColumn(model: model, onFindings: _palette.openView),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _RecordColumn(
            model: model,
            palette: _palette,
            scroll: _scroll,
            onOpen: _open,
            inlineEditor: _editorFor,
          ),
        ),
      ],
    );
  }
}

/// Everything about the character, in one authored order and one scroll.
class _RecordColumn extends StatelessWidget {
  const _RecordColumn({
    required this.model,
    required this.palette,
    required this.scroll,
    required this.onOpen,
    required this.inlineEditor,
  });

  final GridSpikeModel model;
  final SearchController palette;
  final ScrollController scroll;
  final ValueChanged<Subject> onOpen;

  /// What to draw beneath a row that is open for editing.
  final Widget? Function(Subject subject) inlineEditor;

  @override
  Widget build(BuildContext context) {
    final panels = sheetPanelsOf(
      character: model.sheet,
      rulesBind: model.rulesBind,
      onOpen: onOpen,
      inlineEditor: inlineEditor,
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            palette.openView,
      },
      child: Focus(
        autofocus: true,
        child: Scrollbar(
          controller: scroll,
          child: SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _recordColumnWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ⚠️ **Not inside the `SelectionArea`.** A search field
                    // wrapped in one takes the region's gestures instead of its
                    // own; the sheet keeps selection because every number on it
                    // is one somebody wants to quote.
                    CommandPalette(
                      controller: palette,
                      character: model.sheet,
                      onSelected: onOpen,
                    ),
                    const SizedBox(height: 20),
                    SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final title in _record)
                            if (panels[title] case final Widget panel) ...[
                              panel,
                              const SizedBox(height: 16),
                            ],
                        ],
                      ),
                    ),
                    // ⚠️ **The items sit directly above the numbers they
                    // move.** That adjacency is the whole reason §8c wanted the
                    // two screens merged, and it is the last thing left of R1
                    // now that the pin is gone.
                    InventoryPanels(
                      character: () => model.character,
                      onAdd: model.addItem,
                      partyPosition: model.state.selectedIndex,
                      onRemove: model.removeItem,
                      party: [
                        for (final member in model.state.members) member.name,
                      ],
                      onMoveTo: (item, to) => model.moveItem(
                        from: model.state.selectedIndex,
                        to: to,
                        itemIndex: item.index,
                        resref: item.resref,
                      ),
                      // ⚠️ The palette holds the focus, so Ctrl+K works the
                      // moment the grid opens. Two boxes cannot both have it.
                      autofocusSearchField: false,
                    ),
                    const SizedBox(height: 20),
                    CompactNumbers(
                      character: model.sheet,
                      panels: _numbers,
                      rulesBind: model.rulesBind,
                      onOpen: onOpen,
                      inlineEditor: inlineEditor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The left column: who else is in the party, who this is, and the chrome.
class _PartyColumn extends StatelessWidget {
  const _PartyColumn({required this.model, required this.onFindings});

  final GridSpikeModel model;
  final VoidCallback onFindings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PortraitRail(
            state: model.state,
            slotDirectoryName: model.slotDirectoryName,
            onItemDropped: (drag, to) => model.moveItem(
              from: drag.from,
              to: to,
              itemIndex: drag.itemIndex,
              resref: drag.resref,
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: SheetIdentity(character: model.sheet),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: spikeChrome(context, model, onFindings: onFindings),
          ),
        ),
      ],
    );
  }
}

/// The side sheet's editor, expanded in place instead of slid over the page.
class _InlineEditor extends StatelessWidget {
  const _InlineEditor({
    required this.model,
    required this.subject,
    required this.onClose,
  });

  final GridSpikeModel model;
  final Subject subject;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Card(
      // The rung above a panel, so an open editor reads as something laid on
      // top of the record rather than another part of it.
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SubjectEditor(
        key: ValueKey<String>(subjectKey(subject)),
        subject: subject,
        character: model.sheet,
        rulesBind: model.rulesBind,
        onApplyField: model.applyField,
        onApplyPips: model.applyPips,
        onClose: onClose,
        fillsHeight: false,
      ),
    ),
  );
}
