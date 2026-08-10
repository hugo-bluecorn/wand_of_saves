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

import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';

part 'creation_viewmodel.mapper.dart';

/// One question the flow asks, in the order the game asks it.
///
/// ⚠️ **The portrait comes third, before race and class** — which is the
/// engine's own order (`docs/findings/screens/char-create/03-…`), not a guess.
/// The `APPEARANCE` entry in the game's step list is a *different* screen: hair
/// and skin colour, which this flow does not offer.
///
/// ⚠️ **[kit] comes before [alignment], and that ordering is load-bearing.**
/// `alignmnt.2da` has rows for kits as well as classes and they disagree — a
/// Fighter may be any alignment, a Kensai may not be chaotic — so asking about
/// alignment first would offer choices the specialisation then forbids.
enum CreationStep {
  /// Male or female. The other six `GENDER.IDS` values are not people.
  gender('Gender'),

  /// The picture, chosen from the game's own and the player's own.
  portrait('Picture'),

  /// Which race, from the columns of `clsrcreq.2da`.
  race('Race'),

  /// Which class, from the rows that race is allowed.
  characterClass('Class'),

  /// Which specialisation, if the class has any. Skipped when it has none.
  kit('Specialisation'),

  /// Which alignment, from what the class *or kit* allows.
  alignment('Alignment'),

  /// What to call them.
  name('Name');

  const CreationStep(this.label);

  /// What to call this step on screen.
  final String label;
}

/// Everything the creation flow renders, and everything it will write.
@MappableClass()
class CreationState with CreationStateMappable {
  /// Creates a draft.
  const CreationState({
    this.catalogue = CreationCatalogue.empty,
    this.step = CreationStep.gender,
    this.genderId,
    this.portraitName,
    this.race,
    this.characterClass,
    this.specialisation,
    this.alignmentId,
    this.name = '',
  });

  /// What this installation says a character may be.
  ///
  /// Arrives after the first frame and can arrive again. ⚠️ **It is copied into
  /// the state rather than watched**, because a watched provider destroys this
  /// state every time it recomputes — see [CreationViewModel.build].
  final CreationCatalogue catalogue;

  /// The step being answered.
  final CreationStep step;

  /// `GENDER.IDS` id, or `null` if unanswered.
  final int? genderId;

  /// Portrait base name, or `null` if unanswered.
  final String? portraitName;

  /// The chosen race, or `null`.
  final CreationChoice? race;

  /// The chosen class, or `null`.
  final CreationChoice? characterClass;

  /// The chosen specialisation, or `null` if unanswered.
  ///
  /// **"No specialisation" is a choice, not a `null`** —
  /// [CreationChoice.noSpecialisation] — so the two can be told apart.
  final CreationChoice? specialisation;

  /// `ALIGNMEN.IDS` id, or `null`.
  final int? alignmentId;

  /// What to call the character. Never `null`; empty means unanswered.
  final String name;

  /// The classes the chosen race may take.
  List<CreationChoice> get classesAvailable =>
      race == null ? const [] : catalogue.classesFor(race!.value);

  /// The specialisations the chosen class offers, "none" first.
  ///
  /// Empty — not just "none" — when the class has no kits at all, which is what
  /// makes [steps] drop the step entirely.
  List<CreationChoice> get specialisationsAvailable {
    if (characterClass == null) return const [];
    final kits = catalogue.kitsFor(characterClass!.value);
    if (kits.isEmpty) return const [];
    return [CreationChoice.noSpecialisation, ...kits];
  }

  /// The alignments the chosen class — or its specialisation — allows.
  List<int> get alignmentsAvailable => characterClass == null
      ? const []
      : catalogue.alignmentsFor(
          characterClass: characterClass!,
          kit: specialisation == CreationChoice.noSpecialisation
              ? null
              : specialisation,
        );

  /// The steps this character actually has, in order.
  ///
  /// [CreationStep.kit] is absent for every multi-class and for Shaman, because
  /// the game gives them no kits — asking would be a step with one answer.
  List<CreationStep> get steps => [
    for (final step in CreationStep.values)
      if (step != CreationStep.kit || specialisationsAvailable.isNotEmpty) step,
  ];

  /// Whether [step] has an answer.
  bool answered(CreationStep which) => switch (which) {
    CreationStep.gender => genderId != null,
    CreationStep.portrait => portraitName != null,
    CreationStep.race => race != null,
    CreationStep.characterClass => characterClass != null,
    CreationStep.kit => specialisation != null,
    CreationStep.alignment => alignmentId != null,
    CreationStep.name => name.trim().isNotEmpty,
  };

  /// Whether the step on screen has an answer, so Next may be offered.
  bool get isCurrentStepAnswered => answered(step);

  /// Whether every step this character has is answered.
  bool get isComplete => steps.every(answered);
}

/// Drives the creation flow.
///
/// **A synchronous [Notifier], deliberately.** The draft needs no I/O, so Back
/// and Next never pass through a loading state. An `AsyncNotifier` would
/// rebuild asynchronously on every change — the trap `CharacterFileViewModel`
/// already documents for its edit session, where it put a spinner where a value
/// should be.
class CreationViewModel extends Notifier<CreationState> {
  @override
  CreationState build() {
    // ⚠️ **`listen`, never `watch`, and this is the whole reason the class is
    // shaped like this.** Riverpod destroys a provider's state whenever it
    // recomputes ("the state will always be destroyed when the provider is
    // recomputed", `concepts2/auto_dispose.mdx`), and this flow's own portrait
    // step invalidates `portraitNamesProvider` when the player imports a
    // picture. Watching the catalogue would throw a half-made character away
    // mid-flow. `listen` reacts without depending, which is exactly what
    // `concepts2/refs.mdx` documents it for.
    ref.listen(creationCatalogueProvider, (_, next) {
      // `AsyncValue.value` is the nullable one in 3.4.2 — checked against the
      // pinned source, `core/async_value.dart:557`. A load or a failure leaves
      // the catalogue as it was rather than emptying a flow mid-answer.
      final tables = next.value;
      if (tables != null) state = state.copyWith(catalogue: tables);
    });

    // ⚠️ **Seeded by `read`, not by `fireImmediately: true`.** That flag fires
    // the callback *during* this build, before `state` exists — so the moment
    // the catalogue was already cached, the listener above read an
    // uninitialised `state` and threw `Bad state: Tried to read the state of an
    // uninitialized provider`. It only happens when the read has **already**
    // resolved, which is every time but the first: `isAutoDispose` throws this
    // notifier away on leaving, and the query outlives it.
    //
    // A golden test against a real installation caught it. Every unit test
    // overrode the query with something that began life loading, so the guard
    // above skipped the assignment and the bug could not appear.
    //
    // `read` takes no dependency, so this still does not recompute — which is
    // the property the whole class is shaped around.
    return CreationState(
      catalogue:
          ref.read(creationCatalogueProvider).value ?? CreationCatalogue.empty,
    );
  }

  /// Chooses a gender.
  void chooseGender(int id) => state = state.copyWith(genderId: id);

  /// Chooses a portrait by base name.
  void choosePortrait(String baseName) =>
      state = state.copyWith(portraitName: baseName);

  /// Chooses a race, dropping anything downstream it invalidates.
  ///
  /// ⚠️ **An elf cannot be a paladin.** Keeping a class the new race forbids
  /// would carry an illegal value all the way to the writer.
  void chooseRace(CreationChoice choice) {
    final keepsClass = catalogue
        .classesFor(choice.value)
        .any((c) => c.identifier == state.characterClass?.identifier);
    state = state.copyWith(
      race: choice,
      characterClass: keepsClass ? state.characterClass : null,
      specialisation: keepsClass ? state.specialisation : null,
      alignmentId: keepsClass ? state.alignmentId : null,
    );
  }

  /// Chooses a class, dropping a specialisation it does not offer.
  ///
  /// ⚠️ **A class with no kits is answered as `TRUECLASS`, not left unset.**
  /// The step is hidden either way, but the two write different bytes: leaving
  /// it unset keeps `CHARBASE`'s kit of **0**, where the engine's own
  /// Fighter / Mage stores **`0x40000000`**. Both mean "no kit" to the engine,
  /// and only one of them is what the engine writes — a golden test against a
  /// character BG:EE made is what showed the difference.
  void chooseClass(CreationChoice choice) {
    final kits = catalogue.kitsFor(choice.value);
    final keepsKit = kits.any(
      (k) => k.identifier == state.specialisation?.identifier,
    );
    state = state.copyWith(
      characterClass: choice,
      specialisation: switch (0) {
        _ when kits.isEmpty => CreationChoice.noSpecialisation,
        _ when keepsKit => state.specialisation,
        _ => null,
      },
      alignmentId: null,
    );
  }

  /// Chooses a specialisation, dropping an alignment it forbids.
  ///
  /// ⚠️ **A Kensai may not be chaotic where a plain Fighter may**, so this can
  /// invalidate an answer the player already gave — which is why the step comes
  /// before alignment rather than after.
  void chooseSpecialisation(CreationChoice choice) {
    final next = state.copyWith(specialisation: choice);
    state = next.alignmentsAvailable.contains(state.alignmentId)
        ? next
        : next.copyWith(alignmentId: null);
  }

  /// Chooses an alignment.
  void chooseAlignment(int id) => state = state.copyWith(alignmentId: id);

  /// Sets the name.
  void rename(String value) => state = state.copyWith(name: value);

  /// Moves to the next step, if the current one has been answered.
  void next() {
    if (!state.isCurrentStepAnswered) return;
    final steps = state.steps;
    final at = steps.indexOf(state.step);
    if (at < 0 || at + 1 >= steps.length) return;
    state = state.copyWith(step: steps[at + 1]);
  }

  /// Moves back a step.
  void back() {
    final steps = state.steps;
    final at = steps.indexOf(state.step);
    if (at <= 0) return;
    state = state.copyWith(step: steps[at - 1]);
  }

  /// Jumps to [which], which the step rail offers for anything already passed.
  void goTo(CreationStep which) {
    if (!state.steps.contains(which)) return;
    state = state.copyWith(step: which);
  }

  /// The tables the flow is offering from.
  CreationCatalogue get catalogue => state.catalogue;
}

/// The creation flow's state, for one trip through it.
///
/// ⚠️ **`isAutoDispose: true`, and it is load-bearing rather than tidiness.**
/// Riverpod's own guidance says form state should not live in a provider at all
/// — *"leaving and re-entering the form should typically reset the form state.
/// This includes pressing the back button during a multi-page forms"*
/// (`root/do_dont.mdx`). Auto-disposal over a route-scoped provider **is** that
/// reset: leaving `/new-character` drops the last listener, the draft is
/// destroyed, and starting again starts blank.
///
/// The constructor defaults this to `false`, so it has to be written out. And
/// it is the named argument, never `.autoDispose` — that form is codegen-only,
/// which D2 forbids.
///
/// ⚠️ **A deliberate difference from the two document editors, which do not
/// auto-dispose.** They hold a file you opened and losing those edits would be
/// data loss; a creation flow you backed out of is a cancellation.
final creationProvider = NotifierProvider<CreationViewModel, CreationState>(
  isAutoDispose: true,
  CreationViewModel.new,
);
