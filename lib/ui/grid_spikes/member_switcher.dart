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
/// The party, laid across a band instead of down an edge — the same party the
/// rail draws. `NavigationRail` is vertical by construction, so a band needs
/// its own widget.
///
/// ⚠️ **Written for G2 and inherited by G1** when the party column became a
/// band. Both spikes used this one widget rather than each getting a switcher,
/// which is why there was never a question of the two lighting up for
/// different drops.
///
/// ⚠️ **What it does NOT re-decide is which portraits will take a drop.** That
/// rule is `hasPackRoom`, shared with the rail — a second copy here is exactly
/// how one arrangement would come to light up for a drop the other refuses.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wand_of_saves/ui/character/portrait_tile.dart';
import 'package:wand_of_saves/ui/inventory/item_drag.dart';
import 'package:wand_of_saves/ui/inventory/pack_slots.dart';
import 'package:wand_of_saves/ui/party/party_viewmodel.dart';

/// The party across the top, as portraits you can select between.
class MemberSwitcher extends ConsumerWidget {
  /// Shows the party in [state], selecting through the savegame's provider.
  const MemberSwitcher({
    required this.state,
    required this.slotDirectoryName,
    this.onItemDropped,
    super.key,
  });

  /// The party to draw, and which of them is selected.
  final PartyState state;

  /// The save slot whose provider owns the selection.
  final String slotDirectoryName;

  /// Called when an item is dropped on the member at that party position.
  final void Function(ItemDrag drag, int to)? onItemDropped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final select = ref.read(partyProvider(slotDirectoryName).notifier).select;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (position, member) in state.members.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => select(position),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _target(
                      position: position,
                      baseName: member.portraitBaseName,
                      selected: position == state.selectedIndex,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      // ⚠️ A floor with no ceiling let one long name widen the
                      // rail and move every figure downstream of it. Same
                      // hazard here, sideways.
                      width: 76,
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The portrait at [position], as a drop target when items can be moved.
  ///
  /// Refuses the character it came from and one with a full backpack, so the
  /// portrait simply does not light up rather than accepting a drop that would
  /// then throw.
  Widget _target({
    required int position,
    required String baseName,
    required bool selected,
  }) {
    final onDropped = onItemDropped;
    if (onDropped == null) {
      return PortraitTile(baseName: baseName, selected: selected);
    }
    return DragTarget<ItemDrag>(
      onWillAcceptWithDetails: (details) =>
          details.data.from != position &&
          hasPackRoom(state.members[position].items),
      onAcceptWithDetails: (details) => onDropped(details.data, position),
      builder: (context, candidates, _) => PortraitTile(
        baseName: baseName,
        selected: selected || candidates.isNotEmpty,
      ),
    );
  }
}
