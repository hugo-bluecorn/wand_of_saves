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

/// ⚠️ **THROWAWAY.** Everything under `lib/ui/grid_spikes/` exists so the two
/// grid arrangements of `planning/tool-first-study.md` can be looked at with
/// real data, and is **deleted once D19 is decided** — the winning grid is
/// rebuilt test-first in the merge slice. Nothing here is production code and
/// nothing production depends on it, except the debug-only entry on the home
/// screen.
///
/// This file is what both spikes share: opening the savegame, projecting the
/// selected member, and issuing the edit commands. Written once because two
/// copies of the wiring would be two chances for one spike to be quietly more
/// capable than the other — and the comparison is the whole point.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/carried_item.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/edit_command.dart';
import 'package:wand_of_saves/domain/rules/character_sheet.dart';
import 'package:wand_of_saves/ui/character/findings.dart';
import 'package:wand_of_saves/ui/character/findings_badge.dart';
import 'package:wand_of_saves/ui/character/rules_toggle.dart';
import 'package:wand_of_saves/ui/character/sheet_projection.dart';
import 'package:wand_of_saves/ui/character/sheet_view_model.dart';
import 'package:wand_of_saves/ui/core/save_button.dart';
import 'package:wand_of_saves/ui/party/party_viewmodel.dart';

/// One savegame, open, with the selected member already projected.
class GridSpikeModel {
  /// Bundles what a grid needs to draw and edit the open savegame.
  const GridSpikeModel({
    required this.slotDirectoryName,
    required this.state,
    required this.sheet,
    required this.notifier,
    required this.rulesBind,
    required this.onRulesBindChanged,
  });

  /// The save slot directory, which is what `partyProvider` is keyed by.
  final String slotDirectoryName;

  /// The party, and which of them is selected.
  final PartyState state;

  /// The selected member, as the sheet draws them.
  final SheetCharacter sheet;

  /// Where the edits go.
  final PartyViewModel notifier;

  /// Whether the rules bind, or merely advise — D16.
  final bool rulesBind;

  /// Flips the rules check.
  final ValueChanged<bool> onRulesBindChanged;

  /// The selected member's own record.
  Character get character => state.members[state.selectedIndex];

  /// Where that record starts in the savegame.
  int get creOffset => character.creOffset;

  /// Everything this application noticed about the open record.
  List<Finding> get findings => findingsFor(sheet);

  /// Writes one field of the record.
  void applyField(FieldEntry entry, String value) {
    final stat = entry.field.stat;
    final number = int.tryParse(value);
    if (stat == null || number == null) return;
    notifier.edit(
      SetCharacterStat(creOffset: creOffset, stat: stat, value: number),
    );
  }

  /// Writes one proficiency, granting the effect where the record has none.
  void applyPips(SheetProficiency proficiency, int pips) {
    final effectOffset = proficiency.effectOffset;
    notifier.edit(
      effectOffset == null
          ? GrantProficiency(
              creOffset: creOffset,
              proficiencyId: proficiency.id,
              pips: pips,
            )
          : SetProficiency(
              creOffset: creOffset,
              effectOffset: effectOffset,
              proficiencyId: proficiency.id,
              pips: pips,
            ),
    );
  }

  /// Puts [resref] in [slot].
  void addItem(String resref, CreItemSlot slot) =>
      notifier.edit(AddItem(creOffset: creOffset, resref: resref, slot: slot));

  /// Takes [item] out of the record.
  void removeItem(CarriedItem item) => notifier.edit(
    RemoveItem(
      creOffset: creOffset,
      itemIndex: item.index,
      resref: item.resref,
    ),
  );

  /// Hands an item from one party position to another.
  ///
  /// ⚠️ One command, not a remove followed by an add: the removal moves every
  /// record after the source, so the destination's offset does not exist until
  /// the first half has been applied. It is also one undo step.
  void moveItem({
    required int from,
    required int to,
    required int itemIndex,
    required String resref,
  }) => notifier.edit(
    MoveItem(from: from, to: to, itemIndex: itemIndex, resref: resref),
  );
}

/// Opens the savegame in [slotDirectoryName] and hands it to a grid.
class GridSpikeHost extends ConsumerStatefulWidget {
  /// Builds whatever arrangement [builder] draws over the open savegame.
  const GridSpikeHost({
    required this.slotDirectoryName,
    required this.builder,
    super.key,
  });

  /// The save slot directory the entry point picked.
  final String slotDirectoryName;

  /// The arrangement being tried.
  final Widget Function(BuildContext context, GridSpikeModel model) builder;

  @override
  ConsumerState<GridSpikeHost> createState() => _GridSpikeHostState();
}

class _GridSpikeHostState extends ConsumerState<GridSpikeHost> {
  bool _rulesBind = true;

  @override
  Widget build(BuildContext context) {
    final party = ref.watch(partyProvider(widget.slotDirectoryName));

    return Scaffold(
      // ⚠️ **No app bar, deliberately.** Each grid carries its own chrome in
      // the cell the study puts it in, and a second bar above that would both
      // duplicate it and steal 56 points from the height these spikes exist to
      // measure. The way back is a button in that same chrome.
      body: party.when(
        data: (state) {
          final selected = state.selected;
          if (selected == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('This savegame has nobody in its party.'),
              ),
            );
          }
          return widget.builder(
            context,
            GridSpikeModel(
              slotDirectoryName: widget.slotDirectoryName,
              state: state,
              sheet: sheetCharacterFrom(
                character: selected,
                sheet: CharacterSheet(
                  character: selected,
                  rules: ref.watch(gameRulesProvider),
                  proficiencies: state.proficiencies,
                  skills: state.skills,
                ),
                fileName: state.slot.label,
              ),
              notifier: ref.read(
                partyProvider(widget.slotDirectoryName).notifier,
              ),
              rulesBind: _rulesBind,
              onRulesBindChanged: (value) => setState(() => _rulesBind = value),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('This savegame could not be read.\n\n$error'),
          ),
        ),
      ),
    );
  }
}

/// The chrome both grids carry, in the order it reads: what is wrong, what
/// mode we are in, undo, redo, save, and the way out.
///
/// **A list rather than a bar**, because the two grids put it in differently
/// shaped cells — down the right-hand column on G1, across the top band on G2
/// — and only the arrangement should differ between them.
List<Widget> spikeChrome(
  BuildContext context,
  GridSpikeModel model, {
  required VoidCallback onFindings,
}) => [
  FindingsBadge(findings: model.findings, onPressed: onFindings),
  RulesToggle(
    binding: model.rulesBind,
    onChanged: model.onRulesBindChanged,
  ),
  IconButton(
    onPressed: model.state.canUndo ? model.notifier.undo : null,
    icon: const Icon(Icons.undo),
    tooltip: 'Undo',
  ),
  IconButton(
    onPressed: model.state.canRedo ? model.notifier.redo : null,
    icon: const Icon(Icons.redo),
    tooltip: 'Redo',
  ),
  SaveButton(isDirty: model.state.isDirty, onSave: model.notifier.save),
  IconButton(
    onPressed: () => Navigator.of(context).maybePop(),
    icon: const Icon(Icons.close),
    tooltip: 'Leave the spike',
  ),
];
