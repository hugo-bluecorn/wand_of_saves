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
import 'package:wand_of_saves/domain/skill_catalogue.dart';
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
    // The controller lives here, above the rail, so **the tab survives
    // changing character**. Comparing one number across the party is the whole
    // point of having a rail; a controller owned by the detail pane would be
    // rebuilt on every selection and snap back to Character each time.
    return DefaultTabController(
      length: _CharacterTab.values.length,
      child: Row(
        children: [
          _PortraitRail(state: state, slotDirectoryName: slotDirectoryName),
          const VerticalDivider(width: 1),
          Expanded(
            child: _CharacterSummary(
              character: state.members[state.selectedIndex],
              proficiencies: state.proficiencies,
              skills: state.skills,
              reputation: state.reputation,
              slotDirectoryName: slotDirectoryName,
            ),
          ),
        ],
      ),
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
    required this.skills,
    required this.reputation,
    required this.slotDirectoryName,
  });

  final Character character;
  final ProficiencyCatalogue proficiencies;

  /// Which thief skills this character's class may allocate points to.
  final SkillCatalogue skills;

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
      skills: skills,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Above the tabs, not inside one: whose sheet this is has to be true
          // on every tab, and the game keeps its own summary on screen
          // throughout creation for the same reason.
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
            ],
          ),
        ),
        TabBar(
          tabs: [
            for (final tab in _CharacterTab.values) Tab(text: tab.label),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _CharacterFacts(
                character: character,
                sheet: sheet,
                reputation: reputation,
                onCommitted: set,
              ),
              _Abilities(character: character, sheet: sheet, onCommitted: set),
              _Skills(
                character: character,
                sheet: sheet,
                slotDirectoryName: slotDirectoryName,
                onCommitted: set,
              ),
              _Combat(character: character, sheet: sheet, onCommitted: set),
            ],
          ),
        ),
      ],
    );
  }
}

/// How the game itself divides a character.
///
/// BG:EE's character creation walks
/// `GENDER · RACE · CLASS · ALIGNMENT · ABILITIES · SKILLS · APPEARANCE ·
/// NAME`, and these four are the steps whose contents this panel holds. The
/// names are the game's rather than ours, for the same reason the saving
/// throws carry the game's wording: a player can hold the two screens side by
/// side without translating.
///
/// ⚠️ **SKILLS is the game's umbrella for weapon proficiencies too**, and for
/// spells. Pressing it in creation leads to the proficiency screen — whose
/// header reads `PROFICIENCY SLOTS 4 | SKILLS 0` — and on a spellcaster
/// continues into the spellbook and memorisation screens. This panel used to
/// file proficiencies under a heading of their own, which the game does not.
///
/// Two steps have no tab: APPEARANCE, because nothing here edits colours or
/// the voice set yet, and the identity steps, which are read-only and sit
/// above the tabs where they stay visible.
enum _CharacterTab {
  /// Who they are and how they are doing.
  character('Character'),

  /// The six scores.
  abilities('Abilities'),

  /// Proficiencies and thief skills, under the game's own heading.
  skills('Skills'),

  /// How they fight, and what they shrug off.
  combat('Combat');

  const _CharacterTab(this.label);

  /// What the tab says.
  final String label;
}

/// The Character tab: the numbers that belong to the person.
class _CharacterFacts extends StatelessWidget {
  const _CharacterFacts({
    required this.character,
    required this.sheet,
    required this.reputation,
    required this.onCommitted,
  });

  final Character character;
  final CharacterSheet sheet;
  final double reputation;
  final void Function(CharacterStat, int) onCommitted;

  @override
  Widget build(BuildContext context) {
    return _TabBody(
      children: [
        _StatGroup(
          title: 'Character',
          children: [
            _StatField(
              character: character,
              sheet: sheet,
              stat: CharacterStat.currentHitPoints,
              value: character.currentHitPoints,
              label: 'Current hit points',
              onCommitted: onCommitted,
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
              onCommitted: onCommitted,
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
            _StatField(
              character: character,
              sheet: sheet,
              stat: CharacterStat.experience,
              value: character.experience,
              label: 'Experience',
              onCommitted: onCommitted,
            ),
            _StatField(
              character: character,
              sheet: sheet,
              stat: CharacterStat.gold,
              value: character.gold,
              label: 'Gold (carried)',
              onCommitted: onCommitted,
              hint:
                  'Gold on this character. The shared party purse is stored '
                  'separately and is not this number.',
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
        _StatGroup(
          // Not skills, which is where the record's own layout had put them
          // and where this panel followed it. They are how the character is
          // doing right now, which is what the rest of this tab is about.
          title: 'Condition',
          children: [
            _StatField(
              character: character,
              sheet: sheet,
              stat: CharacterStat.fatigue,
              value: character.fatigue,
              label: CharacterStat.fatigue.label,
              onCommitted: onCommitted,
            ),
            _StatField(
              character: character,
              sheet: sheet,
              stat: CharacterStat.intoxication,
              value: character.intoxication,
              label: CharacterStat.intoxication.label,
              onCommitted: onCommitted,
            ),
          ],
        ),
      ],
    );
  }
}

/// The Abilities tab — the game's ABILITIES step.
class _Abilities extends StatelessWidget {
  const _Abilities({
    required this.character,
    required this.sheet,
    required this.onCommitted,
  });

  final Character character;
  final CharacterSheet sheet;
  final void Function(CharacterStat, int) onCommitted;

  @override
  Widget build(BuildContext context) {
    return _TabBody(
      children: [
        _StatGroup(
          title: 'Abilities',
          children: [
            for (final (stat, value) in _scores(character.abilities))
              _StatField(
                character: character,
                sheet: sheet,
                stat: stat,
                value: value,
                // The modifier goes in the label, so what a score is *worth*
                // sits beside the score instead of only in a tooltip.
                label: _label(stat, sheet),
                onCommitted: onCommitted,
                // Percentile strength is only meaningful at Strength 18,
                // which is the one place the engine consults it.
                enabled:
                    stat != CharacterStat.strengthBonus ||
                    character.abilities.strength == 18,
                // The two bytes read out as the one value the game prints,
                // under the first of them. Both stay editable; this only says
                // what the game would show.
                helper: stat == CharacterStat.strength
                    ? switch (sheet.strengthInGame) {
                        final String written => '$written in game',
                        null => null,
                      }
                    : null,
              ),
          ],
        ),
      ],
    );
  }

  /// A stat's label with the modifier the game's tables give it.
  ///
  /// Only the two that this build can look up say anything: Constitution's
  /// hit points per level and Dexterity's armour class. The rest are plain,
  /// rather than implying a modifier of zero where there is simply no table
  /// read yet.
  String _label(CharacterStat stat, CharacterSheet sheet) {
    final modifier = switch (stat) {
      CharacterStat.constitution => sheet.hitPointBonusPerLevel,
      CharacterStat.dexterity => sheet.armourClassModifier,
      _ => null,
    };
    if (modifier == null || modifier == 0) return stat.label;
    final sign = modifier > 0 ? '+' : '';
    return '${stat.label}  $sign$modifier';
  }

  List<(CharacterStat, int)> _scores(AbilityScores abilities) => [
    (CharacterStat.strength, abilities.strength),
    (CharacterStat.strengthBonus, abilities.strengthBonus),
    (CharacterStat.dexterity, abilities.dexterity),
    (CharacterStat.constitution, abilities.constitution),
    (CharacterStat.intelligence, abilities.intelligence),
    (CharacterStat.wisdom, abilities.wisdom),
    (CharacterStat.charisma, abilities.charisma),
  ];
}

/// The Skills tab — the game's SKILLS step, proficiencies included.
///
/// See [_CharacterTab.skills] for why those two share a heading here when the
/// record stores them in completely different places: one is header bytes, the
/// other is opcode 233 effects. The game presents them together, so this does.
class _Skills extends StatelessWidget {
  const _Skills({
    required this.character,
    required this.sheet,
    required this.slotDirectoryName,
    required this.onCommitted,
  });

  final Character character;
  final CharacterSheet sheet;
  final String slotDirectoryName;
  final void Function(CharacterStat, int) onCommitted;

  @override
  Widget build(BuildContext context) {
    return _TabBody(
      children: [
        _ProficiencyGroup(
          character: character,
          sheet: sheet,
          slotDirectoryName: slotDirectoryName,
        ),
        _StatGroup(
          // Named for what they are, because every one of them is a base and
          // the game shows something larger. Saying so once in the title beats
          // repeating "(base)" on ten tiles.
          title: 'Points allocated, not what the game shows',
          children: [
            for (final (stat, value) in _allocated(character))
              _StatField(
                character: character,
                sheet: sheet,
                stat: stat,
                value: value,
                label: stat.label,
                onCommitted: onCommitted,
                // Greyed when the class cannot allocate it — but **not** when
                // the record already holds something. A Fighter/Mage with 40
                // Open Locks is an anomaly, and a field you cannot touch is
                // one you cannot correct.
                enabled: sheet.allows(stat) || value != 0,
                hint: sheet.unavailableReason(stat) ?? _hint(stat),
              ),
          ],
        ),
      ],
    );
  }

  /// The skills a character spends points on, in the record's own order.
  List<(CharacterStat, int)> _allocated(Character character) {
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
    ];
  }

  /// What a skill tile says when the class *can* allocate it.
  ///
  /// Only Move Silently carries one, and it stands for the whole group: the
  /// heading already says these are bases, and this is where the measurement
  /// behind that claim lives.
  String? _hint(CharacterStat stat) => stat == CharacterStat.moveSilently
      ? 'Measured: a thief storing 15 here has the game show 35, and two '
            'characters both storing Lore 3 show 10 and 15. The engine adds '
            'class, race and Dexterity bonuses. Working the shown figure out '
            'needs tables this build does not read, so only the stored base '
            'is offered.'
      : null;
}

/// The Combat tab: how they fight, and what they shrug off.
class _Combat extends StatelessWidget {
  const _Combat({
    required this.character,
    required this.sheet,
    required this.onCommitted,
  });

  final Character character;
  final CharacterSheet sheet;
  final void Function(CharacterStat, int) onCommitted;

  @override
  Widget build(BuildContext context) {
    return _TabBody(
      children: [
        _StatGroup(
          title: 'Combat',
          children: [
            _StatField(
              character: character,
              sheet: sheet,
              stat: CharacterStat.thac0,
              value: character.thac0,
              label: 'THAC0 (base)',
              onCommitted: onCommitted,
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
              onCommitted: onCommitted,
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
              onCommitted: onCommitted,
              hint:
                  'What the character defends at before Dexterity is applied, '
                  'and the field the game actually reads — confirmed in game '
                  'by writing a value that could not arise unarmoured.',
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
            for (final (stat, value) in _fighting(character))
              _StatField(
                character: character,
                sheet: sheet,
                stat: stat,
                value: value,
                label: stat.label,
                onCommitted: onCommitted,
                hint: stat == CharacterStat.saveVersusDeath
                    ? 'The five saving throws are stored exactly as the game '
                          'prints them — nothing is added before display, '
                          'unlike hit points and THAC0. Lower is better.'
                    : null,
              ),
          ],
        ),
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
                onCommitted: onCommitted,
              ),
          ],
        ),
      ],
    );
  }

  /// The combat numbers, in the order the record screen stacks them.
  List<(CharacterStat, int)> _fighting(Character character) {
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

  /// The eleven resistances, in the order the record stores them.
  ///
  /// Shown unconditionally, like every other group. They were briefly folded
  /// away when all eleven were zero — which is every character in every
  /// fixture — but that was a one-off rather than a rule, and the toggle was
  /// dead for anyone who actually resisted something. The page being long was
  /// the real complaint, and the tabs above are the answer to it.
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
}

/// The scrolling body every tab shares, so they indent and space alike.
class _TabBody extends StatelessWidget {
  const _TabBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(24),
    itemCount: children.length,
    itemBuilder: (context, index) => children[index],
    separatorBuilder: (context, _) => const SizedBox(height: 24),
  );
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
            // A cap of 0 is how weapprof.2da says "not this class". As with
            // the skills, an existing non-zero value stays editable so an
            // anomaly can be corrected rather than merely stared at.
            enabled:
                sheet.allowsProficiency(proficiency.id) ||
                proficiency.pips != 0,
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
  String? helper,
}) => InputDecoration(
  labelText: label,
  filled: true,
  border: const OutlineInputBorder(),
  errorText: error,
  // Reserves the error line so a refused value does not shove every tile
  // below it down the screen — and, where there is something worth saying,
  // spends that reserved line on saying it rather than on a blank.
  helperText: error == null ? (helper ?? ' ') : null,
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
    this.helper,
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

  /// A line under the field, on the row the error message already reserves.
  ///
  /// For something true of the value as it stands rather than a warning — the
  /// game's own reading of it, say. Costs no layout, because that row is
  /// reserved whether or not anything is on it.
  final String? helper;

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
          helper: widget.helper,
        ),
      ),
    );

    final hint = widget.hint;
    return hint == null ? field : Tooltip(message: hint, child: field);
  }
}

/// One proficiency's pip count, drawn the way the game draws it.
///
/// Its own widget rather than a [_StatField] because a pip is not a header
/// field and has no [CharacterStat]: it is parameter 1 of an opcode 233
/// effect, and its ceiling comes from the player's own `weapprof.2da` rather
/// than from IESDP.
///
/// **A stepper, not a number field, and that is the game's choice rather than
/// a preference.** BG:EE's proficiency screen draws gold dots beside each name
/// with `[+]` and `[-]` next to them, greyed at their bounds. Two things
/// follow. The cap is stated *before* it is reached, where a text box could
/// only refuse a value after it was typed — which is the complaint this
/// answers, since a constraint you meet only by breaking it is worse than
/// none. And there is no invalid value to refuse at all, so this widget has no
/// error state, no controller and no commit-on-blur: it is stateless, and the
/// pip count it draws is always the one in the record.
class _PipField extends StatelessWidget {
  const _PipField({
    required this.label,
    required this.pips,
    required this.onCommitted,
    this.maximum,
    this.enabled = true,
    super.key,
  });

  /// What the game calls this weapon or fighting style.
  final String label;

  /// Pips the record holds.
  final int pips;

  /// The most this character may have, or `null` when the table cannot say.
  ///
  /// `null` on a machine with no game installed. `[+]` then stays live, which
  /// is the honest reading: no ceiling was found, rather than a ceiling of
  /// zero that would refuse everything.
  final int? maximum;

  /// Called with the new count when either button is pressed.
  final void Function(int) onCommitted;

  /// Whether the class may have this proficiency at all — a ceiling of `0` in
  /// `weapprof.2da` is how the table says it may not.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final maximum = this.maximum;
    final canAdd = enabled && (maximum == null || pips < maximum);
    final canRemove = enabled && pips > 0;

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
      child: Semantics(
        // The dots carry the value visually and reach nobody otherwise, so
        // the count is spoken too. `explicitChildNodes` keeps the two buttons
        // as nodes of their own — without it their labels are folded into
        // this one and the tile announces itself three times over.
        container: true,
        explicitChildNodes: true,
        label: maximum == null ? '$label, $pips' : '$label, $pips of $maximum',
        child: _FieldShell(
          label: label,
          hasHint: true,
          child: InputDecorator(
            decoration: _statDecoration(context, label: label, hasHint: true),
            child: Row(
              children: [
                Expanded(
                  child: _Pips(pips: pips, maximum: maximum, enabled: enabled),
                ),
                _PipButton(
                  icon: Icons.remove,
                  tooltip: 'One less pip in $label',
                  onPressed: canRemove ? () => onCommitted(pips - 1) : null,
                ),
                _PipButton(
                  icon: Icons.add,
                  tooltip: 'One more pip in $label',
                  onPressed: canAdd ? () => onCommitted(pips + 1) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The row of dots: filled for pips taken, hollow for pips still available.
///
/// The game draws only the filled ones. The hollows are the one addition, and
/// they earn their place by making the ceiling countable at a glance instead
/// of only discoverable by finding `[+]` greyed out.
///
/// ⚠️ **Never fewer slots than pips.** A record holding more pips than the
/// table allows is an anomaly the panel still has to draw honestly, and
/// clipping the dots would hide exactly the case worth seeing.
class _Pips extends StatelessWidget {
  const _Pips({
    required this.pips,
    required this.maximum,
    required this.enabled,
  });

  final int pips;
  final int? maximum;
  final bool enabled;

  /// Diameter of one dot.
  static const double _size = 9;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ceiling = maximum ?? pips;
    final slots = pips > ceiling ? pips : ceiling;
    final taken = enabled
        ? colors.primary
        : colors.onSurface.withValues(alpha: 0.38);

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (var i = 0; i < slots; i++)
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < pips ? taken : null,
              border: i < pips
                  ? null
                  : Border.all(color: colors.outlineVariant),
            ),
          ),
      ],
    );
  }
}

/// One of the pair, sized to sit inside a stat tile.
///
/// A default [IconButton] is 48 points square, which two of would leave no
/// room for the dots in the [_tileWidth] every tile shares.
class _PipButton extends StatelessWidget {
  const _PipButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;

  /// `null` disables the button, which is how a bound is stated.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon),
    iconSize: 18,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 30, height: 30),
    tooltip: tooltip,
    onPressed: onPressed,
  );
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
