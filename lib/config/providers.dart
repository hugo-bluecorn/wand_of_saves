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

/// The dependency graph, declared by hand.
///
/// No `@riverpod`, no `*.g.dart` for providers (D2) — these are written out as
/// top-level finals so the graph is readable in one place rather than inferred
/// from annotations scattered across the tree. Riverpod *is* the DI container
/// here (D7); there is no second wiring mechanism.
///
/// Overriding any of these in a `ProviderScope` is the testing seam, which is
/// why the repository is an interface.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod keeps the family provider *types* in its own `misc` library, since
// they are rarely written out. `specify_nonobvious_property_types` requires
// naming this one, so the import is the honest way to satisfy it (D8).
import 'package:flutter_riverpod/misc.dart';
import 'package:wand_of_saves/data/creation_catalogue_loading.dart';
import 'package:wand_of_saves/data/item_catalogue_loading.dart';
import 'package:wand_of_saves/data/name_tables_loading.dart';
import 'package:wand_of_saves/data/repositories/character_file_repository.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/repositories/save_game_repository.dart';
import 'package:wand_of_saves/data/repositories/string_repository.dart';
import 'package:wand_of_saves/data/rules_catalogues.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/data/services/portrait_import_service.dart';
import 'package:wand_of_saves/data/services/recycle_service.dart';
import 'package:wand_of_saves/domain/character_file.dart';
import 'package:wand_of_saves/domain/creation_catalogue.dart';
import 'package:wand_of_saves/domain/document_ref.dart';
import 'package:wand_of_saves/domain/item_catalogue.dart';
import 'package:wand_of_saves/domain/rules/game_rules.dart';
import 'package:wand_of_saves/domain/rules/hit_die_tables.dart';
import 'package:wand_of_saves/domain/rules/name_tables.dart';
import 'package:wand_of_saves/domain/rules/rules_tables.dart';
import 'package:wand_of_saves/domain/rules/saving_throw_tables.dart';
import 'package:wand_of_saves/domain/save_slot.dart';

/// Locates the game installation and save directory on this machine.
final gameProfileServiceProvider = Provider<GameProfileService>(
  (ref) => const GameProfileService(),
);

/// Source of truth for savegames.
final saveGameRepositoryProvider = Provider<SaveGameRepository>(
  (ref) => FileSaveGameRepository(
    profile: ref.watch(gameProfileServiceProvider),
  ),
);

/// Source of truth for exported characters — the `.chr` files beside the saves.
///
/// A peer of [saveGameRepositoryProvider], not a detail of it: a character file
/// is a document in its own right, and one this app creates never came from a
/// savegame at all.
final characterFileRepositoryProvider = Provider<CharacterFileRepository>(
  (ref) => FileCharacterFileRepository(
    profile: ref.watch(gameProfileServiceProvider),
  ),
);

/// Moves deleted saves and characters somewhere they can be fetched back from.
///
/// ⚠️ **Deletion is the only operation in this app with no `.bak`**, so it gets
/// one of its own: nothing is unlinked, everything is moved beside the save
/// root where neither this app nor the game will look.
final recycleServiceProvider = Provider<RecycleService>(
  (ref) => RecycleService(profile: ref.watch(gameProfileServiceProvider)),
);

/// What the installation calls races, classes and kits.
///
/// Its own query so naming what is in a savegame does not depend on anything
/// about *creating* one, and so a machine with no game installed simply gets an
/// empty answer rather than an error.
final nameTablesProvider = FutureProvider<NameTables>(
  retry: neverRetry,
  (ref) => loadNameTables(
    resources: ref.watch(resourceRepositoryProvider),
    strings: ref.watch(stringRepositoryProvider),
  ),
);

/// How many hit points each class gains per level, from the installation.
final hitDieTablesProvider = FutureProvider<HitDieTables>(
  retry: neverRetry,
  (ref) => ref.watch(resourceRepositoryProvider).hitDieTables(),
);

/// The five saving-throw progressions, from the installation.
///
/// Its own query rather than a field of [hitDieTablesProvider]'s: they are
/// different files answering different questions, and a query is the unit that
/// gets invalidated (D12).
final savingThrowTablesProvider = FutureProvider<SavingThrowTables>(
  retry: neverRetry,
  (ref) => ref.watch(resourceRepositoryProvider).savingThrowTables(),
);

/// THAC0, Lore, thief-skill points and the display modifiers.
final rulesTablesProvider = FutureProvider<RulesTables>(
  retry: neverRetry,
  (ref) => ref.watch(resourceRepositoryProvider).rulesTables(),
);

/// The rules, over whatever names could be read.
///
/// ⚠️ **Stays synchronous while depending on an async read**, by taking the
/// query's value and falling back to `NameTables.empty`. Every consumer
/// `ref.watch`es this, so names sharpen from the derived fallback to the
/// installation's own the moment the tables arrive — with no screen passing
/// through a loading state to get there, and no API change anywhere.
final gameRulesProvider = Provider<GameRules>(
  (ref) => GeneratedGameRules(
    tables: ref.watch(nameTablesProvider).value ?? NameTables.empty,
    hitDice: ref.watch(hitDieTablesProvider).value ?? HitDieTables.empty,
    savingThrows:
        ref.watch(savingThrowTablesProvider).value ?? SavingThrowTables.empty,
    rulesTables: ref.watch(rulesTablesProvider).value ?? RulesTables.empty,
  ),
);

/// Source of truth for the rules tables inside the game's own archives.
///
/// **Not the same thing as [gameRulesProvider], and the difference is D11.**
/// That one is a snapshot generated from IESDP, which is right for tables of
/// pure numbers. This one reads the player's installation, which is the only
/// correct source for anything whose values are string references — IESDP
/// ships the BG2:EE `weapprof.2da`, and its strrefs name tutorial prose in a
/// BG:EE talk table.
///
/// On a machine with no game installed this answers an empty catalogue —
/// no second implementation, because there is no open file to stand in for.
final resourceRepositoryProvider = Provider<ResourceRepository>(
  (ref) => ResourceRepository(ref.watch(gameProfileServiceProvider)),
);

/// Puts a portrait of the player's own where the engine looks first.
///
/// The whole of what a "custom portrait" is: a loose file in
/// `<user data>/portraits/` shadows a packed one of the same name, so the same
/// two CRE resrefs serve either and nothing else in the app needs to know
/// which it got.
final portraitImportServiceProvider = Provider<PortraitImportService>(
  (ref) => PortraitImportService(
    profile: ref.watch(gameProfileServiceProvider),
  ),
);

/// A character's portrait, by base name — the picture the record names.
///
/// ⚠️ **Not the same thing as a save's `PORTRT<n>.bmp`.** That sidecar is what
/// the engine drew when the file was written, hit points baked in, and it goes
/// stale as soon as anything is edited; an exported character has none at all.
/// This is the clean portrait the creature record points at, and it is the only
/// one that responds to a change.
///
/// Keyed by base name, so the `…M` variant is chosen here rather than at every
/// call site. `null` when there is no game installed, no such portrait, or the
/// character names none — all ordinary, and all drawn as a placeholder.
///
/// ⚠️ **`isAutoDispose: true` because it is a family, and that is Riverpod's
/// own rule rather than a tuning choice:** without it "one state per parameter
/// combination will be created, which can lead to memory leaks"
/// (`concepts2/auto_dispose.mdx`). The picker shows 210 portraits; scrolling it
/// would otherwise retain every one for the session.
///
/// ⚠️ **The named argument, not `.autoDispose`** — and the reason recorded
/// here until 2026-08-12 was false. It said `.autoDispose` "is codegen-only,
/// which D2 forbids"; Riverpod's own **non-codegen** snippets use it
/// (`concepts2/family/functional/raw.dart`). The real reason is that the builder
/// classes behind `.autoDispose` are `@internal`
/// (`riverpod/src/builder.dart`), while `isAutoDispose:` is what
/// `concepts2/auto_dispose.mdx` prescribes by name for hand-declared
/// providers. Same choice, checkable citation — which is what D2 rests on.
///
final FutureProviderFamily<Uint8List?, String> portraitProvider =
    FutureProvider.family<Uint8List?, String>(
      isAutoDispose: true,
      retry: neverRetry,
      (ref, baseName) {
        if (baseName.isEmpty) return Future.value();
        return ref.watch(resourceRepositoryProvider).portrait('${baseName}M');
      },
    );

/// Source of truth for the game's displayable text.
///
/// Which `dialog.tlk` to open is a fact about this machine, so the choice is
/// made here from the profile service rather than inside the repository. A
/// machine with saves but no game installed gets [AbsentStringRepository] — an
/// explicit state, not a null to thread through every caller.
final stringRepositoryProvider = Provider<StringRepository>((ref) {
  final path = ref.watch(gameProfileServiceProvider).findDialogTlk();
  if (path == null) return const AbsentStringRepository();

  final repository = TlkStringRepository(path: path);
  ref.onDispose(repository.close);
  return repository;
});

/// What the player has ticked on the home screen, across both sections.
///
/// ⚠️ **Apart from anything a re-read touches, and that is the whole point.**
/// Selection used to be a field on the browser's state, which the browser
/// rebuilds from disk — so refreshing, deleting, or an editor saving silently
/// discarded the player's ticks. Nobody reported it; it was found by reading
/// the code. Selection belongs to the player, not to the filesystem, so it
/// outlives every read.
class DocumentSelection extends Notifier<DocumentSelectionState> {
  @override
  DocumentSelectionState build() => (selected: const {}, isSelecting: false);

  /// Turns on the tick boxes.
  void start() => state = (selected: state.selected, isSelecting: true);

  /// Turns them off and forgets what was ticked.
  void cancel() => state = (selected: const {}, isSelecting: false);

  /// Ticks [document] if it is not ticked, and unticks it if it is.
  ///
  /// ⚠️ **Does not turn selection off when the last card is unticked.** A mode
  /// that vanished on an empty selection would take the player's
  /// mind-changing away from them.
  void toggle(DocumentRef document) => state = (
    selected: state.selected.contains(document)
        ? ({...state.selected}..remove(document))
        : {...state.selected, document},
    isSelecting: state.isSelecting,
  );
}

/// What is ticked, and whether the tick boxes are showing.
typedef DocumentSelectionState = ({
  Set<DocumentRef> selected,
  bool isSelecting,
});

/// The home screen's selection.
final documentSelectionProvider =
    NotifierProvider<DocumentSelection, DocumentSelectionState>(
      DocumentSelection.new,
    );

/// How this application retries a provider that fails: **never**.
///
/// ⚠️ **Riverpod retries by default** — up to ten times with an exponential
/// backoff reaching 6.4 seconds (`concepts2/retry.mdx`). That is right for a
/// flaky network and wrong for every data source here, because **all of them
/// are the local filesystem**: a missing save directory does not become
/// present by waiting, and an unreadable `chitin.key` does not become readable.
///
/// Without this, "no Baldur's Gate installed" — an *ordinary* state this app is
/// built to handle — would spin for thirteen seconds before admitting it. It
/// was caught by an existing test the moment repository reads became providers,
/// which is the first thing that made the retry visible at all.
///
/// Passed to `ProviderScope` in `main.dart` so it applies to the whole graph;
/// per-provider `retry:` exists for anything that ever genuinely should.
Duration? neverRetry(int retryCount, Object error) => null;

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------
//
// ⚠️ **A repository read the UI depends on is a provider, never an `await`
// inside a ViewModel's `build()`.** That rule was missing from
// `planning/architecture.md`, so every ViewModel invented its own imperative
// read — and reads that are method calls can be neither invalidated nor
// shared. Three defects came out of that in a single afternoon: a lineup
// showing a portrait the player had just changed, a home screen showing one
// picture and two blanks, and a selection cleared by pressing refresh.
//
// They live here rather than beside their consumers because D7 hand-declares
// the graph so it is readable in one place, and a query is part of the graph.

/// Every readable save slot, newest first.
///
/// ⚠️ **`retry: neverRetry` on each query, not only on the `ProviderScope`.**
/// A test container does not inherit the app's scope, so a policy declared
/// only in `main.dart` would make the suite exercise different behaviour from
/// the app — which is precisely how the retry default went unnoticed until a
/// read became a provider.
final saveSlotsProvider = FutureProvider<List<SaveSlot>>(
  retry: neverRetry,
  (ref) => ref.watch(saveGameRepositoryProvider).listSlots(),
);

/// Every readable exported character, newest first.
final characterFilesProvider = FutureProvider<List<CharacterFile>>(
  retry: neverRetry,
  (ref) => ref.watch(characterFileRepositoryProvider).listFiles(),
);

/// The rules tables a character sheet needs, with their names resolved.
///
/// One query watched by both editors, rather than the same cross-repository
/// merge run once per editor — two copies of it is how two screens start
/// disagreeing about what a proficiency is called.
final rulesCataloguesProvider = FutureProvider<RulesCatalogues>(
  retry: neverRetry,
  (ref) => loadRulesCatalogues(
    resources: ref.watch(resourceRepositoryProvider),
    strings: ref.watch(stringRepositoryProvider),
  ),
);

/// What this installation says a new character may be.
///
/// Its own query rather than part of [rulesCataloguesProvider], because the two
/// serve different screens: a character sheet needs proficiency names on every
/// open, and six creation tables read for it would be read for nothing.
///
/// ⚠️ **Nothing in the creation flow may `ref.watch` this from a ViewModel's
/// `build()`.** A provider's state is destroyed whenever it recomputes
/// (`concepts2/auto_dispose.mdx`), so a half-made character watching a query
/// would be thrown away the moment anything invalidated it — and the flow's own
/// portrait step invalidates [portraitNamesProvider]. `ref.listen` is how a
/// ViewModel reacts to this without depending on it.
final creationCatalogueProvider = FutureProvider<CreationCatalogue>(
  retry: neverRetry,
  (ref) => loadCreationCatalogue(
    resources: ref.watch(resourceRepositoryProvider),
    strings: ref.watch(stringRepositoryProvider),
    rules: ref.watch(gameRulesProvider),
  ),
);

/// Every item the installation ships, named.
///
/// **Keep-alive, which is the hand-declared default** — no `isAutoDispose`,
/// because this is shared business state that many widgets read and it costs a
/// measured ~146 ms to build. `retry: neverRetry` on the provider itself, not
/// only on the scope, for the reason D12 records: a test container does not
/// inherit the app's scope.
///
/// ⚠️ **The search query does NOT live here.** Riverpod's own `do_dont.mdx`
/// classifies a text field's contents as ephemeral, controller-backed state and
/// says to keep it out of providers; `CommandPalette` already does that. This
/// provider holds the corpus; the widget holds the query and filters
/// synchronously.
final FutureProvider<ItemCatalogue> itemCatalogueProvider =
    FutureProvider<ItemCatalogue>(
      retry: neverRetry,
      (ref) => loadItemCatalogue(
        resources: ref.watch(resourceRepositoryProvider),
        strings: ref.watch(stringRepositoryProvider),
      ),
    );

/// Base names of every portrait the player can choose.
///
/// The game's own and their own, in one list — because the engine treats them
/// as one list too: a loose file shadows a packed one of the same name.
final portraitNamesProvider = FutureProvider<List<String>>(
  retry: neverRetry,
  (ref) => ref.watch(resourceRepositoryProvider).portraitNames(),
);

/// One save slot, by directory name.
///
/// A query so the party shell and the editing session behind it resolve the
/// same slot once, rather than each reading the save directory for itself.
final FutureProviderFamily<SaveSlot?, String> saveSlotProvider =
    FutureProvider.family<SaveSlot?, String>(
      retry: neverRetry,
      isAutoDispose: true,
      (ref, directoryName) =>
          ref.watch(saveGameRepositoryProvider).slotNamed(directoryName),
    );

/// One character file, by file name.
final FutureProviderFamily<CharacterFile?, String> characterFileByNameProvider =
    FutureProvider.family<CharacterFile?, String>(
      retry: neverRetry,
      isAutoDispose: true,
      (ref, fileName) =>
          ref.watch(characterFileRepositoryProvider).fileNamed(fileName),
    );
