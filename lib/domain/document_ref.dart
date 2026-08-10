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

import 'package:meta/meta.dart';

/// Which document the browser is pointing at — a save, or a character.
///
/// **Sealed**, so anything that acts on a selection is an exhaustive `switch`
/// and a third kind of document cannot be added without every handler being
/// made to deal with it (D5). That matters most for deletion, where the two
/// kinds are moved differently: a save is a whole directory, a character is a
/// file with a sidecar.
///
/// A reference rather than the document itself: **one selection spans both
/// sections**, so a clear-out of stale saves and old characters is one pass,
/// and a `Set` of these is what that selection is. Holding the summaries would
/// make the selection go stale the moment the browser refreshed.
///
/// Equality is by identity-in-the-filesystem, which is why each carries the
/// same string the route does. `@immutable` rather than `dart_mappable`
/// (D9 decides generation per type): these are two fields and a comparison, and
/// a generated mapper for a type nothing serialises would be ceremony.
@immutable
sealed class DocumentRef {
  /// Creates a reference.
  const DocumentRef();
}

/// A savegame, named by its slot directory.
final class SaveRef extends DocumentRef {
  /// Points at the save in the slot directory called [directoryName].
  const SaveRef(this.directoryName);

  /// The slot directory's name, e.g. `000000022-last`.
  final String directoryName;

  @override
  bool operator ==(Object other) =>
      other is SaveRef && other.directoryName == directoryName;

  @override
  int get hashCode => Object.hash(SaveRef, directoryName);

  @override
  String toString() => 'SaveRef($directoryName)';
}

/// An exported character, named by its file.
final class CharacterRef extends DocumentRef {
  /// Points at the character file called [fileName].
  const CharacterRef(this.fileName);

  /// The file's name with its extension, e.g. `aurel.chr`.
  final String fileName;

  @override
  bool operator ==(Object other) =>
      other is CharacterRef && other.fileName == fileName;

  @override
  int get hashCode => Object.hash(CharacterRef, fileName);

  @override
  String toString() => 'CharacterRef($fileName)';
}
