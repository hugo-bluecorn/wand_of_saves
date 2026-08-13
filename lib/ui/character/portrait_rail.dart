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
import 'package:wand_of_saves/ui/character/portrait_tile.dart';
import 'package:wand_of_saves/ui/party/party_viewmodel.dart';

/// The party down the left-hand side, as portraits you can select between.
///
/// **Its own file because two screens show it** — the character sheet and the
/// inventory. Selection goes through `partyProvider`, so whichever surface is
/// on screen follows the same selection rather than keeping its own.
class PortraitRail extends ConsumerWidget {
  /// Shows the party in [state], selecting through the savegame's provider.
  const PortraitRail({
    required this.state,
    required this.slotDirectoryName,
    super.key,
  });

  /// The party to draw, and which of them is selected.
  final PartyState state;

  /// The save slot whose provider owns the selection.
  final String slotDirectoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationRail(
      selectedIndex: state.selectedIndex,
      onDestinationSelected: ref
          .read(partyProvider(slotDirectoryName).notifier)
          .select,
      labelType: NavigationRailLabelType.all,
      minWidth: PortraitTile.width + 32,
      groupAlignment: -1,
      // ⚠️ **A full party of six does not fit an ordinary window**, and the
      // default is `false` — the destinations sit in a bare `Column` and paint
      // past the bottom. Six is the size the game allows; every fixture before
      // Conan had one member or four, which is why this survived until now.
      // The framework wraps them in a `SingleChildScrollView` itself, so this
      // is a property rather than a hand-rolled scroll view.
      scrollable: true,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      destinations: [
        for (final member in state.members)
          NavigationRailDestination(
            // ⚠️ **`portraitBaseName`, never `PORTRT<n>`.** The first is the
            // resref the record itself names; the second is a file beside the
            // save holding a stale snapshot the engine drew, kept only as an
            // oracle. Passing the filename here resolved nothing and drew a
            // generic icon for every member.
            icon: PortraitTile(baseName: member.portraitBaseName),
            // ⚠️ **Not decoration.** A portrait is opaque and fills the rail's
            // M3 indicator exactly, hiding it — so selection had no visible
            // effect at all until the frame moved onto the portrait itself.
            selectedIcon: PortraitTile(
              baseName: member.portraitBaseName,
              selected: true,
            ),
            label: SizedBox(
              // ⚠️ A floor with no ceiling let one long name widen the rail
              // and move every figure downstream of it.
              width: 92,
              child: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
