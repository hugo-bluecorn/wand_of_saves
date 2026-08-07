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

/// Locates the Baldur's Gate installation and the player's save directory.
///
/// A **service** in the MVVM sense: it wraps one data source — this machine's
/// filesystem — and holds no state.
///
/// This is the home for knowledge `packages/infinity_formats` deliberately
/// refuses. "Where is the game installed" and "which locale did the player
/// configure" are facts about *this machine*, not about a file format, so a
/// codec must never go looking for them. Keeping that split is what stops a
/// codec library quietly becoming a BG:EE-installation library.
///
/// Candidates and the environment are injected so this is testable without
/// depending on what happens to be installed on the machine running the tests.
class GameProfileService {
  /// Creates a service, optionally overriding where it looks.
  const GameProfileService({
    this.gameCandidates,
    this.saveCandidates,
    this.environment,
  });

  /// Environment variable naming the game installation directory.
  static const String gameDirVariable = 'BGEE_GAME_DIR';

  /// Environment variable naming the save root, or a single slot.
  static const String saveDirVariable = 'BGEE_SAVE_DIR';

  /// The file that marks a directory as a game installation.
  static const String gameMarker = 'chitin.key';

  /// The file that marks a directory as a save slot.
  static const String saveMarker = 'BALDUR.gam';

  /// Overrides the installation search path. `null` uses [defaultGameRoots].
  final List<String>? gameCandidates;

  /// Overrides the save-root search path. `null` uses [defaultSaveRoots].
  final List<String>? saveCandidates;

  /// Overrides the process environment. `null` uses the real one.
  final Map<String, String>? environment;

  Map<String, String> get _env => environment ?? Platform.environment;

  String get _home =>
      _env['HOME'] ?? _env['USERPROFILE'] ?? Directory.current.path;

  /// Well-known installation roots, in the order they are tried.
  List<String> get defaultGameRoots => [
    '$_home/.local/share/Steam/steamapps/common/$_steamName',
    '$_home/.steam/steam/steamapps/common/$_steamName',
    '$_home/Library/Application Support/Steam/steamapps/common/$_steamName',
    '$_home/GOG Games/$_gogName',
    '$_home/Games/$_gogName',
    'C:\\Program Files (x86)\\Steam\\steamapps\\common\\$_steamName',
  ];

  /// Well-known save roots, in the order they are tried.
  List<String> get defaultSaveRoots => [
    '$_home/.local/share/$_gogName/save',
    '$_home/Documents/$_gogName/save',
    '$_home/Library/Application Support/$_gogName/save',
  ];

  static const String _steamName = "Baldur's Gate Enhanced Edition";
  static const String _gogName = "Baldur's Gate - Enhanced Edition";

  /// The game installation directory, or `null` if none was found.
  ///
  /// An explicit [gameDirVariable] **replaces** the candidate list rather than
  /// being prepended to it. If someone says where the game is and is wrong,
  /// finding a different copy silently would hide their mistake.
  String? findGameDirectory() {
    final override = _env[gameDirVariable];
    if (override != null) return _isGameDirectory(override) ? override : null;
    return (gameCandidates ?? defaultGameRoots)
        .where(_isGameDirectory)
        .firstOrNull;
  }

  /// The directory holding numbered save slots, or `null` if none was found.
  ///
  /// Same override rule as [findGameDirectory].
  String? findSaveRoot() {
    final override = _env[saveDirVariable];
    if (override != null) return _isSaveRoot(override) ? override : null;
    return (saveCandidates ?? defaultSaveRoots).where(_isSaveRoot).firstOrNull;
  }

  /// Directories inside [root] that are save slots, unordered.
  List<Directory> slotsIn(String root) {
    final dir = Directory(root);
    if (!dir.existsSync()) return const [];
    return dir.listSync().whereType<Directory>().where(_isSaveSlot).toList();
  }

  bool _isGameDirectory(String path) =>
      File('$path${Platform.pathSeparator}$gameMarker').existsSync();

  /// A save root has no marker of its own — it is recognised by containing at
  /// least one slot.
  bool _isSaveRoot(String path) => slotsIn(path).isNotEmpty;

  bool _isSaveSlot(Directory dir) =>
      File('${dir.path}${Platform.pathSeparator}$saveMarker').existsSync();
}
