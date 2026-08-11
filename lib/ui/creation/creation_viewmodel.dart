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

import 'dart:math';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/domain/character_stat.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/domain/rules/creation_derivation.dart';
import 'package:wand_of_saves/ui/creation/pronouns.dart';

part 'creation_viewmodel.mapper.dart';

/// Dice per ability, and sides per die.
///
/// ⚠️ **Not a table's answer**, and `CreationViewModel.roll` says why.
/// The installation states what a score may *be* and nothing about how it is
/// arrived at.
const int _dicePerAbility = 3;
const int _dieSides = 6;

/// Where a character's rolled abilities come from.
///
/// ⚠️ **The first non-deterministic thing in this application**, and a provider
/// rather than a `Random()` inside the ViewModel for exactly one reason: a
/// screen whose output cannot be predicted is a screen no test can pin. A test
/// overrides this with `Random(seed)` and the whole flow becomes reproducible.
final abilityDiceProvider = Provider<Random>((ref) => Random());

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

  /// The six scores, rolled and then moved about.
  abilities('Abilities'),

  /// Which weapons and fighting styles the pips go into.
  ///
  /// ⚠️ **The game's own step list calls this "Skills"** and covers thief
  /// skills here as well. This one only spends proficiency pips, so it says so
  /// — a heading naming something the screen does not do is worse than one that
  /// differs from the engine's.
  proficiencies('Proficiencies'),

  /// Where a thief's starting points go.
  ///
  /// ⚠️ **Conditional, and on two things at once**: the class must have points
  /// to spend (`thiefskl.2da`) *and* skills to spend them on (`thiefscl.2da`).
  /// A monk has a row in the first with `START_POINTS 0`, so asking on the
  /// strength of either table alone would draw a screen with nothing to do.
  thiefSkills('Thief skills'),

  /// Which spells go in the book, and which of those are prepared.
  spells('Spells'),

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
    this.abilities = const {},
    this.abilityPoints = 0,
    this.storedAbilities,
    this.storedAbilityPoints,
    this.proficiencies = const {},
    this.thiefSkills = const {},
    this.knownSpells = const [],
    this.memorisedSpells = const [],
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

  /// The six scores as they stand. Empty until the dice have been thrown.
  final Map<CreationAbility, int> abilities;

  /// The total the roll produced, which moving points about does not change.
  ///
  /// Kept beside [abilities] rather than derived from them, because that is the
  /// whole mechanic: the engine's screen prints "Total Roll 88" and a count of
  /// what is still unspent, and lowering one ability funds raising another.
  final int abilityPoints;

  /// A roll the player asked to keep, or `null` if they have kept none.
  final Map<CreationAbility, int>? storedAbilities;

  /// The total belonging to [storedAbilities].
  ///
  /// Stored rather than summed, because a kept roll may itself have had points
  /// left unspent, and recalling it has to put those back too.
  final int? storedAbilityPoints;

  /// Pips by the id `weapprof.2da` gives each proficiency.
  final Map<int, int> proficiencies;

  /// Points allocated per `thiefscl.2da` row. Absent means none spent.
  final Map<String, int> thiefSkills;

  /// Resrefs of the spells chosen for the book, in the order they were picked.
  final List<String> knownSpells;

  /// Resrefs of the spells prepared, always a subset of [knownSpells].
  final List<String> memorisedSpells;

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
    // ⚠️ **Narrowed by race.** `clsrcreq.2da` lists kits beside classes, and a
    // gnome may take exactly one mage school. Offering all eight would let a
    // player build a character the game will not.
    final allowed = catalogue.kitsAllowedByRace[race?.value];
    final kits = [
      for (final kit in catalogue.kitsFor(characterClass!.value))
        if (allowed == null || allowed.contains(kit.identifier.toUpperCase()))
          kit,
    ];
    if (kits.isEmpty) return const [];
    return [CreationChoice.noSpecialisation, ...kits];
  }

  /// The school this character is given without being asked, or `null`.
  ///
  /// ⚠️ **Measured: a multi-class gets no kit screen and the engine writes a
  /// kit anyway.** A Gnome Cleric/Illusionist made in BG:EE's own flow stores
  /// `0x04000000` — `MAGESCHOOL_ILLUSIONIST` — though the game never asked.
  ///
  /// **The choice is a lookup; only the forcing is a rule.** `clsrcreq.2da`
  /// says a gnome may take exactly one school, so where a multi-class contains
  /// a mage and the race is allowed precisely one, there is nothing to ask and
  /// one answer to write. An elf may take several, so an elf Fighter/Mage is
  /// forced into nothing — which is what BG:EE's own Aurel stores.
  ///
  /// ⚠️ **Only for a multi-class.** A single-class mage *has* a kit screen, and
  /// forcing there would take away a choice the game offers; the race narrows
  /// that list instead — see [specialisationsAvailable].
  CreationChoice? get forcedSpecialisation {
    final identifier = characterClass?.identifier;
    if (identifier == null || !identifier.contains('_')) return null;
    if (!identifier.split('_').contains('MAGE')) return null;

    final allowed = catalogue.kitsAllowedByRace[race?.value];
    if (allowed == null) return null;

    final schools = [
      for (final kit in catalogue.kitsByClass.values.expand((kits) => kits))
        if (catalogue.schoolByKit.containsKey(kit.identifier.toUpperCase()))
          if (allowed.contains(kit.identifier.toUpperCase())) kit,
    ];
    return schools.length == 1 ? schools.single : null;
  }

  /// The specialisation the record should carry: the chosen one, or the forced.
  ///
  /// Kept apart from [specialisation] because the two are different facts —
  /// one is an answer the player gave, the other is one the game gives on their
  /// behalf, and a flow that conflated them could not tell "not specialised"
  /// from "never asked".
  CreationChoice? get specialisationToWrite =>
      specialisation == CreationChoice.noSpecialisation
      ? specialisation
      : specialisation ?? forcedSpecialisation;

  /// The alignments the chosen class — or its specialisation — allows.
  List<int> get alignmentsAvailable => characterClass == null
      ? const []
      : catalogue.alignmentsFor(
          characterClass: characterClass!,
          kit: specialisation == CreationChoice.noSpecialisation
              ? null
              : specialisation,
        );

  /// The column `weapprof.2da` answers this character's questions in.
  ///
  /// **The kit's where there is one, otherwise the class's** — the same
  /// precedence a kit's alignments use, and for the same reason: a
  /// specialisation replaces its class rather than adding to it.
  ///
  /// No `GameRules` lookup is involved, unlike the character sheet's version of
  /// this: there the column has to be recovered from a stored kit dword, and
  /// here the choice already carries `kitlist.2da`'s own row label, which *is*
  /// the column.
  /// ⚠️ **Except for a multi-class, whose class column governs.** Both halves
  /// are measured. `SWASHBUCKLER` allows 2 pips in Short Sword where `THIEF`
  /// allows 1, so a single-class kit's column is the right one. But
  /// `ILLUSIONIST` allows **0** in War Hammer where `CLERIC_MAGE` allows 1, and
  /// BG:EE gave a Gnome Cleric/Illusionist a hammer and a flail — so for a
  /// multi-class the school is a property of one half and cannot speak for the
  /// character. A kit *replaces* its class only when it is the whole class.
  String? get proficiencyColumn {
    final classIdentifier = characterClass?.identifier;
    final kit = specialisation;
    final hasKit = kit != null && kit != CreationChoice.noSpecialisation;
    if (!hasKit || classIdentifier == null) return classIdentifier;
    return classIdentifier.contains('_') ? classIdentifier : kit.identifier;
  }

  /// The most pips [proficiencyId] may hold at first level.
  ///
  /// ⚠️ **The LOWER of two tables, and neither alone is right.**
  /// `profsmax.2da`'s `FIRST_LEVEL` is the *level* ceiling and is `2` for every
  /// row in the file; `weapprof.2da`'s class column is the *class* ceiling and
  /// gives a cleric or a thief `1`, a fighter `5`. Reading only the first let
  /// this flow offer a thief a second pip that **BG:EE refuses** — measured in
  /// game, with a slot still unspent.
  ///
  /// A fighter's 5 is Grand Mastery, reached over many levels, which is exactly
  /// why the level ceiling has to bound it here.
  int rankCapFor(int proficiencyId) {
    final byLevel = proficiencyRankCap;
    final byClass = catalogue.proficiencies[proficiencyId]?.maximumFor(
      proficiencyColumn,
    );
    // ⚠️ `null` is "the table cannot say", not "zero" — a machine with no
    // installation must not have every proficiency silently capped at nothing.
    if (byClass == null) return byLevel;
    return byClass < byLevel ? byClass : byLevel;
  }

  /// The level in each of this character's classes — all `1`, one per class.
  ///
  /// ⚠️ **Written explicitly rather than left to the template.** `CHARBASE`
  /// carries its own level slots, so a single-class Thief built from it would
  /// keep a second and a third, and `CLASS.IDS` would then disagree with the
  /// bytes about how many classes they have. The class *name* is the count: a
  /// `FIGHTER_MAGE_THIEF` is three.
  ///
  /// No `GameRules` lookup, for the same reason [proficiencyColumn] needs none
  /// — the choice already carries the identifier.
  List<int> get classLevels {
    final identifier = characterClass?.identifier;
    if (identifier == null) return const [];
    return List<int>.filled(identifier.split('_').length, 1);
  }

  /// How many pips this character has to spend. `profs.2da`.
  int get proficiencySlots => characterClass == null
      ? 0
      : catalogue.proficiencySlotsFor(characterClass!.identifier);

  /// The most pips that may go into any one of them. `profsmax.2da`.
  int get proficiencyRankCap => characterClass == null
      ? 0
      : catalogue.proficiencyRankCapFor(characterClass!.identifier);

  /// How many thief-skill points this character has to spend. `thiefskl.2da`.
  ///
  /// ⚠️ **Keyed on the class, not on [proficiencyColumn].** A kit has its own
  /// row here — a Shadowdancer starts with 30 where a Thief starts with 40 —
  /// so the kit's identifier is tried first and the class's is the fallback,
  /// which is the same precedence every other kit-aware lookup uses.
  int get thiefSkillPoints {
    final column = proficiencyColumn;
    if (column == null) return 0;
    final own = catalogue.thiefSkillPointsFor(column);
    if (own > 0) return own;
    final base = characterClass?.identifier;
    return base == null ? 0 : catalogue.thiefSkillPointsFor(base);
  }

  /// The thief skills this character may put them into, in table order.
  List<String> get thiefSkillsAvailable {
    final column = proficiencyColumn;
    if (column == null) return const [];
    final own = catalogue.thiefSkillsFor(column);
    if (own.isNotEmpty) return own;
    final base = characterClass?.identifier;
    return base == null ? const [] : catalogue.thiefSkillsFor(base);
  }

  /// Points not yet spent.
  int get thiefSkillPointsRemaining =>
      thiefSkillPoints - thiefSkills.values.fold(0, (a, b) => a + b);

  /// What has been spent, as the stats the record stores them in.
  ///
  /// The row names are the game's and each [CharacterStat] already carries its
  /// own, so this is that table read backwards rather than a second copy.
  Map<CharacterStat, int> get allocatedSkillStats => {
    for (final stat in CharacterStat.values)
      if (stat.thiefSkillRow case final String row)
        if (thiefSkills[row] case final int points) stat: points,
  };

  /// Pips not yet spent.
  int get proficiencyPipsRemaining =>
      proficiencySlots - proficiencies.values.fold(0, (a, b) => a + b);

  /// The proficiencies this class may actually take, in table order.
  ///
  /// ⚠️ **`0` in a class's column is that table's way of saying "not this
  /// class"**, so a proficiency capped at zero is left out rather than shown
  /// greyed — the creation screen offers only what can be chosen.
  List<ProficiencyEntry> get proficienciesAvailable => [
    for (final entry in catalogue.proficiencies.entries.values)
      if ((entry.maximumFor(proficiencyColumn) ?? 0) > 0) entry,
  ];

  /// The school this character specialises in, or `0` for none.
  ///
  /// From `mschool.2da`'s own numbering, which is what a spell's `SPL` header
  /// stores in both its school field and its exclusion bits.
  int get specialistSchool {
    final kit = specialisation;
    if (kit == null || kit == CreationChoice.noSpecialisation) return 0;
    return catalogue.schoolByKit[kit.identifier.toUpperCase()] ?? 0;
  }

  /// The spells this character may actually put in their book.
  ///
  /// ⚠️ **A specialist is barred from their opposed school, and the bar is in
  /// the spell rather than in any table.** Each `SPL` header carries a bit per
  /// specialist; checked and rejected as sources first: `mschool.2da` is
  /// dispel text, `kitlist.2da` has no such column, and nothing in the
  /// installation pairs a school with its opposite. Measured against the
  /// player's own spells — an Abjurer is refused exactly the four Alteration
  /// spells of first level, and a Transmuter exactly the Abjuration ones.
  List<SpellChoice> get spellsAvailable {
    final school = specialistSchool;
    if (school == 0) return catalogue.wizardSpells;
    return [
      for (final spell in catalogue.wizardSpells)
        if (!spell.excludedSchools.contains(school)) spell,
    ];
  }

  /// Whether a specialist has taken at least one spell of their own school.
  ///
  /// ⚠️ **The game requires it** — its own spellbook screen says a specialist
  /// must choose a spell from their school — and it is `true` for everyone
  /// else, so the check costs a plain mage nothing.
  bool get hasOwnSchoolSpell {
    final school = specialistSchool;
    if (school == 0) return true;
    return knownSpells.any(
      (resref) => catalogue.wizardSpells
          .where((spell) => spell.resref == resref)
          .any((spell) => spell.school == school),
    );
  }

  /// How many first-level spells may go in the book.
  int get spellsLearnable => characterClass == null
      ? 0
      : catalogue.spellsLearnableFor(characterClass!.identifier);

  /// How many of those may be prepared.
  int get spellsMemorisable => characterClass == null
      ? 0
      : catalogue.spellsMemorisableFor(characterClass!.identifier);

  /// What the game says about [resref], ready to draw, or `null`.
  ///
  /// **One string is the whole panel.** The `SPL`'s description strref holds
  /// the name, the school in brackets, the six stat lines and the prose —
  /// exactly what the engine's own spell screen shows, so nothing here
  /// composes or reformats it.
  ///
  /// ⚠️ **It carries pronoun tokens**, which is why this lives beside the
  /// gender that resolves them rather than in the widget: Burning Hands reads
  /// *"a jet of searing flame shoots from `<PRO_HISHER>` fingertips"*, and
  /// drawing it unsubstituted prints markup at the player.
  String? spellDescription(String resref) {
    final spell = catalogue.wizardSpells
        .where((spell) => spell.resref == resref)
        .firstOrNull;
    final text = catalogue.textFor(spell?.descriptionStrref);
    return text == null ? null : substituteTokens(text, genderId: genderId);
  }

  /// Whether this character puts spells in a book at all.
  bool get castsSpells =>
      characterClass != null &&
      catalogue.castsWizardSpells(characterClass!.identifier);

  /// Points rolled but not yet placed.
  int get abilityPointsRemaining =>
      abilityPoints - abilities.values.fold(0, (a, b) => a + b);

  /// Whether the dice have been thrown at all.
  bool get hasRolled => abilities.isNotEmpty;

  /// Whether there is a kept roll to go back to.
  bool get hasStoredRoll => storedAbilities != null;

  /// The range [ability] may be moved within, for this race and class.
  ({int minimum, int maximum}) boundsFor(CreationAbility ability) {
    if (race == null || characterClass == null) {
      return (minimum: ability.stat.minimum, maximum: ability.stat.maximum);
    }
    return catalogue.abilityBoundsFor(
      raceId: race!.value,
      characterClass: characterClass!.identifier,
      kit: specialisation == CreationChoice.noSpecialisation
          ? null
          : specialisation?.identifier,
      ability: ability,
    );
  }

  /// The steps this character actually has, in order.
  ///
  /// Three of the ten are conditional, and every condition is a table's answer
  /// rather than a rule written here:
  ///
  /// - [CreationStep.kit] is absent for every multi-class and for Shaman,
  ///   because `kitlist.2da` gives them none.
  /// - [CreationStep.proficiencies] is absent when `profs.2da` gives no slots,
  ///   which on a machine with no installation is every class.
  /// - [CreationStep.spells] is absent for anyone the spell progressions say
  ///   casts nothing at first level — including a **bard**, whose own table
  ///   simply starts at second.
  List<CreationStep> get steps => [
    for (final step in CreationStep.values)
      if (switch (step) {
        CreationStep.kit => specialisationsAvailable.isNotEmpty,
        CreationStep.proficiencies => proficiencySlots > 0,
        // Both tables have to agree there is something to do here.
        CreationStep.thiefSkills =>
          thiefSkillPoints > 0 && thiefSkillsAvailable.isNotEmpty,
        CreationStep.spells => castsSpells,
        _ => true,
      })
        step,
  ];

  /// Whether [step] has an answer.
  bool answered(CreationStep which) => switch (which) {
    CreationStep.gender => genderId != null,
    CreationStep.portrait => portraitName != null,
    CreationStep.race => race != null,
    CreationStep.characterClass => characterClass != null,
    CreationStep.kit => specialisation != null,
    CreationStep.alignment => alignmentId != null,
    // Rolled, and every point placed — the engine will not leave the screen
    // with points outstanding either.
    CreationStep.abilities => hasRolled && abilityPointsRemaining == 0,
    CreationStep.proficiencies => proficiencyPipsRemaining == 0,
    CreationStep.thiefSkills => thiefSkillPointsRemaining == 0,
    CreationStep.spells =>
      knownSpells.length == spellsLearnable &&
          memorisedSpells.length == spellsMemorisable &&
          hasOwnSchoolSpell,
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

  /// The total a roll keeps throwing until it reaches.
  ///
  /// ⚠️ **Not a rule the game states anywhere** — six 3d6 average **63**, and
  /// 85 turns up about once in eight hundred throws. It is what a player gets
  /// by holding the reroll button for ten minutes, done for them. Every point
  /// is still theirs to move afterwards, and the sheet can set any score
  /// outright, so this changes what is *convenient* rather than what is
  /// possible.
  static const int abilityTotalWanted = 85;

  /// How many throws to spend looking for [abilityTotalWanted].
  ///
  /// ⚠️ **The search is bounded because the target may be unreachable.** Six
  /// abilities capped at 17 by a race and a kit cannot total 85 at all, and a
  /// loop with no floor under it would spin for ever on exactly the character
  /// nobody tested. Whatever the best throw was is kept instead.
  static const int rollAttempts = 4000;

  /// Throws the dice for all six abilities, keeping the best of many.
  ///
  /// **3d6 each, then the race's own adjustment, then clamped into what the
  /// tables allow.** ⚠️ **D13, and the reason is that no table was found.** The
  /// installation states the *bounds* — `abracerq.2da`, `abracead.2da` and
  /// `abclasrq.2da`, which compose to exactly the numbers the engine prints —
  /// and states nothing whatever about the distribution the roller uses.
  /// `intmod`, `abclasrq` and the `mxspl*` family were all read; none of them
  /// is a dice table. So the shape here is the ordinary one, and what makes it
  /// harmless is that the player then moves every point themselves.
  ///
  /// The dice come from a provider so the flow is testable at all; `Random()`
  /// reached for inside a ViewModel is a screen no test can pin.
  void roll() {
    final dice = ref.read(abilityDiceProvider);

    var best = <CreationAbility, int>{};
    var bestTotal = -1;
    for (var attempt = 0; attempt < rollAttempts; attempt++) {
      final rolled = _throwDice(dice);
      final total = rolled.values.fold<int>(0, (a, b) => a + b);
      if (total > bestTotal) {
        best = rolled;
        bestTotal = total;
      }
      if (total >= abilityTotalWanted) break;
    }

    state = state.copyWith(abilities: best, abilityPoints: bestTotal);
  }

  /// One throw: 3d6 an ability, plus the race's adjustment, clamped.
  Map<CreationAbility, int> _throwDice(Random dice) {
    final rolled = <CreationAbility, int>{};
    for (final ability in CreationAbility.values) {
      final bounds = state.boundsFor(ability);
      final adjustment = state.race == null
          ? 0
          : state.catalogue.abilityAdjustmentsFor(
                  state.race!.value,
                )[ability.adjustmentColumn] ??
                0;
      var total = adjustment;
      for (var die = 0; die < _dicePerAbility; die++) {
        total += dice.nextInt(_dieSides) + 1;
      }
      rolled[ability] = total.clamp(bounds.minimum, bounds.maximum);
    }
    return rolled;
  }

  /// Spends one point on [ability], if there is one and it has room.
  ///
  /// Silently does nothing where the engine's own button would be dead. A
  /// refusal that throws would make every screen guard against it.
  void raiseAbility(CreationAbility ability) {
    final current = state.abilities[ability];
    if (current == null || state.abilityPointsRemaining <= 0) return;
    if (current >= state.boundsFor(ability).maximum) return;
    state = state.copyWith(
      abilities: {...state.abilities, ability: current + 1},
    );
  }

  /// Takes a point back off [ability], if it is above its floor.
  void lowerAbility(CreationAbility ability) {
    final current = state.abilities[ability];
    if (current == null || current <= state.boundsFor(ability).minimum) return;
    state = state.copyWith(
      abilities: {...state.abilities, ability: current - 1},
    );
  }

  /// Keeps the current roll, so a worse one can be undone.
  void storeRoll() {
    if (!state.hasRolled) return;
    state = state.copyWith(
      storedAbilities: Map.of(state.abilities),
      storedAbilityPoints: state.abilityPoints,
    );
  }

  /// Puts back the roll [storeRoll] kept, if there is one.
  void recallRoll() {
    final kept = state.storedAbilities;
    if (kept == null) return;
    state = state.copyWith(
      abilities: Map.of(kept),
      abilityPoints: state.storedAbilityPoints ?? 0,
    );
  }

  /// Puts [points] into [row], as long as the pool can pay for it.
  ///
  /// **Absolute rather than incremental**, unlike the proficiency pips: a skill
  /// runs 0 to 100 in steps a slider makes, and applying a delta would need the
  /// caller to know the current value to avoid drifting.
  ///
  /// ⚠️ **Refuses silently in two cases**, both of which the screen already
  /// prevents and neither of which should be able to reach the record: a skill
  /// this class may not allocate at all, and more points than remain. A
  /// creation flow that could overspend would write a character the engine
  /// never offers.
  void allocateSkill(String row, int points) {
    if (points < 0) return;
    if (!state.thiefSkillsAvailable.contains(row)) return;

    final current = state.thiefSkills[row] ?? 0;
    if (points - current > state.thiefSkillPointsRemaining) return;

    // Dropping to zero removes the entry, for the same reason a proficiency
    // does: a stored zero and an unspent skill are the same thing, and only one
    // of them should be written down.
    final skills = {...state.thiefSkills};
    if (points == 0) {
      skills.remove(row);
    } else {
      skills[row] = points;
    }
    state = state.copyWith(thiefSkills: skills);
  }

  /// Puts one more pip into [proficiencyId], if there is one to spend.
  ///
  /// Three ceilings, from three tables: `profs.2da` says how many pips exist,
  /// and `profsmax.2da` and `weapprof.2da` between them say how many may go
  /// into any one — see [CreationState.rankCapFor], which is where the two
  /// meet and why neither alone is the answer.
  void raiseProficiency(int proficiencyId) {
    if (state.proficiencyPipsRemaining <= 0) return;
    final current = state.proficiencies[proficiencyId] ?? 0;
    if (current >= state.rankCapFor(proficiencyId)) return;
    state = state.copyWith(
      proficiencies: {...state.proficiencies, proficiencyId: current + 1},
    );
  }

  /// Takes a pip back out of [proficiencyId].
  ///
  /// Dropping to zero **removes** the entry rather than storing a zero: a
  /// proficiency at no pips is one the character does not have, and writing an
  /// opcode 233 effect granting nothing would be a record the engine never
  /// makes.
  void lowerProficiency(int proficiencyId) {
    final current = state.proficiencies[proficiencyId] ?? 0;
    if (current <= 0) return;
    state = state.copyWith(
      proficiencies: {
        for (final entry in state.proficiencies.entries)
          if (entry.key != proficiencyId)
            entry.key: entry.value
          else if (entry.value > 1)
            entry.key: entry.value - 1,
      },
    );
  }

  /// Puts [resref] in the book, or takes it out again.
  ///
  /// ⚠️ **Taking one out forgets it was prepared**, because the memorise screen
  /// only ever lists spells that are in the book — a prepared spell nobody
  /// knows is a record the engine does not produce.
  void learnSpell(String resref) {
    if (state.knownSpells.contains(resref)) {
      state = state.copyWith(
        knownSpells: [...state.knownSpells]..remove(resref),
        memorisedSpells: [...state.memorisedSpells]..remove(resref),
      );
      return;
    }
    if (state.knownSpells.length >= state.spellsLearnable) return;
    state = state.copyWith(knownSpells: [...state.knownSpells, resref]);
  }

  /// Prepares [resref], or unprepares it. Only a spell in the book may be.
  void memoriseSpell(String resref) {
    if (state.memorisedSpells.contains(resref)) {
      state = state.copyWith(
        memorisedSpells: [...state.memorisedSpells]..remove(resref),
      );
      return;
    }
    if (!state.knownSpells.contains(resref)) return;
    if (state.memorisedSpells.length >= state.spellsMemorisable) return;
    state = state.copyWith(
      memorisedSpells: [...state.memorisedSpells, resref],
    );
  }

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

  /// What the game's tables say this character's record should hold.
  ///
  /// ⚠️ **Separate from the player's own choices, and D14 is why.** The engine
  /// overwrites six fields on import and leaves sixty-seven alone; the saving
  /// throws, THAC0 and Lore below are all in the sixty-seven, so a character
  /// created without them keeps the template's values for the whole game.
  ///
  /// Empty when the class has not been chosen yet, and short by whatever the
  /// tables could not answer — a machine with no installation writes nothing
  /// rather than zeros.
  Map<CharacterStat, int> derivedStats() {
    final identifier = state.characterClass?.identifier;
    if (identifier == null) return const {};

    return derivedStatsFor(
      rules: ref.read(gameRulesProvider),
      classIdentifier: identifier,
      raceIdentifier: state.race?.identifier,
      levels: state.classLevels,
      constitution: state.abilities[CreationAbility.constitution] ?? 0,
    );
  }
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
