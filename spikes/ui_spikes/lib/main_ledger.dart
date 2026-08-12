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

/// Spike A — **Ledger**: a dense, provenance-first character editor.
///
/// The one idea, stated once: **a savegame stores base values and the engine
/// draws something else**. This application exists to make that safe to act
/// on, so here it is not a hint, a hover or a paragraph — it is the **column
/// structure**. A character is a table of rows with `STORED` and `IN GAME`
/// side by side and `OWNER` beside them, and everything else in the spike
/// follows from having chosen that shape.
///
/// Three consequences worth looking for on the screen:
///
/// 1. **Skills goes from thirteen fields to eleven rows.** The application
///    prints the same eight labels twice on that one tab, once under *Points
///    allocated* and again under *What the game shows*, with the same helper
///    text repeated verbatim seven times. Two columns do what two tables were
///    doing. See `lib/ledger/ledger_row.dart`.
/// 2. **The arithmetic wraps and the caveat does not compete with it.** The
///    sum is on the row, always visible, never ellipsised; the one thing no
///    number can say is behind the row's ⓘ.
/// 3. **A greyed field is still readable, and an anomalous one is still
///    editable.** Nothing is dimmed by opacity, because M3's 0.38 is exactly
///    the contrast failure that makes an unavailable row impossible to read —
///    and reading it is how a person finds out why it is grey.
///
/// Run:
/// ```sh
/// fvm flutter run -d linux -t lib/main_ledger.dart
/// SPIKE_SCREEN=character SPIKE_TAB=2 ./ui_spikes   # the Skills merge
/// SPIKE_SCREEN=inventory ./ui_spikes
/// ```
library;

import 'package:flutter/material.dart';
import 'package:ui_spikes/demo/aard.dart';
import 'package:ui_spikes/demo/boot.dart';
import 'package:ui_spikes/demo/demo_character.dart';
import 'package:ui_spikes/ledger/character_screen.dart';
import 'package:ui_spikes/ledger/home_screen.dart';
import 'package:ui_spikes/ledger/theme.dart';

/// Boots the Ledger spike.
void main() => runApp(const _LedgerApp());

/// Screen routing without a `Navigator`.
///
/// Two screens and one transition between them do not need a route table, and
/// a spike that grew one would be inviting a conversation about navigation
/// instead of about the sheet. What it *does* need is to open on any of them
/// without a click: nothing on this machine can drive the pointer, so a screen
/// that can only be reached by clicking cannot be photographed at all.
class _LedgerApp extends StatefulWidget {
  const _LedgerApp();

  @override
  State<_LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<_LedgerApp> {
  DemoCharacter? _open;
  int _section = 0;

  @override
  void initState() {
    super.initState();
    final requested = BootScreen.requested;
    _open = requested == BootScreen.home ? null : aard;
    _section = switch (requested) {
      BootScreen.home => 0,
      BootScreen.character => requestedTab,
      BootScreen.inventory => _inventorySection,
      // Spells arrived after this spike was frozen; it opens on the
      // first section instead.
      BootScreen.spells => 0,
    };
  }

  void _openCharacter(DemoCharacter character) => setState(() {
    _open = character;
    _section = 0;
  });

  void _close() => setState(() => _open = null);

  @override
  Widget build(BuildContext context) {
    final open = _open;
    return MaterialApp(
      title: 'Wand of Saves — Ledger',
      debugShowCheckedModeBanner: false,
      theme: LedgerTheme.light,
      darkTheme: LedgerTheme.dark,
      home: open == null
          ? HomeScreen(
              characters: const [aard, nadia],
              onOpen: _openCharacter,
            )
          : CharacterScreen(
              character: open,
              initialSection: _section,
              onClose: _close,
            ),
    );
  }
}

/// Where the Inventory destination sits in the rail, found rather than
/// hardcoded so that reordering `aard.sections` cannot silently boot the
/// capture onto the wrong screen.
int get _inventorySection {
  final index = aard.sections.indexWhere(
    (section) => section.title == 'Inventory',
  );
  return index < 0 ? 0 : index;
}
