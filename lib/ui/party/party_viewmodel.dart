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
import 'package:wand_of_saves/data/rules_catalogues.dart';
import 'package:wand_of_saves/data/save_editor.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/character_file.dart';
import 'package:wand_of_saves/domain/edit_command.dart';
import 'package:wand_of_saves/domain/proficiency_catalogue.dart';
import 'package:wand_of_saves/domain/save_slot.dart';
import 'package:wand_of_saves/domain/skill_catalogue.dart';
import 'package:wand_of_saves/ui/edit_session.dart';

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

/// The names companions do not carry in the savegame, resolved once.
///
/// ⚠️ **A query, because the shell now rebuilds on every edit.** Editing a stat
/// cannot change a name, and re-resolving the whole party through the talk
/// table every time a digit is typed is exactly what the mutable `_names` map
/// existed to avoid. Memoised by Riverpod instead of by hand.
final FutureProviderFamily<Map<int, String>, String> partyNamesProvider =
    FutureProvider.family<Map<int, String>, String>(
      retry: neverRetry,
      isAutoDispose: true,
      (ref, directoryName) async {
        final slot = await ref.watch(saveSlotProvider(directoryName).future);
        if (slot == null) return const {};

        final saves = ref.watch(saveGameRepositoryProvider);
        final strings = ref.watch(stringRepositoryProvider);
        final names = <int, String>{};
        final party = charactersFrom(await saves.load(slot), slot);
        for (final (position, member) in party.indexed) {
          if (member.name.isNotEmpty) continue;
          // The chain is savegame → talk table → resref. Both of the first two
          // legs occur in real data: the protagonist's name is in the savegame
          // and their creature record says -1, while every recruitable
          // companion is the other way round.
          //
          // ⚠️ **Keyed by party POSITION, never by `creOffset`.** This map is
          // built from the file on disk and read against the live edited
          // document, and a resizing edit moves every record after the one it
          // grew — so an offset key misses for exactly those members and the
          // fallback prints a raw resref like `*AHEIR` on screen. Position is
          // what a relocation cannot change: `withCreature` splices bytes and
          // shifts pointers, it never reorders the party array.
          names[position] =
              await strings.lookup(member.nameStrref) ?? member.creResref;
        }
        return names;
      },
    );

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

  /// The savegame being edited, and everything the player could take back.
  ///
  /// **One immutable value, replaced whole**, where this used to keep four
  /// mutable fields — `_working`, `_onDisk`, `_undoStack`, `_redoStack` — that
  /// could disagree with each other. `EditSession` is shared with the character
  /// editor, so undo, redo and "dirty" are defined once for both documents and
  /// tested on their own.
  ///
  /// ⚠️ **Held here rather than in a provider of its own, and that was
  /// measured rather than assumed.** A session provider is the tidier shape and
  /// it was tried: it makes every edit an *asynchronous* rebuild of this
  /// notifier, because `build` awaits three queries. The party shell would then
  /// pass through `AsyncLoading` on every committed keystroke — a spinner where
  /// a number should be. Editing has to update state synchronously; the
  /// existing tests caught this within a minute of the attempt.
  ///
  /// It never reaches a widget: [PartyState] carries domain models only, so no
  /// `infinity_formats` type crosses into the view layer.
  EditSession<Gam>? _session;

  /// Which member the detail pane is showing.
  int _selectedIndex = 0;

  @override
  Future<PartyState> build() async {
    final slot = await ref.watch(saveSlotProvider(directoryName).future);
    if (slot == null) throw SaveNotFoundException(directoryName);

    final gam = await ref.watch(saveGameRepositoryProvider).load(slot);
    _session = EditSession.opened(gam);
    _selectedIndex = 0;

    return _projected(
      slot,
      names: await ref.watch(partyNamesProvider(directoryName).future),
      // One query, watched by both editors, rather than the same
      // cross-repository merge run once per editor.
      catalogues: await ref.watch(rulesCataloguesProvider.future),
    );
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
    _selectedIndex = index;
    state = AsyncData(current.copyWith(selectedIndex: index));
  }

  /// Applies [command] to the working copy.
  ///
  /// Nothing is written to disk here — [save] does that. Throws
  /// [InvalidEditException] if the value is outside what the stat accepts;
  /// the view checks the range first so it can show the error in place.
  void edit(EditCommand command) =>
      _change((s) => s.edited(applyEdit(s.document, command)));

  /// Takes back the most recent edit.
  void undo() => _change((s) => s.undone());

  /// Puts back the most recently undone edit.
  void redo() => _change((s) => s.redone());

  /// Writes the working copy over the savegame, leaving a `.bak`.
  ///
  /// Does nothing when there is nothing to save: the browser sorts slots by
  /// modification time, so an idle write would reorder the grid for no reason.
  Future<void> save() async {
    final current = state.value;
    final session = _session;
    if (current == null || session == null || !session.isDirty) return;

    await ref
        .read(saveGameRepositoryProvider)
        .write(current.slot, session.document);
    _session = session.saved();
    state = AsyncData(current.copyWith(isDirty: false));
    // ⚠️ Exactly the list that changed. The browser's card for this save shows
    // its gold and party size, so it has to re-read — but nothing about the
    // characters moved, and re-reading those too was what a global signal
    // could not avoid.
    ref.invalidate(saveSlotsProvider);
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
  Future<CharacterFile> export(String fileName) async {
    final current = state.value;
    final session = _session;
    if (current == null || session == null) {
      throw StateError('there is no savegame open to export from');
    }

    final members = session.document.partyMembers;
    final index = current.selectedIndex;
    if (index < 0 || index >= members.length) {
      throw StateError('there is no character selected to export');
    }

    final created = await ref
        .read(characterFileRepositoryProvider)
        .create(fileName, ChrCodec.exportOf(members[index]));
    // A new character has appeared in the lineup.
    ref.invalidate(characterFilesProvider);
    return created;
  }

  /// Applies [next] to the session and republishes the view state.
  ///
  /// **Synchronously**, which is the whole reason the session lives here — see
  /// [_session].
  void _change(EditSession<Gam> Function(EditSession<Gam>) next) {
    final current = state.value;
    final session = _session;
    if (current == null || session == null) return;

    _session = next(session);
    state = AsyncData(
      _projected(
        current.slot,
        names: const {},
        catalogues: (
          proficiencies: current.proficiencies,
          skills: current.skills,
        ),
        keepNamesFrom: current.members,
      ),
    );
  }

  /// The working copy as the view sees it.
  PartyState _projected(
    SaveSlot slot, {
    required Map<int, String> names,
    required RulesCatalogues catalogues,
    List<Character>? keepNamesFrom,
  }) {
    // ⚠️ **Keyed by party position** — see [partyNamesProvider] for why an
    // offset key silently loses the name of every member below a resizing edit.
    final resolved = {
      for (final (position, member)
          in (keepNamesFrom ?? const <Character>[]).indexed)
        position: member.name,
      ...names,
    };
    final session = _session!;

    return PartyState(
      slot: slot,
      members: [
        for (final (position, member) in charactersFrom(
          session.document,
          slot,
        ).indexed)
          member.name.isNotEmpty
              ? member
              : member.copyWith(
                  name: resolved[position] ?? member.creResref,
                ),
      ],
      reputation: session.document.reputation,
      proficiencies: catalogues.proficiencies,
      skills: catalogues.skills,
      selectedIndex: _selectedIndex,
      isDirty: session.isDirty,
      canUndo: session.canUndo,
      canRedo: session.canRedo,
    );
  }
}

/// The party shell's state, per save slot directory name.
///
/// Keyed by directory name rather than holding a `SaveSlot`, so the route
/// parameter is enough to rebuild this from scratch after a reload.
///
/// ⚠️ **Deliberately NOT `isAutoDispose`, against the rule its being a family
/// would otherwise imply.** Riverpod recommends automatic disposal for
/// families because one state per parameter is a leak — but this state is an
/// **open document with unsaved edits and an undo history**, and discarding it
/// the moment no widget happens to be watching would throw away the player's
/// work. The leak here is bounded by how many saves someone opens in a
/// session; the alternative loses data.
final AsyncNotifierProviderFamily<PartyViewModel, PartyState, String>
partyProvider =
    AsyncNotifierProvider.family<PartyViewModel, PartyState, String>(
      PartyViewModel.new,
    );
