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
      final created = await ref
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
          );
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
