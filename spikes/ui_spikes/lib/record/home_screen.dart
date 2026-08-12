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

/// The lineup, in the same voice as the document it opens.
///
/// Not a grid of cards — an **index**. One ruled entry per record, its facts
/// spaced apart rather than joined by interpuncts, and its file name where a
/// file name belongs: under the name, small.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/demo/portrait.dart';
import 'package:ui_spikes/record/character_screen.dart';
import 'package:ui_spikes/record/theme.dart';

/// The identity list is gender, race, class, alignment. Only the class is set
/// in full ink; the other three are the muted supporting facts.
const int _classFact = 2;

/// The application's entry point: every record it can open.
class HomeScreen extends StatefulWidget {
  /// Creates the index over [characters].
  ///
  /// When [openOnBoot] is given, that record is pushed from a post-frame
  /// callback, so the back button and the page transition are real rather than
  /// a two-state shell. It exists because nothing on this machine can drive
  /// the pointer: a screen that needs a click to reach cannot be photographed.
  const HomeScreen({
    required this.characters,
    required this.bootChapter,
    this.openOnBoot,
    super.key,
  });

  /// Every record in the lineup.
  final List<DemoCharacter> characters;

  /// Which chapter [openOnBoot] should open on.
  final int bootChapter;

  /// A record to open immediately, or null to stay on the index.
  final DemoCharacter? openOnBoot;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final character = widget.openOnBoot;
    if (character == null) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _open(character, widget.bootChapter),
    );
  }

  void _open(DemoCharacter character, int chapter) {
    if (!mounted) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CharacterScreen(
            character: character,
            initialChapter: chapter,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    return Scaffold(
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: tokens.measure),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('WAND OF SAVES', style: tokens.chapterHead),
                  const SizedBox(height: 16),
                  Text('Characters', style: tokens.coverName),
                  const SizedBox(height: 26),
                  const Divider(),
                  for (final character in widget.characters)
                    _RecordEntry(
                      character: character,
                      onOpen: () => _open(character, 0),
                    ),
                  const SizedBox(height: 36),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('Open a character file…'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One record in the index.
class _RecordEntry extends StatelessWidget {
  const _RecordEntry({required this.character, required this.onOpen});

  final DemoCharacter character;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    // The running head takes this same role from the app bar theme, so the
    // name is the same face at the same size in both places.
    final nameStyle = Theme.of(context).textTheme.titleLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: '${character.name}, ${character.identity.join(', ')}',
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  DemoPortrait(
                    initial: character.name.isEmpty ? '?' : character.name[0],
                    width: 48,
                    radius: 4,
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(character.name, style: nameStyle),
                        const SizedBox(height: 4),
                        _IdentityFacts(identity: character.identity),
                        const SizedBox(height: 4),
                        Text(character.fileName, style: tokens.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(character.levelLine, style: tokens.storedValue),
                  const SizedBox(width: 16),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}

/// The four facts, spaced apart. No interpuncts, and no one sentence.
class _IdentityFacts extends StatelessWidget {
  const _IdentityFacts({required this.identity});

  final List<String> identity;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    return Wrap(
      spacing: 24,
      runSpacing: 2,
      children: [
        for (var i = 0; i < identity.length; i++)
          Text(
            identity[i],
            style: i == _classFact
                ? tokens.identityLineStrong
                : tokens.identityLine,
          ),
      ],
    );
  }
}
