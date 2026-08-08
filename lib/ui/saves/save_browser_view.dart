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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wand_of_saves/config/router.dart';
import 'package:wand_of_saves/domain/save_slot.dart';
import 'package:wand_of_saves/ui/saves/save_browser_viewmodel.dart';

/// Lets the player choose a savegame.
///
/// Paired 1:1 with [SaveBrowserViewModel]. Every piece below is its own widget
/// class rather than a `_buildX()` helper: helpers cannot be `const`, so they
/// rebuild with their parent, and they never appear in the widget inspector.
class SaveBrowserView extends ConsumerWidget {
  /// Creates the save browser.
  const SaveBrowserView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(saveBrowserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wand of Saves'),
        actions: [
          IconButton(
            onPressed: () => ref.read(saveBrowserProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Look for saves again',
          ),
        ],
      ),
      body: slots.when(
        data: (found) =>
            found.isEmpty ? const _NoSaves() : _SaveSlotGrid(slots: found),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadFailed(error: error),
      ),
    );
  }
}

class _SaveSlotGrid extends StatelessWidget {
  const _SaveSlotGrid({required this.slots});

  final List<SaveSlot> slots;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Cards keep a readable width instead of stretching across a desktop
        // window; the column count follows the space available.
        final columns = (constraints.maxWidth ~/ 280).clamp(1, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            // Height is the 4:3 screenshot plus the text block, rather than a
            // guessed ratio -- the first attempt left a visible gap under
            // every card.
            mainAxisExtent:
                (constraints.maxWidth - 32 - (columns - 1) * 16) /
                    columns /
                    (239 / 180) +
                88,
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) => _SaveSlotCard(slot: slots[index]),
        );
      },
    );
  }
}

class _SaveSlotCard extends StatelessWidget {
  const _SaveSlotCard({required this.slot});

  final SaveSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card.filled(
      child: InkWell(
        onTap: () => context.go(Routes.partyFor(slot.directoryName)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SaveScreenshot(path: slot.screenshotPath),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.label,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _SaveSlotSummary(slot: slot),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The screenshot the game took when the save was written.
///
/// Its own widget because it owns three states — present, absent, unreadable —
/// and a broken image should degrade in one small place rather than in the
/// middle of a card's build. `Image.file` gives us Flutter's image cache, and
/// `dart:ui` decodes BMP natively, so no decoder is needed.
class _SaveScreenshot extends StatelessWidget {
  const _SaveScreenshot({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    // The game writes 239x180.
    const ratio = 239 / 180;
    final path = this.path;

    if (path == null) return const _NoScreenshot(ratio: ratio);

    return AspectRatio(
      aspectRatio: ratio,
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => const _NoScreenshot(ratio: ratio),
      ),
    );
  }
}

class _NoScreenshot extends StatelessWidget {
  const _NoScreenshot({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: ratio,
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Icon(Icons.image_not_supported_outlined, color: colors.outline),
      ),
    );
  }
}

class _SaveSlotSummary extends StatelessWidget {
  const _SaveSlotSummary({required this.slot});

  final SaveSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final party = slot.partySize == 1 ? '1 character' : '${slot.partySize}';

    return DefaultTextStyle.merge(
      style: theme.textTheme.bodySmall!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${slot.area} · ${slot.hoursPlayed.toStringAsFixed(1)} h'),
          Text('$party · ${slot.gold} gold'),
        ],
      ),
    );
  }
}

class _NoSaves extends StatelessWidget {
  const _NoSaves();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No Baldur’s Gate saves found.\n'
          'Set BGEE_SAVE_DIR if the game lives somewhere unusual.',
          textAlign: TextAlign.center,
        ),
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
