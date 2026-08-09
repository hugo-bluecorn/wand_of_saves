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
import 'package:wand_of_saves/data/repositories/character_file_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/save_slot.dart';
import 'package:wand_of_saves/ui/character/character_panel.dart';
import 'package:wand_of_saves/ui/character/portrait_image.dart';
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
    final state = party.value;
    final notifier = ref.read(partyProvider(slotDirectoryName).notifier);

    return PopScope(
      // Leaving with unsaved edits would discard them silently, and this app
      // exists to protect files that represent tens of hours of play.
      canPop: !(state?.isDirty ?? false),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard(context);
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            // ⚠️ **The label, even while loading.** Falling back to the route
            // parameter showed `000000022-last` for a frame before settling on
            // `last` — the index the player is never meant to see, flashed on
            // every open. The rule does not depend on the file being read.
            '${state?.slot.label ?? SaveSlot.labelOf(slotDirectoryName)}'
            '${(state?.isDirty ?? false) ? ' •' : ''}',
          ),
          actions: [
            _ExportButton(
              character: state?.selected,
              slotDirectoryName: slotDirectoryName,
            ),
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
        body: party.when(
          data: (state) => state.members.isEmpty
              ? const _EmptyParty()
              : _PartyShell(state: state, slotDirectoryName: slotDirectoryName),
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
          'This savegame has changes that are not written to disk yet.',
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

/// Writes the character on screen out as a `.chr`.
///
/// **Where the game puts it.** BG:EE exports from the Record screen of a saved
/// game, and imports from character creation to start a new one — so this
/// belongs beside the character, not on the home screen.
///
/// ⚠️ **Not a save**, and the two are deliberately separate controls: this
/// creates a new file and never touches the savegame, which makes it the safest
/// write in the application. The dirty marker is untouched by it.
class _ExportButton extends ConsumerWidget {
  const _ExportButton({
    required this.character,
    required this.slotDirectoryName,
  });

  final Character? character;
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

class _PartyShell extends StatelessWidget {
  const _PartyShell({required this.state, required this.slotDirectoryName});

  final PartyState state;
  final String slotDirectoryName;

  @override
  Widget build(BuildContext context) {
    // The controller lives here, above the rail, so **the tab survives
    // changing character**. Comparing one number across the party is the whole
    // point of having a rail; a controller owned by the detail pane would be
    // rebuilt on every selection and snap back to Character each time.
    return DefaultTabController(
      length: CharacterPanel.tabCount,
      child: Row(
        children: [
          _PortraitRail(state: state, slotDirectoryName: slotDirectoryName),
          const VerticalDivider(width: 1),
          Expanded(
            child: _CharacterPane(
              state: state,
              slotDirectoryName: slotDirectoryName,
            ),
          ),
        ],
      ),
    );
  }
}

/// The shared character sheet, wired to this savegame's ViewModel.
///
/// The only thing this adds to [CharacterPanel] is *where the edits go*, which
/// is the whole of what differs between the two documents.
class _CharacterPane extends ConsumerWidget {
  const _CharacterPane({required this.state, required this.slotDirectoryName});

  final PartyState state;
  final String slotDirectoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CharacterPanel(
    character: state.members[state.selectedIndex],
    proficiencies: state.proficiencies,
    skills: state.skills,
    reputation: state.reputation,
    onEdit: ref.read(partyProvider(slotDirectoryName).notifier).edit,
  );
}

/// The party, as the portraits their records name.
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
            icon: _Portrait(baseName: member.portraitBaseName),
            selectedIcon: _Portrait(
              baseName: member.portraitBaseName,
              selected: true,
            ),
            label: Text(member.name),
          ),
      ],
    );
  }
}

/// One party portrait — **the one the record names**, not the one the game
/// baked beside the save.
///
/// ⚠️ **This reverses a decision that was right until this slice.** The rail
/// used to draw `PORTRT<n>.bmp`, the picture the engine wrote when the file was
/// saved, under a tooltip explaining that its baked-in hit points would not
/// follow an edit. That reasoning was correct for a panel that could not change
/// a portrait. This one can, and a rail still showing the old face after the
/// player picked a new one would simply look broken.
///
/// The sidecar keeps its job, which nothing else can do: it is a picture of
/// what the engine *believed*, and reading `18 / 18` out of one is what closed
/// D10. It is an oracle, not the character's face.
///
/// The two are close enough in shape that nothing else moves: the rail draws
/// 54×84 (0.643) and an `…M` portrait is 169×266 (0.635).
class _Portrait extends StatelessWidget {
  const _Portrait({required this.baseName, this.selected = false});

  /// The width the game writes.
  static const double width = 54;

  /// The height the game writes.
  static const double height = 84;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(6));

  /// The portrait's base name, with no variant suffix.
  final String baseName;

  /// Whether this is the character on show.
  ///
  /// The rail's own M3 indicator is drawn *behind* the icon, and a portrait is
  /// opaque and fills that space exactly — so it hid the indicator completely
  /// and selection had no visible effect. The frame is drawn here instead.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'The portrait this character’s record names.',
      child: _frame(colors),
    );
  }

  Widget _frame(ColorScheme colors) {
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
        child: PortraitImage(baseName: baseName, iconSize: 28),
      ),
    );
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
