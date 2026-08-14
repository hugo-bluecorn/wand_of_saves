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
/// **G1, as the user has reshaped it: the party, and one page in two columns.**
///
/// - **Left, the party**: portraits that accept a dropped item, the identity,
///   and the chrome. Its own column, its own height.
/// - **The page, in two columns**: the field palette and the read-once panels —
///   Character, Abilities, Skills, Proficiencies — on the left; the
///   **inventory** and then the numbers equipment moves — Combat, Resistances,
///   Condition — on the right.
///
/// ⚠️ **One page, not two panes.** The two columns share a single scroll, so
/// the record and the items move together and the page reads as one document
/// laid out in columns. The three-column G1 that came before scrolled each
/// bench separately, which is the thing this replaced.
///
/// Editing is **inline** wherever a row lives: the selected row expands the
/// editor beneath itself, and the side sheet does not appear. Finds stay
/// **split**: Ctrl+K over the record, the item search over the catalogue.
///
/// ⚠️ **The name is historical**, and so are the study's scores for this
/// variant. Four changes, all the user's, all made after looking at the built
/// spike, none of them what the paper derived:
///
/// 1. **The party column moved from the right edge to the left.** The study put
///    it on the right so the dominant drag — pack → member — travelled one
///    column instead of the window. It now travels the window. That was G1's
///    margin on the **W-A2** script.
/// 2. **The numbers stopped being pinned.** Measured, the band cost ~750 points
///    and left 78 for the backpack at 1280 × 860 — R1's pin was bought at the
///    price of the thing it sat above. **W-A6** is a scroll again.
/// 3. **The record and the items became one page.** Two independent scrolling
///    benches became one scroll in two columns.
/// 4. **The items lead their own column**, which is what puts the backpack back
///    above the fold: stacked under the record it began 1,438 points down, and
///    about 2,500 with a real installation's proficiencies.
///
/// The one thing left over from the pin is the **compact** rendering of the
/// last three panels: it was what made a pinned band possible at all, and the
/// user chose it. It now sits under an inventory drawn at full height, which is
/// a difference a capture will show.
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

/// The panels the left-hand column holds, in the sheet's own order.
const List<String> _record = [
  'Character',
  'Abilities',
  'Skills',
  'Proficiencies',
];

/// How wide the party column is. **Authored, not computed.**
const double _partyColumnWidth = 232;

/// How wide the two columns together run before they stop growing.
///
/// Without a ceiling a wide monitor gives each column eleven hundred points and
/// a row of two words with a number a metre away from it.
const double _pageWidth = 1600;

/// The gutter between the two columns.
const double _columnGap = 24;

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

  /// ⚠️ **One controller, because it is one page.** Two would be two
  /// scrollbars, which is exactly the two-panes reading this replaced.
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
  /// **One answer for every row on the page**, in either column: nothing here
  /// has a height that may not change, so nothing has to open anywhere but
  /// under the row it belongs to.
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
    final panels = sheetPanelsOf(
      character: model.sheet,
      rulesBind: model.rulesBind,
      onOpen: _open,
      inlineEditor: _editorFor,
    );

    return Row(
      children: [
        SizedBox(
          width: _partyColumnWidth,
          child: _PartyColumn(model: model, onFindings: _palette.openView),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                  _palette.openView,
            },
            child: Focus(
              autofocus: true,
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _pageWidth),
                      // ⚠️ **The two columns, and the reason this is a `Row`
                      // inside the scroll view rather than two scroll views in
                      // a `Row`.** The page is one document: one scrollbar
                      // moves both, and the page is as tall as its taller
                      // column.
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _RecordColumn(
                              model: model,
                              palette: _palette,
                              panels: panels,
                              onOpen: _open,
                            ),
                          ),
                          const SizedBox(width: _columnGap),
                          Expanded(
                            child: _ItemsColumn(
                              model: model,
                              onOpen: _open,
                              inlineEditor: _editorFor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The left-hand column of the page: the palette, then the read-once panels.
class _RecordColumn extends StatelessWidget {
  const _RecordColumn({
    required this.model,
    required this.palette,
    required this.panels,
    required this.onOpen,
  });

  final GridSpikeModel model;
  final SearchController palette;
  final Map<String, Widget> panels;
  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      // ⚠️ In an unbounded height — this sits in a scroll view — a column that
      // wants all of it resolves to infinity and throws during layout.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ⚠️ **Outside the `SelectionArea`.** A search field wrapped in one
        // gives the region its gestures instead of keeping its own.
        CommandPalette(
          controller: palette,
          character: model.sheet,
          onSelected: onOpen,
        ),
        const SizedBox(height: 20),
        SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
      ],
    );
  }
}

/// The right-hand column of the page: the items, then the numbers they move.
///
/// ⚠️ **The items lead, and that is what puts them above the fold.** Stacked
/// under the record they began fourteen hundred points down; at the top of
/// their own column they are the first thing in it.
class _ItemsColumn extends StatelessWidget {
  const _ItemsColumn({
    required this.model,
    required this.onOpen,
    required this.inlineEditor,
  });

  final GridSpikeModel model;
  final ValueChanged<Subject> onOpen;

  /// What to draw beneath a number that is open for editing.
  final Widget? Function(Subject subject) inlineEditor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InventoryPanels(
          character: () => model.character,
          onAdd: model.addItem,
          partyPosition: model.state.selectedIndex,
          onRemove: model.removeItem,
          party: [for (final member in model.state.members) member.name],
          onMoveTo: (item, to) => model.moveItem(
            from: model.state.selectedIndex,
            to: to,
            itemIndex: item.index,
            resref: item.resref,
          ),
          // ⚠️ The palette holds the focus, so Ctrl+K works the moment the
          // grid opens. Two boxes cannot both have it.
          autofocusSearchField: false,
        ),
        const SizedBox(height: 20),
        // Selectable, because every number here is one somebody wants to quote
        // — and unlike the items above it, nothing in this block drags.
        SelectionArea(
          child: CompactNumbers(
            character: model.sheet,
            panels: _numbers,
            rulesBind: model.rulesBind,
            onOpen: onOpen,
            inlineEditor: inlineEditor,
          ),
        ),
      ],
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
