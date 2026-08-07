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
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/data/repositories/string_repository.dart';
import 'package:wand_of_saves/domain/character.dart';
import 'package:wand_of_saves/domain/save_slot.dart';

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
    this.selectedIndex = 0,
  });

  /// The savegame being edited.
  final SaveSlot slot;

  /// The party, in the order the savegame stores them.
  final List<Character> members;

  /// Which member the detail pane is showing.
  final int selectedIndex;

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

  @override
  Future<PartyState> build() async {
    final saves = ref.watch(saveGameRepositoryProvider);
    final slot = await saves.slotNamed(directoryName);
    if (slot == null) throw SaveNotFoundException(directoryName);

    final strings = ref.watch(stringRepositoryProvider);
    final members = await saves.party(slot);

    return PartyState(
      slot: slot,
      members: [
        for (final member in members) await _named(member, strings),
      ],
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
    state = AsyncData(current.copyWith(selectedIndex: index));
  }

  /// Fills in [Character.name] when the savegame did not carry one.
  ///
  /// The chain is savegame → talk table → resref. Both of the first two legs
  /// occur in real data: the protagonist's name is in the savegame and their
  /// creature record says `-1`, while every recruitable companion is the other
  /// way round.
  Future<Character> _named(Character member, StringRepository strings) async {
    if (member.name.isNotEmpty) return member;
    final resolved = await strings.lookup(member.nameStrref);
    return member.copyWith(name: resolved ?? member.creResref);
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
