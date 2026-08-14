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
/// **G1 — "Two benches", adjacency-biased.** Three fixed columns, authored
/// positions, no `MediaQuery` and no `LayoutBuilder`: nothing here rearranges
/// when the window resizes.
///
/// - **Left, the slow bench**: the panels you read once — Character, Abilities,
///   Skills, Proficiencies — with the field palette above them. Scrolls.
/// - **Centre, the fast bench**: the numbers that *move*, pinned at the top and
///   never scrolling, with the items directly beneath them. This is the whole
///   argument of G1: an equip changes a number you can already see.
/// - **Right, the party**: portraits that accept a dropped item, the identity,
///   and the chrome. ⚠️ **On the right on purpose** — the dominant drag is pack
///   → member, and putting the party beside the items makes that one column's
///   travel instead of the window's width.
///
/// Editing is **inline**: the selected row expands the editor beneath itself,
/// and the side sheet does not appear. Finds stay **split**: Ctrl+K over the
/// record, the item search over the catalogue.
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

/// The panels that stay pinned beside the items, because equipment moves them,
/// and how dense each may be. ⚠️ **Combat keeps a line per number** — its rows
/// carry what the engine draws instead, which is the comparison the pin is for.
const Map<String, CompactStyle> _pinned = {
  'Combat': CompactStyle.lines,
  'Resistances': CompactStyle.flowing,
  'Condition': CompactStyle.flowing,
};

/// The panels you read through once, in the sheet's own order.
const List<String> _slow = [
  'Character',
  'Abilities',
  'Skills',
  'Proficiencies',
];

/// How wide the three columns are. **Authored, not computed** — a fixed grid
/// means a fixed column count and stated widths.
const double _slowBenchWidth = 480;
const double _partyColumnWidth = 232;

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
  final ScrollController _slowScroll = ScrollController();
  final ScrollController _fastScroll = ScrollController();

  /// What is open for editing, or `null` when nothing is.
  Subject? _editing;

  @override
  void dispose() {
    _palette.dispose();
    _slowScroll.dispose();
    _fastScroll.dispose();
    super.dispose();
  }

  void _open(Subject subject) => setState(() => _editing = subject);

  void _close() => setState(() => _editing = null);

  /// Whether [subject] belongs to the pinned band rather than the slow bench.
  bool _isPinned(Subject subject) => switch (subject) {
    FieldSubject(:final entry) => _pinned.containsKey(entry.group.title),
    ProficiencySubject() => false,
  };

  /// The editor for [subject], when that is what is open.
  ///
  /// ⚠️ **Never for a pinned row.** The band's promise is that its height does
  /// not change, so an editor expanding inside it would be the one thing this
  /// column may not do. Those open at the top of the scrolling region below
  /// instead — still inline, still adjacent, and the numbers stay put.
  Widget? _editorFor(Subject subject) {
    final editing = _editing;
    if (editing == null) return null;
    if (subjectKey(editing) != subjectKey(subject)) return null;
    if (_isPinned(subject)) return null;
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
    final editing = _editing;

    return Row(
      children: [
        SizedBox(
          width: _slowBenchWidth,
          child: _SlowBench(
            model: model,
            palette: _palette,
            scroll: _slowScroll,
            panels: panels,
            onOpen: _open,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _FastBench(
            model: model,
            scroll: _fastScroll,
            onOpen: _open,
            editor: editing != null && _isPinned(editing)
                ? _InlineEditor(
                    model: model,
                    subject: editing,
                    onClose: _close,
                  )
                : null,
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: _partyColumnWidth,
          child: _PartyColumn(model: model, onFindings: _palette.openView),
        ),
      ],
    );
  }
}

/// The left bench: the palette, then the panels nobody watches change.
class _SlowBench extends StatelessWidget {
  const _SlowBench({
    required this.model,
    required this.palette,
    required this.scroll,
    required this.panels,
    required this.onOpen,
  });

  final GridSpikeModel model;
  final SearchController palette;
  final ScrollController scroll;
  final Map<String, Widget> panels;
  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CommandPalette(
                    controller: palette,
                    character: model.sheet,
                    onSelected: onOpen,
                  ),
                  const SizedBox(height: 20),
                  for (final title in _slow)
                    if (panels[title] case final Widget panel) ...[
                      panel,
                      const SizedBox(height: 16),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The centre bench: the moving numbers pinned above the items.
class _FastBench extends StatelessWidget {
  const _FastBench({
    required this.model,
    required this.scroll,
    required this.onOpen,
    this.editor,
  });

  final GridSpikeModel model;
  final ScrollController scroll;
  final ValueChanged<Subject> onOpen;

  /// The editor for a pinned row, drawn above the items rather than in the
  /// band — see `_G1BodyState._editorFor`.
  final Widget? editor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ⚠️ **Content-sized and outside the scroll view.** This is the pin:
        // whatever the window does, these numbers are on screen. The region
        // below takes whatever is left, which is the measurement the spike
        // exists to produce.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: CompactNumbers(
            character: model.sheet,
            panels: _pinned,
            rulesBind: model.rulesBind,
            onOpen: onOpen,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Scrollbar(
            controller: scroll,
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (editor case final Widget open) ...[
                    open,
                    const SizedBox(height: 20),
                  ],
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
                    // ⚠️ The slow bench holds the focus, so Ctrl+K works the
                    // moment the grid opens. Two boxes cannot both have it.
                    autofocusSearchField: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The right column: who else is in the party, who this is, and the chrome.
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
  Widget build(BuildContext context) => Card(
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
  );
}
