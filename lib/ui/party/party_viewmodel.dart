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
// Riverpod keeps the family provider *types* in its own `misc` library, since
// they are rarely written out. `specify_nonobvious_property_types` requires
// naming this one, so the import is the honest way to satisfy it (D8).
import 'package:flutter_riverpod/misc.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/data/party_projection.dart';
import 'package:wand_of_saves/data/repositories/character_file_repository.dart';
import 'package:wand_of_saves/data/rules_catalogues.dart';
import 'package:wand_of_saves/data/save_editor.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/character_file.dart';
import 'package:wand_of_saves/domain/edit_command.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/domain/save_slot.dart';
import 'package:wand_of_saves/domain/skill_catalogue.dart';

part 'party_viewmodel.mapper.dart';

/// Raised when the route names a save that is no longer there.
///
/// The repository answers `null` — an absent save is not its problem to judge.
/// It is this screen's, because a party editor with nothing to edit has
/// nothing to show, so the decision to treat it as a failure is made here.
class SaveNotFoundException implements Exception {
  /// Names the save that could not be found.
  const SaveNotFoundException(this.directoryName);

  /// The save slot directory the route asked for.
  final String directoryName;

  @override
  String toString() =>
      'No savegame named "$directoryName". It may have been deleted or '
      'overwritten while this window was open.';
}

/// Everything the party shell renders.
///
/// A value class rather than three loose fields on the notifier: `select`
/// rebuilds it through `copyWith`, and equality means re-selecting the member
/// who is already selected does not repaint the rail. `dart_mappable` gives
/// list fields `IterableEquality`, so [members] compares by content.
@MappableClass()
class PartyState with PartyStateMappable {
  /// Creates the party shell's state.
  const PartyState({
    required this.slot,
    required this.members,
    required this.reputation,
    this.proficiencies = ProficiencyCatalogue.empty,
    this.skills = SkillCatalogue.empty,
    this.selectedIndex = 0,
    this.isDirty = false,
    this.canUndo = false,
    this.canRedo = false,
  });

  /// The savegame being edited.
  final SaveSlot slot;

  /// The party, in the order the savegame stores them.
  ///
  /// **Domain models only — no savegame bytes reach the view.** The working
  /// copy lives in private fields on the notifier, so a widget can render this
  /// without any way to reach into the file.
  final List<Character> members;

  /// The party's reputation, as displayed.
  ///
  /// ⚠️ **The GAM's, not the creature's, and they genuinely differ.** Every
  /// creature record carries a reputation byte of its own, and it is easy to
  /// assume the engine reads it. Measured in game 2026-08-08 on the
  /// four-member save: the GAM held 11.0 and BG:EE printed "Average (11)" on
  /// Xzar's record screen, while Xzar's own record held 10.0 — as did
  /// Montaron's and Imoen's. Only the protagonist's copy agreed.
  ///
  /// The companions' copies are simply stale; the engine never consults them.
  /// The panel used to show one, against a game showing something else, under
  /// a tooltip asserting the two matched.
  final double reputation;

  /// What the game calls each proficiency, and how many pips it allows.
  ///
  /// Merged from two repositories — the player's `weapprof.2da` for the rows
  /// and their talk table for the text. Empty on a machine with no game
  /// installed, which the panel degrades to numbers for rather than failing.
  final ProficiencyCatalogue proficiencies;

  /// Which thief skills each class may allocate points to.
  ///
  /// The player's own `thiefscl.2da`. Empty on a machine with no game
  /// installed, which the panel reads as "allow everything" rather than
  /// "forbid everything" — refusing edits on the strength of a table that was
  /// never read would be a broken screen.
  final SkillCatalogue skills;

  /// Which member the detail pane is showing.
  final int selectedIndex;

  /// Whether there are edits the file does not have yet.
  final bool isDirty;

  /// Whether there is an edit to take back.
  final bool canUndo;

  /// Whether there is an undone edit to put back.
  final bool canRedo;

  /// The member on screen, or `null` when the party is empty.
  Character? get selected => members.elementAtOrNull(selectedIndex);
}

/// ViewModel for the party shell, paired 1:1 with `PartyView`.
///
/// It merges two repositories — the savegame for the party, the talk table for
/// the names companions do not carry in the save. That merge lives here
/// deliberately: **repositories must never be aware of each other**, and the
/// architecture puts cross-repository logic in the ViewModel or a use-case.
/// One ViewModel needs it today, so it is here; it moves to a use-case when a
/// second one does.
class PartyViewModel extends AsyncNotifier<PartyState> {
  /// Views the party in the save slot directory named [directoryName].
  PartyViewModel(this.directoryName);

  /// The save slot directory the route named.
  final String directoryName;

  /// The savegame as edited so far.
  ///
  /// **Private, and never placed in [PartyState].** The rule that no
  /// `infinity_formats` type reaches a widget is what this preserves; the
  /// session state has to live somewhere, and a second notifier behind this
  /// one rebuilt on every edit, which snapped the selection back to the first
  /// character mid-typing. One notifier with a private working copy keeps both
  /// properties.
  Gam? _working;

  /// The savegame as the file has it — identical to [_working] when clean.
  ///
  /// Compared by identity, which is exactly right: undoing back to the loaded
  /// snapshot restores *that same object*, so "nothing to save" needs no
  /// byte comparison.
  Gam? _onDisk;

  /// Snapshots to go back to, oldest first.
  ///
  /// Whole savegames rather than inverse commands. A 96 KB buffer per edit
  /// costs nothing, and an inverse command that reconstructs a previous value
  /// is one more place to get a save subtly wrong.
  final List<Gam> _undoStack = [];

  /// Snapshots to go forward to.
  final List<Gam> _redoStack = [];

  /// Names resolved once at load, by creature offset.
  ///
  /// Editing a stat cannot change a name, so the talk-table lookups happen on
  /// load and are reapplied afterwards — rather than re-resolving the whole
  /// party every time a digit is typed.
  final Map<int, String> _names = {};

  /// The proficiency table, named, resolved once at load.
  ///
  /// ⚠️ **The merge itself has moved out** — see `loadRulesCatalogues`. It sat
  /// here under a note saying it would go to a use-case when a second ViewModel
  /// needed it, and `CharacterFileViewModel` is that second one.
  ProficiencyCatalogue _proficiencies = ProficiencyCatalogue.empty;

  /// Which thief skills this character's class may allocate, resolved once at
  /// load. No talk-table merge: `thiefscl.2da` is numbers all the way down.
  SkillCatalogue _skills = SkillCatalogue.empty;

  @override
  Future<PartyState> build() async {
    final saves = ref.watch(saveGameRepositoryProvider);
    final slot = await saves.slotNamed(directoryName);
    if (slot == null) throw SaveNotFoundException(directoryName);

    final gam = await saves.load(slot);
    _working = gam;
    _onDisk = gam;
    _undoStack.clear();
    _redoStack.clear();

    final strings = ref.watch(stringRepositoryProvider);
    _names.clear();
    for (final member in charactersFrom(gam, slot)) {
      if (member.name.isNotEmpty) continue;
      // The chain is savegame → talk table → resref. Both of the first two
      // legs occur in real data: the protagonist's name is in the savegame and
      // their creature record says -1, while every recruitable companion is
      // the other way round.
      _names[member.creOffset] =
          await strings.lookup(member.nameStrref) ?? member.creResref;
    }

    final catalogues = await loadRulesCatalogues(
      resources: ref.watch(resourceRepositoryProvider),
      strings: strings,
    );
    _proficiencies = catalogues.proficiencies;
    _skills = catalogues.skills;

    return _projected(slot, selectedIndex: 0);
  }

  /// Shows the member at [index] in the detail pane.
  ///
  /// Out-of-range indices are ignored rather than clamped or thrown: the view
  /// builds its rail from [PartyState.members], so this cannot happen by a
  /// route the user can take, and leaving the selection where it is beats
  /// moving it somewhere they did not ask for.
  void select(int index) {
    final current = state.value;
    if (current == null) return;
    if (index < 0 || index >= current.members.length) return;
    state = AsyncData(current.copyWith(selectedIndex: index));
  }

  /// Applies [command] to the working copy.
  ///
  /// Nothing is written to disk here — [save] does that. Throws
  /// [InvalidEditException] if the value is outside what the stat accepts;
  /// the view checks the range first so it can show the error in place.
  void edit(EditCommand command) {
    final current = state.value;
    final working = _working;
    if (current == null || working == null) return;

    _undoStack.add(working);
    _working = applyEdit(working, command);
    // A redo stack kept across a fresh edit would reapply an edit onto a
    // history it was never taken from.
    _redoStack.clear();
    state = AsyncData(
      _projected(current.slot, selectedIndex: current.selectedIndex),
    );
  }

  /// Takes back the most recent edit.
  void undo() => _step(from: _undoStack, to: _redoStack);

  /// Puts back the most recently undone edit.
  void redo() => _step(from: _redoStack, to: _undoStack);

  /// Writes the working copy over the savegame, leaving a `.bak`.
  ///
  /// Does nothing when there is nothing to save: the browser sorts slots by
  /// modification time, so an idle write would reorder the grid for no reason.
  Future<void> save() async {
    final current = state.value;
    final working = _working;
    if (current == null || working == null || working == _onDisk) return;

    await ref.read(saveGameRepositoryProvider).write(current.slot, working);
    _onDisk = working;
    state = AsyncData(
      _projected(current.slot, selectedIndex: current.selectedIndex),
    );
  }

  /// Writes the selected member to `characters/` as [fileName].
  ///
  /// **The other output path, and the safer one** — it creates a new file and
  /// never touches the savegame. It is also how the player gets a character out
  /// of one game and into another: BG:EE's own EXPORT button is on the Record
  /// screen of a saved game, and its IMPORT button starts a new one.
  ///
  /// ⚠️ **Exports the working copy, unsaved edits included.** That is the
  /// workflow: change the character, then export. Writing the on-disk copy
  /// instead would silently drop the edit the player is looking at.
  ///
  /// ⚠️ **Not a save.** The dirty marker is deliberately untouched, so someone
  /// who exports and then closes the window is still warned about the savegame
  /// edits they have not written.
  ///
  /// Throws [CharacterFileExistsException] if the name is taken, and
  /// [StateError] if there is no character selected to export.
  Future<CharacterFile> export(String fileName) async {
    final current = state.value;
    final working = _working;
    if (current == null || working == null) {
      throw StateError('there is no savegame open to export from');
    }

    final members = working.partyMembers;
    final index = current.selectedIndex;
    if (index < 0 || index >= members.length) {
      throw StateError('there is no character selected to export');
    }

    return ref
        .read(characterFileRepositoryProvider)
        .create(fileName, ChrCodec.exportOf(members[index]));
  }

  void _step({required List<Gam> from, required List<Gam> to}) {
    final current = state.value;
    final working = _working;
    if (current == null || working == null || from.isEmpty) return;

    to.add(working);
    _working = from.removeLast();
    state = AsyncData(
      _projected(current.slot, selectedIndex: current.selectedIndex),
    );
  }

  /// The working copy as the view sees it.
  PartyState _projected(SaveSlot slot, {required int selectedIndex}) {
    final members = charactersFrom(_working!, slot);
    return PartyState(
      slot: slot,
      members: [
        for (final member in members)
          member.name.isNotEmpty
              ? member
              : member.copyWith(
                  name: _names[member.creOffset] ?? member.creResref,
                ),
      ],
      reputation: _working!.reputation,
      proficiencies: _proficiencies,
      skills: _skills,
      selectedIndex: selectedIndex,
      isDirty: _working != _onDisk,
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
    );
  }
}

/// The party shell's state, per save slot directory name.
///
/// Keyed by directory name rather than holding a `SaveSlot`, so the route
/// parameter is enough to rebuild this from scratch after a reload.
final AsyncNotifierProviderFamily<PartyViewModel, PartyState, String>
partyProvider =
    AsyncNotifierProvider.family<PartyViewModel, PartyState, String>(
      PartyViewModel.new,
    );
