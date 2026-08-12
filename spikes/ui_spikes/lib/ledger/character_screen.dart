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

/// The character sheet: a rail, a masthead, a ledger and a detail rail.
///
/// ## A rail rather than a `TabBar`
///
/// The sections are `NavigationRail` destinations, and the reason is arithmetic
/// rather than taste. A `TabBar` divides a fixed width between its tabs, so
/// every section added makes every existing label narrower — and this
/// application's own tab labels are already the thing that truncates. A rail
/// spends **vertical** space, which a desktop window has, and
/// `scrollable: true` means the sixth section costs nothing at all. Adding one
/// here is one line in `lib/demo/aard.dart` and no layout decision.
///
/// ## Where the state lives
///
/// This screen owns all three pieces of mutable state — the selected section,
/// the selected row and the pending edits — because all three are shared
/// between the table and the rail and none of them outlives the screen. A
/// spike that reached for a state-management package here would be measuring
/// the plumbing rather than the design.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/demo/portrait.dart';
import 'package:ui_spikes/ledger/detail_rail.dart';
import 'package:ui_spikes/ledger/inventory_view.dart';
import 'package:ui_spikes/ledger/ledger_edits.dart';
import 'package:ui_spikes/ledger/ledger_row.dart';
import 'package:ui_spikes/ledger/ledger_table.dart';

/// The whole editor for one character.
class CharacterScreen extends StatefulWidget {
  /// Opens [character] on [initialSection].
  const CharacterScreen({
    required this.character,
    this.initialSection = 0,
    this.onClose,
    super.key,
  });

  /// Whose sheet this is.
  final DemoCharacter character;

  /// Which rail destination to open on, so a screen that cannot be clicked to
  /// can still be photographed. See `lib/demo/boot.dart`.
  final int initialSection;

  /// Called to go back to the lineup, or null when there is nowhere to go.
  final VoidCallback? onClose;

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  final LedgerEdits _edits = LedgerEdits();
  int _section = 0;
  LedgerRow? _selected;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection.clamp(
      0,
      widget.character.sections.length - 1,
    );
  }

  void _selectSection(int index) => setState(() {
    _section = index;
    // A row from the section just left would leave the detail rail showing
    // something the table on screen no longer contains.
    _selected = null;
  });

  void _select(LedgerRow row) => setState(() => _selected = row);

  void _write(String id, String value) =>
      setState(() => _edits.write(id, value));

  void _reset(String id) => setState(() => _edits.reset(id));

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_edits.changeCount} fields would be written. A spike writes '
          'nothing to disk.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final character = widget.character;
    final section = character.sections[_section];
    final onClose = widget.onClose;
    // Pips are allocated points, so they belong with the other allocated
    // points. Nothing in `DemoSection` says which section that is, so the
    // screen decides rather than the merge inventing a rule about it.
    final proficiencies = section.title == 'Skills'
        ? character.proficiencies
        : const <DemoProficiency>[];
    final body = section.title == 'Inventory'
        ? InventoryView(
            character: character,
            edits: _edits,
            onSelect: _select,
            selectedId: _selected?.id,
          )
        : LedgerTable(
            columns: LedgerColumns.fields,
            blocks: ledgerBlocks(section, proficiencies: proficiencies),
            edits: _edits,
            onSelect: _select,
            selectedId: _selected?.id,
          );

    return Scaffold(
      appBar: AppBar(
        leading: onClose == null
            ? null
            : IconButton(
                onPressed: onClose,
                tooltip: 'Back to the lineup',
                icon: const Icon(Icons.arrow_back),
              ),
        title: Text(character.fileName),
        actions: [
          _ChangeCount(count: _edits.changeCount),
          IconButton(
            onPressed: _edits.canUndo ? () => setState(_edits.undo) : null,
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: _edits.canRedo ? () => setState(_edits.redo) : null,
            tooltip: 'Redo',
            icon: const Icon(Icons.redo),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _edits.changeCount == 0 ? null : _save,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            // ⚠️ The one thing that keeps a five-destination rail usable when
            // someone turns the system text size up.
            scrollable: true,
            selectedIndex: _section,
            onDestinationSelected: _selectSection,
            destinations: [
              for (final destination in character.sections)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  label: Text(destination.title),
                ),
            ],
          ),
          const VerticalDivider(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Masthead(character: character),
                const Divider(),
                Expanded(child: body),
              ],
            ),
          ),
          DetailRail(
            edits: _edits,
            onWrite: _write,
            onReset: _reset,
            row: _selected,
          ),
        ],
      ),
    );
  }
}

class _ChangeCount extends StatelessWidget {
  const _ChangeCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Text(
        count == 1 ? '1 field changed' : '$count fields changed',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Whose sheet this is, which has to be true of every destination rather than
/// of one of them.
class _Masthead extends StatelessWidget {
  const _Masthead({required this.character});

  final DemoCharacter character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DemoPortrait(initial: character.name.substring(0, 1), width: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(character.name, style: theme.textTheme.titleLarge),
                    const SizedBox(width: 10),
                    Text(
                      character.levelLine,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                _FactStrip(facts: character.identity),
                const SizedBox(height: 6),
                Text(
                  character.experienceLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _AnomalyBadge(anomalies: character.anomalies),
        ],
      ),
    );
  }
}

/// ⚠️ Four facts with rules between them, not one concatenated sentence.
///
/// The application writes `Level 1/1 · Male · Elf · Fighter / Mage · Neutral
/// Good`, which reads as prose and hides that these are four separate answers
/// the engine prints on four separate lines. Keeping them apart costs one
/// hairline each and makes the class — the one a kit *replaces*, so `Nadia` is
/// a `Swashbuckler` and never a `Thief (Swashbuckler)` — a thing you can point
/// at.
class _FactStrip extends StatelessWidget {
  const _FactStrip({required this.facts});

  final List<String> facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < facts.length; index++) ...[
          Text(facts[index], style: theme.textTheme.bodyMedium),
          if (index < facts.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                width: 1,
                height: 12,
                child: ColoredBox(color: theme.colorScheme.outline),
              ),
            ),
        ],
      ],
    );
  }
}

class _AnomalyBadge extends StatelessWidget {
  const _AnomalyBadge({required this.anomalies});

  final List<String> anomalies;

  @override
  Widget build(BuildContext context) {
    if (anomalies.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Tooltip(
      message: anomalies.join('\n\n'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 14,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 5),
              Text(
                anomalies.length == 1
                    ? '1 anomaly'
                    : '${anomalies.length} anomalies',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
