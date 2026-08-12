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

/// The bar at the top of the document, which is a running head rather than a
/// toolbar: it says which document you are in, and once you are inside it says
/// who the document is about.
///
/// **One bar, not two.** The two states are cross-faded in place, so the change
/// costs no relayout and the actions never move under the pointer.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/demo/portrait.dart';
import 'package:ui_spikes/record/theme.dart';

/// The identity list is gender, race, class, alignment. The class is the fact
/// worth carrying up into the head.
const int _classFact = 2;

/// The document's running head.
class RunningHead extends StatelessWidget {
  /// Creates the head at [progress], where 0 is the top of the document and 1
  /// is far enough in that the cover has gone.
  const RunningHead({
    required this.character,
    required this.progress,
    required this.height,
    required this.onSave,
    this.onUndo,
    this.onRedo,
    super.key,
  });

  /// Whose record this is.
  final DemoCharacter character;

  /// How far the cross-fade has run, from 0 to 1.
  final double progress;

  /// The bar's height, already scaled for the reader's text size.
  final double height;

  /// Writes the file back.
  final VoidCallback onSave;

  /// Takes back the last edit, or null when there is nothing to take back.
  final VoidCallback? onUndo;

  /// Puts back the last undone edit, or null when there is none.
  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) {
    final shown = progress.clamp(0, 1).toDouble();
    return AppBar(
      toolbarHeight: height,
      title: Stack(
        alignment: Alignment.centerLeft,
        children: [
          IgnorePointer(
            ignoring: shown > 0.5,
            child: Opacity(
              opacity: 1 - shown,
              child: _AtRest(fileName: character.fileName),
            ),
          ),
          IgnorePointer(
            ignoring: shown <= 0.5,
            child: Opacity(
              opacity: shown,
              child: _Scrolled(character: character),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: onUndo,
          tooltip: 'Undo',
          icon: const Icon(Icons.undo),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onRedo,
          tooltip: 'Redo',
          icon: const Icon(Icons.redo),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

/// At the top of the document, the head names the document.
class _AtRest extends StatelessWidget {
  const _AtRest({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Text(fileName);
  }
}

/// Once the cover has gone, it names the person instead — separated by
/// whitespace, never by interpuncts, because these are four facts and not one
/// sentence.
class _Scrolled extends StatelessWidget {
  const _Scrolled({required this.character});

  final DemoCharacter character;

  @override
  Widget build(BuildContext context) {
    final tokens = context.recordTokens;
    final identity = character.identity;
    final className = identity.length > _classFact ? identity[_classFact] : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Thumb(initial: character.name.isEmpty ? '?' : character.name[0]),
        const SizedBox(width: 16),
        Text(character.name),
        const SizedBox(width: 26),
        Text(className, style: tokens.railEntry),
        const SizedBox(width: 22),
        Text(character.levelLine, style: tokens.railEntry),
      ],
    );
  }
}

/// A portrait at the aspect the game actually draws — never a square, never a
/// circle.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return DemoPortrait(initial: initial, width: 28, radius: 3);
  }
}
