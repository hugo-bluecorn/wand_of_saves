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

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/data/services/portrait_import_service.dart';
import 'package:wand_of_saves/domain/bitmap_info.dart';
import 'package:wand_of_saves/ui/character/portrait_image.dart';

/// Every portrait the player can choose, by base name.
///
/// The game's own 210 **and** whatever is in their `portraits/` folder, in one
/// list — because the engine treats them as one list too: a loose file simply
/// shadows a packed one of the same name.
final portraitNamesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(resourceRepositoryProvider).portraitNames(),
);

/// Asks which portrait a character should use.
///
/// Returns the chosen base name, or `null` if the player backed out. Choosing a
/// face is what starts a character in BG:EE's own flow, and it is the first
/// step of creating one here for the same reason: it is the only part of a
/// character that cannot be derived from anything else.
class PortraitPicker extends ConsumerStatefulWidget {
  /// Creates a picker, with [selected] already chosen if there is one.
  const PortraitPicker({this.selected, super.key});

  /// The base name currently in use, so it can be shown as chosen.
  final String? selected;

  /// Shows the picker and answers what was chosen.
  static Future<String?> show(BuildContext context, {String? selected}) =>
      showDialog<String>(
        context: context,
        builder: (context) => PortraitPicker(selected: selected),
      );

  @override
  ConsumerState<PortraitPicker> createState() => _PortraitPickerState();
}

class _PortraitPickerState extends ConsumerState<PortraitPicker> {
  late String? _chosen = widget.selected;
  String _filter = '';

  /// Takes a picture from anywhere and puts it where the engine looks.
  ///
  /// **The same thing the game's own CUSTOM button does**, which is why it
  /// needs no new field, flag or code path: the file lands in
  /// `<user data>/portraits/` under a name the CRE resrefs can reach, and
  /// shadows any packed portrait of that name.
  Future<void> _addOne() async {
    // Not filtered to `.bmp`. A player who picks a JPEG has to be *told* what
    // is wrong with it — a file dialog that silently cannot see their picture
    // teaches them nothing.
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Images',
          extensions: ['bmp', 'png', 'jpg', 'jpeg', 'gif', 'webp'],
        ),
      ],
    );
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => _AddPortraitDialog(
        importer: ref.read(portraitImportServiceProvider),
        suggestedName: _suggest(file.name),
        bytes: bytes,
      ),
    );
    if (chosen == null || !mounted) return;

    // The picker reads the folder through the resource repository, so the new
    // portrait only appears once that list is re-read.
    ref.invalidate(portraitNamesProvider);
    setState(() => _chosen = chosen);
  }

  /// A first guess at a name, from the file the player picked.
  static String _suggest(String fileName) {
    final stem = fileName.split('.').first.toUpperCase();
    final kept = stem.replaceAll(RegExp('[^A-Z0-9_]'), '');
    const limit = PortraitImportService.baseNameLimit;
    return kept.length > limit ? kept.substring(0, limit) : kept;
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(portraitNamesProvider);

    return AlertDialog(
      title: const Text('Choose a portrait'),
      content: SizedBox(
        width: 640,
        height: 520,
        child: Column(
          children: [
            // Both controls act on the *list*, so they sit together above it
            // — where the dialog's actions below act on the choice.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    onChanged: (value) =>
                        setState(() => _filter = value.trim().toUpperCase()),
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _addOne,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add a portrait…'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: names.when(
                data: (all) => _PortraitGrid(
                  names: [
                    for (final name in all)
                      if (_filter.isEmpty || name.contains(_filter)) name,
                  ],
                  chosen: _chosen,
                  onChoose: (name) => setState(() => _chosen = name),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('$error')),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _chosen == null
              ? null
              : () => Navigator.of(context).pop(_chosen),
          child: const Text('Use this portrait'),
        ),
      ],
    );
  }
}

/// Asks what to call an imported portrait, and says what was actually read.
///
/// ⚠️ **Explains rather than refuses.** The only hard rule is the name; the
/// picture's depth, compression and size are *reported* and allowed, because
/// the game's own 210 portraits include eleven off-size ones, a 32-bit one and
/// an 8-bit one. A check stricter than the engine refuses files the engine
/// would happily draw.
class _AddPortraitDialog extends StatefulWidget {
  const _AddPortraitDialog({
    required this.importer,
    required this.suggestedName,
    required this.bytes,
  });

  final PortraitImportService importer;
  final String suggestedName;
  final Uint8List bytes;

  @override
  State<_AddPortraitDialog> createState() => _AddPortraitDialogState();
}

class _AddPortraitDialogState extends State<_AddPortraitDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.suggestedName,
  );
  late final BitmapInfo? _info = BitmapInfo.parse(widget.bytes);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    final problem = widget.importer.nameProblem(name);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    await widget.importer.add(baseName: name, bytes: widget.bytes);
    if (mounted) Navigator.of(context).pop(name.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _info;

    return AlertDialog(
      title: const Text('Add a portrait'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The picture is copied into the game’s portraits folder, where '
              'the engine looks before its own archives. It is used for both '
              'sizes a character record names.',
            ),
            const SizedBox(height: 16),
            if (info == null)
              _Note(
                icon: Icons.error_outline,
                colour: theme.colorScheme.error,
                // Named precisely, because there is no converter here and the
                // player has to be able to fix it themselves.
                text:
                    'This is not a BMP. The game reads Windows bitmaps only — '
                    'any image editor will save one.',
              )
            else ...[
              _Note(
                icon: Icons.image_outlined,
                colour: theme.colorScheme.onSurfaceVariant,
                text: info.description,
              ),
              if (!info.isConventionalSize)
                _Note(
                  icon: Icons.info_outline,
                  colour: theme.colorScheme.onSurfaceVariant,
                  text:
                      'Portraits are usually 169 × 266 or 210 × 330. This one '
                      'is not, which the game allows — several of its own are '
                      'odd sizes too.',
                ),
              if (!info.isConventionalFormat)
                _Note(
                  icon: Icons.info_outline,
                  colour: theme.colorScheme.onSurfaceVariant,
                  text:
                      'Portraits are usually 24-bit and uncompressed. This one '
                      'is not, which the game also allows — one of its own is '
                      '32-bit and another is 8-bit.',
                ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Name',
                helperText:
                    'Up to seven characters. The game adds its own letter for '
                    'each size.',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // ⚠️ Only the *name* can disable this. A picture the engine would
          // draw is a picture this app accepts.
          onPressed: info == null ? null : _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.colour, required this.text});

  final IconData icon;
  final Color colour;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colour),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortraitGrid extends StatelessWidget {
  const _PortraitGrid({
    required this.names,
    required this.chosen,
    required this.onChoose,
  });

  final List<String> names;
  final String? chosen;
  final void Function(String) onChoose;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return const Center(
        child: Text(
          'No portraits found. They come from the game’s own archives, so '
          'this is what a machine with no Baldur’s Gate installed shows.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        // The game's own M portrait, so a picture sits at its native shape.
        childAspectRatio: 169 / 266,
      ),
      itemCount: names.length,
      itemBuilder: (context, index) => _PortraitTile(
        name: names[index],
        chosen: names[index] == chosen,
        onChoose: () => onChoose(names[index]),
      ),
    );
  }
}

class _PortraitTile extends StatelessWidget {
  const _PortraitTile({
    required this.name,
    required this.chosen,
    required this.onChoose,
  });

  final String name;
  final bool chosen;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onChoose,
      child: Container(
        // A frame in the foreground, both states the same width, so nothing
        // shifts as the choice moves.
        foregroundDecoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          border: Border.all(
            color: chosen ? colors.primary : colors.outlineVariant,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PortraitImage(baseName: name, iconSize: 24),
              // ⚠️ **Named, not just pictured.** The game's own picker shows
              // bare faces, but it has no search box; this one does, which
              // means names are how a player finds a portrait. And on a
              // machine with no game installed every tile is the same
              // placeholder — an unlabelled grid there says nothing at all.
              Align(
                alignment: Alignment.bottomCenter,
                child: ColoredBox(
                  color: colors.scrim.withValues(alpha: 0.7),
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
