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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ui_spikes/demo/aard.dart';
import 'package:ui_spikes/demo/boot.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/demo/portrait.dart';
import 'package:ui_spikes/workbench/character_screen.dart';
import 'package:ui_spikes/workbench/command_palette.dart';
import 'package:ui_spikes/workbench/findings.dart';

/// The lineup — the application's front door.
///
/// It carries the palette too, because searching a record is not a thing you
/// should have to open a record to do; picking `Strength` here opens Aard on
/// the workbench with that field already in the side sheet.
class HomeScreen extends StatefulWidget {
  /// Creates the lineup.
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SearchController _palette = SearchController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (requestedTab == 1) {
        _palette
          ..text = 'str'
          ..openView();
      }
    });
  }

  @override
  void dispose() {
    _palette.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openCharacter(DemoCharacter character) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CharacterScreen(character: character),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wand of Saves'),
        actions: const [_HomeMenu(), SizedBox(width: 8)],
      ),
      body: CallbackShortcuts(
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
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Characters', style: text.headlineSmall),
                      const SizedBox(height: 6),
                      Text(
                        'Each character is its own document. Open one, or go '
                        'straight to the thing you came to change.',
                        style: text.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: CommandPalette(
                          controller: _palette,
                          character: aard,
                          onSelected: (_) => _openCharacter(aard),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _Lineup(onOpen: _openCharacter),
                      const SizedBox(height: 40),
                      Text('Saves', style: text.headlineSmall),
                      const SizedBox(height: 6),
                      Text(
                        'A savegame is a party, not a document. Open one to '
                        'edit whoever is in it.',
                        style: text.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _Saves(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Lineup extends StatelessWidget {
  const _Lineup({required this.onOpen});

  final ValueChanged<DemoCharacter> onOpen;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        for (final character in [aard, nadia])
          SizedBox(
            width: 380,
            child: _CharacterCard(
              character: character,
              onOpen: () => onOpen(character),
            ),
          ),
      ],
    );
  }
}

/// The savegames beside the characters — the other half of the lineup.
class _Saves extends StatelessWidget {
  const _Saves();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        for (final save in demoSaves)
          SizedBox(width: 280, child: _SaveCard(save: save)),
      ],
    );
  }
}

class _SaveCard extends StatelessWidget {
  const _SaveCard({required this.save});

  final DemoSave save;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: '${save.label}, saved ${save.saved}',
        child: InkWell(
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DemoScreenshot(name: save.screenshot),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(save.label, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      save.party == 1
                          ? '${save.lead} · alone'
                          : '${save.lead} and ${save.party - 1} others',
                      style: text.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${save.location} · ${save.saved}',
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character, required this.onOpen});

  final DemoCharacter character;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final flagged = findingsFor(character).length;
    return Card(
      child: Semantics(
        button: true,
        label: '${character.name}, ${character.fileName}',
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DemoPortrait(initial: character.name.substring(0, 1)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(character.name, style: text.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        character.levelLine,
                        style: text.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // ⚠️ Nadia's reads `Swashbuckler`: a kit replaces
                          // the class name, and nothing here recomposes it.
                          for (final fact in character.identity)
                            Chip(
                              label: Text(fact),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        character.fileName,
                        style: text.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        flagged == 0
                            ? 'Nothing flagged'
                            : flagged == 1
                            ? '1 thing to look at'
                            : '$flagged things to look at',
                        style: text.bodyMedium?.copyWith(
                          color: flagged == 0
                              ? colors.onSurfaceVariant
                              : colors.tertiary,
                        ),
                      ),
                    ],
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

class _HomeMenu extends StatelessWidget {
  const _HomeMenu();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.folder_open_outlined),
          onPressed: () {},
          child: const Text('Open a character file…'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.save_outlined),
          onPressed: () {},
          child: const Text('Open a savegame…'),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        onPressed: controller.isOpen ? controller.close : controller.open,
        tooltip: 'More',
        icon: const Icon(Icons.more_vert),
      ),
    );
  }
}
