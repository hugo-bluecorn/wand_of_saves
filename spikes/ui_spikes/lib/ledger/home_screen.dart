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

/// The lineup, which is a ledger too.
///
/// Characters are rows under a sticky header — the same grammar the sheet
/// itself uses — rather than cards in a grid. A card shows one character
/// beautifully and two characters comparably badly; the question a person
/// actually has on this screen is *which of these*, and that is a question
/// about columns.
///
/// The identity is drawn twice on purpose, and the difference is the point.
/// In the table it is one joined string, because a table cell wants one value.
/// In the rail it is **four facts with a rule between each**, because they are
/// four separate answers the engine prints on four separate lines, and the
/// third of them — the class — is the one a kit *replaces* rather than
/// qualifies. `Nadia` is a `Swashbuckler`, never a `Thief (Swashbuckler)`, and
/// no code here does anything to make that true: the data already says so.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/demo/portrait.dart';

/// The character lineup, with a detail rail for the selected one.
class HomeScreen extends StatefulWidget {
  /// Lists [characters], opening one through [onOpen].
  const HomeScreen({required this.characters, required this.onOpen, super.key});

  /// Everyone on offer.
  final List<DemoCharacter> characters;

  /// Called with the character a person chose to open.
  final ValueChanged<DemoCharacter> onOpen;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final characters = widget.characters;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wand of Saves'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              characters.length == 1
                  ? '1 character'
                  : '${characters.length} characters',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _LineupHeader(),
                const Divider(),
                Expanded(
                  child: ListView(
                    primary: false,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (var index = 0; index < characters.length; index++)
                        _LineupRow(
                          character: characters[index],
                          selected: index == _selected,
                          onTap: () => setState(() => _selected = index),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _LineupDetail(
            character: characters[_selected],
            onOpen: () => widget.onOpen(characters[_selected]),
          ),
        ],
      ),
    );
  }
}

const double _levelWidth = 76;
const double _identityWidth = 232;
const double _fileWidth = 108;
const double _rowIndent = 16;

class _LineupHeader extends StatelessWidget {
  const _LineupHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(_rowIndent, 12, 16, 8),
      child: Row(
        children: [
          Expanded(child: Text('NAME', style: style)),
          SizedBox(
            width: _levelWidth,
            child: Text('LEVEL', style: style),
          ),
          SizedBox(
            width: _identityWidth,
            child: Text('IDENTITY', style: style),
          ),
          SizedBox(
            width: _fileWidth,
            child: Text('FILE', style: style),
          ),
        ],
      ),
    );
  }
}

class _LineupRow extends StatelessWidget {
  const _LineupRow({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  final DemoCharacter character;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      label: [
        character.name,
        character.levelLine,
        ...character.identity,
        character.fileName,
      ].join(', '),
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colors.surfaceContainerHighest : null,
            border: Border(
              left: BorderSide(
                color: selected ? colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_rowIndent - 2, 8, 16, 8),
            child: Row(
              children: [
                DemoPortrait(
                  initial: character.name.substring(0, 1),
                  width: 24,
                  radius: 3,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    character.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: _levelWidth,
                  child: Text(
                    character.levelLine,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                SizedBox(
                  width: _identityWidth,
                  child: Text(
                    character.identity.join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(
                  width: _fileWidth,
                  child: Text(
                    character.fileName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LineupDetail extends StatelessWidget {
  const _LineupDetail({required this.character, required this.onOpen});

  final DemoCharacter character;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A character with no sections is in the lineup so that the list is not a
    // single row; there is no sheet behind it to open.
    final openable = character.sections.isNotEmpty;
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(left: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: ListView(
        primary: false,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          Center(
            child: DemoPortrait(initial: character.name.substring(0, 1)),
          ),
          const SizedBox(height: 14),
          Text(
            character.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            character.levelLine,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _FactList(facts: character.identity),
          const SizedBox(height: 16),
          Text(
            character.experienceLine,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (character.anomalies.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'WHAT LOOKS ODD',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            for (final anomaly in character.anomalies)
              _AnomalyLine(text: anomaly),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: openable ? onOpen : null,
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('Open'),
          ),
          if (!openable) ...[
            const SizedBox(height: 8),
            Text(
              'This one is here so the lineup is not a single row. Only Aard '
              'has a sheet behind him.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ⚠️ The four facts kept apart, with a rule between each.
///
/// The application joins them — `Level 1/1 · Male · Elf · Fighter / Mage ·
/// Neutral Good` — which reads as prose and buries the fact that the engine
/// prints them as four separate answers. The table on the left joins them too,
/// because a table cell wants one value; here, where there is room, they are
/// four.
class _FactList extends StatelessWidget {
  const _FactList({required this.facts});

  final List<String> facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < facts.length; index++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(facts[index], style: theme.textTheme.bodyLarge),
          ),
          if (index < facts.length - 1) const Divider(),
        ],
      ],
    );
  }
}

class _AnomalyLine extends StatelessWidget {
  const _AnomalyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline,
              size: 13,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
