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

import 'dart:io';

import 'package:infinity_formats/infinity_formats.dart';
import 'package:wand_of_saves/data/party_projection.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/character_file.dart';

/// Source of truth for exported characters.
///
/// The peer of `SaveGameRepository`, and shaped like it deliberately: an
/// interface so `ProviderScope(overrides:)` can substitute a fake, returning
/// domain models so no `infinity_formats` type reaches a ViewModel.
abstract interface class CharacterFileRepository {
  /// Every readable `.chr`, newest first.
  Future<List<CharacterFile>> listFiles();

  /// The character file called [fileName], or `null`.
  ///
  /// The route carries a file name rather than a [CharacterFile], so that a
  /// reload resolves to the same character instead of losing it.
  Future<CharacterFile?> fileNamed(String fileName);

  /// Loads the full document behind [file].
  ///
  /// Separate from [listFiles] for the same reason `load` is there: the browser
  /// needs a summary, and an editor needs the bytes.
  ///
  /// Throws [InfinityFormatException] if the file will not parse — unlike
  /// listing, a character the user explicitly chose should fail loudly.
  Future<Chr> load(CharacterFile file);

  /// Writes [chr] over [file], keeping a `.bak`.
  ///
  /// Atomic — temporary file, then rename — so a reader sees either the whole
  /// old character or the whole new one.
  Future<void> write(CharacterFile file, Chr chr);

  /// Writes [chr] as a **new** file called [fileName].
  ///
  /// Creates the characters directory if the player has never exported before.
  ///
  /// Throws [CharacterFileExistsException] if something is already there.
  /// ⚠️ **Never overwrites**, unlike [write]: an export creates rather than
  /// replaces, so a name collision is a real answer to give the player rather
  /// than a race to resolve. There is no `.bak` convention for a file nobody
  /// opened, so a silent overwrite would simply destroy the earlier export.
  Future<CharacterFile> create(String fileName, Chr chr);
}

/// Thrown when an export would land on a character file that already exists.
///
/// A domain failure rather than a codec one: the bytes are fine, the *name* is
/// taken. The screen turns this into a question — pick another name — which is
/// why it carries the name rather than only a message.
class CharacterFileExistsException implements Exception {
  /// Records that [fileName] is already in [directory].
  const CharacterFileExistsException({
    required this.fileName,
    required this.directory,
  });

  /// The file name that was asked for.
  final String fileName;

  /// Where it would have gone.
  final String directory;

  @override
  String toString() =>
      'CharacterFileExistsException: there is already a character called '
      '"$fileName" in $directory';
}

/// Thrown when there is nowhere to put an exported character.
///
/// Distinct from [CharacterFileExistsException] because the player can do
/// nothing about it by choosing another name: no save directory was found, so
/// this machine has no game user-data folder to write into.
class NoCharacterDirectoryException implements Exception {
  /// Records that no characters directory could be located.
  const NoCharacterDirectoryException();

  @override
  String toString() =>
      'NoCharacterDirectoryException: no Baldur’s Gate user data directory was '
      'found, so there is nowhere to save a character';
}

/// Reads exported characters from the local filesystem.
class FileCharacterFileRepository implements CharacterFileRepository {
  /// Creates a repository over [profile]'s view of this machine.
  const FileCharacterFileRepository({required this.profile});

  /// Locates the characters directory. Repositories own no discovery of their
  /// own.
  final GameProfileService profile;

  @override
  Future<List<CharacterFile>> listFiles() async {
    final files = <CharacterFile>[];
    for (final file in _chrFiles()) {
      final summary = await _read(file);
      // A character that will not parse is skipped rather than failing the
      // whole listing: one damaged export should not hide the others.
      if (summary != null) files.add(summary);
    }
    files.sort((a, b) => b.modified.compareTo(a.modified));
    return files;
  }

  @override
  Future<CharacterFile?> fileNamed(String fileName) async {
    final file = _chrFiles()
        .where((f) => _basename(f.path) == fileName)
        .firstOrNull;
    return file == null ? null : _read(file);
  }

  @override
  Future<Chr> load(CharacterFile file) async =>
      ChrCodec.decode(await File(file.path).readAsBytes(), source: file.path);

  @override
  Future<void> write(CharacterFile file, Chr chr) =>
      writeFileAtomically(file.path, ChrCodec.encode(chr));

  @override
  Future<CharacterFile> create(String fileName, Chr chr) async {
    final root = profile.findCharacterRoot();
    if (root == null) throw const NoCharacterDirectoryException();

    // The first export on a machine has nowhere to go: the game creates
    // `characters/` when it writes one, so a player who has never used the
    // Record screen's EXPORT button has no folder at all.
    final directory = Directory(root);
    if (!directory.existsSync()) directory.createSync(recursive: true);

    final path = '$root${Platform.pathSeparator}$fileName';
    if (File(path).existsSync()) {
      throw CharacterFileExistsException(
        fileName: fileName,
        directory: root,
      );
    }

    // Still atomic, though there is nothing here to back up: a half-written
    // character that the browser then tries to parse is a worse first
    // impression than no character at all.
    await writeFileAtomically(path, ChrCodec.encode(chr));

    final created = await _read(File(path));
    if (created == null) {
      // Unreachable in practice -- the bytes were just written from a parsed
      // document. Loud rather than a silent null, because a listing that
      // cannot see what was just saved is a bug worth hearing about.
      throw StateError('the character written to $path could not be read back');
    }
    return created;
  }

  /// Every `.chr` in the characters directory, unordered.
  ///
  /// Filtered by extension rather than by trying to parse everything: the
  /// folder also holds a `.bio` beside each character, and a player may keep
  /// anything else there.
  List<File> _chrFiles() {
    final root = profile.findCharacterRoot();
    if (root == null) return const [];

    final dir = Directory(root);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .where(
          (f) => _basename(f.path).toLowerCase().endsWith(
            GameProfileService.characterExtension,
          ),
        )
        .toList();
  }

  Future<CharacterFile?> _read(File file) async {
    try {
      final chr = ChrCodec.decode(
        await file.readAsBytes(),
        source: file.path,
      );
      final cre = CreCodec.decode(chr.creBytes, source: file.path);

      return CharacterFile(
        fileName: _basename(file.path),
        path: file.path,
        // ⚠️ The name comes from the CHR header, never from the record. An
        // exported character's `dialogFile` is eight zero bytes and its
        // `longNameStrref` is -1 -- the protagonist's shape, which an export
        // always is -- so there is no name inside the creature to find.
        character: characterFrom(
          cre,
          name: chr.name,
          creResref: cre.dialogFile,
          creOffset: chr.creOffset,
          creLength: chr.creLength,
        ),
        modified: file.lastModifiedSync(),
      );
    } on InfinityFormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  static String _basename(String path) =>
      path.split(Platform.pathSeparator).last;
}
