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

import 'package:flutter/material.dart';

/// The app bar's Save action, for any document that can be dirty.
///
/// **Extracted because there are three of these now**, and they were identical:
/// the savegame editor, the character-file editor and the inventory. A button
/// that means "write this to disk" drifting apart between surfaces is how one
/// of them ends up enabled when there is nothing to write.
///
/// ⚠️ **Takes state rather than reaching for a provider.** The two documents
/// this app edits have different notifiers — `PartyViewModel` and
/// `CharacterFileViewModel` — and a widget that picked one could only ever
/// serve one editor. The caller already watches its own view model.
class SaveButton extends StatelessWidget {
  /// Saves through [onSave], enabled only when [isDirty].
  const SaveButton({required this.isDirty, required this.onSave, super.key});

  /// Whether there are edits the file does not have yet.
  final bool isDirty;

  /// Writes the document. `null` where the surface cannot save at all.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    // Disabled on a clean document, not hidden: a Save that comes and goes
    // reads as the app losing the ability rather than having nothing to do.
    onPressed: isDirty ? onSave : null,
    icon: const Icon(Icons.save_outlined),
    label: const Text('Save'),
  );
}
