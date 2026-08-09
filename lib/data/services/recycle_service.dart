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

import 'package:wand_of_saves/data/services/game_profile_service.dart';

/// Moves deleted saves and characters somewhere they can be fetched back from.
///
/// A **service** in the MVVM sense: it wraps one data source — this machine's
/// filesystem — and holds no state. It spans both document types deliberately,
/// which is exactly why it is not a repository: repositories must never be
/// aware of each other, and this has to know about both.
///
/// ### Why this exists at all
///
/// ⚠️ **Deletion is the only operation in this application with no `.bak`.**
/// Every other write goes through `writeFileAtomically`, which leaves the
/// previous bytes beside the new ones. There is no equivalent for removing a
/// file, so one is built here: nothing is ever unlinked, it is moved.
///
/// ### Beside the save root, never inside it
///
/// A save slot is recognised by containing `BALDUR.gam`
/// (`GameProfileService.saveMarker`), and **the engine agrees** — so a
/// `deleted/` folder *inside* the save root would still be listed as a save, by
/// this app and by the game. One level up, nothing looks: `findSaveRoot` only
/// ever tries its candidate list, and `slotsIn` reads exactly one level deep.
///
/// The layout mirrors the live one — `deleted/save/…`, `deleted/characters/…` —
/// so putting something back is a straight move in any file manager.
class RecycleService {
  /// Creates a service over [profile]'s view of this machine.
  const RecycleService({required this.profile});

  /// Locates the save and character directories.
  final GameProfileService profile;

  /// The directory deleted documents are moved into.
  static const String recycleDirectory = 'deleted';

  /// Where deleted things go, or `null` if there is no save root.
  ///
  /// The directory need not exist; the first deletion creates it.
  String? recycleRoot() {
    final saveRoot = profile.findSaveRoot();
    if (saveRoot == null) return null;
    return _at([Directory(saveRoot).parent.path, recycleDirectory]);
  }

  /// Whether anything has been deleted and not yet emptied.
  bool get hasRecycled {
    final root = recycleRoot();
    if (root == null) return false;
    final dir = Directory(root);
    return dir.existsSync() && dir.listSync().isNotEmpty;
  }

  /// Moves the save slot directory at [path] out of the save root.
  ///
  /// **The whole directory**, not just `BALDUR.gam`: a slot also holds the
  /// screenshot and one `PORTRT<n>.bmp` per party member, and removing the
  /// savegame alone would leave a folder the browser skips and the player
  /// cannot put back.
  ///
  /// Returns where it went.
  Future<String> recycleSaveAt(String path) async {
    final destination = _free(
      _at([
        _requireRoot(),
        GameProfileService.saveDirectoryName,
        _basename(path),
      ]),
    );
    Directory(destination).parent.createSync(recursive: true);
    await Directory(path).rename(destination);
    return destination;
  }

  /// Moves the character file at [path] out of the characters directory.
  ///
  /// ⚠️ **Takes the `.bio` sidecar with it.** A `.chr` and its biography are
  /// one document in two files; leaving the biography behind deletes half a
  /// character and orphans the rest.
  ///
  /// Returns where the `.chr` went.
  Future<String> recycleCharacterAt(String path) async {
    final destination = _free(
      _at([
        _requireRoot(),
        GameProfileService.characterDirectory,
        _basename(path),
      ]),
    );
    Directory(destination).parent.createSync(recursive: true);
    await File(path).rename(destination);

    final biography = File(_withExtension(path, _biography));
    if (biography.existsSync()) {
      await biography.rename(_withExtension(destination, _biography));
    }
    return destination;
  }

  /// Removes everything that has been deleted, permanently.
  ///
  /// ⚠️ **The only irreversible operation in this application**, which is why
  /// it is a separate control with a confirm of its own rather than something
  /// that happens on a timer or a count.
  Future<void> empty() async {
    final root = recycleRoot();
    if (root == null) return;
    final dir = Directory(root);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  static const String _biography = GameProfileService.biographyExtension;

  String _requireRoot() {
    final root = recycleRoot();
    if (root == null) {
      throw const NoRecycleDirectoryException();
    }
    return root;
  }

  /// [path], or the first numbered variant of it that is not taken.
  ///
  /// ⚠️ **Delete, restore, delete again is an ordinary sequence**, so a name
  /// collision here is expected rather than exceptional — and overwriting would
  /// destroy the earlier deletion, which is the one thing this service exists
  /// to prevent.
  String _free(String path) {
    if (!_exists(path)) return path;

    final name = _basename(path);
    final dot = name.lastIndexOf('.');
    final split = dot <= 0 ? path.length : path.length - name.length + dot;
    final stem = path.substring(0, split);
    final extension = path.substring(split);

    for (var n = 2; ; n++) {
      final candidate = '$stem ($n)$extension';
      if (!_exists(candidate)) return candidate;
    }
  }

  bool _exists(String path) =>
      File(path).existsSync() || Directory(path).existsSync();

  static String _at(List<String> parts) => parts.join(Platform.pathSeparator);

  static String _basename(String path) =>
      path.split(Platform.pathSeparator).last;

  static String _withExtension(String path, String extension) {
    final dot = path.lastIndexOf('.');
    final separator = path.lastIndexOf(Platform.pathSeparator);
    return dot > separator
        ? '${path.substring(0, dot)}$extension'
        : '$path$extension';
  }
}

/// Thrown when there is nowhere to move a deleted document to.
///
/// No save directory was found, so this machine has no game user-data folder —
/// which also means there was nothing to delete.
class NoRecycleDirectoryException implements Exception {
  /// Records that no recycle directory could be located.
  const NoRecycleDirectoryException();

  @override
  String toString() =>
      'NoRecycleDirectoryException: no Baldur’s Gate user data directory was '
      'found, so there is nowhere to move a deleted file';
}
