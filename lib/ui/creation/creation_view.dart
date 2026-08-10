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
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/config/router.dart';
import 'package:wand_of_saves/data/repositories/character_file_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/ui/character/portrait_image.dart';
import 'package:wand_of_saves/ui/character/portrait_picker.dart';
import 'package:wand_of_saves/ui/creation/creation_viewmodel.dart';
import 'package:wand_of_saves/ui/creation/pronouns.dart';
import 'package:wand_of_saves/ui/saves/save_browser_viewmodel.dart';

/// Makes a character, one question at a time.
///
/// **A screen, not a pop-up.** The flow used to be two stacked dialogs; this
/// is the game's own guided sequence with the step list kept in view, which
/// lets a player see what is coming and go back to a step without walking
/// backwards through the ones between.
class CreationView extends ConsumerWidget {
  /// Creates the screen.
  const CreationView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(creationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New character'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => context.go('/'),
        ),
      ),
      body: Row(
        children: [
          _StepRail(state: state),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _StepBody(state: state),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _Controls(state: state),
    );
  }
}

/// The steps, with the one being answered marked and the finished ones ticked.
///
/// Finished steps are tappable so a player can go back to one directly. Steps
/// *ahead* are not: they may not exist yet — the specialisation step appears
/// only once a class with kits is chosen.
class _StepRail extends ConsumerWidget {
  const _StepRail({required this.state});

  final CreationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final steps = state.steps;

    return SizedBox(
      width: 220,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          for (final step in steps)
            ListTile(
              dense: true,
              selected: step == state.step,
              leading: Icon(
                switch (step) {
                  _ when step == state.step => Icons.play_arrow,
                  _ when state.answered(step) => Icons.check,
                  _ => Icons.circle_outlined,
                },
                size: 18,
                color: state.answered(step) && step != state.step
                    ? colors.primary
                    : null,
              ),
              title: Text(step.label),
              onTap: state.answered(step)
                  ? () => ref.read(creationProvider.notifier).goTo(step)
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Back, Next, and — on the last step — Create.
class _Controls extends ConsumerWidget {
  const _Controls({required this.state});

  final CreationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.read(creationProvider.notifier);
    final isLast = state.step == state.steps.last;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: state.step == state.steps.first ? null : model.back,
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
            if (isLast)
              FilledButton(
                onPressed: state.isComplete
                    ? () => _create(context, ref, state)
                    : null,
                child: const Text('Create'),
              )
            else
              FilledButton(
                onPressed: state.isCurrentStepAnswered ? model.next : null,
                child: const Text('Next'),
              ),
          ],
        ),
      ),
    );
  }

  /// Writes the character and opens it.
  ///
  /// Failures are said out loud rather than swallowed: a name already taken is
  /// something the player can fix, and no installation is something they
  /// cannot.
  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    CreationState state,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final name = state.name.trim();

    try {
      await ref
          .read(saveBrowserProvider.notifier)
          .createCharacter(
            name: name,
            fileName: '$name${GameProfileService.characterExtension}',
            portraitName: state.portraitName ?? '',
            genderId: state.genderId,
            raceId: state.race?.value,
            classId: state.characterClass?.value,
            alignmentId: state.alignmentId,
            kitValue: state.specialisation?.value,
            abilities: {
              for (final MapEntry(key: ability, value: score)
                  in state.abilities.entries)
                ability.stat: score,
            },
            // What the tables say follows from those choices — saving throws,
            // THAC0, Lore, hit points and the skills a bard or ranger gets
            // without asking. The engine maintains none of them (D14).
            derived: ref.read(creationProvider.notifier).derivedStats(),
            // Allocated, not derived: the player spent these themselves, and
            // they win over anything a table would have written.
            allocated: state.allocatedSkillStats,
            classLevels: state.classLevels,
            proficiencies: state.proficiencies,
            knownSpells: state.knownSpells,
            memorisedSpells: state.memorisedSpells,
            spellsMemorisable: state.spellsMemorisable,
          );
      // ⚠️ **Home, not the new character's sheet.** Creating one is finishing
      // something; being dropped straight back into an editor reads as though
      // the flow had not finished at all. The character is on the list.
      router.go(Routes.browser);
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

/// Whichever question is being asked.
class _StepBody extends ConsumerWidget {
  const _StepBody({required this.state});

  final CreationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.read(creationProvider.notifier);
    final rules = ref.watch(gameRulesProvider);

    return switch (state.step) {
      CreationStep.gender => _Gender(
        state: state,
        onChoose: model.chooseGender,
      ),
      CreationStep.portrait => _Portrait(state: state),
      CreationStep.race => _Choices(
        title: 'Race',
        choices: state.catalogue.races,
        chosen: state.race,
        nameOf: (choice) => rules.raceName(choice.value) ?? choice.identifier,
        state: state,
        footnote: _adjustmentLine(state, state.race),
        onChoose: model.chooseRace,
      ),
      CreationStep.characterClass => _Choices(
        title: 'Class',
        choices: state.classesAvailable,
        chosen: state.characterClass,
        nameOf: (choice) => rules.className(choice.value) ?? choice.identifier,
        state: state,
        onChoose: model.chooseClass,
      ),
      CreationStep.kit => _Choices(
        title: 'Specialisation',
        choices: state.specialisationsAvailable,
        chosen: state.specialisation,
        // ⚠️ A kit's name comes from the talk table and nowhere else: the row
        // label for the Ranger's first kit is FERALAN and the game draws
        // "Archer".
        nameOf: (choice) => choice == CreationChoice.noSpecialisation
            ? 'No specialisation'
            : state.catalogue.textFor(choice.nameStrref) ?? choice.identifier,
        state: state,
        onChoose: model.chooseSpecialisation,
      ),
      CreationStep.alignment => _Alignment(state: state, rules: rules),
      CreationStep.abilities => _Abilities(state: state, model: model),
      CreationStep.proficiencies => _Proficiencies(
        state: state,
        model: model,
      ),
      CreationStep.thiefSkills => _ThiefSkills(state: state, model: model),
      CreationStep.spells => _Spells(state: state, model: model),
      CreationStep.name => _Name(state: state, onChanged: model.rename),
    };
  }

  /// What the chosen race adds to and takes from the ability scores.
  ///
  /// The line the game prints under a race — "+1 Dexterity, -1 Constitution"
  /// for an elf — read from `abracead.2da` rather than written out here.
  static String? _adjustmentLine(CreationState state, CreationChoice? race) {
    if (race == null) return null;
    final adjustments = state.catalogue.abilityAdjustmentsFor(race.value);
    if (adjustments.isEmpty) return null;

    const names = {
      'MOD_STR': 'Strength',
      'MOD_DEX': 'Dexterity',
      'MOD_CON': 'Constitution',
      'MOD_INT': 'Intelligence',
      'MOD_WIS': 'Wisdom',
      'MOD_CHR': 'Charisma',
    };
    return [
      for (final MapEntry(key: column, value: amount) in adjustments.entries)
        '${amount > 0 ? '+' : ''}$amount ${names[column] ?? column}',
    ].join(', ');
  }
}

/// Two buttons, because the game's own gender screen has two.
class _Gender extends StatelessWidget {
  const _Gender({required this.state, required this.onChoose});

  final CreationState state;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Gender', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 24),
      Row(
        children: [
          for (final (id, label) in [(1, 'Male'), (2, 'Female')])
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ChoiceChip(
                selected: state.genderId == id,
                onSelected: (_) => onChoose(id),
                label: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Text(label),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

/// The portrait grid, the same one the picker dialog shows.
class _Portrait extends ConsumerWidget {
  const _Portrait({required this.state});

  final CreationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Picture', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Expanded(
        child: PortraitChooser(
          selected: state.portraitName,
          onChoose: ref.read(creationProvider.notifier).choosePortrait,
        ),
      ),
    ],
  );
}

/// A list of choices with the game's own description beside it.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.title,
    required this.choices,
    required this.chosen,
    required this.nameOf,
    required this.state,
    required this.onChoose,
    this.footnote,
  });

  final String title;
  final List<CreationChoice> choices;
  final CreationChoice? chosen;
  final String Function(CreationChoice) nameOf;
  final CreationState state;
  final ValueChanged<CreationChoice> onChoose;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final description = chosen == null
        ? null
        : state.catalogue.textFor(chosen!.descriptionStrref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleLarge),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 260,
                // `RadioGroup` rather than a `groupValue` on each tile: the
                // per-tile form is deprecated as of Flutter 3.32 and D8 leaves
                // no way to silence a deprecation.
                child: RadioGroup<String>(
                  groupValue: chosen?.identifier,
                  onChanged: (identifier) {
                    if (identifier == null) return;
                    onChoose(
                      choices.firstWhere((c) => c.identifier == identifier),
                    );
                  },
                  child: ListView(
                    children: [
                      for (final choice in choices)
                        RadioListTile<String>(
                          value: choice.identifier,
                          title: Text(nameOf(choice)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // ⚠️ Scrollable, because these run to several paragraphs — the
              // Archer's is 1,100 characters. A fixed pane would clip it.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (footnote != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            footnote!,
                            style: text.titleSmall,
                          ),
                        ),
                      if (description != null)
                        Text(
                          substituteTokens(
                            description,
                            genderId: state.genderId,
                          ),
                          style: text.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The alignments the class — or its specialisation — allows.
class _Alignment extends ConsumerWidget {
  const _Alignment({required this.state, required this.rules});

  final CreationState state;
  final GameRules rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.read(creationProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Alignment', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Expanded(
          child: RadioGroup<int>(
            groupValue: state.alignmentId,
            onChanged: (id) {
              if (id != null) model.chooseAlignment(id);
            },
            child: ListView(
              children: [
                for (final id in state.alignmentsAvailable)
                  RadioListTile<int>(
                    value: id,
                    title: Text(rules.alignmentName(id) ?? '$id'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The six scores, rolled and then moved about.
///
/// Laid out the way the engine's own screen is: the abilities down the left
/// with a pair of buttons each, the running total underneath, and Store /
/// Recall / Reroll along the bottom. The bounds beside each one come from three
/// of the game's tables and are the numbers it prints itself.
class _Abilities extends StatelessWidget {
  const _Abilities({required this.state, required this.model});

  final CreationState state;
  final CreationViewModel model;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Abilities', style: text.titleLarge),
            const Spacer(),
            if (state.hasRolled)
              Text(
                'Total ${state.abilityPoints}   '
                '${state.abilityPointsRemaining} to place',
                style: text.titleMedium,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: state.hasRolled
              ? ListView(
                  children: [
                    for (final ability in CreationAbility.values)
                      _AbilityRow(
                        ability: ability,
                        value: state.abilities[ability] ?? 0,
                        bounds: state.boundsFor(ability),
                        canRaise: state.abilityPointsRemaining > 0,
                        onRaise: () => model.raiseAbility(ability),
                        onLower: () => model.lowerAbility(ability),
                      ),
                  ],
                )
              : Center(
                  child: Text(
                    'Roll for this character’s abilities.',
                    style: text.bodyLarge,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.tonal(
              onPressed: model.roll,
              child: Text(state.hasRolled ? 'Reroll' : 'Roll'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: state.hasRolled ? model.storeRoll : null,
              child: const Text('Store'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: state.hasStoredRoll ? model.recallRoll : null,
              child: const Text('Recall'),
            ),
          ],
        ),
      ],
    );
  }
}

/// One ability, its value, and the two buttons that move a point.
class _AbilityRow extends StatelessWidget {
  const _AbilityRow({
    required this.ability,
    required this.value,
    required this.bounds,
    required this.canRaise,
    required this.onRaise,
    required this.onLower,
  });

  final CreationAbility ability;
  final int value;
  final ({int minimum, int maximum}) bounds;
  final bool canRaise;
  final VoidCallback onRaise;
  final VoidCallback onLower;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // ⚠️ **150, measured from a capture rather than borrowed.** The
          // character sheet's tiles are 222 because "Paralysis / Poison /
          // Death" needs it; the longest label here is "Constitution", and at
          // 222 the number floated a third of the pane away from its name.
          SizedBox(
            width: 150,
            child: Text(ability.label, style: text.bodyLarge),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$value',
              style: text.titleMedium,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: value > bounds.minimum ? onLower : null,
            icon: const Icon(Icons.remove),
            tooltip: 'Lower ${ability.label}',
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            onPressed: canRaise && value < bounds.maximum ? onRaise : null,
            icon: const Icon(Icons.add),
            tooltip: 'Raise ${ability.label}',
          ),
          const SizedBox(width: 16),
          // ⚠️ **Shown rather than only enforced.** A cap that appears only
          // when a value is refused is a worse experience than no cap at all —
          // the lesson the sheet's proficiency tiles already learned.
          Text('${bounds.minimum}–${bounds.maximum}', style: text.bodySmall),
        ],
      ),
    );
  }
}

/// Which weapons and fighting styles the pips go into.
/// Where a thief's starting points go.
///
/// ⚠️ **Sliders rather than the proficiency step's plus and minus.** A skill
/// runs 0 to 100 in fives where a proficiency runs 0 to 3, and forty points
/// placed a pip at a time is eight taps for one skill.
class _ThiefSkills extends StatelessWidget {
  const _ThiefSkills({required this.state, required this.model});

  final CreationState state;
  final CreationViewModel model;

  /// What the game calls each `thiefscl.2da` row.
  ///
  /// Taken from `CharacterStat`, which already carries the pairing — the
  /// character sheet and this screen name a skill the same way or one of them
  /// is wrong.
  static final Map<String, String> _labels = {
    for (final stat in CharacterStat.values)
      if (stat.thiefSkillRow case final String row) row: stat.label,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final remaining = state.thiefSkillPointsRemaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Thief skills', style: text.titleLarge),
            const Spacer(),
            Text('$remaining still to spend', style: text.titleMedium),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${state.thiefSkillPoints} points at first level.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (final row in state.thiefSkillsAvailable)
                _SkillRow(
                  label: _labels[row] ?? row,
                  points: state.thiefSkills[row] ?? 0,
                  // The pool, not the skill's own ceiling: what is left plus
                  // what is already here is everything this skill could hold.
                  ceiling: (state.thiefSkills[row] ?? 0) + remaining,
                  onChanged: (points) => model.allocateSkill(row, points),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One skill, its points, and a slider bounded by what is left to spend.
class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.label,
    required this.points,
    required this.ceiling,
    required this.onChanged,
  });

  final String label;
  final int points;
  final int ceiling;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: text.bodyLarge)),
          Expanded(
            child: Slider(
              value: points.toDouble(),
              max: ceiling == 0 ? 1 : ceiling.toDouble(),
              // ⚠️ Divisions of five, which is the step the game's own screen
              // moves in. A slider free to land on 37 offers a precision the
              // engine does not.
              divisions: ceiling < 5 ? null : ceiling ~/ 5,
              label: '$points',
              onChanged: ceiling == 0
                  ? null
                  : (value) => onChanged(value.round()),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text('$points', style: text.titleMedium),
          ),
        ],
      ),
    );
  }
}

class _Proficiencies extends StatelessWidget {
  const _Proficiencies({required this.state, required this.model});

  final CreationState state;
  final CreationViewModel model;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final available = state.proficienciesAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Proficiencies', style: text.titleLarge),
            const Spacer(),
            // ⚠️ **"0 of 4 to spend" read as "none of four chosen".** What a
            // capture showed with four pips already placed. The count that
            // matters is what is *left*, and the total belongs in the line
            // below it rather than fused into the same phrase.
            Text(
              '${state.proficiencyPipsRemaining} still to spend',
              style: text.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${state.proficiencySlots} pips at first level, at most '
          '${state.proficiencyRankCap} in any one.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (final entry in available)
                _PipRow(
                  // ⚠️ The row label is not the name: `2WEAPON` is what the
                  // table says and *Two-Weapon Style* is what the game draws.
                  label:
                      state.catalogue.textFor(entry.nameStrref) ??
                      entry.identifier,
                  pips: state.proficiencies[entry.id] ?? 0,
                  cap: state.proficiencyRankCap,
                  canRaise: state.proficiencyPipsRemaining > 0,
                  onRaise: () => model.raiseProficiency(entry.id),
                  onLower: () => model.lowerProficiency(entry.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One proficiency and the two buttons that move a pip.
class _PipRow extends StatelessWidget {
  const _PipRow({
    required this.label,
    required this.pips,
    required this.cap,
    required this.canRaise,
    required this.onRaise,
    required this.onLower,
  });

  final String label;
  final int pips;
  final int cap;
  final bool canRaise;
  final VoidCallback onRaise;
  final VoidCallback onLower;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 222,
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        // The game draws pips as plus signs — "Two-Weapon Style +++".
        SizedBox(
          width: 48,
          child: Text(
            '+' * pips,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          onPressed: pips > 0 ? onLower : null,
          icon: const Icon(Icons.remove),
          tooltip: 'Fewer pips in $label',
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          onPressed: canRaise && pips < cap ? onRaise : null,
          icon: const Icon(Icons.add),
          tooltip: 'More pips in $label',
        ),
        const SizedBox(width: 16),
        Text('max $cap', style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

/// The book, and which of it is prepared.
///
/// Two lists, because the engine asks two questions: *Mage Book: Level 1* picks
/// what the character knows, and *Memorize Mage Spells* picks which of those
/// are ready to cast. The second only ever lists the first's answers.
class _Spells extends StatelessWidget {
  const _Spells({required this.state, required this.model});

  final CreationState state;
  final CreationViewModel model;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final catalogue = state.catalogue;

    String nameOf(String resref) {
      final spell = state.spellsAvailable
          .where((s) => s.resref == resref)
          .firstOrNull;
      return catalogue.textFor(spell?.nameStrref) ?? resref;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Spells', style: text.titleLarge),
            const Spacer(),
            Text(
              '${state.spellsLearnable - state.knownSpells.length} '
              'still to choose',
              style: text.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${state.spellsLearnable} for the book, of which '
          '${state.spellsMemorisable} prepared.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The engine's own heading for this list.
                    Text('Mage Book: Level 1', style: text.titleMedium),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final spell in state.spellsAvailable)
                            CheckboxListTile(
                              value: state.knownSpells.contains(spell.resref),
                              // ⚠️ **Leading, not the default trailing.** A
                              // capture showed the box sitting seven hundred
                              // pixels from the name it belongs to, because a
                              // `CheckboxListTile` puts its control at the far
                              // edge of whatever width it is given.
                              controlAffinity: ListTileControlAffinity.leading,
                              // Unticking is always allowed; ticking stops at
                              // the limit, so a full book refuses rather than
                              // swapping out a spell chosen deliberately.
                              onChanged:
                                  state.knownSpells.contains(spell.resref) ||
                                      state.knownSpells.length <
                                          state.spellsLearnable
                                  ? (_) => model.learnSpell(spell.resref)
                                  : null,
                              title: Text(nameOf(spell.resref)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              const VerticalDivider(width: 1),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Memorise ${state.spellsMemorisable}',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (state.knownSpells.isEmpty)
                      Text(
                        'Choose spells for the book first.',
                        style: text.bodyMedium,
                      ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final resref in state.knownSpells)
                            CheckboxListTile(
                              value: state.memorisedSpells.contains(resref),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged:
                                  state.memorisedSpells.contains(resref) ||
                                      state.memorisedSpells.length <
                                          state.spellsMemorisable
                                  ? (_) => model.memoriseSpell(resref)
                                  : null,
                              title: Text(nameOf(resref)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What to call them, and a look at what they turned out to be.
class _Name extends StatelessWidget {
  const _Name({required this.state, required this.onChanged});

  final CreationState state;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Name', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 320,
            child: TextFormField(
              initialValue: state.name,
              onChanged: onChanged,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ),
          const SizedBox(width: 32),
          if (state.portraitName case final String portrait)
            SizedBox(
              width: 110,
              height: 170,
              child: PortraitImage(baseName: portrait),
            ),
        ],
      ),
    ],
  );
}
