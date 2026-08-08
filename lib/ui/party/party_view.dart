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
import 'package:wand_of_saves/domain/ability_scores.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/edit_command.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/domain/rules/character_sheet.dart';
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
            proficiencies: state.proficiencies,
            reputation: state.reputation,
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
///
/// **The game bakes its own HUD into the picture**, hit points included, so a
/// portrait keeps showing the numbers from the moment the file was saved and
/// will disagree with the pane as soon as anything is edited. That is not a
/// staleness bug to fix — it cannot be repainted, the pixels are the game's —
/// but it does need saying, which is what the tooltip is for. Those same baked
/// numbers are how the Constitution bonus was discovered.
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

    return Tooltip(
      message:
          'The picture the game saved with this file. The hit points drawn on '
          'it are from that moment and do not follow your edits.',
      child: _frame(colors, path),
    );
  }

  Widget _frame(ColorScheme colors, String? path) {
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
    required this.proficiencies,
    required this.reputation,
    required this.slotDirectoryName,
  });

  final Character character;
  final ProficiencyCatalogue proficiencies;

  /// The **party's** reputation — see `PartyState.reputation` for why this is
  /// not the character's own copy.
  final double reputation;

  final String slotDirectoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sheet = CharacterSheet(
      character: character,
      rules: ref.watch(gameRulesProvider),
      proficiencies: proficiencies,
    );

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
          // What BG:EE's own record screen says, in its order.
          [
            'Level ${sheet.levelLabel}',
            if (sheet.identity.isNotEmpty) sheet.identity,
          ].join(' · '),
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
              sheet: sheet,
              stat: CharacterStat.currentHitPoints,
              value: character.currentHitPoints,
              label: 'Current hit points',
              onCommitted: set,
              hint:
                  'What the savegame stores, and what you edit. The game adds '
                  'the Constitution bonus before showing it, and clamps to '
                  'the maximum — the "in game" tile does the same arithmetic.',
            ),
            _StatField(
              character: character,
              sheet: sheet,
              stat: CharacterStat.maximumHitPoints,
              value: character.maximumHitPoints,
              label: 'Maximum hit points',
              onCommitted: set,
            ),
            _StatField(
              character: character,
              sheet: sheet,
              stat: CharacterStat.experience,
              value: character.experience,
              label: 'Experience',
              onCommitted: set,
            ),
            _StatField(
              character: character,
              sheet: sheet,
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
              sheet: sheet,
              stat: CharacterStat.thac0,
              value: character.thac0,
              label: 'THAC0 (base)',
              onCommitted: set,
              hint:
                  'The game calls this "Base THAC0" and shows a second, lower '
                  'number beside it — Strength, Dexterity and weapon '
                  'proficiencies are applied before display, and a Necromancer '
                  'with 20 here reads 20 while a thief with 20 reads 18. '
                  'Working the modified value out needs proficiency data this '
                  'app does not read yet, so only the stored base is shown.',
            ),
            _StatField(
              character: character,
              sheet: sheet,
              stat: CharacterStat.armorClassNatural,
              value: character.armorClassNatural,
              label: 'Armour class (natural)',
              onCommitted: set,
              hint:
                  'Measured twice: changing this alone does not move what the '
                  'game shows. The effective field beside it is the one the '
                  'engine reads. Kept editable because the field is real.',
            ),
            _StatField(
              character: character,
              sheet: sheet,
              stat: CharacterStat.armorClassEffective,
              value: character.armorClass,
              label: 'Armour class (effective)',
              onCommitted: set,
              hint:
                  'What the character defends at before Dexterity is applied, '
                  'and the field the game actually reads — confirmed in game '
                  'by writing a value that could not arise unarmoured.',
            ),
            if (sheet.maximumHitPointsInGame != null)
              _ReadOnlyStat(
                label: 'Hit points (in game)',
                value:
                    '${sheet.currentHitPointsInGame} / '
                    '${sheet.maximumHitPointsInGame}',
                hint:
                    'Stored hit points plus '
                    '${sheet.hitPointBonusPerLevel} per level from '
                    'Constitution ${character.abilities.constitution}, which '
                    'is what the game shows on the character sheet.',
              ),
            if (sheet.armourClassInGame != null)
              _ReadOnlyStat(
                label: 'Armour class (in game)',
                value: sheet.armourClassInGame.toString(),
                hint:
                    'Armour class plus ${sheet.armourClassModifier} from '
                    'Dexterity ${character.abilities.dexterity}. Equipment '
                    'moves it further, and that needs the item records.',
              ),
            _ReadOnlyStat(
              label: 'Reputation (party)',
              value: reputation.toStringAsFixed(1),
              hint:
                  'Reputation belongs to the party, not to one character, and '
                  'this is the party’s — which is the number the game shows. '
                  'Each creature record carries a copy of its own, and on '
                  'everyone but the protagonist it goes stale: this character '
                  'stores ${character.reputation.toStringAsFixed(1)}, and the '
                  'engine ignores it. Measured in game.',
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
                sheet: sheet,
                stat: stat,
                value: value,
                // The modifier goes in the label, so what a score is *worth*
                // sits beside the score instead of only in a tooltip.
                label: _abilityLabel(stat, sheet),
                onCommitted: set,
                // Percentile strength is only meaningful at Strength 18,
                // which is the one place the engine consults it.
                enabled:
                    stat != CharacterStat.strengthBonus ||
                    character.abilities.strength == 18,
              ),
          ],
        ),
        const SizedBox(height: 24),
        _StatGroup(
          title: 'Combat',
          children: [
            for (final (stat, value) in _combat(character))
              _StatField(
                character: character,
                sheet: sheet,
                stat: stat,
                value: value,
                label: stat.label,
                onCommitted: set,
                hint: stat == CharacterStat.saveVersusDeath
                    ? 'The five saving throws are stored exactly as the game '
                          'prints them — nothing is added before display, '
                          'unlike hit points and THAC0. Lower is better.'
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 24),
        _ProficiencyGroup(
          character: character,
          sheet: sheet,
          slotDirectoryName: slotDirectoryName,
        ),
        const SizedBox(height: 24),
        _StatGroup(
          // Named for what they are, because every one of them is a base and
          // the game shows something larger. Saying so once in the title beats
          // repeating "(base)" on nine tiles.
          title: 'Skills — points allocated, not what the game shows',
          children: [
            for (final (stat, value) in _skills(character))
              _StatField(
                character: character,
                sheet: sheet,
                stat: stat,
                value: value,
                label: stat.label,
                onCommitted: set,
                hint: stat == CharacterStat.moveSilently
                    ? 'Measured: a thief storing 15 here has the game show '
                          '35, and two characters both storing Lore 3 show 10 '
                          'and 15. The engine adds class, race and Dexterity '
                          'bonuses. Working the shown figure out needs tables '
                          'this build does not read, so only the stored base '
                          'is offered.'
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 24),
        _StatGroup(
          title: 'Resistances',
          children: [
            for (final (stat, value) in _resistances(character))
              _StatField(
                character: character,
                sheet: sheet,
                stat: stat,
                value: value,
                label: stat.label,
                onCommitted: set,
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// The Combat group, in the order the record screen stacks it.
  List<(CharacterStat, int)> _combat(Character character) {
    final saves = character.savingThrows;
    final modifiers = character.armorClassModifiers;
    return [
      (CharacterStat.saveVersusDeath, saves.death),
      (CharacterStat.saveVersusWands, saves.wands),
      (CharacterStat.saveVersusPolymorph, saves.polymorph),
      (CharacterStat.saveVersusBreath, saves.breath),
      (CharacterStat.saveVersusSpells, saves.spells),
      (CharacterStat.numberOfAttacks, character.numberOfAttacks),
      (CharacterStat.armorClassCrushing, modifiers.crushing),
      (CharacterStat.armorClassMissile, modifiers.missile),
      (CharacterStat.armorClassPiercing, modifiers.piercing),
      (CharacterStat.armorClassSlashing, modifiers.slashing),
      (CharacterStat.morale, character.morale),
      (CharacterStat.moraleBreak, character.moraleBreak),
      (CharacterStat.luck, character.luck),
    ];
  }

  /// The Skills group. Every one of these is a base; see the group's title.
  List<(CharacterStat, int)> _skills(Character character) {
    final skills = character.thiefSkills;
    return [
      (CharacterStat.lore, skills.lore),
      (CharacterStat.lockpicking, skills.lockpicking),
      (CharacterStat.findTraps, skills.findTraps),
      (CharacterStat.pickPockets, skills.pickPockets),
      (CharacterStat.moveSilently, skills.moveSilently),
      (CharacterStat.hideInShadows, skills.hideInShadows),
      (CharacterStat.detectIllusion, skills.detectIllusion),
      (CharacterStat.setTraps, skills.setTraps),
      (CharacterStat.turnUndeadLevel, character.turnUndeadLevel),
      (CharacterStat.trackingSkill, character.trackingSkill),
      (CharacterStat.fatigue, character.fatigue),
      (CharacterStat.intoxication, character.intoxication),
    ];
  }

  /// The eleven resistances, in the order the record stores them.
  ///
  /// Shown unconditionally, like every other group. They were briefly folded
  /// away when all eleven were zero — which is every character in every
  /// fixture — but that was a one-off rather than a rule: Skills shows nine
  /// zeroes on the same character and Combat six. The page *is* too long; the
  /// answer to that is tabbing it, not one collapsible group.
  List<(CharacterStat, int)> _resistances(Character character) {
    final resists = character.resistances;
    return [
      (CharacterStat.resistFire, resists.fire),
      (CharacterStat.resistCold, resists.cold),
      (CharacterStat.resistElectricity, resists.electricity),
      (CharacterStat.resistAcid, resists.acid),
      (CharacterStat.resistMagic, resists.magic),
      (CharacterStat.resistMagicFire, resists.magicFire),
      (CharacterStat.resistMagicCold, resists.magicCold),
      (CharacterStat.resistSlashing, resists.slashing),
      (CharacterStat.resistCrushing, resists.crushing),
      (CharacterStat.resistPiercing, resists.piercing),
      (CharacterStat.resistMissile, resists.missile),
    ];
  }

  /// A stat's label with the modifier the game's tables give it.
  ///
  /// Only the two that this build can look up say anything: Constitution's
  /// hit points per level and Dexterity's armour class. The rest are plain,
  /// rather than implying a modifier of zero where there is simply no table
  /// read yet.
  String _abilityLabel(CharacterStat stat, CharacterSheet sheet) {
    final modifier = switch (stat) {
      CharacterStat.constitution => sheet.hitPointBonusPerLevel,
      CharacterStat.dexterity => sheet.armourClassModifier,
      _ => null,
    };
    if (modifier == null || modifier == 0) return stat.label;
    final sign = modifier > 0 ? '+' : '';
    return '${stat.label}  $sign$modifier';
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

/// The weapons and fighting styles this character has pips in.
///
/// **Only the ones they already have.** Every pip here patches a dword inside
/// an effect the record already holds, which is fixed-width and safe. Granting
/// a proficiency from nothing would add a 264-byte effect and move every
/// offset after it — the layout pass, deliberately deferred — so there is no
/// "add" control, and its absence is explained rather than left to look like
/// an oversight.
class _ProficiencyGroup extends ConsumerWidget {
  const _ProficiencyGroup({
    required this.character,
    required this.sheet,
    required this.slotDirectoryName,
  });

  final Character character;
  final CharacterSheet sheet;
  final String slotDirectoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (character.proficiencies.isEmpty) return const SizedBox.shrink();

    return _StatGroup(
      title: 'Proficiencies',
      children: [
        for (final proficiency in character.proficiencies)
          _PipField(
            key: ValueKey('${character.creOffset}:prof:${proficiency.id}'),
            label: sheet.proficiencyLabel(proficiency.id),
            pips: proficiency.pips,
            maximum: sheet.maximumPipsFor(proficiency.id),
            onCommitted: (pips) => ref
                .read(partyProvider(slotDirectoryName).notifier)
                .edit(
                  SetProficiency(
                    creOffset: character.creOffset,
                    effectOffset: proficiency.effectOffset,
                    proficiencyId: proficiency.id,
                    pips: pips,
                  ),
                ),
          ),
      ],
    );
  }
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
/// Wide enough for the longest label this screen uses, and it has now been
/// too narrow twice — each time caught by looking at the screen rather than by
/// reading the code.
///
/// The first attempt was 148 and truncated "Exceptional strength" and "Armour
/// class (worn)", which mattered more than it sounds: the two armour-class
/// tiles then both read "Armour class" and nothing distinguished the one you
/// can edit from the one the engine computes.
///
/// 190 then truncated **"Paralysis / Poison / Death"** to
/// "Paralysis / Poison / De…". The saving throws are deliberately labelled in
/// BG:EE's own words so a player can hold the two screens side by side, and a
/// label cut off mid-word is exactly the thing that stops working.
const double _tileWidth = 222;

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
    required this.sheet,
    required this.stat,
    required this.value,
    required this.label,
    required this.onCommitted,
    this.enabled = true,
    this.hint,
  }) : super(key: ValueKey('${character.creOffset}:${stat.name}'));

  final Character character;

  /// Where the bounds come from — some depend on another field's value.
  final CharacterSheet sheet;

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

  /// The range this field accepts, as the error line phrases it.
  String get _range =>
      '${widget.sheet.lowerBoundFor(widget.stat)}–'
      '${widget.sheet.upperBoundFor(widget.stat)}';

  void _commit() {
    final typed = int.tryParse(_controller.text.trim());
    if (typed == null || !widget.sheet.isWithinBounds(widget.stat, typed)) {
      // Refuse rather than clamp. Silently turning 300 into 25 is the kind of
      // quiet substitution that makes an editor untrustworthy.
      setState(() => _error = _range);
      return;
    }
    setState(() => _error = null);
    if (typed != widget.value) widget.onCommitted(widget.stat, typed);
  }

  /// The error to show for the value as it stands, typed or not.
  ///
  /// A savegame can arrive already inconsistent — current hit points above the
  /// maximum, say — and saying so is more use than rendering it as if it were
  /// ordinary. Silence would leave the player to notice that the game quietly
  /// discards it.
  String? get _errorText =>
      _error ??
      (widget.sheet.isWithinBounds(widget.stat, widget.value) ? null : _range);

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
          error: _errorText,
        ),
      ),
    );

    final hint = widget.hint;
    return hint == null ? field : Tooltip(message: hint, child: field);
  }
}

/// One proficiency's pip count.
///
/// Its own widget rather than a [_StatField] because a pip is not a header
/// field and has no [CharacterStat]: it is parameter 1 of an opcode 233
/// effect, and its ceiling comes from the player's own `weapprof.2da` rather
/// than from IESDP. Everything else — commit on Enter and on blur, refuse
/// rather than clamp — is deliberately identical, because two number fields on
/// one screen behaving differently is its own kind of bug.
class _PipField extends StatefulWidget {
  const _PipField({
    required this.label,
    required this.pips,
    required this.onCommitted,
    this.maximum,
    super.key,
  });

  final String label;
  final int pips;

  /// The most this character may have, or `null` when the table cannot say.
  ///
  /// `null` on a machine with no game installed. The field then accepts what
  /// the record can physically hold, which is the honest bound rather than a
  /// zero that would refuse everything.
  final int? maximum;

  final void Function(int) onCommitted;

  @override
  State<_PipField> createState() => _PipFieldState();
}

class _PipFieldState extends State<_PipField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.pips}',
  );
  final FocusNode _focus = FocusNode();
  String? _error;

  /// Pips cannot be negative: the record stores them in an unsigned dword.
  static const int _minimum = 0;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _PipField old) {
    super.didUpdateWidget(old);
    if (widget.pips != old.pips && !_focus.hasFocus) {
      _controller.text = '${widget.pips}';
      _error = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _accepts(int value) {
    if (value < _minimum) return false;
    final maximum = widget.maximum;
    return maximum == null || value <= maximum;
  }

  String get _range {
    final maximum = widget.maximum;
    return maximum == null ? '$_minimum or more' : '$_minimum–$maximum';
  }

  void _commit() {
    final typed = int.tryParse(_controller.text.trim());
    if (typed == null || !_accepts(typed)) {
      setState(() => _error = _range);
      return;
    }
    setState(() => _error = null);
    if (typed != widget.pips) widget.onCommitted(typed);
  }

  @override
  Widget build(BuildContext context) {
    final maximum = widget.maximum;
    final hint = maximum == null
        ? 'Pips in this weapon or style. The game caps them per class, but '
              'that table lives in the game files and none were found on this '
              'machine — so no ceiling is enforced here.'
        : 'Pips in this weapon or style. The game allows this character at '
              'most $maximum, which is what their own weapprof.2da says for '
              'their class. Only a proficiency they already have can be '
              'changed — granting a new one resizes the record, which this '
              'build does not do yet.';

    return Tooltip(
      message: hint,
      child: _FieldShell(
        label: widget.label,
        hasHint: true,
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _commit(),
          decoration: _statDecoration(
            context,
            label: widget.label,
            hasHint: true,
            error: _error ?? (_accepts(widget.pips) ? null : _range),
          ),
        ),
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
