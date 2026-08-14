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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/edit_command.dart';
import 'package:wand_of_saves/domain/rules/character_sheet.dart';
import 'package:wand_of_saves/domain/save_slot.dart';
import 'package:wand_of_saves/ui/character/character_sheet_view.dart';
import 'package:wand_of_saves/ui/character/command_palette.dart';
import 'package:wand_of_saves/ui/character/findings.dart';
import 'package:wand_of_saves/ui/character/findings_badge.dart';
import 'package:wand_of_saves/ui/character/portrait_rail.dart';
import 'package:wand_of_saves/ui/character/rules_toggle.dart';
import 'package:wand_of_saves/ui/character/sheet_projection.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';
import 'package:wand_of_saves/ui/character/side_sheet.dart';
import 'package:wand_of_saves/ui/core/save_button.dart';
import 'package:wand_of_saves/ui/inventory/inventory_screen.dart';
import 'package:wand_of_saves/ui/party/export_button.dart';
import 'package:wand_of_saves/ui/party/party_viewmodel.dart';

/// The workbench: one savegame, the party down the left, and the selected
/// character's whole record in a single column with what is wrong with it
/// marked in place.
///
/// **No tabs.** The four tabs this replaces hid three quarters of the record
/// behind a click, which is the wrong trade for an editor — a reader who opens
/// a record wants the record. Findings are marked *on the field*, so a hidden
/// field was a mark nobody could see.
///
/// ⚠️ **One column, deliberately.** An earlier arrangement balanced panels
/// greedily across two columns, which read as a zigzag: the named order —
/// Character, Abilities, Skills, Proficiencies, Combat, Resistances,
/// Condition — went down one column and back up the other. One column costs
/// some width on a wide window and is the order a person actually reads a
/// character in.
///
/// ⚠️ **Edits apply immediately.** There is no staging buffer here, because
/// [PartyViewModel] already keeps an undo stack over immutable snapshots and a
/// dirty marker; a second staging model beside it would be two sources of truth
/// for the same question. Save writes what the document holds.
class CharacterScreen extends ConsumerStatefulWidget {
  /// Opens the savegame in the slot directory named [slotDirectoryName].
  const CharacterScreen({required this.slotDirectoryName, super.key});

  /// The save slot directory the route named.
  final String slotDirectoryName;

  @override
  ConsumerState<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends ConsumerState<CharacterScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SearchController _palette = SearchController();

  // ⚠️ Explicit, and shared with the scroll view. `thumbVisibility` asserts a
  // controller with an attached position, and desktop has no
  // `PrimaryScrollController` to fall back on.
  final ScrollController _scroll = ScrollController();

  /// Whether the rules bind, or merely advise. On by default — D16.
  ///
  /// ⚠️ **It never blocks a keystroke.** This project's rule is that an anomaly
  /// you cannot touch is one you cannot correct, so a flagged field always
  /// accepts input; what the check governs is how the value is *described*.
  bool _rulesBind = true;

  Subject? _subject;

  @override
  void dispose() {
    _palette.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _open(Subject subject) {
    setState(() => _subject = subject);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  void _closeSheet() {
    _scaffoldKey.currentState?.closeEndDrawer();
    setState(() => _subject = null);
  }

  /// Opens the palette, which already lists and reaches everything flagged.
  ///
  /// ⚠️ **There is no findings panel.** Every flagged field is marked where it
  /// lives. What the badge is still for is the question a mark cannot answer:
  /// how many are there, and are they all above the fold.
  void _showFindings() {
    _palette
      ..text = ''
      ..openView();
  }

  void _applyField(FieldEntry entry, String value) {
    final stat = entry.field.stat;
    final number = int.tryParse(value);
    if (stat == null || number == null) return;
    ref
        .read(partyProvider(widget.slotDirectoryName).notifier)
        .edit(
          SetCharacterStat(
            creOffset: _creOffset,
            stat: stat,
            value: number,
          ),
        );
  }

  void _applyPips(SheetProficiency proficiency, int pips) {
    final effectOffset = proficiency.effectOffset;
    // ⚠️ **A proficiency the record has no effect for is GRANTED**, which
    // appends a 264-byte opcode 233 effect and resizes the record. That used
    // to be refused here — a savegame moves 43 pointers against a `.chr`'s
    // one — and the relocation is why it no longer is.
    ref
        .read(partyProvider(widget.slotDirectoryName).notifier)
        .edit(
          effectOffset == null
              ? GrantProficiency(
                  creOffset: _creOffset,
                  proficiencyId: proficiency.id,
                  pips: pips,
                )
              : SetProficiency(
                  creOffset: _creOffset,
                  effectOffset: effectOffset,
                  proficiencyId: proficiency.id,
                  pips: pips,
                ),
        );
  }

  void _addItem(String resref, CreItemSlot slot) => ref
      .read(partyProvider(widget.slotDirectoryName).notifier)
      .edit(AddItem(creOffset: _creOffset, resref: resref, slot: slot));

  /// Opens the inventory, which re-reads the party on every build.
  ///
  /// ⚠️ **Watched, not captured.** A snapshot taken here would leave the screen
  /// showing the inventory as it stood when the route opened.
  void _openInventory() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final state = ref
              .watch(partyProvider(widget.slotDirectoryName))
              .value;
          final selected = state?.selected;
          if (state == null || selected == null) {
            return const SizedBox.shrink();
          }
          return InventoryScreen(
            character: () =>
                ref
                    .watch(partyProvider(widget.slotDirectoryName))
                    .value
                    ?.selected ??
                selected,
            onAdd: _addItem,
            partyPosition: state.selectedIndex,
            onRemove: (item) => ref
                .read(partyProvider(widget.slotDirectoryName).notifier)
                .edit(
                  RemoveItem(
                    creOffset: _creOffset,
                    itemIndex: item.index,
                    resref: item.resref,
                  ),
                ),
            party: [for (final member in state.members) member.name],
            onMoveTo: (item, to) => ref
                .read(partyProvider(widget.slotDirectoryName).notifier)
                .edit(
                  MoveItem(
                    from: state.selectedIndex,
                    to: to,
                    itemIndex: item.index,
                    resref: item.resref,
                  ),
                ),
            onUndo: state.canUndo
                ? ref
                      .read(partyProvider(widget.slotDirectoryName).notifier)
                      .undo
                : null,
            onRedo: state.canRedo
                ? ref
                      .read(partyProvider(widget.slotDirectoryName).notifier)
                      .redo
                : null,
            isDirty: state.isDirty,
            onSave: ref
                .read(partyProvider(widget.slotDirectoryName).notifier)
                .save,
            // ⚠️ **Selecting here switches the inventory, and that is the
            // point.** `character` above re-reads `selected` on every build, so
            // the rail needs no wiring of its own — a rail that only decorated
            // would be a control that does nothing.
            rail: PortraitRail(
              state: state,
              slotDirectoryName: widget.slotDirectoryName,
              // ⚠️ One command, not a remove followed by an add: the removal
              // moves every record after the source, so the destination's
              // offset does not exist until the first half has been applied.
              // It is also one undo step, which is what a move should be.
              onItemDropped: (drag, to) => ref
                  .read(partyProvider(widget.slotDirectoryName).notifier)
                  .edit(
                    MoveItem(
                      from: drag.from,
                      to: to,
                      itemIndex: drag.itemIndex,
                      resref: drag.resref,
                    ),
                  ),
            ),
          );
        },
      ),
    ),
  );

  /// Where the selected character's record starts in the savegame.
  ///
  /// Read rather than watched: an edit needs it at the moment it is issued, and
  /// a rebuild is not what changes it.
  int get _creOffset {
    final state = ref.read(partyProvider(widget.slotDirectoryName)).value;
    return state?.selected?.creOffset ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final party = ref.watch(partyProvider(widget.slotDirectoryName));
    final state = party.value;
    final notifier = ref.read(
      partyProvider(widget.slotDirectoryName).notifier,
    );
    final selected = state?.selected;
    final sheet = selected == null || state == null
        ? null
        : sheetCharacterFrom(
            character: selected,
            sheet: CharacterSheet(
              character: selected,
              rules: ref.watch(gameRulesProvider),
              proficiencies: state.proficiencies,
              skills: state.skills,
            ),
            fileName: state.slot.label,
          );
    final subject = _subject;

    return PopScope(
      // Leaving with unsaved edits would discard them silently, and this app
      // exists to protect files that represent tens of hours of play.
      canPop: !(state?.isDirty ?? false),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard(context);
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        endDrawerEnableOpenDragGesture: false,
        endDrawer: subject == null || sheet == null
            ? null
            : SideSheet(
                key: ValueKey<String>(
                  '${subject.runtimeType}:${subject.title}',
                ),
                subject: subject,
                character: sheet,
                rulesBind: _rulesBind,
                onApplyField: _applyField,
                onApplyPips: _applyPips,
                onClose: _closeSheet,
              ),
        appBar: AppBar(
          title: Text(
            // ⚠️ **The label, even while loading.** Falling back to the route
            // parameter showed `000000022-last` for a frame before settling on
            // `last` — the index the player is never meant to see, flashed on
            // every open.
            '${state?.slot.label ?? SaveSlot.labelOf(widget.slotDirectoryName)}'
            '${(state?.isDirty ?? false) ? ' •' : ''}',
          ),
          actions: [
            if (sheet != null)
              FindingsBadge(
                findings: findingsFor(sheet),
                onPressed: _showFindings,
              ),
            const SizedBox(width: 8),
            RulesToggle(
              binding: _rulesBind,
              onChanged: (value) => setState(() => _rulesBind = value),
            ),
            const SizedBox(width: 8),
            if (selected != null)
              IconButton(
                onPressed: _openInventory,
                icon: const Icon(Icons.backpack_outlined),
                tooltip: 'Inventory',
              ),
            ExportButton(
              character: selected,
              slotDirectoryName: widget.slotDirectoryName,
            ),
            IconButton(
              onPressed: (state?.canUndo ?? false) ? notifier.undo : null,
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
            ),
            IconButton(
              onPressed: (state?.canRedo ?? false) ? notifier.redo : null,
              icon: const Icon(Icons.redo),
              tooltip: 'Redo',
            ),
            const SizedBox(width: 8),
            SaveButton(
              isDirty: state?.isDirty ?? false,
              onSave: notifier.save,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: party.when(
          data: (state) => state.members.isEmpty
              ? const _EmptyParty()
              : Row(
                  children: [
                    PortraitRail(
                      state: state,
                      slotDirectoryName: widget.slotDirectoryName,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: sheet == null
                          ? const _EmptyParty()
                          : _Body(
                              character: sheet,
                              palette: _palette,
                              scroll: _scroll,
                              rulesBind: _rulesBind,
                              onOpen: _open,
                            ),
                    ),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LoadFailed(error: error),
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave without saving?'),
        content: const Text(
          'This savegame has changes that are not written to disk yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }
}

/// The scrolling body: the palette, then the record.
class _Body extends StatelessWidget {
  const _Body({
    required this.character,
    required this.palette,
    required this.scroll,
    required this.rulesBind,
    required this.onOpen,
  });

  final SheetCharacter character;
  final SearchController palette;
  final ScrollController scroll;
  final bool rulesBind;
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
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CommandPalette(
                      controller: palette,
                      character: character,
                      onSelected: onOpen,
                    ),
                    const SizedBox(height: 24),
                    CharacterSheetView(
                      character: character,
                      rulesBind: rulesBind,
                      onOpen: onOpen,
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

/// The party, as a rail down the left.
///
/// A `NavigationRail` rather than a hand-rolled column: it brings selection
/// semantics, keyboard traversal and the right sizes with it.
class _EmptyParty extends StatelessWidget {
  const _EmptyParty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('This savegame has nobody in its party.'),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text('This savegame could not be read.\n\n$error'),
      ),
    );
  }
}
