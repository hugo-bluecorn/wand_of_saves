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

import 'package:infinity_formats/infinity_formats.dart';
import 'package:meta/meta.dart';

/// One open document, and everything the player could still take back.
///
/// **Immutable, and that is the point.** Both editors used to keep this as
/// mutable private fields beside their state — `_working`, `_onDisk`,
/// `_undoStack`, `_redoStack` — which is the `ChangeNotifier` shape Riverpod's
/// own migration guide exists to move code off:
///
/// > *"`Notifier`/`AsyncNotifier`, in combination with immutable state, can
/// > lead to better design choices and less errors."* … *"mutable state might
/// > be way harder than it initially promises."*
///
/// Every command returns a new session, so nothing downstream can miss a change
/// and there is no order in which the fields can disagree with each other.
///
/// **One type for both documents.** A savegame and an exported character
/// differ in almost everything and agree on what editing *means*, so undo,
/// redo and "dirty" are defined once. Two copies would be two chances for undo
/// to behave slightly differently in one of the editors.
@immutable
class EditSession<T extends CreatureDocument<T>> {
  /// Creates a session in an arbitrary state. Prefer [EditSession.opened].
  const EditSession({
    required this.document,
    required this.onDisk,
    this.undo = const [],
    this.redo = const [],
  });

  /// A session over [document] exactly as it was read from disk.
  const EditSession.opened(T document)
    : this(document: document, onDisk: document);

  /// The document as edited so far — what the screen shows.
  final T document;

  /// The document as the file has it.
  final T onDisk;

  /// Documents to go back to, oldest first.
  ///
  /// Whole documents rather than inverse commands. A 96 KB buffer per edit
  /// costs nothing, and an inverse command that reconstructs a previous value
  /// is one more place to get a save subtly wrong.
  final List<T> undo;

  /// Documents to go forward to.
  final List<T> redo;

  /// Whether there are edits the file does not have yet.
  ///
  /// ⚠️ **Identity, not a byte comparison, and that is load-bearing.** Undoing
  /// back to the loaded snapshot restores *that same object*, so "nothing to
  /// save" is answered without diffing 96 KB. It is also why a save that has
  /// been undone back to where it started writes nothing at all.
  bool get isDirty => !identical(document, onDisk);

  /// Whether there is an edit to take back.
  bool get canUndo => undo.isNotEmpty;

  /// Whether there is an undone edit to put back.
  bool get canRedo => redo.isNotEmpty;

  /// This session with [next] as the document, ready to be undone.
  ///
  /// ⚠️ **Clears the redo stack.** A redo kept across a fresh edit would
  /// reapply an edit onto a history it was never taken from.
  EditSession<T> edited(T next) =>
      EditSession(document: next, onDisk: onDisk, undo: [...undo, document]);

  /// This session one edit further back, or itself when there is none.
  EditSession<T> undone() {
    if (undo.isEmpty) return this;
    return EditSession(
      document: undo.last,
      onDisk: onDisk,
      undo: undo.sublist(0, undo.length - 1),
      redo: [...redo, document],
    );
  }

  /// This session one edit further forward, or itself when there is none.
  EditSession<T> redone() {
    if (redo.isEmpty) return this;
    return EditSession(
      document: redo.last,
      onDisk: onDisk,
      undo: [...undo, document],
      redo: redo.sublist(0, redo.length - 1),
    );
  }

  /// This session with the working copy recorded as what the file now holds.
  ///
  /// The history survives: saving is not forgetting, and a player who saves
  /// and then changes their mind still has every step to walk back.
  EditSession<T> saved() =>
      EditSession(document: document, onDisk: document, undo: undo, redo: redo);

  @override
  String toString() =>
      'EditSession(${isDirty ? 'edited' : 'clean'}, '
      '${undo.length} back, ${redo.length} forward)';
}
