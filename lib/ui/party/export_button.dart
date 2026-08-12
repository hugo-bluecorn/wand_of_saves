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
import 'package:wand_of_saves/data/repositories/character_file_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/ui/party/party_viewmodel.dart';

/// Writes the character on screen out as a `.chr`.
///
/// **Where the game puts it.** BG:EE exports from the Record screen of a saved
/// game, and imports from character creation to start a new one — so this
/// belongs beside the character, not on the home screen.
///
/// ⚠️ **Not a save**, and the two are deliberately separate controls: this
/// creates a new file and never touches the savegame, which makes it the safest
/// write in the application. The dirty marker is untouched by it.
class ExportButton extends ConsumerWidget {
  /// Offers to export [character] out of [slotDirectoryName].
  const ExportButton({
    required this.character,
    required this.slotDirectoryName,
    super.key,
  });

  /// The character to write, or `null` while the save is still loading.
  final Character? character;

  /// The save slot the character lives in.
  final String slotDirectoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final character = this.character;

    return IconButton(
      onPressed: character == null
          ? null
          : () => _export(context, ref, character),
      icon: const Icon(Icons.file_upload_outlined),
      tooltip: character == null
          ? 'Export a character'
          : 'Export ${character.name}…',
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    Character character,
  ) async {
    final fileName = await showDialog<String>(
      context: context,
      builder: (context) => _ExportDialog(character: character),
    );
    if (fileName == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref
          .read(partyProvider(slotDirectoryName).notifier)
          .export(fileName);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Exported ${created.character.name} to $fileName'),
        ),
      );
    } on CharacterFileExistsException {
      // Named rather than generic: the player can fix this by choosing another
      // name, and nothing was written, so saying so is the whole remedy.
      messenger.showSnackBar(
        SnackBar(
          content: Text('There is already a character called $fileName'),
        ),
      );
    } on NoCharacterDirectoryException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No Baldur’s Gate user data folder was found, so there is nowhere '
            'to put a character.',
          ),
        ),
      );
    }
  }
}

/// Asks what to call the exported character.
///
/// The game asks the same question, and defaults to the character's name. A
/// file name is the only thing an export needs that the record does not already
/// carry.
class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.character});

  final Character character;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: _defaultName,
  );
  String? _error;

  /// The character's name, made safe to use as a file name.
  ///
  /// A player may legitimately type a name with a slash in it, and the game
  /// lets them; that must not become a path.
  String get _defaultName =>
      widget.character.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final typed = _controller.text.trim();
    if (typed.isEmpty) {
      setState(() => _error = 'Give the character a file name.');
      return;
    }
    if (RegExp(r'[\\/:*?"<>|]').hasMatch(typed)) {
      setState(
        () => _error = r'A file name cannot contain \ / : * ? " < > or |.',
      );
      return;
    }
    Navigator.of(context).pop(
      typed.toLowerCase().endsWith(GameProfileService.characterExtension)
          ? typed
          : '$typed${GameProfileService.characterExtension}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export character'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Writes ${widget.character.name} to the game’s characters folder, '
            'ready for New Game → IMPORT. The savegame is not changed.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'File name',
              suffixText: GameProfileService.characterExtension,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Export')),
      ],
    );
  }
}
