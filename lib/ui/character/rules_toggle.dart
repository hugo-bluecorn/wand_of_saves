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

/// The rules check, as a visible mode rather than a hidden preference.
///
/// ⚠️ **A mode you cannot see is a mode that surprises you**, so this is a
/// labelled control in the app bar and not an item in a menu. On, a value the
/// rules would not produce is marked as a fault. Off, the same value is marked
/// as *enhanced* — the game will take it, so the application's job is to say
/// plainly that it is not what the rules would give you, not to prevent it.
///
/// That off state is the reason a save editor exists. Calling it *enhanced*
/// rather than *invalid* is the honest word for a value the engine accepts.
class RulesToggle extends StatelessWidget {
  /// Shows the check as [binding], and reports a flip through [onChanged].
  const RulesToggle({
    required this.binding,
    required this.onChanged,
    super.key,
  });

  /// Whether the rules currently bind.
  final bool binding;

  /// Called with the mode the user asked for.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: binding
          ? 'Rules check on — a value the rules would not produce is a fault'
          : 'Rules check off — values beyond the rules are allowed and marked',
      child: TextButton.icon(
        onPressed: () => onChanged(!binding),
        icon: Icon(
          binding ? Icons.rule : Icons.auto_fix_high_outlined,
          size: 18,
          color: binding ? null : colors.secondary,
        ),
        label: Text(
          binding ? 'Rules' : 'Enhanced',
          style: binding ? null : TextStyle(color: colors.secondary),
        ),
      ),
    );
  }
}
