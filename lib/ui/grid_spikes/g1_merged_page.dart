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
/// **The merged page — one character, one page: their record and what they
/// carry, together.** That merge is what D19 decides and is the one thing about
/// this page that never moved; the arrangement below moved eleven times in a
/// day.
///
/// ⚠️ **`G1` is kept as a lineage marker, and `Two benches` is not.** The study
/// derived two grids on paper and this is the first; the benches it was named
/// for stopped existing at the fourth change, and a name for a structure the
/// page does not have is the stale-comment defect this project treats as a bug
/// report. Everything that addresses this page — `planning/tool-first-study.md`,
/// `planning/grid-spike-brief.md`, the commit trail and D19 — says G1.
///
/// **Its arrangement, as the user left it:**
///
/// - **Across the top, the party**: portraits that accept a dropped item, who
///   this is, and the chrome — one band the width of the page.
/// - **Heading the page, Combat**: the full width of both columns, its
///   eighteen rows split into three. It is the one panel neither half owns —
///   the items move its numbers and the record explains them — so it belongs
///   above both rather than inside either, and at the top of the scroll it is
///   what an unscrolled window opens on.
/// - **Left column**: Character — which now ends with fatigue and
///   intoxication — Abilities, the Resistances as pills, Skills, and anything
///   in no slot.
/// - **Right column**: the **backpack**, what is **Equipped**, and the
///   **Proficiencies**.
///
/// ⚠️ **That split is a balance, chosen by measuring rather than by meaning.**
/// The obvious division — record on the left, items on the right — left the
/// left column about twice the height of the right. Twenty-four pip meters is
/// the one block big enough to move the other way.
///
/// ⚠️ **One page, not two panes.** The two columns share a single scroll, so
/// the record and the items move together and the page reads as one document
/// laid out in columns. The three-column G1 that came before scrolled each
/// bench separately, which is the thing this replaced.
///
/// Editing is **inline** wherever a row lives: the selected row expands the
/// editor beneath itself, and the side sheet does not appear.
///
/// ⚠️ **There is one find, and it is the item search.** The field-and-
/// proficiency palette — the Ctrl+K box that used to head the left column —
/// was removed at the user's asking. On a page that draws every field at once
/// there is less for it to reach, and the record's own panels are the index.
/// ⚠️ **The record cannot be searched at all**, and the findings badge counts
/// without navigating, because the palette was where it went. That removal also
/// settled **R5** — one find surface or two, the deepest question the two
/// spikes existed to put to the user — by deletion rather than by comparison,
/// and G2 was deleted the day after.
///
/// ⚠️ **The study's scores for this variant are historical.** Eleven changes to
/// the page and one to the theme, all the user's, all made after looking at the
/// built spike, none of them what the paper derived —
/// `planning/grid-spike-brief.md` carries each with the measurement that
/// prompted or followed it. The load-bearing ones:
///
/// 1. **The party stopped being a column at all.** The study put it on the
///    right edge so the dominant drag — pack → member — travelled one column
///    instead of the window; it went to the left edge, and is now a band across
///    the top. The drag travels up rather than sideways, and every portrait is
///    the same distance from the backpack. That was G1's margin on the **W-A2**
///    script, and it is spent. ⚠️ It also makes G1's chrome the same shape as
///    G2's, which is one fewer thing the two variants disagree about.
/// 2. **The numbers stopped being pinned.** Measured, the band cost ~750 points
///    and left 78 for the backpack at 1280 × 860 — R1's pin was bought at the
///    price of the thing it sat above. **W-A6** is a scroll again.
/// 3. **The record and the items became one page.** Two independent scrolling
///    benches became one scroll in two columns.
/// 4. **The items lead their own column**, which is what puts the backpack back
///    above the fold: stacked under the record it began 1,438 points down, and
///    about 2,500 with a real installation's proficiencies.
/// 5. **Condition stopped being a panel**, and Combat became a band across
///    both columns — first at the foot of the page, then at its head. ⚠️ Moving
///    it to the head is what **got R1 back**: the numbers equipment moves are
///    what an unscrolled window opens on, twenty points above the backpack, at
///    every window height the application allows — and it cost nothing.
/// 6. **The field palette is gone**, and with it Ctrl+K and the findings
///    badge's destination — see above.
///
/// The one thing left over from the pin is the **compact** rendering: it was
/// what made a pinned band possible at all, and the user chose it. Combat and
/// the Resistances are still drawn that way while every panel around them is
/// drawn at full height, which is a difference a capture will show.
library;

import 'package:flutter/material.dart';
import 'package:wand_of_saves/ui/character/character_sheet_view.dart';
import 'package:wand_of_saves/ui/character/findings.dart';
import 'package:wand_of_saves/ui/character/side_sheet.dart';
import 'package:wand_of_saves/ui/grid_spikes/compact_numbers.dart';
import 'package:wand_of_saves/ui/grid_spikes/grid_spike_host.dart';
import 'package:wand_of_saves/ui/grid_spikes/member_switcher.dart';
import 'package:wand_of_saves/ui/inventory/inventory_screen.dart';

/// Combat, drawn across the head of the page.
///
/// ⚠️ **A line per number, in three columns.** Its rows carry what the engine
/// draws instead of what is stored, which is the comparison they are here for —
/// so they cannot become pills. Eighteen of them down a single file under a
/// page twice as wide as it is tall is what the three columns answer.
const Map<String, CompactStyle> _combat = {'Combat': CompactStyle.lines};

/// The resistances, above Skills, as pills.
///
/// Eleven values, each a word and a percentage, none of which the engine draws
/// differently. A line each would spend three hundred points saying `0%`.
const Map<String, CompactStyle> _resistances = {
  'Resistances': CompactStyle.flowing,
};

/// The left column, above and below the Resistances — an authored order, not
/// the sheet's own.
///
/// ⚠️ **Proficiencies is in neither, and that is the balance.** Four panels on
/// the left against a backpack on the right left the left column twice the
/// height of the right; twenty-four pip meters is the one block big enough to
/// move the other way.
const List<String> _aboveResistances = ['Character', 'Abilities'];
const List<String> _belowResistances = ['Skills'];

/// ⚠️ **Condition is not a panel any more.** Fatigue and intoxication are two
/// values about the person, and a card of its own for two rows was a heading
/// costing more than what it headed. They are the last two rows of Character.
const Map<String, String> _folded = {'Condition': 'Character'};

/// How wide the two columns together run before they stop growing.
///
/// Without a ceiling a wide monitor gives each column eleven hundred points and
/// a row of two words with a number a metre away from it.
const double _pageWidth = 1600;

/// The gutter between the two columns.
const double _columnGap = 24;

/// G1 over the savegame in [slotDirectoryName].
class G1MergedPage extends StatelessWidget {
  /// Opens the spike on that save slot.
  const G1MergedPage({required this.slotDirectoryName, super.key});

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
  /// ⚠️ **One controller, because it is one page.** Two would be two
  /// scrollbars, which is exactly the two-panes reading this replaced.
  final ScrollController _scroll = ScrollController();

  /// What is open for editing, or `null` when nothing is.
  Subject? _editing;

  @override
  void dispose() {
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
      foldInto: _folded,
    );

    return Column(
      children: [
        // ⚠️ **The badge counts and does not navigate.** With the palette gone
        // there is nowhere for it to send anybody, and `FindingsBadge` takes a
        // null `onPressed` for exactly this — the count is still worth showing,
        // and an enabled button that does nothing is the dead control this
        // project keeps deleting.
        _PartyBand(model: model),
        const Divider(height: 1),
        Expanded(
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _pageWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ⚠️ **Combat heads the page**, across both columns and
                      // the full width of them, split into three. It is the
                      // one panel neither half owns — the items move its
                      // numbers and the record explains them — and at the top
                      // of the scroll it is what an unscrolled window opens
                      // on, which is the nearest thing left to R1's pin now
                      // that nothing is pinned.
                      CompactNumbers(
                        character: model.sheet,
                        panels: _combat,
                        rulesBind: model.rulesBind,
                        onOpen: _open,
                        inlineEditor: _editorFor,
                        columns: 3,
                      ),
                      const SizedBox(height: 20),
                      // ⚠️ **The two columns, and the reason this is a
                      // `Row` inside the scroll view rather than two
                      // scroll views in a `Row`.** The page is one
                      // document: one scrollbar moves both.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _RecordColumn(
                              model: model,
                              panels: panels,
                              onOpen: _open,
                              inlineEditor: _editorFor,
                            ),
                          ),
                          const SizedBox(width: _columnGap),
                          Expanded(
                            child: _ItemsColumn(
                              model: model,
                              panels: panels,
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// The left-hand column: the read-once panels, the resistances among them, and
/// whatever the record holds in no slot at all.
class _RecordColumn extends StatelessWidget {
  const _RecordColumn({
    required this.model,
    required this.panels,
    required this.onOpen,
    required this.inlineEditor,
  });

  final GridSpikeModel model;
  final Map<String, Widget> panels;
  final ValueChanged<Subject> onOpen;

  /// What to draw beneath a number that is open for editing.
  final Widget? Function(Subject subject) inlineEditor;

  @override
  Widget build(BuildContext context) {
    return Column(
      // ⚠️ In an unbounded height — this sits in a scroll view — a column that
      // wants all of it resolves to infinity and throws during layout.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final title in _aboveResistances)
                if (panels[title] case final Widget panel) ...[
                  panel,
                  const SizedBox(height: 16),
                ],
              // Above Skills: a resistance is something the character *is*,
              // like an ability score, rather than something they have learnt.
              // Nothing in this block drags, so it can sit inside the
              // selectable region with the panels around it.
              CompactNumbers(
                character: model.sheet,
                panels: _resistances,
                rulesBind: model.rulesBind,
                onOpen: onOpen,
                inlineEditor: inlineEditor,
              ),
              const SizedBox(height: 16),
              for (final title in _belowResistances)
                if (panels[title] case final Widget panel) ...[
                  panel,
                  const SizedBox(height: 16),
                ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        // ⚠️ **Items no slot points at, over here with the record rather than
        // with the backpack.** They are not a place anything can be put and
        // the game will not draw them at all, so they read as something wrong
        // with the record — which is what this column is about.
        _Items(model: model, groups: const [CarriedGroup.inNoSlot]),
      ],
    );
  }
}

/// The right-hand column: the backpack, what is worn, and the proficiencies.
///
/// ⚠️ **The items lead, and that is what puts them above the fold.** Stacked
/// under the record they began fourteen hundred points down; at the top of
/// their own column they are the first thing in it.
class _ItemsColumn extends StatelessWidget {
  const _ItemsColumn({required this.model, required this.panels});

  final GridSpikeModel model;

  /// The sheet's panels by name — this column takes exactly one of them.
  final Map<String, Widget> panels;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Items(
          model: model,
          groups: const [CarriedGroup.backpack, CarriedGroup.equipped],
          withSearch: true,
        ),
        const SizedBox(height: 20),
        if (panels['Proficiencies'] case final Widget proficiencies)
          SelectionArea(child: proficiencies),
      ],
    );
  }
}

/// Some of the character's items, wired to the savegame.
///
/// **One place the wiring is written**, because the page draws two of these —
/// the backpack and what is worn on the right, whatever is in no slot on the
/// left — and two copies of the callbacks is two chances for one of them to
/// refuse a move the other offers.
class _Items extends StatelessWidget {
  const _Items({
    required this.model,
    required this.groups,
    this.withSearch = false,
  });

  final GridSpikeModel model;
  final List<CarriedGroup> groups;

  /// Whether this is the one that carries the item search.
  final bool withSearch;

  @override
  Widget build(BuildContext context) => InventoryPanels(
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
    groups: groups,
    showSearchField: withSearch,
    // ⚠️ Nothing on this page takes focus on open. The palette that used to
    // hold it was removed at the seventh change, and an autofocused search box
    // would open the page with a cursor blinking mid-column.
    autofocusSearchField: false,
    // ⚠️ **Vertical here, horizontal on the pushed screen, and the difference
    // is where the targets are.** The party is a band across the TOP of this
    // page and the equipment slots sit BELOW the backpack, so both of the drops
    // this arrangement offers are vertical ones. The price is Flutter's own:
    // a vertical draggable out-competes the scrollable, so a pull that starts
    // on an item picks the item up instead of scrolling the page.
    dragAffinity: Axis.vertical,
  );
}

/// The band across the top: who this is, who else is in the party, and the
/// chrome.
///
/// ⚠️ **`MemberSwitcher` rather than `PortraitRail`, and it is G2's.**
/// `NavigationRail` is vertical by construction, so a party laid across a band
/// needs the other widget — the one G2 already had. Writing a second horizontal
/// switcher for G1 would be two answers to "which portraits will take a drop",
/// which is the bug this project keeps paying for.
class _PartyBand extends StatelessWidget {
  const _PartyBand({required this.model});

  final GridSpikeModel model;

  /// How wide the identity gets. Stated, because the switcher beside it must
  /// not move when a character with a longer name is selected.
  static const double _identityWidth = 300;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: _identityWidth,
            child: SheetIdentity(character: model.sheet),
          ),
          const SizedBox(width: 16),
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
          const Spacer(),
          ...spikeChrome(context, model),
        ],
      ),
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
