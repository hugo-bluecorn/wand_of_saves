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

/// Pending edits, and the undo/redo they make possible.
///
/// **Every enabled field is live, and that is cheaper than making two of them
/// live.** The whole mechanism is one map keyed by [LedgerRow.id]; restricting
/// it to a demonstration field or two would have meant *adding* a rule. So the
/// undo and redo buttons in the app bar are wired to something real rather than
/// drawn and left dead, which is the only way to tell whether a dense grid
/// still reads once a third of it has been touched.
///
/// Snapshots rather than a command log: the state is a handful of short
/// strings, and a list of maps is exactly as much machinery as that needs. The
/// real application has sealed `EditCommand`s over an immutable savegame, and
/// nothing here is a proposal to replace them.
library;

import 'package:ui_spikes/ledger/ledger_row.dart';

/// A stack of override maps with a cursor, which is undo/redo.
class LedgerEdits {
  /// Creates an empty edit stack.
  LedgerEdits();

  final List<Map<String, String>> _history = [<String, String>{}];
  int _cursor = 0;

  Map<String, String> get _current => _history[_cursor];

  /// The override for [id], or null when the row still holds what was read.
  String? operator [](String id) => _current[id];

  /// How many rows currently differ from the file.
  int get changeCount => _current.length;

  /// Whether there is a state to go back to.
  bool get canUndo => _cursor > 0;

  /// Whether there is a state to go forward to.
  bool get canRedo => _cursor < _history.length - 1;

  /// Whether [id] has been changed.
  bool isChanged(String id) => _current.containsKey(id);

  /// Records [value] against [id], collapsing a no-op so that typing the same
  /// number twice does not cost two presses of undo.
  void write(String id, String value) {
    if (_current[id] == value) return;
    _push({..._current, id: value});
  }

  /// Drops the override on [id], returning the row to what the file holds.
  void reset(String id) {
    if (!_current.containsKey(id)) return;
    _push({..._current}..remove(id));
  }

  /// Steps back one edit.
  void undo() {
    if (canUndo) _cursor -= 1;
  }

  /// Steps forward one edit.
  void redo() {
    if (canRedo) _cursor += 1;
  }

  void _push(Map<String, String> next) {
    // A new edit after an undo discards the redo tail, which is what every
    // editor does and what a person expects.
    _history
      ..removeRange(_cursor + 1, _history.length)
      ..add(next);
    _cursor = _history.length - 1;
  }
}
