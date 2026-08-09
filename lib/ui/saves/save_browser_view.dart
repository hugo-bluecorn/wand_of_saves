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
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/config/router.dart';
import 'package:wand_of_saves/data/repositories/character_file_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/character_file.dart';
import 'package:wand_of_saves/domain/document_ref.dart';
import 'package:wand_of_saves/domain/rules/character_sheet.dart';
import 'package:wand_of_saves/domain/save_slot.dart';
import 'package:wand_of_saves/ui/character/portrait_image.dart';
import 'package:wand_of_saves/ui/character/portrait_picker.dart';
import 'package:wand_of_saves/ui/saves/save_browser_viewmodel.dart';

/// The home screen: the two kinds of document this app opens.
///
/// Paired 1:1 with [SaveBrowserViewModel]. Every piece below is its own widget
/// class rather than a `_buildX()` helper: helpers cannot be `const`, so they
/// rebuild with their parent, and they never appear in the widget inspector.
///
/// **Two sections, because there are two documents.** A savegame holds a party;
/// a `.chr` holds one character and need never have come from a savegame at
/// all. Presenting characters as a detail of the saves browser would misstate
/// what they are.
class SaveBrowserView extends ConsumerWidget {
  /// Creates the home screen.
  const SaveBrowserView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browser = ref.watch(saveBrowserProvider);

    final state = browser.value;
    final notifier = ref.read(saveBrowserProvider.notifier);
    // ⚠️ **Watched here, not folded into `BrowserState`.** Selection changes on
    // every tap; the lists change when a file does. Deriving one from the other
    // would put the whole screen through an async rebuild each tick.
    final selection = ref.watch(documentSelectionProvider);

    return Scaffold(
      appBar: selection.isSelecting
          ? _SelectionBar(
              state: state!,
              selected: selection.selected,
              notifier: notifier,
            )
          : AppBar(
              title: const Text('Wand of Saves'),
              actions: [
                IconButton(
                  onPressed: notifier.refresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Look again',
                ),
                IconButton(
                  onPressed: (state?.isEmpty ?? true)
                      ? null
                      : notifier.startSelecting,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete saves or characters',
                ),
                _OverflowMenu(
                  hasDeleted: state?.hasDeleted ?? false,
                  notifier: notifier,
                ),
              ],
            ),
      body: browser.when(
        data: (found) => found.isEmpty
            ? const _NothingFound()
            : _Sections(
                state: found,
                selection: selection,
                notifier: notifier,
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadFailed(error: error),
      ),
    );
  }
}

/// The app bar while cards are being ticked.
///
/// **Contextual, and it says the count.** A dialog asking "are you sure?" is
/// one nobody reads; a bar that says how many are ticked, beside a Delete that
/// then lists them by name, is one that can actually be checked.
class _SelectionBar extends StatelessWidget implements PreferredSizeWidget {
  const _SelectionBar({
    required this.state,
    required this.selected,
    required this.notifier,
  });

  final BrowserState state;
  final Set<DocumentRef> selected;
  final SaveBrowserViewModel notifier;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final count = selected.length;

    return AppBar(
      leading: IconButton(
        onPressed: notifier.cancelSelection,
        icon: const Icon(Icons.close),
        tooltip: 'Cancel',
      ),
      title: Text(count == 1 ? '1 selected' : '$count selected'),
      actions: [
        FilledButton.icon(
          onPressed: count == 0
              ? null
              : () => _confirm(context, state, selected, notifier),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  static Future<void> _confirm(
    BuildContext context,
    BrowserState state,
    Set<DocumentRef> selected,
    SaveBrowserViewModel notifier,
  ) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _ConfirmDeleteDialog(state: state, selected: selected),
    );
    if (go ?? false) await notifier.deleteSelected();
  }
}

/// Names what will move, and where, rather than asking "are you sure?".
class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.state, required this.selected});

  final BrowserState state;
  final Set<DocumentRef> selected;

  @override
  Widget build(BuildContext context) {
    final saves = state.selectedSaveLabels(selected);
    final characters = state.selectedCharacterNames(selected);

    return AlertDialog(
      title: const Text('Delete these?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️ Says "moved", because that is what happens. Telling a player
          // their save was deleted when it was moved is as wrong as the
          // reverse, and the difference is the whole point of this design.
          const Text(
            'Nothing is erased. These move to a “deleted” folder beside your '
            'saves, where the game will not see them, and you can move them '
            'back at any time.',
          ),
          if (saves.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DeleteList(title: 'Saves', items: saves),
          ],
          if (characters.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DeleteList(title: 'Characters', items: characters),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _DeleteList extends StatelessWidget {
  const _DeleteList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        for (final item in items) Text('· $item'),
      ],
    );
  }
}

/// The commands that are not everyday ones.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.hasDeleted, required this.notifier});

  final bool hasDeleted;
  final SaveBrowserViewModel notifier;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) => IconButton(
        onPressed: controller.isOpen ? controller.close : controller.open,
        icon: const Icon(Icons.more_vert),
        tooltip: 'More',
      ),
      menuChildren: [
        MenuItemButton(
          // ⚠️ Offered only when there is something to empty. An irreversible
          // command that does nothing is worse than an absent one.
          onPressed: hasDeleted ? () => _confirmEmpty(context, notifier) : null,
          child: const Text('Empty deleted items…'),
        ),
      ],
    );
  }

  static Future<void> _confirmEmpty(
    BuildContext context,
    SaveBrowserViewModel notifier,
  ) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty deleted items?'),
        // ⚠️ The only place in this application where this sentence is true,
        // which is why it is said plainly here and nowhere else.
        content: const Text(
          'This erases everything in the “deleted” folder for good. It is the '
          'one thing in this app that cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep them'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Erase for good'),
          ),
        ],
      ),
    );
    if (go ?? false) await notifier.emptyDeleted();
  }
}

/// Characters above saves, each with a heading of its own.
///
/// **Both headings stay when their section is empty.** A Characters heading
/// that appears only once a character exists is a feature nobody discovers —
/// and the empty line under it is where the `+` card will live.
class _Sections extends StatelessWidget {
  const _Sections({
    required this.state,
    required this.selection,
    required this.notifier,
  });

  final BrowserState state;
  final DocumentSelectionState selection;
  final SaveBrowserViewModel notifier;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const _SectionHeading('Characters'),
        if (state.characters.isEmpty && !selection.isSelecting)
          const _SectionEmpty(
            'No characters yet. The game writes these from the Record '
            'screen’s EXPORT button — or make one with the ＋ card.',
          ),
        if (!(state.characters.isEmpty && selection.isSelecting))
          _CardGrid(
            // A portrait is taller than it is wide, unlike a screenshot, so a
            // character card is narrower and taller than a save card. Both
            // numbers are the game's own M portrait, 169x266 -- at that width
            // the card holds the picture at its native size instead of
            // stretching a small image across a save-sized card.
            aspectRatio: 169 / 266,
            minimumCardWidth: 169,
            textBlockHeight: 108,
            // One past the end: the trailing card is the ＋. It is part of the
            // lineup rather than a button elsewhere because creating a
            // character *is* filling an empty slot, which is how the game
            // presents it too.
            childCount:
                state.characters.length + (selection.isSelecting ? 0 : 1),
            itemBuilder: (context, index) {
              if (index == state.characters.length) {
                return const _NewCharacterCard();
              }
              final file = state.characters[index];
              final document = CharacterRef(file.fileName);
              return _CharacterCard(
                file: file,
                selecting: selection.isSelecting,
                selected: selection.selected.contains(document),
                onToggle: () => notifier.toggle(document),
              );
            },
          ),
        const _SectionHeading('Saves'),
        if (state.saves.isEmpty)
          const _SectionEmpty(
            'No Baldur’s Gate saves found. Set BGEE_SAVE_DIR if the game '
            'lives somewhere unusual.',
          )
        else
          _CardGrid(
            // The 4:3-ish screenshot the game writes beside each save.
            aspectRatio: 239 / 180,
            textBlockHeight: 88,
            childCount: state.saves.length,
            itemBuilder: (context, index) {
              final slot = state.saves[index];
              final document = SaveRef(slot.directoryName);
              return _SaveSlotCard(
                slot: slot,
                selecting: selection.isSelecting,
                selected: selection.selected.contains(document),
                onToggle: () => notifier.toggle(document),
              );
            },
          ),
        // Breathing room under the last row, which a grid does not provide.
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A grid of cards sized to the window, as a sliver.
///
/// **A sliver rather than a `GridView`**, because two of these share one
/// scroll view. A `GridView` owns a viewport, so nesting one needs `shrinkWrap`
/// and `NeverScrollableScrollPhysics` — which builds every card at once and
/// throws away the laziness the widget exists for.
///
/// [SliverLayoutBuilder] supplies the cross-axis extent that a `LayoutBuilder`
/// used to; the column arithmetic below is unchanged.
class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.aspectRatio,
    required this.childCount,
    required this.itemBuilder,
    required this.textBlockHeight,
    this.minimumCardWidth = 280,
  });

  /// Width over height of the picture at the top of each card.
  final double aspectRatio;

  /// The narrowest a card may be before the column count drops.
  ///
  /// Per section, because the two pictures are different shapes: a save's
  /// screenshot is wider than it is tall and a portrait is the reverse, so one
  /// width for both makes one of them wrong.
  final double minimumCardWidth;

  /// Height of the text under the picture.
  ///
  /// Stated rather than derived: the grid has to size a card before its
  /// children are laid out, so this counts the lines each card actually draws.
  /// A save card writes a title and two detail lines; a character card writes a
  /// title, an identity that may wrap to two, and the file's own name.
  final double textBlockHeight;

  final int childCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  /// Padding around the grid, and the gap between cards.
  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        // Cards keep a readable width instead of stretching across a desktop
        // window; the column count follows the space available.
        final columns = (constraints.crossAxisExtent ~/ minimumCardWidth).clamp(
          1,
          8,
        );
        final cardWidth =
            (constraints.crossAxisExtent - 2 * _gap - (columns - 1) * _gap) /
            columns;

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(_gap, _gap, _gap, 0),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: _gap,
              crossAxisSpacing: _gap,
              // Height is the picture plus the text block, rather than a
              // guessed ratio -- the first attempt left a visible gap under
              // every card.
              mainAxisExtent: cardWidth / aspectRatio + textBlockHeight,
            ),
            itemCount: childCount,
            itemBuilder: itemBuilder,
          ),
        );
      },
    );
  }
}

class _SaveSlotCard extends StatelessWidget {
  const _SaveSlotCard({
    required this.slot,
    required this.selecting,
    required this.selected,
    required this.onToggle,
  });

  final SaveSlot slot;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SelectableCard(
      selecting: selecting,
      selected: selected,
      // ⚠️ Outside selection a card behaves exactly as it always did: click
      // opens it. Changing what a tap means is the whole hazard of a selection
      // mode, so the mode is explicit and the ordinary behaviour is untouched.
      onOpen: () => context.go(Routes.partyFor(slot.directoryName)),
      onToggle: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ⚠️ **Expanded, not a fixed aspect ratio.** The grid sizes a card
          // from the picture's shape plus a text budget, and a picture that
          // insists on its own height makes the Column overflow the moment the
          // text needs one pixel more than budgeted -- which a different font,
          // a longer label or a larger text scale all cause. Yielding the
          // space is the only version that cannot overflow.
          Expanded(child: _SaveScreenshot(path: slot.screenshotPath)),
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
    );
  }
}

/// A card that can be ticked, and otherwise behaves as it always did.
///
/// One wrapper for both sections, because **one selection spans both** — two
/// implementations would be two chances for a tick box to mean something
/// slightly different on one of them.
class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selecting,
    required this.selected,
    required this.onOpen,
    required this.onToggle,
    required this.child,
  });

  final bool selecting;
  final bool selected;

  /// What a tap does outside selection. `null` for a card nothing opens yet.
  final VoidCallback? onOpen;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card.filled(
      clipBehavior: Clip.antiAlias,
      // The tick alone is a small target on a large card, so the selected
      // state is also said in colour -- the same information twice, which is
      // what M3's selected containers are for.
      color: selecting && selected ? colors.secondaryContainer : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InkWell(onTap: selecting ? onToggle : onOpen, child: child),
          if (selecting)
            Positioned(
              top: 4,
              right: 4,
              child: Checkbox(
                value: selected,
                onChanged: (_) => onToggle(),
              ),
            ),
        ],
      ),
    );
  }
}

/// One exported character.
///
/// A `ConsumerWidget` because the identity line — class, kit, race, alignment —
/// is the rules layer's to phrase, exactly as it is on the character sheet.
/// Showing raw `CLASS.IDS` numbers would be worse than showing nothing.
class _CharacterCard extends ConsumerWidget {
  const _CharacterCard({
    required this.file,
    required this.selecting,
    required this.selected,
    required this.onToggle,
  });

  final CharacterFile file;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sheet = CharacterSheet(
      character: file.character,
      rules: ref.watch(gameRulesProvider),
    );

    return _SelectableCard(
      selecting: selecting,
      selected: selected,
      onOpen: () => context.go(Routes.characterFor(file.fileName)),
      onToggle: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PortraitImage(baseName: file.character.portraitBaseName),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.character.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                DefaultTextStyle.merge(
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ⚠️ **The class and the level, not the whole identity
                      // line.** The sheet's `identity` also carries gender,
                      // race and alignment, and a capture showed it truncated
                      // to "Level 1/1 · Male · Elf · Fighter / Mag…" even
                      // across two lines. A card this wide holds a portrait,
                      // so it gets what tells two characters apart; the rest
                      // is one click away. Third time a label in this app has
                      // been too narrow, and all three were invisible to the
                      // suite -- see `dart-toolchain-traps`.
                      Text(
                        [
                          'Level ${sheet.levelLabel}',
                          ?sheet.classOrKitName,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // ⚠️ The file's name, which is *not* the character's:
                      // `Aard1.chr` holds a character called `Aard`, and a
                      // player with two exports of one character has only this
                      // to tell them apart.
                      Text(
                        file.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The empty slot that makes a character.
///
/// **Portrait first, and that order is the point.** Choosing a face is what
/// starts a character in BG:EE's own flow, and it is the only part of one that
/// cannot be derived from anything else — everything after it is the ordinary
/// character sheet.
///
/// Absent during selection: there is nothing to tick on a card that is not a
/// document.
class _NewCharacterCard extends ConsumerWidget {
  const _NewCharacterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    // ⚠️ **An explicit border, not `Card.outlined`.** That constructor's
    // default outline is invisible against this theme -- the very first defect
    // a capture caught in this project, on the save cards. An empty slot with
    // no edge does not read as something you can press.
    return Card.filled(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: colors.primary, width: 1.5),
      ),
      color: colors.surfaceContainerLowest,
      child: InkWell(
        onTap: () => _create(context, ref),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 40, color: colors.primary),
              const SizedBox(height: 8),
              Text(
                'New character',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _create(BuildContext context, WidgetRef ref) async {
    final portrait = await PortraitPicker.show(context);
    if (portrait == null || !context.mounted) return;

    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NewCharacterDialog(),
    );
    if (name == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final created = await ref
          .read(saveBrowserProvider.notifier)
          .createCharacter(
            name: name,
            fileName: '$name${GameProfileService.characterExtension}',
            portraitName: portrait,
          );
      // Straight into the sheet, where class, abilities and the rest are
      // edited like any other character. Nothing else is asked for up front.
      router.go(Routes.characterFor(created.fileName));
    } on CharacterFileExistsException {
      messenger.showSnackBar(
        SnackBar(content: Text('There is already a character called $name')),
      );
    } on NoCharacterTemplateException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Baldur’s Gate does not appear to be installed, so there is no '
            'character template to build from.',
          ),
        ),
      );
    }
  }
}

/// Asks what to call the new character.
///
/// The name is the second and last question: everything else is on the sheet
/// the player lands in.
class _NewCharacterDialog extends StatefulWidget {
  const _NewCharacterDialog();

  @override
  State<_NewCharacterDialog> createState() => _NewCharacterDialogState();
}

class _NewCharacterDialogState extends State<_NewCharacterDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final typed = _controller.text.trim();
    if (typed.isEmpty) {
      setState(() => _error = 'Give the character a name.');
      return;
    }
    if (RegExp(r'[\\/:*?"<>|]').hasMatch(typed)) {
      setState(
        () => _error = r'A name cannot contain \ / : * ? " < > or |.',
      );
      return;
    }
    Navigator.of(context).pop(typed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name your character'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The character is built from the game’s own template, then opens '
            'so you can set class, abilities and the rest.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Name',
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
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

/// The screenshot the game took when the save was written.
///
/// Its own widget because it owns three states — present, absent, unreadable —
/// and a broken image should degrade in one small place rather than in the
/// middle of a card's build. `Image.file` gives us Flutter's image cache, and
/// `dart:ui` decodes BMP natively, so no decoder is needed.
///
/// **Fills whatever box it is given** rather than claiming a shape. The card's
/// height already comes from the game's 239×180, so in the ordinary case this
/// is exactly that; when the text under it wants more room, the picture gives
/// it rather than the card overflowing.
class _SaveScreenshot extends StatelessWidget {
  const _SaveScreenshot({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    // ⚠️ **Absent and unreadable are drawn differently, because they are
    // different facts.** Both used to get the "image not supported" icon, which
    // announces a failure — and a save with no screenshot is not a failure. Two
    // of the developer's own saves have no `BALDUR.bmp` at all (hand-made
    // copies that took the savegame and left the picture), and the card read as
    // broken rather than as plain.
    if (path == null) {
      return const _NoScreenshot(
        icon: Icons.image_outlined,
        label: 'No screenshot',
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, _, _) => const _NoScreenshot(
        icon: Icons.broken_image_outlined,
        label: 'Screenshot unreadable',
      ),
    );
  }
}

/// Where a save's screenshot goes when there is none to draw, or none that
/// will decode.
class _NoScreenshot extends StatelessWidget {
  const _NoScreenshot({required this.icon, required this.label});

  final IconData icon;

  /// Said in words, not only in an icon: an unlabelled symbol on a card is
  /// exactly what made a missing picture look like a bug.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: theme.colorScheme.outline),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
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

/// Shown only when there is neither a save nor a character anywhere.
class _NothingFound extends StatelessWidget {
  const _NothingFound();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No Baldur’s Gate saves or characters found.\n'
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
