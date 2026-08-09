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
import 'package:wand_of_saves/config/providers.dart';
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
            TextField(
              autofocus: true,
              onChanged: (value) =>
                  setState(() => _filter = value.trim().toUpperCase()),
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
              ),
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
          child: Tooltip(
            message: name,
            child: PortraitImage(baseName: name, iconSize: 24),
          ),
        ),
      ),
    );
  }
}
