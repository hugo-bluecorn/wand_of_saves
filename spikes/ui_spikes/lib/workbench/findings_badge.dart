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

/// How many things this application noticed, carried on every screen.
///
/// ## Why a badge rather than a drawer
///
/// The findings are **not notifications.** A notification is asynchronous,
/// external and time-based: it arrives while you are doing something else, it
/// queues, it goes stale, you dismiss it. These are *synchronous and derived* —
/// a property of the record that is open. They do not arrive; open the same
/// character tomorrow and they are the same three. You cannot dismiss one, only
/// fix it.
///
/// The right analogy is **diagnostics** — a problems panel, a linter's
/// output — and the panel already behaves like one: every finding carries an
/// `Open` that navigates to its subject. That reframing decides the
/// component. Notifications want a transient surface; diagnostics want a
/// persistent, addressable one you navigate *from*.
///
/// ⚠️ **And a drawer was structurally unavailable anyway.** `endDrawer` already
/// holds the field editor on both the character and inventory screens, so a
/// findings drawer would be replaced by the very thing it opened, losing the
/// reader's place. Two surfaces, one slot.
///
/// ## What Material actually offers
///
/// There is **no notification component in Material at all** — no tray, no
/// centre, no panel. That is an operating-system concern rather than a widget.
/// What exists is `SnackBar` (transient), `MaterialBanner` (one persistent
/// message, below the app bar), and [Badge], whose own documentation scopes it
/// to "a small amount of information about its child, like a count or status".
/// A list of things needing attention is something an application builds.
///
/// So the panel stays where it is — visible, not hidden, because curation is
/// this spike's whole argument — and the *count* travels, so a reader who has
/// scrolled away, opened the inventory or is standing in the palette still
/// knows there is something to come back to.
///
/// ⚠️ **The badge names no colour**, and so takes Material's default, which
/// is the error role. That is right when a conflict is present and slightly
/// overstated when every finding is a notice; the honest fix is a
/// severity-aware badge colour supplied by the theme rather than chosen
/// here, which is a change to make once a palette is settled.
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/workbench/findings.dart';

/// A badged control carrying the number of findings, for an app bar.
class FindingsBadge extends StatelessWidget {
  /// Creates a badge over [findings], calling [onPressed] when tapped.
  const FindingsBadge({
    required this.findings,
    required this.onPressed,
    super.key,
  });

  /// Everything this application noticed about the open record.
  final List<Finding> findings;

  /// What to do about it — scroll the panel into view, or go to the screen
  /// that has one.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return const SizedBox.shrink();

    final conflicts = findings
        .where((finding) => finding.severity == Severity.conflict)
        .length;

    // Spoken as a sentence rather than as a number, because "3" alone tells a
    // screen reader nothing about what it counts.
    final counted = findings.length == 1
        ? '1 thing to look at'
        : '${findings.length} things to look at';
    final spoken = conflicts == 0
        ? counted
        : conflicts == 1
        ? '$counted, 1 of them a conflict'
        : '$counted, $conflicts of them conflicts';

    return Semantics(
      button: true,
      label: spoken,
      excludeSemantics: true,
      child: Badge(
        label: Text('${findings.length}'),
        child: IconButton(
          onPressed: onPressed,
          tooltip: spoken,
          icon: const Icon(Icons.flag_outlined),
        ),
      ),
    );
  }
}
