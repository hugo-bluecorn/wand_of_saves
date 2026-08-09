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

/// @docImport 'package:wand_of_saves/domain/save_slot.dart';
library;

import 'package:dart_mappable/dart_mappable.dart';
import 'package:wand_of_saves/domain/character.dart';

part 'character_file.mapper.dart';

/// An exported character on disk — a `.chr` file — summarised for the browser.
///
/// **The peer of `SaveSlot`, not a member of one.** A character file is a
/// document in its own right: it is opened, edited and saved on its own terms,
/// it need never have come from a savegame, and one this app creates never has.
/// That is what makes the home screen two sections rather than a saves browser
/// with an extra button.
///
/// Immutable, with value equality from `dart_mappable` (D9), for the same
/// reason [SaveSlot] has it: the viewmodel holds a list of these and identity
/// equality would make every refresh look like a change.
///
/// ⚠️ **Two names, and they are genuinely different.** [fileName] is what the
/// file is called and what the route carries; [Character.name] is what the
/// character is called, and it comes from the CHR header. On the developer's
/// own machine `Aard1.chr` holds a character named `Aard`.
@MappableClass()
class CharacterFile with CharacterFileMappable {
  /// Creates a summary of one exported character.
  const CharacterFile({
    required this.fileName,
    required this.path,
    required this.character,
    required this.modified,
  });

  /// The file's name with its extension, e.g. `aurel.chr`.
  ///
  /// The route parameter, chosen for the same reason `SaveSlot.directoryName`
  /// is: it needs no escaping beyond a URI component, it is stable across
  /// machines, and the repository can resolve it from scratch so a reload lands
  /// on the same character.
  final String fileName;

  /// Absolute path to the `.chr`.
  final String path;

  /// The character the file holds.
  ///
  /// The **same** [Character] the party shell edits — projected by
  /// `characterFrom`, which both documents share. A sheet that could tell the
  /// two apart would be two sheets.
  final Character character;

  /// When the file was last written.
  final DateTime modified;

  /// The file's name without its extension, e.g. `aurel`.
  ///
  /// What a card shows underneath the character's own name, so a player with
  /// two exports of the same character can tell them apart.
  String get label {
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? fileName : fileName.substring(0, dot);
  }
}
