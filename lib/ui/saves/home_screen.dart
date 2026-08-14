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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/config/router.dart';
import 'package:wand_of_saves/domain/character_file.dart';
import 'package:wand_of_saves/domain/document_ref.dart';
import 'package:wand_of_saves/domain/rules/character_sheet.dart';
import 'package:wand_of_saves/domain/save_slot.dart';
import 'package:wand_of_saves/ui/character/portrait_image.dart';
import 'package:wand_of_saves/ui/core/palette_finish.dart';
import 'package:wand_of_saves/ui/grid_spikes/g1_two_benches.dart';
import 'package:wand_of_saves/ui/grid_spikes/g2_ledger_grid.dart';
import 'package:wand_of_saves/ui/saves/save_browser_viewmodel.dart';

/// The lineup — the application's front door, and the Workbench structure D15
/// chose.
///
/// Paired 1:1 with [SaveBrowserViewModel]. Every piece below is its own widget
/// class rather than a `_buildX()` helper: helpers cannot be `const`, so they
/// rebuild with their parent, and they never appear in the widget inspector.
///
/// **Two sections, because there are two documents.** A savegame holds a party;
/// a `.chr` holds one character and need never have come from a savegame at
/// all. Presenting characters as a detail of a saves browser would misstate
/// what they are.
///
/// ⚠️ **One column, and every card is a row.** The screen this replaced laid
/// both sections out as responsive grids — column arithmetic against a
/// `SliverLayoutBuilder`, one minimum card width per section, and a stated text
/// budget per card because a grid has to size a cell before its children are
/// laid out. All of that existed to make a card *narrow*, and a narrow card is
/// what truncated a class name to `Fighter / Mag…` and an ability label to
/// `Exceptional stre…`. A full-width row has room for the picture beside the
/// words and needs no arithmetic, no breakpoints and no budget.
class HomeScreen extends ConsumerWidget {
  /// Creates the lineup.
  const HomeScreen({super.key});

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
      appBar: selection.isSelecting && state != null
          ? _SelectionBar(
              state: state,
              selected: selection.selected,
              notifier: notifier,
            )
          : AppBar(
              // ⚠️ **No title, because the window already carries one.** The
              // desktop's own title bar says *Wand of Saves* directly above
              // this, so naming the app again cost a line and said nothing. The
              // other screens name the *document* — `Arduin Start`,
              // `Arduin.chr` — which the window bar cannot.
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
                const SizedBox(width: 8),
              ],
            ),
      body: browser.when(
        // ⚠️ **No "nothing found" branch, deliberately.** There used to be one
        // for both lists empty, and it replaced the whole screen — including
        // the ＋ card, which lives *inside* the characters section. So an app
        // emptied of saves and characters offered no way to make one, which is
        // a state this app can put itself in. Each section says its own piece.
        data: (found) => _Sections(
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
///
/// ⚠️ **The spike's two menu items are not here, because both did nothing.**
/// `Open a character file…` and `Open a savegame…` were `onPressed: () {}` in
/// the spike, which is fine in a spike and is a dead control in an
/// application. What the menu carries instead is the one command that is real
/// and does not belong on the bar.
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

/// Characters above saves, each headed and each explained in one line.
///
/// **Both headings stay when their section is empty.** A Characters heading
/// that appears only once a character exists is a feature nobody discovers —
/// and the empty line under it is where the ＋ card lives.
class _Sections extends StatefulWidget {
  const _Sections({
    required this.state,
    required this.selection,
    required this.notifier,
  });

  final BrowserState state;
  final DocumentSelectionState selection;
  final SaveBrowserViewModel notifier;

  @override
  State<_Sections> createState() => _SectionsState();
}

class _SectionsState extends State<_Sections> {
  // ⚠️ On desktop a vertical scroll view does not attach itself to the
  // PrimaryScrollController, so the theme's always-visible Scrollbar must
  // share a controller with the scroll view it measures — without one it
  // has no position and asserts on the first frame.
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The widest the column runs before it stops growing with the window.
  ///
  /// The spike's own number. Not a breakpoint and not a column count — past
  /// this a card only gets emptier, and a line of prose gets harder to read.
  static const double _measure = 1180;

  /// ⚠️ **Two widths, because the two pictures are different sizes.** A
  /// character card carries an 84 × 132 portrait and a save card a 239 × 180
  /// screenshot, so one shared width would either crush the save or strand the
  /// character in whitespace. Each is picked to fit a whole number of cards
  /// across [_measure] with the 12-point gaps: three characters, two saves.
  static const double _characterCardWidth = 380;
  static const double _saveCardWidth = 578;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final selection = widget.selection;
    final notifier = widget.notifier;
    final selecting = selection.isSelecting;

    return Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _measure),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionHeading(
                  title: 'Characters',
                  note:
                      'Each character is its own document. Open one to edit '
                      'it — it need never have come from a savegame.',
                ),
                if (state.characters.isEmpty && !selecting)
                  const _SectionEmpty(
                    'No characters yet. The game writes these from the Record '
                    'screen’s EXPORT button — or make one with the ＋ card.',
                  ),
                // ⚠️ **Horizontal within the group, vertical between groups.**
                // The sheet is one column because a record reads top to bottom;
                // a *lineup* does not. `Wrap` rather than a scrolling shelf so
                // nothing is hidden off the right edge — a document you cannot
                // see is one you cannot open.
                _CardRow(
                  width: _characterCardWidth,
                  children: [
                    for (final file in state.characters)
                      _CharacterCard(
                        file: file,
                        selecting: selecting,
                        selected: selection.selected.contains(
                          CharacterRef(file.fileName),
                        ),
                        onToggle: () =>
                            notifier.toggle(CharacterRef(file.fileName)),
                      ),
                    // ⚠️ **Last, and absent during selection.** Creating a
                    // character *is* filling an empty slot, which is how the
                    // game presents it too — and there is nothing to tick on a
                    // card that is not a document.
                    if (!selecting) const _NewCharacterCard(),
                  ],
                ),
                const SizedBox(height: 36),
                const _SectionHeading(
                  title: 'Saves',
                  note:
                      'A savegame is a party, not a document. Open one to '
                      'edit whoever is in it.',
                ),
                if (state.saves.isEmpty)
                  const _SectionEmpty(
                    'No Baldur’s Gate saves found. Set BGEE_SAVE_DIR if the '
                    'game lives somewhere unusual.',
                  ),
                _CardRow(
                  width: _saveCardWidth,
                  children: [
                    for (final slot in state.saves)
                      _SaveCard(
                        slot: slot,
                        selecting: selecting,
                        selected: selection.selected.contains(
                          SaveRef(slot.directoryName),
                        ),
                        onToggle: () =>
                            notifier.toggle(SaveRef(slot.directoryName)),
                      ),
                  ],
                ),
                if (kDebugMode && state.saves.isNotEmpty) ...[
                  const SizedBox(height: 36),
                  _LayoutSpikes(slot: state.saves.first),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ⚠️ **THROWAWAY, and the only production surface the grid spikes touch.**
/// Two buttons opening the two arrangements of `planning/tool-first-study.md`,
/// so D19 can be closed by looking at them. Guarded by [kDebugMode]: a release
/// build draws nothing here, and the whole block goes when D19 does.
///
/// ⚠️ **It opens the most recently modified save**, which is [slot] — the
/// browser already sorts that way, and it is the six-member party the study
/// asks for. Named on the row, so it is never a guess which file is open.
class _LayoutSpikes extends StatelessWidget {
  const _LayoutSpikes({required this.slot});

  /// The save both spikes open.
  final SaveSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Layout spikes', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Debug only. Two grid arrangements of the merged character and '
          'inventory page, over ${slot.label}.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      G1TwoBenches(slotDirectoryName: slot.directoryName),
                ),
              ),
              child: const Text('G1 — Two benches'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      G2LedgerGrid(slotDirectoryName: slot.directoryName),
                ),
              ),
              child: const Text('G2 — Ledger grid'),
            ),
          ],
        ),
      ],
    );
  }
}

/// One group's cards, flowing across and wrapping rather than stacking.
///
/// ⚠️ **A fixed card width is a deliberate choice and it has a cost.** `Wrap`
/// neither justifies nor stretches, so a row that does not divide evenly leaves
/// its remainder as slack on the right — the same effect the UI review measured
/// at 19.3 % on the old stat grid. It is acceptable here and was not there,
/// because these are a handful of large cards rather than fifty small ones, and
/// because the alternative is a card whose picture resizes with the window.
class _CardRow extends StatelessWidget {
  const _CardRow({required this.width, required this.children});

  /// How wide each card is.
  final double width;

  /// The cards, in the order they should be read.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      ),
    );
  }
}

/// A section's name and the one line that says what the section is.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.note});

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            note,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A card that can be ticked, and otherwise behaves as it always did.
///
/// One wrapper for both sections, because **one selection spans both** — two
/// implementations would be two chances for a tick box to mean something
/// slightly different on one of them.
///
/// The tick box is a **leading** child rather than a corner overlay. On the
/// grid this replaced the card had a height the grid had already computed, so a
/// `Stack` could fill it; a row card is as tall as its contents, and a stack
/// over that either clips the box or stretches the card.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.selecting,
    required this.selected,
    required this.onOpen,
    required this.onToggle,
    required this.label,
    required this.picture,
    required this.details,
  });

  final bool selecting;
  final bool selected;

  /// What a tap does outside selection.
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  /// What a screen reader is told the whole card is.
  final String label;

  /// The picture on the left, at whatever size it states.
  final Widget picture;

  /// The words beside it.
  final Widget details;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      // The tick alone is a small target on a large card, so the selected
      // state is also said in colour — the same information twice, which is
      // what M3's selected containers are for.
      color: selecting && selected ? colors.secondaryContainer : null,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          // ⚠️ Outside selection a card opens. Changing what a tap means is
          // the whole hazard of a selection mode, so the mode is explicit and
          // the ordinary behaviour is untouched.
          onTap: selecting ? onToggle : onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selecting) ...[
                  Checkbox(value: selected, onChanged: (_) => onToggle()),
                  const SizedBox(width: 12),
                ],
                picture,
                const SizedBox(width: 16),
                Expanded(child: details),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One exported character.
///
/// A `ConsumerWidget` because the identity — class, kit, race, alignment — is
/// the rules layer's to phrase, exactly as it is on the character sheet.
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

  /// The game's own medium portrait, 84 × 132.
  ///
  /// Stated at the picture's native size rather than derived from the card:
  /// a portrait is taller than it is wide, and a row card has no shape of its
  /// own to hand it.
  static const double _portraitWidth = 84;
  static const double _portraitHeight = 132;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sheet = CharacterSheet(
      character: file.character,
      rules: ref.watch(gameRulesProvider),
    );

    return _DocumentCard(
      selecting: selecting,
      selected: selected,
      onOpen: () => context.go(Routes.characterFor(file.fileName)),
      onToggle: onToggle,
      label: '${file.character.name}, ${file.fileName}',
      picture: SizedBox(
        width: _portraitWidth,
        height: _portraitHeight,
        child: ClipRRect(
          // The corner is asked for, not stated: a palette that squares its
          // edges squares this too.
          borderRadius: PaletteFinish.of(context).radiusOf(6),
          child: PortraitImage(baseName: file.character.portraitBaseName),
        ),
      ),
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(file.character.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            'Level ${sheet.levelLabel}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          // ⚠️ A kit **replaces** the class name rather than qualifying it, so
          // a Swashbuckler's chip reads `Swashbuckler` and the word `Thief`
          // appears nowhere. That is what the game's own record screen does.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final fact in _factsOf(sheet))
                Chip(
                  label: Text(fact),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          // ⚠️ **Only when it differs from the character's own name.** The
          // file's name is *not* the character's — `Aard1.chr` holds a
          // character called `Aard`, and a player with two exports of one
          // character has only this to tell them apart — but the common case is
          // that they match, and then this card spent its last line repeating
          // its first.
          if (file.label != file.character.name) ...[
            const SizedBox(height: 12),
            Text(
              file.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The identity, one chip per fact.
  ///
  /// ⚠️ **Split back out of the rules layer's own sentence**, rather than
  /// rebuilt from `GameRules` here. `CharacterSheet.identity` joins gender,
  /// race, class-or-kit and alignment with this exact separator, leaving out
  /// anything the tables cannot name; composing the list a second time in the
  /// UI would be two places that decide which facts a character has and in
  /// what order — and the sheet's doc comment says that decision is the rules
  /// layer's. An installation that can name none of them yields no chips
  /// rather than one empty one.
  static List<String> _factsOf(CharacterSheet sheet) => [
    for (final fact in sheet.identity.split(' · '))
      if (fact.isNotEmpty) fact,
  ];
}

/// The empty slot that makes a character.
///
/// **Portrait first, and that order is the point.** Choosing a face is what
/// starts a character in BG:EE's own flow, and it is the only part of one that
/// cannot be derived from anything else.
class _NewCharacterCard extends StatelessWidget {
  const _NewCharacterCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // ⚠️ **An explicit border, not the theme's.** An empty slot with the same
    // edge as a document does not read as something you press — and the very
    // first defect a capture caught in this project was an invisible outline
    // on these cards.
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: PaletteFinish.of(context).radiusOf(16),
        side: BorderSide(color: colors.primary, width: 1.5),
      ),
      child: InkWell(
        onTap: () => context.go(Routes.newCharacterPath),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.add, size: 32, color: colors.primary),
              const SizedBox(width: 16),
              Text(
                'New character',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One savegame.
class _SaveCard extends StatelessWidget {
  const _SaveCard({
    required this.slot,
    required this.selecting,
    required this.selected,
    required this.onToggle,
  });

  final SaveSlot slot;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;

  /// The screenshot the engine writes, at the size it writes it: 239 × 180.
  static const double _shotWidth = 239;
  static const double _shotHeight = 180;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final party = slot.partySize == 1
        ? '1 character'
        : '${slot.partySize} characters';

    return _DocumentCard(
      selecting: selecting,
      selected: selected,
      onOpen: () => context.go(Routes.partyFor(slot.directoryName)),
      onToggle: onToggle,
      label: '${slot.label}, $party',
      picture: SizedBox(
        width: _shotWidth,
        height: _shotHeight,
        child: ClipRRect(
          borderRadius: PaletteFinish.of(context).radiusOf(6),
          child: _SaveScreenshot(path: slot.screenshotPath),
        ),
      ),
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(slot.label, style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            '$party · ${slot.gold} gold',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${slot.area} · ${slot.hoursPlayed.toStringAsFixed(1)} h',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
    final path = this.path;
    // ⚠️ **Absent and unreadable are drawn differently, because they are
    // different facts.** Both used to get the "image not supported" icon,
    // which announces a failure — and a save with no screenshot is not a
    // failure. Two of the developer's own saves have no `BALDUR.bmp` at all.
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
      // ⚠️ **The field rung, not the card's own.** A placeholder painted the
      // same colour as the card it sits inside is invisible in exactly the
      // place it is needed, which is the defect the theme's surface ladder
      // exists to state.
      color: theme.colorScheme.surfaceContainerHigh,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: theme.colorScheme.outline),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when neither directory could be read at all.
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
