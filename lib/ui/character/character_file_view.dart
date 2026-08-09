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
import 'package:go_router/go_router.dart';
import 'package:wand_of_saves/ui/character/character_file_viewmodel.dart';
import 'package:wand_of_saves/ui/character/character_panel.dart';

/// The editor for one exported character.
///
/// Paired 1:1 with [CharacterFileViewModel]. **The same sheet the party shell
/// shows**, with two things missing because a `.chr` does not have them: a
/// portrait rail, since there is one character and nothing to rail between, and
/// the party's reputation, which no exported character has.
class CharacterFileView extends ConsumerWidget {
  /// Opens the character file called [fileName].
  const CharacterFileView({required this.fileName, super.key});

  /// The character file the route named.
  final String fileName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final character = ref.watch(characterFileProvider(fileName));
    final state = character.value;
    final notifier = ref.read(characterFileProvider(fileName).notifier);

    return PopScope(
      // Leaving with unsaved edits would discard them silently. The same guard
      // the savegame editor has, for the same reason: this is somebody's
      // character.
      canPop: !(state?.isDirty ?? false),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard(context);
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          // ⚠️ **The file, not the character.** The party shell's bar names the
          // savegame while the panel below names the character, and this is the
          // same division: the panel already says "Aurel" in headline type, so
          // repeating it here says nothing and loses the one fact the bar can
          // add. The two really are different — `Aard1.chr` holds a character
          // called `Aard`, and a player with two exports of one character has
          // only the file name to tell them apart.
          title: Text(
            '${state?.file.fileName ?? fileName}'
            '${(state?.isDirty ?? false) ? ' •' : ''}',
          ),
          actions: [
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
            FilledButton.icon(
              onPressed: (state?.isDirty ?? false) ? notifier.save : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: character.when(
          data: (found) => DefaultTabController(
            length: CharacterPanel.tabCount,
            child: CharacterPanel(
              character: found.character,
              proficiencies: found.proficiencies,
              skills: found.skills,
              // No party, so no reputation row -- rather than a blank one, or
              // the character's own stale copy that the engine ignores.
              onEdit: notifier.edit,
            ),
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
          'This character has changes that are not written to disk yet.',
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
