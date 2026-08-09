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

import 'dart:typed_data';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/config/providers.dart';
import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/save_editor.dart';
import 'package:wand_of_saves/domain/character_file.dart';
import 'package:wand_of_saves/domain/document_ref.dart';
import 'package:wand_of_saves/domain/edit_command.dart';
import 'package:wand_of_saves/domain/save_slot.dart';

part 'save_browser_viewmodel.mapper.dart';

/// Everything the home screen renders: two sections, both documents.
///
/// A value class rather than two providers, because MVVM pairs a view with a
/// ViewModel 1:1 and this is one screen. `dart_mappable` gives the list fields
/// `IterableEquality`, so a refresh that finds the same files does not repaint.
@MappableClass()
class BrowserState with BrowserStateMappable {
  /// Creates the home screen's state.
  const BrowserState({
    this.characters = const [],
    this.saves = const [],
    this.hasDeleted = false,
  });

  /// Exported characters, newest first.
  ///
  /// **A section of its own, not a detail of a save.** A `.chr` is opened,
  /// edited and saved on its own terms and need never have come from a
  /// savegame — which is why it gets equal billing rather than a button.
  final List<CharacterFile> characters;

  /// Save slots, newest first.
  final List<SaveSlot> saves;

  /// Whether anything has been deleted and not yet emptied.
  ///
  /// Drives whether "Empty deleted items" is offered at all — an irreversible
  /// command that does nothing is worse than an absent one.
  final bool hasDeleted;

  /// Whether there is nothing at all to show.
  ///
  /// Both sections, deliberately: a player with characters and no saves has
  /// something to open, and telling them the app found nothing would be false.
  bool get isEmpty => characters.isEmpty && saves.isEmpty;

  /// The saves in [selected], by label, in the order shown.
  ///
  /// Takes the selection rather than holding it: **ticking a card must not
  /// re-read the disk.** Selection changes on every tap and these lists change
  /// when a file does, so they are watched separately and combined here.
  List<String> selectedSaveLabels(Set<DocumentRef> selected) => [
    for (final slot in saves)
      if (selected.contains(SaveRef(slot.directoryName))) slot.label,
  ];

  /// The characters in [selected], by file name, in the order shown.
  List<String> selectedCharacterNames(Set<DocumentRef> selected) => [
    for (final file in characters)
      if (selected.contains(CharacterRef(file.fileName))) file.fileName,
  ];
}

/// ViewModel for the home screen, paired 1:1 with `SaveBrowserView`.
///
/// Holds the presentation state for the screen and exposes [refresh] as its
/// one command. It talks to two repositories and never to `infinity_formats`,
/// which is what lets a test swap both out entirely.
class SaveBrowserViewModel extends AsyncNotifier<BrowserState> {
  @override
  Future<BrowserState> build() async {
    // ⚠️ **Watched queries, not repository calls.** A card shows what is
    // *inside* a document — a character's portrait, level and class; a save's
    // gold and party size — so a lineup drawn before an edit shows the player
    // their own change missing. Watching means an editor can invalidate
    // exactly the list it changed and this re-reads by itself.
    //
    // `await ref.watch(other.future)` is the documented shape for one async
    // provider depending on another.
    // ⚠️ **Selection is deliberately not watched here.** It changes on every
    // tap, and this rebuild awaits two disk reads — so deriving it would put
    // the whole screen through an async rebuild each time a box is ticked, and
    // flash the loading state. The view watches selection directly; the two
    // change on completely different schedules and are combined where they are
    // drawn.
    final recycler = ref.watch(recycleServiceProvider);
    return BrowserState(
      saves: await ref.watch(saveSlotsProvider.future),
      characters: await ref.watch(characterFilesProvider.future),
      hasDeleted: recycler.hasRecycled,
    );
  }

  /// Re-reads both directories.
  ///
  /// Saves and characters both change underneath us — the game is very likely
  /// running while this app is open, and exporting a character is something a
  /// player does mid-session.
  ///
  /// ⚠️ **`refresh`, not `invalidate`.** The app bar's button awaits this;
  /// `invalidate` returns before the read does, so the spinner would stop
  /// while the disk was still being read.
  Future<void> refresh() async {
    await Future.wait([
      ref.refresh(saveSlotsProvider.future),
      ref.refresh(characterFilesProvider.future),
    ]);
  }

  /// Turns on the tick boxes.
  ///
  /// Delegated, so the view's command API is unchanged while the state moves
  /// somewhere a re-read cannot reach it.
  void startSelecting() => ref.read(documentSelectionProvider.notifier).start();

  /// Turns them off and forgets what was ticked. Moves nothing.
  void cancelSelection() =>
      ref.read(documentSelectionProvider.notifier).cancel();

  /// Ticks [document] if it is not ticked, and unticks it if it is.
  void toggle(DocumentRef document) =>
      ref.read(documentSelectionProvider.notifier).toggle(document);

  /// Moves everything ticked out of the way, then re-reads.
  ///
  /// **Nothing is unlinked** — see `RecycleService`. A save's whole directory
  /// moves and a character goes with its `.bio`, both to a folder beside the
  /// save root where neither this app nor the game will find them.
  ///
  /// The `switch` is exhaustive over [DocumentRef], which is the point of its
  /// being sealed: a third kind of document cannot be added without this being
  /// made to say how it is deleted.
  Future<void> deleteSelected() async {
    final current = state.value;
    final selected = ref.read(documentSelectionProvider).selected;
    if (current == null || selected.isEmpty) return;

    final recycler = ref.read(recycleServiceProvider);
    final saves = {for (final s in current.saves) s.directoryName: s.path};
    final characters = {for (final c in current.characters) c.fileName: c.path};

    for (final document in selected) {
      switch (document) {
        case SaveRef(:final directoryName):
          final path = saves[directoryName];
          if (path != null) await recycler.recycleSaveAt(path);
        case CharacterRef(:final fileName):
          final path = characters[fileName];
          if (path != null) await recycler.recycleCharacterAt(path);
      }
    }

    // ⚠️ **Leaving selection mode is stated, not inherited.** It used to happen
    // by accident: `refresh()` rebuilt the whole state from defaults, which
    // dropped the ticks along with everything else. Once the lists became
    // queries that rebuild on their own schedule, that accident stopped
    // happening and the app sat in selection mode over documents it had just
    // moved. Selection is the player's, so ending it is a decision.
    cancelSelection();

    // Both lists, because a selection spans both sections.
    await refresh();
  }

  /// Creates a new character called [name] with the portrait [portraitName].
  ///
  /// ⚠️ **The record comes from the engine's own `CHARBASE`**, read out of the
  /// player's installation at run time. It is the template every protagonist is
  /// built from — which is why the resref of the player's own character always
  /// reads `*HARBASE` — so creating a character means loading the seed and
  /// editing it, never synthesising 6,000 bytes of creature.
  ///
  /// Everything written here is fixed-width: a 100-byte header around a record
  /// copied whole, with the name and both portrait resrefs patched in. Nothing
  /// resizes.
  ///
  /// Throws [NoCharacterTemplateException] when the game is not installed,
  /// `CharacterFileExistsException` if the name is taken, and
  /// [InvalidEditException] if the portrait name is too long.
  Future<CharacterFile> createCharacter({
    required String name,
    required String fileName,
    required String portraitName,
  }) async {
    final template = await ref
        .read(resourceRepositoryProvider)
        .creature(characterTemplate);
    if (template == null) throw const NoCharacterTemplateException();

    final blank = ChrCodec.blank(
      name: name,
      // A copy: the archive's buffer is shared, and a document that reached
      // back into it would change under the next reader.
      record: Uint8List.fromList(template),
    );
    final created = applyCharacterEdit(
      blank,
      SetPortrait(creOffset: blank.creOffset, baseName: portraitName),
    );

    final file = await ref
        .read(characterFileRepositoryProvider)
        .create(fileName, created);
    ref.invalidate(characterFilesProvider);
    return file;
  }

  /// Removes everything that has been deleted, permanently.
  ///
  /// ⚠️ **The only irreversible command in this application.** Kept apart from
  /// [deleteSelected] so it can never happen as a consequence of a deletion.
  Future<void> emptyDeleted() async {
    await ref.read(recycleServiceProvider).empty();
    await refresh();
  }
}

/// Thrown when a character cannot be created because the game is not there.
///
/// Distinct from a name collision: no installation means no `CHARBASE`, and no
/// `CHARBASE` means nothing to build a character *from*. Nothing the player
/// types will help.
class NoCharacterTemplateException implements Exception {
  /// Records that the template could not be read.
  const NoCharacterTemplateException();

  @override
  String toString() =>
      'NoCharacterTemplateException: the game’s own character template '
      '($characterTemplate) could not be read, so there is nothing to build a '
      'new character from. Baldur’s Gate does not appear to be installed.';
}

/// The home screen's state: what is on disk, or a load failure.
final saveBrowserProvider =
    AsyncNotifierProvider<SaveBrowserViewModel, BrowserState>(
      SaveBrowserViewModel.new,
    );
