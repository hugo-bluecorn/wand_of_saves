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
import 'dart:typed_data';

import 'package:wand_of_saves/data/repositories/resource_repository.dart';
import 'package:wand_of_saves/data/services/game_profile_service.dart';
import 'package:wand_of_saves/domain/edit_command.dart';

/// Puts a portrait of the player's own into the folder the engine reads first.
///
/// A **service**: it wraps this machine's filesystem and holds no state.
///
/// ### Why this is all a "custom portrait" is
///
/// The engine looks in `<user data>/portraits/` before its own archives, and a
/// portrait is named by resref either way — so a loose file simply shadows a
/// packed one. There is no separate field, flag or code path anywhere; the same
/// two CRE resrefs serve a built-in portrait and a custom one. This service
/// copies a file into that folder under a name the resrefs can reach, and that
/// is the whole mechanism.
///
/// ### What is deliberately not here
///
/// **No image conversion.** Turning a JPEG into a conforming pair means an
/// encoder and a resample, which is a dependency and a slice of its own. What
/// is *missing* from a file is named precisely instead — see `BitmapInfo` — so
/// the player can fix it in any image editor.
class PortraitImportService {
  /// Creates a service over [profile]'s view of this machine.
  const PortraitImportService({required this.profile});

  /// Locates the portraits directory.
  final GameProfileService profile;

  /// The variant letters a CRE can reference.
  ///
  /// ⚠️ **Both, from one file.** A creature record names two portraits — the
  /// `…M` a character sheet shows and the `…L` — and one whose `L` does not
  /// resolve is a character the game draws inconsistently. Writing the same
  /// picture under both is the engine's own tolerance for off-size portraits
  /// put to use, and it is what the alternative (asking the player for two
  /// files) would mostly produce anyway.
  static const List<String> variants = ['M', 'L'];

  /// The longest base name that can carry a variant letter.
  ///
  /// Seven, so the suffix fits an 8-byte resref. **The only hard requirement an
  /// imported portrait has to meet** — every other property of the file is
  /// reported and allowed, because the game's own portraits include eleven
  /// off-size ones, a 32-bit one and an 8-bit one.
  static const int baseNameLimit = SetPortrait.baseNameLimit;

  /// A characters-only name, so it cannot become a path.
  static final RegExp _validName = RegExp(r'^[A-Za-z0-9_]+$');

  /// What is wrong with [baseName], phrased for the player, or `null`.
  String? nameProblem(String baseName) {
    final name = baseName.trim();
    if (name.isEmpty) return 'Give the portrait a name.';
    if (name.length > baseNameLimit) {
      return 'A portrait name can be at most seven characters, so the game '
          'can add its own letter for each size.';
    }
    if (!_validName.hasMatch(name)) {
      return 'A portrait name can use letters, numbers and underscores only.';
    }
    if (_existing(name).isNotEmpty) {
      return 'There is already a portrait called ${name.toUpperCase()}.';
    }
    return null;
  }

  /// Copies [bytes] into the portraits folder, once per variant.
  ///
  /// Returns the paths written.
  ///
  /// Throws [ArgumentError] if [nameProblem] would have complained, and
  /// [NoPortraitDirectoryException] if there is no user-data folder at all.
  Future<List<String>> add({
    required String baseName,
    required Uint8List bytes,
  }) async {
    final problem = nameProblem(baseName);
    if (problem != null) {
      throw ArgumentError.value(baseName, 'baseName', problem);
    }

    final root = profile.findPortraitRoot();
    if (root == null) throw const NoPortraitDirectoryException();

    // A player who has never added a portrait has no folder at all.
    Directory(root).createSync(recursive: true);

    final name = baseName.trim().toUpperCase();
    final written = <String>[];
    for (final variant in variants) {
      final path = _pathOf(root, '$name$variant');
      // Copied untouched: no encoder, no resample, nothing reinterpreted.
      await File(path).writeAsBytes(bytes, flush: true);
      written.add(path);
    }
    return written;
  }

  /// Files that would be overwritten by importing under [baseName].
  List<String> _existing(String baseName) {
    final root = profile.findPortraitRoot();
    if (root == null) return const [];

    final name = baseName.trim().toUpperCase();
    return [
      for (final variant in variants)
        if (File(_pathOf(root, '$name$variant')).existsSync())
          _pathOf(root, '$name$variant'),
    ];
  }

  String _pathOf(String root, String resref) =>
      '$root${Platform.pathSeparator}$resref$portraitFileExtension';
}

/// Thrown when there is nowhere to put an imported portrait.
///
/// No save directory was found, so this machine has no game user-data folder.
class NoPortraitDirectoryException implements Exception {
  /// Records that no portraits directory could be located.
  const NoPortraitDirectoryException();

  @override
  String toString() =>
      'NoPortraitDirectoryException: no Baldur’s Gate user data directory was '
      'found, so there is nowhere to put a portrait';
}
