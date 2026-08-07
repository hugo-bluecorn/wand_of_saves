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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wand_of_saves/domain/ability_scores.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/ui/party/party_viewmodel.dart';

/// The editor shell for one savegame: the party down the left, the selected
/// character's numbers on the right.
///
/// Paired 1:1 with [PartyViewModel]. Every piece is its own widget class
/// rather than a `_buildX()` helper — helpers cannot be `const`, so they
/// rebuild with their parent, and they never appear in the widget inspector.
class PartyView extends ConsumerWidget {
  /// Opens the savegame in the slot directory named [slotDirectoryName].
  const PartyView({required this.slotDirectoryName, super.key});

  /// The save slot directory the route named.
  final String slotDirectoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final party = ref.watch(partyProvider(slotDirectoryName));

    return Scaffold(
      appBar: AppBar(
        title: Text(party.value?.slot.label ?? slotDirectoryName),
        // Nothing here can be saved yet, and an action that does nothing is
        // worse than no action. Editing arrives with the next slice.
      ),
      body: party.when(
        data: (state) => state.members.isEmpty
            ? const _EmptyParty()
            : _PartyShell(state: state, slotDirectoryName: slotDirectoryName),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadFailed(error: error),
      ),
    );
  }
}

class _PartyShell extends StatelessWidget {
  const _PartyShell({required this.state, required this.slotDirectoryName});

  final PartyState state;
  final String slotDirectoryName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PortraitRail(state: state, slotDirectoryName: slotDirectoryName),
        const VerticalDivider(width: 1),
        Expanded(
          child: _CharacterSummary(
            character: state.members[state.selectedIndex],
          ),
        ),
      ],
    );
  }
}

/// The party, as the portraits the game itself drew.
///
/// A `NavigationRail` rather than a hand-rolled column: it brings selection
/// semantics, keyboard traversal and the M3 indicator with it, and D4 already
/// nominates the party as the primary rail with editor categories nested
/// beside it later.
class _PortraitRail extends ConsumerWidget {
  const _PortraitRail({required this.state, required this.slotDirectoryName});

  final PartyState state;
  final String slotDirectoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationRail(
      selectedIndex: state.selectedIndex,
      onDestinationSelected: ref
          .read(partyProvider(slotDirectoryName).notifier)
          .select,
      labelType: NavigationRailLabelType.all,
      minWidth: _Portrait.width + 32,
      groupAlignment: -1,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      destinations: [
        for (final member in state.members)
          NavigationRailDestination(
            icon: _Portrait(path: member.portraitPath),
            selectedIcon: _Portrait(
              path: member.portraitPath,
              selected: true,
            ),
            label: Text(member.name),
          ),
      ],
    );
  }
}

/// One party portrait.
///
/// The game writes `PORTRT<n>.bmp` beside each savegame at 54×84, and
/// `dart:ui` decodes BMP natively — so these are the player's real portraits
/// with no decoder and no resource index behind them. Three states: present,
/// absent, unreadable.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.path, this.selected = false});

  /// The width the game writes.
  static const double width = 54;

  /// The height the game writes.
  static const double height = 84;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(6));

  final String? path;

  /// Whether this is the character on show.
  ///
  /// The rail's own M3 indicator is drawn *behind* the icon, and a portrait is
  /// opaque and fills that space exactly — so it hid the indicator completely
  /// and selection had no visible effect. The frame is drawn here instead.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final path = this.path;

    return Container(
      width: width,
      height: height,
      // Foreground, so the frame sits over the portrait rather than under it.
      // Both states carry a border of the same width, so nothing shifts when
      // the selection moves.
      foregroundDecoration: BoxDecoration(
        borderRadius: _radius,
        border: Border.all(
          color: selected ? colors.primary : colors.outlineVariant,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: path == null
            ? const _NoPortrait()
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => const _NoPortrait(),
              ),
      ),
    );
  }
}

class _NoPortrait extends StatelessWidget {
  const _NoPortrait();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Icon(Icons.person_outline, color: colors.outline),
    );
  }
}

/// Everything the savegame knows about one character.
///
/// Read-only for now. Class, race and alignment are deliberately absent: their
/// *names* live in `CLASS.IDS` and friends inside the game's BIFF archives,
/// which is Phase 3. Showing a raw class number would be worse than showing
/// nothing.
class _CharacterSummary extends StatelessWidget {
  const _CharacterSummary({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(character.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Level ${character.levelLabel}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _StatGroup(
          title: 'Character',
          tiles: [
            _Stat(
              'Hit points (base)',
              '${character.currentHitPoints} / ${character.maximumHitPoints}',
              // Verified against the game's own portrait overlay: it renders
              // 8/9 where the savegame stores 6/7, and 9/9 where it stores
              // 7/7, at a constant Constitution of 16. The stored field is
              // what an editor edits; saying "base" stops the difference
              // reading as a bug.
              hint:
                  'The savegame stores hit points without the Constitution '
                  'bonus. The game adds that bonus when it displays them, so '
                  'this number is lower than the one on your character sheet.',
            ),
            _Stat('Experience', character.experience.toString()),
            _Stat(
              'Gold (carried)',
              character.gold.toString(),
              hint:
                  'Gold on this character. The shared party purse is stored '
                  'separately and is not this number.',
            ),
            _Stat('THAC0', character.thac0.toString()),
            _Stat('Armour class', character.armorClass.toString()),
            _Stat('Reputation', character.reputation.toStringAsFixed(1)),
          ],
        ),
        const SizedBox(height: 24),
        _StatGroup(
          title: 'Abilities',
          tiles: _abilityTiles(character.abilities),
        ),
      ],
    );
  }

  List<_Stat> _abilityTiles(AbilityScores abilities) => [
    // Strength carries its percentile, which is meaningful only at 18 -- so
    // the model formats it rather than the view guessing when to show it.
    _Stat('Strength', abilities.strengthLabel),
    _Stat('Dexterity', abilities.dexterity.toString()),
    _Stat('Constitution', abilities.constitution.toString()),
    _Stat('Intelligence', abilities.intelligence.toString()),
    _Stat('Wisdom', abilities.wisdom.toString()),
    _Stat('Charisma', abilities.charisma.toString()),
  ];
}

/// One labelled number, and the unit the next slice makes editable.
class _Stat {
  const _Stat(this.label, this.value, {this.hint});

  final String label;
  final String value;

  /// Why this number may not match what the game shows.
  ///
  /// Some stored fields are *base* values the engine modifies before
  /// displaying them. Saying so where the number is beats leaving the player
  /// to conclude the editor is reading their save wrongly.
  final String? hint;
}

class _StatGroup extends StatelessWidget {
  const _StatGroup({required this.title, required this.tiles});

  final String title;
  final List<_Stat> tiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final tile in tiles) _StatTile(stat: tile)],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = stat.hint;
    final tile = Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          width: 128,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      stat.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(stat.value, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );

    // Tooltip carries its own semantics, so the explanation reaches a screen
    // reader as well as a pointer.
    return hint == null ? tile : Tooltip(message: hint, child: tile);
  }
}

class _EmptyParty extends StatelessWidget {
  const _EmptyParty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('This savegame has nobody in the party.'),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colors.error),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
