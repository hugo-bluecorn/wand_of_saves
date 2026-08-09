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
import 'package:wand_of_saves/domain/skill_catalogue.dart';

part 'character_file_viewmodel.mapper.dart';

/// Raised when the route names a character file that is no longer there.
///
/// The repository answers `null` — an absent file is not its problem to judge.
/// It is this screen's, because an editor with nothing to edit has nothing to
/// show. The savegame side says the same thing in the same way.
class CharacterFileNotFoundException implements Exception {
  /// Names the file that could not be found.
  const CharacterFileNotFoundException(this.fileName);

  /// The character file the route asked for.
  final String fileName;

  @override
  String toString() =>
      'No character file named "$fileName". It may have been deleted or '
      'renamed while this window was open.';
}

/// Everything the character editor renders.
///
/// The peer of `PartyState`, and shorter for one reason: there is no party.
/// No member list, no selection, no reputation — a `.chr` is one character and
/// nothing else.
@MappableClass()
class CharacterFileState with CharacterFileStateMappable {
  /// Creates the character editor's state.
  const CharacterFileState({
    required this.file,
    required this.character,
    this.proficiencies = ProficiencyCatalogue.empty,
    this.skills = SkillCatalogue.empty,
    this.isDirty = false,
    this.canUndo = false,
    this.canRedo = false,
  });

  /// The file being edited.
  final CharacterFile file;

  /// The character in it.
  ///
  /// **The same [Character] the party shell edits**, projected by the same
  /// `characterFrom`. A sheet that could tell the two apart would be two
  /// sheets.
  final Character character;

  /// What the game calls each proficiency, and how many pips it allows.
  final ProficiencyCatalogue proficiencies;

  /// Which thief skills this character's class may allocate points to.
  final SkillCatalogue skills;

  /// Whether there are edits the file does not have yet.
  final bool isDirty;

  /// Whether there is an edit to take back.
  final bool canUndo;

  /// Whether there is an undone edit to put back.
  final bool canRedo;
}

/// ViewModel for the character editor, paired 1:1 with `CharacterFileView`.
///
/// **Deliberately the same shape as `PartyViewModel`**: a private working copy,
/// whole-document snapshots for undo, an identity comparison for "clean", and
/// an atomic write leaving a `.bak`. The two documents are edited by one sheet,
/// so anywhere these two diverge is somewhere the user would find one of them
/// behaving oddly.
class CharacterFileViewModel extends AsyncNotifier<CharacterFileState> {
  /// Views the character file called [fileName].
  CharacterFileViewModel(this.fileName);

  /// The character file the route named.
  final String fileName;

  /// The document as edited so far.
  ///
  /// **Private, and never placed in [CharacterFileState].** No
  /// `infinity_formats` type reaches a widget; the session state has to live
  /// somewhere, and this is it.
  Chr? _working;

  /// The document as the file has it — identical to [_working] when clean.
  ///
  /// Compared by identity, which is exactly right: undoing back to the loaded
  /// snapshot restores *that same object*, so "nothing to save" needs no byte
  /// comparison.
  Chr? _onDisk;

  /// Snapshots to go back to, oldest first.
  ///
  /// Whole documents rather than inverse commands — and a `.chr` is about 7 KB,
  /// so this is cheaper here than on the savegame side where it is already
  /// cheap enough.
  final List<Chr> _undoStack = [];

  /// Snapshots to go forward to.
  final List<Chr> _redoStack = [];

  ProficiencyCatalogue _proficiencies = ProficiencyCatalogue.empty;
  SkillCatalogue _skills = SkillCatalogue.empty;
  CharacterFile? _file;

  @override
  Future<CharacterFileState> build() async {
    final files = ref.watch(characterFileRepositoryProvider);
    final resources = ref.watch(resourceRepositoryProvider);
    final strings = ref.watch(stringRepositoryProvider);

    final file = await files.fileNamed(fileName);
    if (file == null) throw CharacterFileNotFoundException(fileName);

    final chr = await files.load(file);
    _file = file;
    _working = chr;
    _onDisk = chr;
    _undoStack.clear();
    _redoStack.clear();

    final catalogues = await loadRulesCatalogues(
      resources: resources,
      strings: strings,
    );
    _proficiencies = catalogues.proficiencies;
    _skills = catalogues.skills;

    return _projected();
  }

  /// Applies [command] to the working copy.
  ///
  /// Nothing is written to disk here — [save] does that. Throws
  /// [InvalidEditException] if the value is outside what the stat accepts.
  void edit(CharacterEditCommand command) {
    final working = _working;
    if (working == null) return;

    _undoStack.add(working);
    _working = applyCharacterEdit(working, command);
    // A redo stack kept across a fresh edit would reapply an edit onto a
    // history it was never taken from.
    _redoStack.clear();
    state = AsyncData(_projected());
  }

  /// Takes back the most recent edit.
  void undo() => _step(from: _undoStack, to: _redoStack);

  /// Puts back the most recently undone edit.
  void redo() => _step(from: _redoStack, to: _undoStack);

  /// Writes the working copy over the file, leaving a `.bak`.
  ///
  /// Does nothing when there is nothing to save: the lineup sorts by
  /// modification time, so an idle write would reorder it for no reason.
  Future<void> save() async {
    final file = _file;
    final working = _working;
    if (file == null || working == null || working == _onDisk) return;

    await ref.read(characterFileRepositoryProvider).write(file, working);
    _onDisk = working;
    state = AsyncData(_projected());
  }

  void _step({required List<Chr> from, required List<Chr> to}) {
    final working = _working;
    if (working == null || from.isEmpty) return;

    to.add(working);
    _working = from.removeLast();
    state = AsyncData(_projected());
  }

  /// The working copy as the view sees it.
  CharacterFileState _projected() {
    final working = _working!;
    return CharacterFileState(
      file: _file!,
      // ⚠️ The name comes from the CHR header, never from the record: an
      // exported character's `dialogFile` is eight zero bytes and its
      // `longNameStrref` is -1, so there is no name inside the creature.
      character: characterFrom(
        CreCodec.decode(working.creBytes, source: fileName),
        name: working.name,
        creResref: '',
        creOffset: working.creOffset,
        creLength: working.creLength,
      ),
      proficiencies: _proficiencies,
      skills: _skills,
      isDirty: working != _onDisk,
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
    );
  }
}

/// The character editor's state, per character file name.
///
/// Keyed by file name rather than holding a [CharacterFile], so the route
/// parameter is enough to rebuild this from scratch after a reload — exactly as
/// `partyProvider` is keyed by slot directory.
final AsyncNotifierProviderFamily<
  CharacterFileViewModel,
  CharacterFileState,
  String
>
characterFileProvider =
    AsyncNotifierProvider.family<
      CharacterFileViewModel,
      CharacterFileState,
      String
    >(CharacterFileViewModel.new);
