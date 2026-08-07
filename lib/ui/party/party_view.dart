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
import 'package:wand_of_saves/domain/ability_scores.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/edit_command.dart';
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
            '${state?.slot.label ?? slotDirectoryName}'
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

class _PartyShell extends StatelessWidget {
  const _PartyShell({required this.state, required this.slotDirectoryName});

  final PartyState state;
  final String slotDirectoryName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PortraitRail(state: state, slotDirectoryName: slotDirectoryName),
        const VerticalDivider(width: 1),
        Expanded(
          child: _CharacterSummary(
            character: state.members[state.selectedIndex],
            slotDirectoryName: slotDirectoryName,
          ),
        ),
      ],
    );
  }
}

/// The party, as the portraits the game itself drew.
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
            icon: _Portrait(path: member.portraitPath),
            selectedIcon: _Portrait(
              path: member.portraitPath,
              selected: true,
            ),
            label: Text(member.name),
          ),
      ],
    );
  }
}

/// One party portrait.
///
/// The game writes `PORTRT<n>.bmp` beside each savegame at 54×84, and
/// `dart:ui` decodes BMP natively — so these are the player's real portraits
/// with no decoder and no resource index behind them. Three states: present,
/// absent, unreadable.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.path, this.selected = false});

  /// The width the game writes.
  static const double width = 54;

  /// The height the game writes.
  static const double height = 84;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(6));

  final String? path;

  /// Whether this is the character on show.
  ///
  /// The rail's own M3 indicator is drawn *behind* the icon, and a portrait is
  /// opaque and fills that space exactly — so it hid the indicator completely
  /// and selection had no visible effect. The frame is drawn here instead.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final path = this.path;

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
        child: path == null
            ? const _NoPortrait()
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => const _NoPortrait(),
              ),
      ),
    );
  }
}

class _NoPortrait extends StatelessWidget {
  const _NoPortrait();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Icon(Icons.person_outline, color: colors.outline),
    );
  }
}

/// Everything the savegame knows about one character.
///
/// Read-only for now. Class, race and alignment are deliberately absent: their
/// *names* live in `CLASS.IDS` and friends inside the game's BIFF archives,
/// which is Phase 3. Showing a raw class number would be worse than showing
/// nothing.
class _CharacterSummary extends ConsumerWidget {
  const _CharacterSummary({
    required this.character,
    required this.slotDirectoryName,
  });

  final Character character;
  final String slotDirectoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    void set(CharacterStat stat, int value) => ref
        .read(partyProvider(slotDirectoryName).notifier)
        .edit(
          SetCharacterStat(
            creOffset: character.creOffset,
            stat: stat,
            value: value,
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(character.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Level ${character.levelLabel}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _StatGroup(
          title: 'Character',
          children: [
            _StatField(
              character: character,
              stat: CharacterStat.currentHitPoints,
              value: character.currentHitPoints,
              label: 'Hit points (base)',
              onCommitted: set,
              // Verified against the game's own portrait overlay: it renders
              // 8/9 where the savegame stores 6/7, and 9/9 where it stores
              // 7/7, at a constant Constitution of 16. The stored field is
              // what an editor edits; saying "base" stops the difference
              // reading as a bug.
              hint:
                  'The savegame stores hit points without the Constitution '
                  'bonus. The game adds that bonus when it displays them, so '
                  'this number is lower than the one on your character sheet.',
            ),
            _StatField(
              character: character,
              stat: CharacterStat.maximumHitPoints,
              value: character.maximumHitPoints,
              label: 'Maximum hit points',
              onCommitted: set,
            ),
            _StatField(
              character: character,
              stat: CharacterStat.experience,
              value: character.experience,
              label: 'Experience',
              onCommitted: set,
            ),
            _StatField(
              character: character,
              stat: CharacterStat.gold,
              value: character.gold,
              label: 'Gold (carried)',
              onCommitted: set,
              hint:
                  'Gold on this character. The shared party purse is stored '
                  'separately and is not this number.',
            ),
            _StatField(
              character: character,
              stat: CharacterStat.thac0,
              value: character.thac0,
              label: 'THAC0',
              onCommitted: set,
            ),
            _StatField(
              character: character,
              stat: CharacterStat.armorClassNatural,
              value: character.armorClassNatural,
              label: 'Armour class (natural)',
              onCommitted: set,
              hint:
                  'Measured in game on 2026-08-07: changing this had no '
                  'visible effect. Kept editable, and recorded as such, until '
                  'we know which field the engine reads.',
            ),
            _StatField(
              character: character,
              stat: CharacterStat.armorClassEffective,
              value: character.armorClass,
              label: 'Armour class (effective)',
              onCommitted: set,
              hint:
                  'What the character defends at before Dexterity is applied. '
                  'Which of the two armour-class fields the game actually '
                  'reads is still being measured.',
            ),
            _ReadOnlyStat(
              label: 'Reputation',
              value: character.reputation.toStringAsFixed(1),
              hint:
                  'Reputation belongs to the party, not to one character. '
                  'This is the copy stored on this creature record, and it '
                  'matches the party’s — so editing it here alone would only '
                  'make the two disagree.',
            ),
          ],
        ),
        const SizedBox(height: 24),
        _StatGroup(
          title: 'Abilities',
          children: [
            for (final (stat, value) in _abilities(character.abilities))
              _StatField(
                character: character,
                stat: stat,
                value: value,
                label: stat.label,
                onCommitted: set,
                // Percentile strength is only meaningful at Strength 18,
                // which is the one place the engine consults it.
                enabled:
                    stat != CharacterStat.strengthBonus ||
                    character.abilities.strength == 18,
              ),
          ],
        ),
      ],
    );
  }

  List<(CharacterStat, int)> _abilities(AbilityScores abilities) => [
    (CharacterStat.strength, abilities.strength),
    (CharacterStat.strengthBonus, abilities.strengthBonus),
    (CharacterStat.dexterity, abilities.dexterity),
    (CharacterStat.constitution, abilities.constitution),
    (CharacterStat.intelligence, abilities.intelligence),
    (CharacterStat.wisdom, abilities.wisdom),
    (CharacterStat.charisma, abilities.charisma),
  ];
}

class _StatGroup extends StatelessWidget {
  const _StatGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: children),
      ],
    );
  }
}

/// Width every stat tile shares, editable or not, so they line up.
///
/// Wide enough for the longest label this screen uses. The first attempt was
/// 148 and truncated "Exceptional strength" and "Armour class (worn)" to
/// ellipses — which mattered more than it sounds, because the two armour-class
/// tiles then both read "Armour class" and nothing distinguished the one you
/// can edit from the one the engine computes.
const double _tileWidth = 190;

/// A number the savegame stores and this build does not offer to change.
///
/// Drawn as a **disabled field**, not as a different kind of tile: the same
/// shape and height as its editable neighbours keeps the rows level, and
/// "greyed out" already reads as "not yours to change" — the disabled
/// exceptional-strength field teaches that vocabulary on the same screen.
///
/// [hint] says *why* it is not editable. A stored value the player cannot
/// reconcile with their game reads as a bug unless the screen explains itself.
class _ReadOnlyStat extends StatelessWidget {
  const _ReadOnlyStat({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    final field = _FieldShell(
      label: label,
      hasHint: hint != null,
      child: TextField(
        controller: TextEditingController(text: value),
        enabled: false,
        decoration: _statDecoration(
          context,
          label: label,
          hasHint: hint != null,
        ),
      ),
    );

    // Tooltip carries its own semantics, so the explanation reaches a screen
    // reader as well as a pointer.
    return hint == null ? field : Tooltip(message: hint, child: field);
  }
}

/// The fixed footprint every stat occupies.
class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.label,
    required this.hasHint,
    required this.child,
  });

  final String label;
  final bool hasHint;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: _tileWidth, child: child);
}

/// The decoration every stat field shares.
InputDecoration _statDecoration(
  BuildContext context, {
  required String label,
  required bool hasHint,
  String? error,
}) => InputDecoration(
  labelText: label,
  filled: true,
  border: const OutlineInputBorder(),
  errorText: error,
  // Reserves the error line so a refused value does not shove every tile
  // below it down the screen.
  helperText: error == null ? ' ' : null,
  suffixIcon: hasHint
      ? Icon(
          Icons.info_outline,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )
      : null,
);

/// One editable number.
///
/// Commits **on Enter and on losing focus**, never per keystroke: a command
/// per character typed would fill the undo stack with fragments of a number
/// and make undo useless.
///
/// Keyed by character and stat, so selecting a different party member builds a
/// fresh field rather than carrying uncommitted text across to someone else.
class _StatField extends StatefulWidget {
  _StatField({
    required this.character,
    required this.stat,
    required this.value,
    required this.label,
    required this.onCommitted,
    this.enabled = true,
    this.hint,
  }) : super(key: ValueKey('${character.creOffset}:${stat.name}'));

  final Character character;
  final CharacterStat stat;
  final int value;
  final String label;
  final void Function(CharacterStat, int) onCommitted;
  final bool enabled;
  final String? hint;

  @override
  State<_StatField> createState() => _StatFieldState();
}

class _StatFieldState extends State<_StatField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );
  final FocusNode _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _StatField old) {
    super.didUpdateWidget(old);
    // Undo, redo and a reload change the value from underneath. Only adopt it
    // while the field is idle, so a number being typed is never yanked away.
    if (widget.value != old.value && !_focus.hasFocus) {
      _controller.text = '${widget.value}';
      _error = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final typed = int.tryParse(_controller.text.trim());
    if (typed == null || !widget.stat.holds(typed)) {
      // Refuse rather than clamp. Silently turning 300 into 25 is the kind of
      // quiet substitution that makes an editor untrustworthy.
      setState(() => _error = '${widget.stat.minimum}–${widget.stat.maximum}');
      return;
    }
    setState(() => _error = null);
    if (typed != widget.value) widget.onCommitted(widget.stat, typed);
  }

  @override
  Widget build(BuildContext context) {
    final field = _FieldShell(
      label: widget.label,
      hasHint: widget.hint != null,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        enabled: widget.enabled,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _commit(),
        decoration: _statDecoration(
          context,
          label: widget.label,
          hasHint: widget.hint != null,
          error: _error,
        ),
      ),
    );

    final hint = widget.hint;
    return hint == null ? field : Tooltip(message: hint, child: field);
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
